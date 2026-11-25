# home-manager config for wes. Program enables live in hosts/fw13.kdl (the
# home-manager node); their settings, packages, files and dconf live here.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Config that gets edited in place (nvim, wezterm, starship, ~/bin) is symlinked to
  # the checkout rather than copied into the store, so this path must exist.
  repo = "${config.home.homeDirectory}/projects/laptop/home/files";
  live = path: config.lib.file.mkOutOfStoreSymlink "${repo}/${path}";

  # One tiling extension only (Tiling Shell); two fight over the same windows.
  extensions = with pkgs.gnomeExtensions; [
    vicinae
    dash-to-dock
    appindicator
    tiling-shell
    vitals
    gsconnect
    caffeine
  ];
in
{
  home.sessionVariables = {
    # Serena's TS language server is slow to warm up in the big monorepos.
    MCP_TIMEOUT = "60000";
    TRIGGERDOTDEV_REPOS_PATH = "${config.home.homeDirectory}/projects/trigger";
    PNPM_HOME = "${config.home.homeDirectory}/.local/share/pnpm";
    DEBFULLNAME = "Wes Mason (1stvamp)";
    DEBEMAIL = "wes@1stvamp.org";
  };

  home.sessionPath = [
    "$HOME/bin"
    "$HOME/.local/bin"
    "$HOME/go/bin"
    "$HOME/.cargo/bin"
    "$PNPM_HOME/bin"
  ];

  home.file."bin".source = live "bin";
  xdg.configFile."nvim".source = live "nvim";
  xdg.configFile."wezterm/wezterm.lua".source = live "wezterm.lua";
  xdg.configFile."starship.toml".source = live "starship/starship.toml";
  xdg.configFile."starship/gitbutler-branch.sh".source = live "starship/gitbutler-branch.sh";
  xdg.configFile."mise/config.toml".source = live "mise/config.toml";
  xdg.dataFile."gnome-shell/extensions/hide-vicinae-from-dock@laptop".source =
    live "gnome-shell/hide-vicinae-from-dock@laptop";

  programs.zsh = {
    history = {
      size = 20000;
      save = 20000;
      extended = true;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };
    oh-my-zsh = {
      enable = true;
      # No theme: starship draws the prompt.
      plugins = [
        "sudo"
        "extract"
        "colored-man-pages"
      ];
    };
    shellAliases = {
      clear = "timeout 3 cmatrix; clear || clear";
      ls = "lsd";
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
      sl = "ls";
      "cd.." = "cd ..";
      monitor = "gsettings set org.gnome.desktop.interface text-scaling-factor 1.5";
      laptop = "gsettings set org.gnome.desktop.interface text-scaling-factor 1.0";
      tf = "tofu";
      kc = "kubectl";
      kx = "kubectx";
      p = "pnpm";
      cat = "bat";
      less = "bat --paging=always";
      du = "dust";
      ping = "gping";
      diff = "difff";
      diffs = "difft --check-only --exit-code";
      copy-to-clipboard = "wl-copy";
      act = "gh act";
      pp = "pull && push";
      open-pr = "gh pr view --web";
      assume = ". assume";
      "1p" = "1password --quick-access &>/dev/null";
      c = ''claude --system-prompt="$(serena prompts print-cc-system-prompt-override)"'';
      cr = "c -r";
      cc = "c -c";
      cu = "claude update";
      resource = "exec zsh";
      query-ts = "query-ts --api-key=$(cd ~/projects/homelab/; swamp vault read-secret --force --json homelab-secrets TAILSCALE_API_KEY | jq -r .value)";
      rt = "rename-tab $(basename $PWD)";
      trigger-webapp = "pnpm -C ~/projects/trigger/trigger.dev run dev --filter webapp";
      trigger-up = "(cd ~/projects/trigger/trigger.dev && swamp workflow run triggerdev-dev-up)";
      trigger-down = "(cd ~/projects/trigger/trigger.dev && swamp workflow run triggerdev-dev-down)";
    };
    initContent = ''
      bindkey ' ' magic-space

      g() { if [ $# -gt 0 ]; then git "$@"; else git st; fi; }

      # pull/push/pr/pushpr use GitButler's `but` in a GitButler workspace, else git.
      _in_gitbutler_workspace() {
        [ "$(git symbolic-ref --short HEAD 2>/dev/null)" = "gitbutler/workspace" ]
      }
      pull() { if _in_gitbutler_workspace; then but pull "$@"; else git pull "$@"; fi; }
      push() { if _in_gitbutler_workspace; then but push "$@"; else git push "$@"; fi; }
      pushpr() { if _in_gitbutler_workspace; then but pr new "$@"; else git push && open-pull-request; fi; }
      pr() { if _in_gitbutler_workspace; then but pr new "$@"; else open-pull-request "$@"; fi; }

      rename-tab() { wezterm cli set-tab-title "$@"; }

      rm-untracked() { git status -s | sed -n 's/^?? //p' | while read -r f; do rm -rf -- "$f"; done; }

      webm2gif() {
        ffmpeg -y -i "$1" -vf palettegen _tmp_palette.png
        ffmpeg -y -i "$1" -i _tmp_palette.png -filter_complex paletteuse -r 10 "''${1%.webm}.gif"
        rm _tmp_palette.png
      }

      # The starship env_var segment shows the superproject's name inside a submodule.
      _set_git_root_dir() {
        [ "$_OLD_GR_PWD" = "$PWD" ] && return
        _OLD_GR_PWD="$PWD"
        GIT_ROOT_DIR=$(git root-dir 2>/dev/null)
        GIT_SUPER_ROOT_DIR=$(git super-root-dir 2>/dev/null)
        if [ -n "$GIT_SUPER_ROOT_DIR" ] && [ "$GIT_ROOT_DIR" != "$GIT_SUPER_ROOT_DIR" ]; then
          export STARSHIP_DIRECTORY_BEFORE_REPO="$(basename "$GIT_SUPER_ROOT_DIR")/"
        else
          export STARSHIP_DIRECTORY_BEFORE_REPO=
        fi
      }
      precmd_functions+=(_set_git_root_dir)

      # Tokens are copied over by hand, never committed.
      [ -f ~/.secrets.zsh ] && . ~/.secrets.zsh
    '';
  };

  programs.git = {
    signing = {
      key = "Wes Mason (1stvamp) <wes@1stvamp.org>";
      signByDefault = true;
    };
    lfs.enable = true;
    settings = {
      user = {
        name = "Wes Mason";
        email = "wes@1stvamp.org";
      };
      github.user = "1stvamp";
      alias = {
        st = "status -s";
        ci = "commit";
        br = "branch";
        co = "checkout";
        df = "diff";
        lg = "log -p";
        up = "pull";
        ad = "add";
        comit = "commit";
        oops = "commit --amend";
        pop = "stash pop";
        pus = "push";
        pul = "pull";
        psh = "push";
        pll = "pull";
        git = "!exec git";
        fu = "push --force-with-lease -u";
        sha = "rev-parse HEAD";
        root-dir = "rev-parse --show-toplevel";
        super-root-dir = "rev-parse --show-superproject-working-tree";
        unstash = "stash pop";
      };
      color = {
        ui = "auto";
        branch = {
          current = "yellow reverse";
          local = "yellow";
          remote = "green";
        };
        diff = {
          meta = "yellow bold";
          frag = "magenta bold";
          old = "red bold";
          new = "green bold";
        };
        status = {
          added = "yellow";
          changed = "green";
          untracked = "cyan";
        };
      };
      branch.autosetupmerge = true;
      push = {
        default = "current";
        followTags = true;
      };
      merge.conflictStyle = "zdiff3";
      rerere.enabled = true;
      transfer.fsckobjects = true;
      fetch.fsckobjects = true;
      receive.fsckObjects = true;
      init.defaultBranch = "main";
      url."git+ssh://wesmason@git.launchpad.net/".insteadOf = "lp:";
      diff = {
        tool = "difftastic";
        noprefix = true;
        external = "difft";
      };
      difftool.prompt = false;
      "difftool \"difftastic\"".cmd = ''difft "$MERGED" "$LOCAL" "abcdef1" "100644" "$REMOTE" "abcdef2" "100644"'';
      pager.difftool = true;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  # gh as git's credential helper, replacing the snap path in the old gitconfig.
  programs.gh.gitCredentialHelper.enable = true;

  # SSH through gpg-agent, keys on the Yubikey.
  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  programs.wezterm.enableZshIntegration = true;

  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    # GNOME has no layer shell; the GNOME extension below does the floating window.
    settings.launcher_window.layer_shell.enabled = false;
  };

  dconf.settings = {
    "org/gnome/shell".enabled-extensions = map (e: e.extensionUuid) extensions ++ [
      "hide-vicinae-from-dock@laptop"
    ];
    # GTK3 apps styled like libadwaita ones.
    "org/gnome/desktop/interface".gtk-theme = "adw-gtk3";
    "org/gnome/desktop/input-sources" = {
      sources = [ (lib.hm.gvariant.mkTuple [ "xkb" "gb" ]) ];
      xkb-options = [ "caps:escape" ];
    };
    # The COSMIC settings carried over: 600ms delay, 25 repeats a second.
    "org/gnome/desktop/peripherals/keyboard" = {
      delay = lib.hm.gvariant.mkUint32 600;
      repeat-interval = lib.hm.gvariant.mkUint32 40;
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      tap-to-click = true;
      tap-and-drag = true;
      click-method = "fingers";
      two-finger-scrolling-enabled = true;
      natural-scroll = false;
    };
    # Alt+Space is Vicinae's; GNOME has it opening the window menu.
    "org/gnome/desktop/wm/keybindings".activate-window-menu = [ ];
    "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = [
      "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vicinae/"
    ];
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vicinae" = {
      name = "Vicinae";
      command = "vicinae toggle";
      binding = "<Alt>space";
    };
  };

  systemd.user.services.pnpm-deps-watch = {
    Unit.Description = "pnpm deps drift marker (.pnpm-install-needed in the trigger.dev checkout)";
    Service = {
      ExecStart = "${config.home.homeDirectory}/bin/pnpm-deps-watch";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.disk-janitor = {
    Unit.Description = "Free disk when / runs low (container cache, idle /tmp, unused Rust targets)";
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/bin/disk-janitor";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };
  systemd.user.timers.disk-janitor = {
    Unit.Description = "Check free disk every 10 minutes";
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "10min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  home.packages = extensions ++ (with pkgs; [
    gradia
    iotas
    resources
    gnome-extension-manager
    refine
    adw-gtk3
    wl-clipboard
    yubikey-manager
    # shell tools the aliases and prompt expect
    lsd
    dust
    gping
    difftastic
    cmatrix
    zellij
    hyperfine
    tealdeer
    choose
    eva
    huniq
    jql
    glow
    httpie
    procs
    bottom
    trippy
    yt-dlp
    asciinema
    asciinema-agg
    ffmpeg
    yq-go
    # dev
    gh
    uv
    rustup
    go
    gopls
    actionlint
    shellcheck
    shellharden
    cargo-audit
    cargo-deny
    cargo-release
    cargo-dist
    cargo-fuzz
    neovide
    kubectl
    kubectx
    k9s
    kubernetes-helm
    awscli2
    granted
    flyctl
    mkcert
    sops
    age
    ncdu
    nmap
    testssl
    infisical
    aws-vault
  ]);
}
