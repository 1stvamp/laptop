# laptop

A knixl project: swappable-desktop NixOS for the Framework 13 (AMD Ryzen AI 300),
testable in a VM first. KDL is the source of truth, and everything under
`generated/` (the flake included) is knixl output.

```
knixl.kdl              project: flake inputs, and the disko/home-manager modules
knixl.lock.kdl         knixl's lock: tool, modules, nixpkgs baseline, input revs
mise.toml              the knixl version, and the vm tasks
hosts/fw13.kdl         the laptop
hosts/vm-{gnome,plasma,cosmic}.kdl   one throwaway VM per desktop
modules/base/          local module: locale, audio, power, bootloader
modules/desktop/       local module: the DE selector
modules/vm-guest/      local module: QEMU guest agents, build-vm sizing, a VM password
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
   value, so it sits in `raw-nix`. `boot.kernelPackages` is there too, though it
   could now move to the built-in `os` module's `kernel-package` child.
4. **No mutual exclusion in schemas.** Nothing stops `desktop { gnome; plasma }`,
   and knixl generates it happily; you only find out from the NixOS eval conflict.
   A `one-of` schema constraint would catch it at generate time.
5. **No cross-host sharing.** Host files are standalone, which is why `base` exists
   as a module, and the four hosts still repeat the same `base` block body. The
   built-in `os` module now covers state version, timezone, locale, systemd-boot,
   EFI variables and nix experimental features, so `base` could shrink to the rest
   (keymap, unfree, networkmanager, pipewire, power, fwupd, printing).
6. **home-manager interiors are unchecked.** Since knixl 1.5.0 the oracle lets
   anything under `home-manager.users.<name>` through without checking it (before
   that it rejected all of it), because the NixOS options don't describe
   home-manager's per-user options.

## Verification status

Checked, with knixl 1.5.0. Later releases up to 1.6.0 left every system's
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
- `hardware-configuration.nix`. disko supplies the filesystems and nixos-hardware
  the platform bits, so the plan is to do without it, but `nixos-generate-config
  --no-filesystems` on the target is worth diffing against the evaluated config
  before the first `switch`.
