#!/usr/bin/python3
"""Stop agents running type40-shaped root commands on this laptop.

One classifier, two callers:
  agent_guard.py hook      Claude Code PreToolUse hook for Bash (JSON on stdin)
  agent_guard.py askpass   sudo askpass helper (sudo is our parent process)
  agent_guard.py check '<shell command>'   print the verdict, for testing

Only a sudo that the local shell itself would run is judged. A sudo inside an
ssh argument or after `lab ... exec --` is never a local command start, so it
is ignored, as is anything run without sudo.
"""

from __future__ import annotations

import datetime
import html
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

STATE = Path.home() / ".local/state/agent-askpass"
LOG = STATE / "log"
LAST_FRESH_SECONDS = 1800

# Root on the laptop with any of these is never right: they only make sense on type40.
DENY_PROGRAMS = {"zfs", "zpool", "kvm-mode", "nixos-rebuild", "fsfreeze", "xfs_freeze"}
DENY_ARG = re.compile(r"/dev/zvol|/proc/sysrq-trigger|\btype40\b|\blab-[a-z0-9][a-z0-9-]*")
# Legitimate locally now and then, but worth a human look first.
ASK_PROGRAMS = {
    "mount", "umount", "wipefs", "parted", "sgdisk", "sfdisk", "fdisk", "gdisk",
    "blkdiscard", "losetup", "cryptsetup", "resize2fs", "xfs_growfs", "swapoff",
    "pvcreate", "vgcreate", "lvcreate", "lvremove", "vgremove", "lvresize",
    "reboot", "poweroff", "shutdown", "halt",
}
SHELLS = {"sh", "bash", "dash", "zsh"}
WRAPPERS = {"env", "timeout", "nice", "nohup", "time", "command", "exec", "stdbuf", "ionice", "setsid"}
SUDO_OPTS_WITH_ARG = {"-u", "-g", "-h", "-p", "-C", "-D", "-r", "-t", "-U", "-T", "-R"}

REMOTE_HINT = (
    "Run it where it belongs: `lab vm exec <vm> -- <cmd>`, `lab cell exec <cell> -- <cmd>`, "
    "or `lab host exec -- <cmd>` for type40 itself (or `ssh type40 '<cmd>'`). If it really is "
    "meant for this laptop, stop and ask Wes to run it himself."
)


def _strip_heredocs(text: str) -> str:
    out, lines, i = [], text.split("\n"), 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        m = re.search(r"<<-?\s*(['\"]?)(\w+)\1", line)
        i += 1
        if m:
            end = m.group(2)
            while i < len(lines) and lines[i].strip() != end:
                i += 1
            i += 1
    return "\n".join(out)


def _segments(text: str) -> list[str]:
    """Split on unquoted ; & | newline ( ) into simple-command strings."""
    segs, cur, q, i = [], [], None, 0
    while i < len(text):
        c = text[i]
        if q:
            cur.append(c)
            if c == "\\" and q == '"' and i + 1 < len(text):
                cur.append(text[i + 1])
                i += 1
            elif c == q:
                q = None
        elif c in "'\"":
            q = c
            cur.append(c)
        elif c == "\\" and i + 1 < len(text):
            cur.append(c + text[i + 1])
            i += 1
        elif c in ";&|\n()":
            segs.append("".join(cur))
            cur = []
        elif c == "#" and (not cur or cur[-1].isspace()):
            while i < len(text) and text[i] != "\n":
                i += 1
            continue
        else:
            cur.append(c)
        i += 1
    segs.append("".join(cur))
    return [s for s in segs if s.strip()]


def _unwrap(words: list[str]) -> list[str]:
    """Drop leading VAR=val assignments and wrappers like env/timeout/nice."""
    while words:
        w = words[0]
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", w):
            words = words[1:]
        elif os.path.basename(w) in WRAPPERS:
            words = words[1:]
            while words and (words[0].startswith("-") or re.fullmatch(r"[0-9.]+[smhd]?", words[0])
                             or re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", words[0])):
                words = words[1:]
        else:
            return words
    return words


def _after_sudo(words: list[str]) -> list[str]:
    i = 1
    while i < len(words):
        w = words[i]
        if w == "--":
            return words[i + 1:]
        if not w.startswith("-") or re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", w):
            break
        i += 2 if w in SUDO_OPTS_WITH_ARG else 1
    return _unwrap(words[i:])


def _shell_c(words: list[str]) -> str | None:
    if words and os.path.basename(words[0]) in SHELLS:
        for j, w in enumerate(words[1:], 1):
            if w.startswith("-") and "c" in w and not w.startswith("--") and j + 1 < len(words):
                return words[j + 1]
    return None


def judge_root_argv(argv: list[str]) -> tuple[str | None, str]:
    """Verdict for a command that will run as root on this laptop."""
    argv = _unwrap(argv)
    if not argv:
        return None, ""
    inner = _shell_c(argv)
    if inner is not None:
        return judge_shell(inner, root=True)
    prog = os.path.basename(argv[0])
    joined = " ".join(argv)
    if prog in DENY_PROGRAMS or prog.startswith("zfs"):
        return "deny", f"`{prog}` as root on this laptop"
    if prog in ("mount", "umount") and re.search(r"remount|(^|\s)/(\s|$)", joined):
        return "deny", "remounting or unmounting / on this laptop"
    if m := DENY_ARG.search(joined):
        return "deny", f"root command on this laptop mentions `{m.group(0)}`"
    if prog in ASK_PROGRAMS or prog.startswith("mkfs") or (
        prog == "dd" and re.search(r"\bof=/dev/", joined)
    ):
        return "ask", f"`{prog}` as root on this laptop"
    return None, ""


def judge_shell(text: str, root: bool = False) -> tuple[str | None, str]:
    worst: tuple[str | None, str] = (None, "")
    for seg in _segments(_strip_heredocs(text)):
        try:
            words = shlex.split(seg, comments=False)
        except ValueError:
            continue
        words = _unwrap(words)
        if not words:
            continue
        verdict: tuple[str | None, str] = (None, "")
        if os.path.basename(words[0]) == "sudo":
            verdict = judge_root_argv(_after_sudo(words))
        elif root:
            verdict = judge_root_argv(words)
        elif (inner := _shell_c(words)) is not None:
            verdict = judge_shell(inner)
        if verdict[0] == "deny":
            return verdict
        if verdict[0] == "ask" and worst[0] is None:
            worst = verdict
    return worst


# ---- who is asking ----

def session_info(env=os.environ) -> str:
    sid = env.get("CLAUDE_CODE_SESSION_ID", "")
    if not sid:
        return "not a Claude Code session (no CLAUDE_CODE_SESSION_ID)"
    parts = []
    pid = env.get("CLAUDE_PID", "")
    try:
        parts.append(os.readlink(f"/proc/{pid}/cwd").replace(str(Path.home()), "~"))
    except OSError:
        pass
    title = ""
    for f in (Path.home() / ".claude/projects").glob(f"*/{sid}.jsonl"):
        try:
            with open(f, errors="replace") as fh:
                for line in fh:
                    if '"customTitle"' in line or '"aiTitle"' in line:
                        try:
                            d = json.loads(line)
                        except ValueError:
                            continue
                        if d.get("customTitle"):
                            title = d["customTitle"]
                        elif d.get("aiTitle") and not title:
                            title = d["aiTitle"]
        except OSError:
            pass
    if title:
        parts.append(f'"{title}"')
    parts.append(f"session {sid[:8]}")
    return " · ".join(parts)


def log(decision: str, who: str, cmd: str, why: str = "") -> None:
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG, "a") as fh:
            ts = datetime.datetime.now().isoformat(timespec="seconds")
            fh.write(json.dumps({"ts": ts, "decision": decision, "who": who, "why": why, "cmd": cmd}) + "\n")
    except OSError:
        pass


def record_last(sid: str, cmd: str, desc: str, cwd: str) -> None:
    """Remember the session's latest Bash call, so askpass can show what the agent meant."""
    if not re.fullmatch(r"[A-Za-z0-9-]+", sid or ""):
        return
    try:
        STATE.mkdir(parents=True, exist_ok=True)
        tmp = STATE / f".last-{sid}.tmp"
        tmp.write_text(json.dumps({"cmd": cmd, "desc": desc, "cwd": cwd,
                                   "ts": datetime.datetime.now().timestamp()}))
        tmp.replace(STATE / f"last-{sid}.json")
    except OSError:
        pass


def last_call(env=os.environ) -> dict:
    sid = env.get("CLAUDE_CODE_SESSION_ID", "")
    try:
        d = json.loads((STATE / f"last-{sid}.json").read_text())
    except (OSError, ValueError):
        return {}
    if datetime.datetime.now().timestamp() - d.get("ts", 0) > LAST_FRESH_SECONDS:
        return {}
    return d


def ancestry(pid: int, stop_at: str = "claude", limit: int = 8) -> str:
    """The processes above `pid` up to Claude, e.g. `bash run.sh  <-  bash -c ...  <-  claude`."""
    chain = []
    for _ in range(limit):
        try:
            stat = Path(f"/proc/{pid}/stat").read_text()
            ppid = int(stat.rsplit(")", 1)[1].split()[1])
            args = Path(f"/proc/{ppid}/cmdline").read_bytes().split(b"\0")
        except (OSError, ValueError, IndexError):
            break
        words = [a.decode(errors="replace") for a in args if a]
        if not words:
            break
        name = os.path.basename(words[0])
        short = " ".join(words)
        chain.append(name if name == stop_at else (short[:90] + ("…" if len(short) > 90 else "")))
        if name == stop_at or ppid <= 1:
            break
        pid = ppid
    return "  <-  ".join(chain)


# ---- entry points ----

def hook() -> int:
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return 0
    if data.get("tool_name") != "Bash":
        return 0
    cmd = (data.get("tool_input") or {}).get("command", "")
    record_last(data.get("session_id", ""), cmd, (data.get("tool_input") or {}).get("description", ""),
                data.get("cwd", ""))
    decision, why = judge_shell(cmd)
    if not decision:
        return 0
    log(f"hook-{decision}", session_info(), cmd, why)
    reason = f"Blocked: {why}. Is this meant for type40 or a lab VM/cell? {REMOTE_HINT}"
    if decision == "ask":
        reason = f"Check: {why}. Make sure this is meant for this laptop. {REMOTE_HINT}"
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }}))
    return 0


def askpass() -> int:
    try:
        raw = Path(f"/proc/{os.getppid()}/cmdline").read_bytes()
        argv = [a.decode(errors="replace") for a in raw.split(b"\0") if a]
    except OSError:
        argv = []
    try:
        cwd = os.readlink(f"/proc/{os.getppid()}/cwd")
    except OSError:
        cwd = "?"
    cmd = shlex.join(argv) if argv else "(could not read the sudo command)"
    who = session_info()
    if argv and os.path.basename(argv[0]) == "sudo":
        decision, why = judge_root_argv(_after_sudo(argv))
    else:
        decision, why = "ask", "could not read the command sudo is running"
    if decision == "deny":
        log("askpass-refused", who, cmd, why)
        subprocess.Popen(
            ["zenity", "--warning", "--timeout=30", "--width=640", "--title=sudo refused (agent-askpass)",
             f"--text=<b>Refused without asking:</b> {html.escape(why)}\n\n"
             f"<tt>{html.escape(cmd)}</tt>\n\n{html.escape(who)}\n\nLog: {LOG}"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
        print(f"agent-askpass refused: {why}. {REMOTE_HINT}", file=sys.stderr)
        return 1
    warn = (f'<span foreground="red"><b>Careful: {html.escape(why)}.</b> Is this meant for type40?</span>\n\n'
            if decision else "")
    last = last_call()
    tool = ""
    if last:
        desc = last.get("desc") or "(no description)"
        full = last.get("cmd", "")
        full = full if len(full) <= 600 else full[:600] + " …"
        tool = (f"<b>Agent says it is:</b> {html.escape(desc)}\n"
                f"<b>Its Bash call</b>\n<tt>{html.escape(full)}</tt>\n\n")
    host = os.uname().nodename
    text = (f"{warn}<b>sudo will run, as root on {html.escape(host)} (this laptop)</b>\n"
            f"<tt>{html.escape(cmd)}</tt>\n\n{tool}"
            f"<b>In</b> {html.escape(cwd)}\n<b>From</b> {html.escape(who)}\n"
            f"<b>Called via</b> <tt>{html.escape(ancestry(os.getppid()))}</tt>\n\nPassword:")
    r = subprocess.run(
        ["zenity", "--entry", "--hide-text", "--width=720",
         "--title=sudo password (Claude Code)", f"--text={text}"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
    )
    log("askpass-" + ("given" if r.returncode == 0 else "cancelled"), who, cmd, why)
    if r.returncode != 0:
        return 1
    sys.stdout.write(r.stdout)
    return 0


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "hook":
        return hook()
    if mode == "askpass":
        return askpass()
    if mode == "check" and len(sys.argv) > 2:
        print(judge_shell(sys.argv[2]))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
