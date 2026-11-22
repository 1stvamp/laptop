# laptop

NixOS for the Framework Laptop 13 Pro (Intel Core Ultra Series 3), written as knixl KDL.

- The KDL is the source of truth: `knixl.kdl`, `hosts/*.kdl` and `modules/*/knixl-module.kdl`. Every host setting goes there, as a knixl node where one exists (`knixl doc <node>`), otherwise in the host's `raw-nix` block with a comment saying why no node can carry it.
- `generated/` is knixl output, the flake included. Never edit it. After changing KDL run `knixl generate`, then `knixl check`, and commit the regenerated files and `knixl.lock.kdl` with the change.
- After changing an input or a rev: `knixl upgrade --yes`, `knixl generate`, `git add generated/`, then `nix flake lock` in `generated/`. The add has to come first, since nix only sees tracked files in a git flake.
- Reusable Nix that no node can express (a derivation, a module defining options) goes in its own file and comes in through a host `import "<path>"` node. Never `imports =` in raw-nix.
- Verify a change by evaluating every host: `nix eval --raw ./generated#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` for fw13, vm-gnome, vm-plasma and vm-cosmic (this is what CI runs). A change meant for one host should leave the others' drvPaths unchanged.
- `mise run vm <desktop>` boots a throwaway VM; `mise run install <address>` wipes and installs the laptop, so never run it without being asked.
- wes's home-manager config is `home/wes.nix` (program enables stay in fw13's `home-manager` node). Files under `home/files/` are out-of-store symlinks into this checkout. This repo is public: no secrets, and nothing naming private trigger.dev repos or internal tooling.
