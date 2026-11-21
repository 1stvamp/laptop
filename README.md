# laptop

A knixl project: swappable-desktop NixOS for the Framework Laptop 13 Pro (Intel Core
Ultra Series 3, Panther Lake), testable in a VM first. KDL is the source of truth, and everything under
`generated/` (the flake included) is knixl output.

```
knixl.kdl              project: flake inputs, and the disko/home-manager modules
knixl.lock.kdl         knixl's lock: tool, modules, nixpkgs baseline, input revs
mise.toml              the knixl version, the vm tasks and the install task
hosts/fw13.kdl         the laptop
hosts/vm-{gnome,plasma,cosmic}.kdl   one throwaway VM per desktop
modules/base/          local module: keyboard, networking, audio, power, firmware, printing
modules/desktop/       local module: the DE selector
modules/vm-guest/      local module: QEMU guest agents, build-vm sizing, a VM password
home/default.nix       wes's login shell (zsh), and the import of home/wes.nix
home/wes.nix           home-manager config: zsh, git, gpg-agent, Vicinae, dconf, packages
home/files/            dotfiles: ~/bin, nvim-ai, wezterm, starship, mise
pkgs/claude-desktop/   Claude desktop from Anthropic's .deb, and its bump script
generated/             knixl output (flake.nix, hosts/*.nix), never hand-edited
generated/flake.lock   nix's lock, derived from knixl.lock.kdl, commit it
```

## The flake

knixl writes `generated/flake.nix` in input mode (ADR 0014, knixl 1.5.0 or later).
The inputs are declared in `system {}` in `knixl.kdl`: nixpkgs, nixos-hardware,
disko and home-manager, the last three following our nixpkgs.

Every input is pinned by rev in `knixl.lock.kdl`, and the rev is written into its
url in the generated flake, so `nix flake update` has nothing to move. nixpkgs has
no rev of its own: it is the hosts' shared baseline (26.05). Branch refs are
refused, which is why home-manager carries an explicit `rev=` (the tip of
`release-26.05` when it was pinned).

Each `oracle-modules` entry does two jobs: the oracle validates option paths
against that module, and each host's `nixosSystem` imports it. fw13 has its own
`oracle-modules` block to add the nixos-hardware profile, and because a host block
replaces the project set it repeats disko and home-manager.

The profile is `framework-intel-core-ultra-series3`, which is what nixos-hardware
calls the 13 Pro (its README links `frame.work/laptop13pro`). It is thin: fwupd, a
6.17 kernel floor, fingerprint, the Intel bits from `common/cpu/intel`, and touchscreen
modules in the initrd when unl0kr is on. It does not turn on
`hardware.enableRedistributableFirmware`, which would normally come from
`hardware-configuration.nix`, so fw13 sets it in `raw-nix` (without it there's no
wifi or GPU firmware and no microcode). The 13-inch common module also pulls in
the classic chassis speaker tuning; it's off by default and not tuned for the Pro,
so leave `hardware.framework.laptop13.audioEnhancement` alone.

**Note**: the project set applies to every host, so the VMs import the disko and
home-manager modules too. Both are inert without config.

## Testing desktops

```sh
mise run vm              # gnome; or: mise run vm plasma, mise run vm cosmic
```

That regenerates from the KDL, builds the VM into `result-vm-<desktop>` and boots
it in a window. You're logged in as `wes` automatically; the password is also
`wes`, for when the idle lock screen kicks in. 8GB, 4 cores.

The disk is a fresh temp image every run and is deleted when the VM exits, so
nothing persists between runs. `mise run vm:build <desktop>` does the first two
steps without booting.

Changing the laptop's desktop is one flag in `hosts/fw13.kdl`:

```kdl
desktop {
    gnome     // -> plasma, or cosmic
}
```

then `knixl generate && nixos-rebuild switch --flake ./generated#fw13`. On the
metal you can also skip the regenerate cycle: fw13's `raw-nix` carries a
`specialisation.plasma`, so Plasma is a boot menu entry alongside the default.

## Home

knixl's `home-manager` node can set session variables and enable programs, and
that's all, so fw13 lists the programs there and everything else lives in
`home/wes.nix`: their settings, `home.packages`, dconf, the user services, and the
files. It comes in through fw13's `import "../home"` node.

The files under `home/files/` are linked into place as out-of-store symlinks
(`~/bin`, `~/.config/nvim-ai`, wezterm, starship, mise), the way the Dropbox links
worked, so editing them in place works without a rebuild. That only holds while
the repo is checked out at `~/projects/laptop`.

**Note**: secrets stay out of git. Copy them across once: `~/.secrets.zsh` (sourced
by zsh if it exists) for the tokens, plus `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.kube`,
`~/.config/gh/hosts.yml` and so on. `~/.claude` is left out as well, since parts
of it name private repos and this repo is public.

## Claude desktop

nixpkgs doesn't package it, so `pkgs/claude-desktop/` repackages Anthropic's
official `.deb` (adapted from kubastick/claude-desktop-nixos, MIT), plus the nix-ld
and KVM setup its Code and Cowork tabs need. `update.sh` points `sources.json` at
the newest version in Anthropic's apt repo, after checking the repo's signed index
against `archive-keyring.asc`. `.github/workflows/claude-desktop.yml` runs it daily
and opens a PR when the version moves.

**Note**: the workflow needs "Allow GitHub Actions to create and approve pull
requests" turned on in the repo settings. Its PRs don't trigger `check.yml`, so it
builds the package itself.

ChatGPT is in nixpkgs-unstable, and comes in from there once knixl 1.7.0 can take
packages from a second nixpkgs.

## Installing

Boot the laptop from the stock NixOS installer, run `passwd` there (it sets the
`nixos` user's password, which the installer's sshd needs), and find its address
with `ip addr`. Then, from a machine with this repo:

```sh
mise run install <address>
```

That runs `knixl check`, asks for the LUKS passphrase twice, and runs nixos-anywhere
against `./generated#fw13` (disko partitions and formats `/dev/nvme0n1`, then the
install). The passphrase is uploaded to `/tmp/secret.key` on the installer, which is
where disko reads it at format time. Last it asks for `wes`'s password, set with
`nixos-enter` on the new system, since nothing in the config sets one.

**Note**: this wipes `/dev/nvme0n1`.

It stops short of rebooting, so pull the stick first, then `ssh nixos@<address> sudo
reboot`.

## Loop

knixl itself is pinned in `mise.toml` (1.6.0, from the GitHub release, whose build
provenance mise verifies on install), so `mise install` in this directory gets the
version the lock was written with.

- `knixl plan` : what would change, writes nothing.
- `knixl generate` : apply. Refuses hand-edited generated files without `--accept-drift`.
- `knixl check` : CI gate, exits 0 only if generated matches the lock, and
  `generated/flake.lock` agrees with `knixl.lock.kdl`.
- `knixl upgrade --yes` : the only thing that moves pins (tool, modules, baseline, inputs).
- `knixl doc desktop` : typed reference for any node, including the local modules.
- `knixl install <pkg>` : add a package, verified under nix before it lands.

After an `upgrade` that moves a rev, `git add generated/` and then run
`nix flake lock` in `generated/`, or `check` fails. The add has to come first: in
a git flake nix only sees tracked files.

Overrides go at the KDL layer, in `raw-nix`, or in a hand-written module pulled in
with a host `import "<path>"`. Never in `generated/`.

## Known gaps, in rough priority order

Worth filing against knixl itself rather than working around forever:

1. **No btrfs in the disko built-in.** It models `ext4`/`vfat`/`swap`/`zfs` content
   under `luks`, so the btrfs-with-subvolumes layout (and the Timeshift-style
   snapshot workflow that goes with it) can't be expressed. fw13 uses LUKS + ext4
   as a result. ZFS *is* well covered and would give snapshots, but ZFS lags new
   kernels and fw13 runs `linuxPackages_latest`, so keep ZFS to the Framework
   Desktop, or pin a kernel ZFS supports.
2. **No desktop module in the stdlib.** Hence `modules/desktop/`. It is ~40 lines of
   plain bool sets and needs no Rust, so it is a reasonable stdlib candidate.
3. **`set` cannot emit package references.** `fonts.packages` needs a `pkgs.*`
   value, so it sits in `raw-nix`. (`boot.kernelPackages` moved to the `os` node.)
4. **No mutual exclusion in schemas.** Nothing stops `desktop { gnome; plasma }`,
   and knixl generates it happily; you only find out from the NixOS eval conflict.
   A `one-of` schema constraint would catch it at generate time.
5. **No cross-host sharing.** Host files are standalone, which is why `base` exists
   as a module, and the four hosts still repeat the same `os` and `base` blocks.
   `base` now only carries what `os` doesn't (keymap, unfree, networkmanager,
   pipewire, power, fwupd, printing).
6. **home-manager interiors are unchecked.** Since knixl 1.5.0 the oracle lets
   anything under `home-manager.users.<name>` through without checking it (before
   that it rejected all of it), because the NixOS options don't describe
   home-manager's per-user options.
7. **The luks node has no `passwordFile`.** So the one disko option the install
   needs is set in fw13's `raw-nix`, where the oracle can't check the path.

## Verification status

Checked, with knixl 1.6.0, after the move to the 13 Pro profile and the `os` node:

- `knixl check` is clean, and all four hosts evaluate.
- claude-desktop 6.28899.2 builds and its binary reports its version (run on
  Pop!_OS, not NixOS). `update.sh` refuses an index signed by any other key.
- The three VMs' toplevel derivations are unchanged by moving `base` into `os`.
- fw13 evaluates with firmware and Intel microcode on, nix-ld on, kernel 7.2.8,
  and disko's `passwordFile` at `/tmp/secret.key`.

`.github/workflows/check.yml` runs `knixl check` and evaluates every host on each
push and pull request, and passed on the first PR.

Checked earlier, with knixl 1.5.0. Later releases up to 1.6.0 left every system's
toplevel derivation unchanged:

- `knixl plan` and `knixl check` are clean.
- All four `nixosConfigurations` evaluate to a toplevel derivation, and so does
  fw13's `specialisation.plasma`.
- Adding `follows nixpkgs` to nixos-hardware left fw13's toplevel derivation
  unchanged.
- `vm-gnome`'s build-vm output builds. That caught `vm-guest` emitting its sizes
  as strings, which the 1.5.0 oracle couldn't see (1.5.1 checks `diskSize`, but
  still not `memorySize` or `cores`), so those sets now use `(scalar)`.
- `mise run vm gnome` boots headless to the graphical target with no failed units.
  That caught `base` setting `console.keyMap = "gb"`, which kbd doesn't have (it
  calls it `uk`), so the console keymap is now derived from the XKB layout.

Not checked:

- The GNOME desktop in a real window, the plasma and cosmic VMs, or anything on
  the metal.
- `mise run install`, end to end.
- Claude desktop on NixOS: its window, the Code tab under nix-ld, and Cowork's VM.
  `claude-desktop.yml` hasn't run either.
- Anything in `home/`, beyond evaluating it: no session has run zsh, Vicinae or the
  dconf settings yet.
- `hardware-configuration.nix`. disko supplies the filesystems and nixos-hardware
  the platform bits, so the plan is to do without it, but `nixos-generate-config
  --no-filesystems` on the target is worth diffing against the evaluated config
  before the first `switch`.
