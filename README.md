# nix-config

A knixl project: swappable-desktop NixOS for the Framework 13 (AMD Ryzen AI 300),
testable in a VM first. KDL is the source of truth, and everything under
`generated/` (the flake included) is knixl output.

```
knixl.kdl              project: flake inputs, and the disko/home-manager modules
knixl.lock.kdl         knixl's lock: tool, modules, nixpkgs baseline, input revs
hosts/fw13.kdl         the laptop
hosts/vm-{gnome,plasma,cosmic}.kdl   one throwaway VM per desktop
modules/base/          local module: locale, audio, power, bootloader
modules/desktop/       local module: the DE selector
modules/vm-guest/      local module: QEMU guest agents and build-vm sizing
generated/             knixl output (flake.nix, hosts/*.nix), never hand-edited
generated/flake.lock   nix's lock, derived from knixl.lock.kdl, commit it
```

## The flake

knixl writes `generated/flake.nix` in input mode (knixl 1.5.0, ADR 0014). The
inputs are declared in `system {}` in `knixl.kdl`: nixpkgs, nixos-hardware,
disko and home-manager, the last three following our nixpkgs.

Every input is pinned by rev in `knixl.lock.kdl`, and the rev is written into
its url in the generated flake, so `nix flake update` has nothing to move.
nixpkgs has no rev of its own: it is the hosts' shared baseline (26.05). Branch
refs are refused, which is why home-manager carries an explicit `rev=` (the
tip of `release-26.05` when it was pinned).

`oracle-modules` does two jobs per entry: the oracle validates option paths
against that module, and each host's `nixosSystem` imports it. fw13 has its own
`oracle-modules` block to add the nixos-hardware profile, and because a host
block replaces the project set it repeats disko and home-manager.

**Note**: the project set applies to every host, so the VMs import the disko
and home-manager modules too. Both are inert without config.

## Testing desktops

```sh
knixl generate
nixos-rebuild build-vm --flake ./generated#vm-gnome   # or vm-plasma, vm-cosmic
./result/bin/run-vm-gnome-vm
```

Autologin as `wes`, 8GB, 4 cores, nothing persists between runs.

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

- `knixl plan` : what would change, writes nothing.
- `knixl generate` : apply. Refuses hand-edited generated files without `--accept-drift`.
- `knixl check` : CI gate, exits 0 only if generated matches the lock, and
  `generated/flake.lock` agrees with `knixl.lock.kdl`.
- `knixl upgrade --yes` : the only thing that moves pins (tool, modules, baseline, inputs).
- `knixl doc desktop` : typed reference for any node, including the local modules.
- `knixl install <pkg>` : add a package, verified under nix before it lands.

After an `upgrade` that moves a rev, run `nix flake lock` in `generated/`, or
`check` fails. If this directory becomes a git repo, `git add generated/` first:
in a git flake nix only sees tracked files, so locking before the add fails.

Overrides go at the KDL layer, in `raw-nix`, or in a hand-written module pulled
in with a host `import "<path>"`. Never in `generated/`.

## Known gaps, in rough priority order

Worth filing against knixl itself rather than working around forever:

1. **No btrfs in the disko built-in.** It models `ext4`/`vfat`/`swap`/`zfs` content
   under `luks`, so the btrfs-with-subvolumes layout (and the Timeshift-style
   snapshot workflow that goes with it) is not expressible. fw13 uses LUKS + ext4
   as a result. ZFS *is* well covered and would give snapshots, but ZFS lags new
   kernels and fw13 runs `linuxPackages_latest`, so keep ZFS to the Framework
   Desktop, or pin a kernel ZFS supports.
2. **No desktop module in the stdlib.** Hence `modules/desktop/`. It is ~40 lines of
   plain bool sets and needs no Rust, so it is a reasonable stdlib candidate.
3. **`set` cannot emit package references.** `fonts.packages` needs a `pkgs.*`
   value, so it sits in `raw-nix`. `boot.kernelPackages` could move to the
   built-in `os` module's `kernel-package` child, which didn't exist when this
   was written; it is still in `raw-nix` for now.
4. **No mutual exclusion in schemas.** Nothing stops `desktop { gnome; plasma }`;
   it surfaces as a NixOS eval conflict, not a knixl error. A `one-of` schema
   constraint would catch it at generate time.
5. **No cross-host sharing.** Host files are standalone, which is why `base` exists
   as a module, and the four hosts still repeat the same `base` block body. The
   built-in `os` module now covers state version, timezone, locale, systemd-boot,
   EFI variables and nix experimental features, so `base` could shrink to the
   rest (keymap, unfree, networkmanager, pipewire, power, fwupd, printing).
6. **home-manager interiors are unchecked.** Since knixl 1.5.0 the oracle lets
   anything under `home-manager.users.<name>` through without checking it
   (before that it rejected all of it), because nixos options don't describe
   home-manager's per-user options.

## Verification status

Checked, with knixl 1.5.0:

- `knixl plan` and `knixl check` are clean.
- All four `nixosConfigurations` evaluate to a toplevel derivation, and so does
  fw13's `specialisation.plasma`.
- Adding `follows nixpkgs` to nixos-hardware left fw13's toplevel derivation
  unchanged.
- `vm-gnome`'s build-vm output builds. That caught `vm-guest` emitting its sizes
  as strings, which the oracle can't see (it punts on an `"auto" or int` type),
  so those sets now use `(scalar)`.

Not checked:

- Booting any of it, building the plasma and cosmic VMs, or anything on the metal.
- `hardware-configuration.nix`. disko supplies the filesystems and nixos-hardware
  the platform bits, so the plan is to do without it, but `nixos-generate-config
  --no-filesystems` on the target is worth diffing against the evaluated config
  before the first `switch`.
