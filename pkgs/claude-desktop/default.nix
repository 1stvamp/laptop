# Claude desktop plus the host setup its Code and Cowork tabs need. Adapted from
# github.com/kubastick/claude-desktop-nixos (MIT, see ./LICENSE).
{ lib, pkgs, ... }:
{
  # An overlay so CI can build it alone, as nixosConfigurations.fw13.pkgs.claude-desktop.
  nixpkgs.overlays = [ (final: _: { claude-desktop = final.callPackage ./package.nix { }; }) ];

  environment.systemPackages = [ pkgs.claude-desktop ];
  # D-Bus activation for the GNOME Shell search provider.
  services.dbus.packages = [ pkgs.claude-desktop ];

  # The Code tab downloads a generic-Linux Claude Code CLI; it can't be patched
  # without failing the app's checksum, so it needs nix-ld.
  programs.nix-ld.enable = true;

  # Cowork runs a QEMU/KVM VM and probes these FHS paths for its firmware and virtiofsd.
  boot.kernelModules = [ "vhost_vsock" ];
  users.users.wes.extraGroups = [ "kvm" ];
  systemd.tmpfiles.rules = [
    "d /usr/share 0755 root root -"
    "d /usr/libexec 0755 root root -"
    "L+ /usr/share/OVMF - - - - ${pkgs.OVMF.fd}/FV"
    "L+ /usr/libexec/virtiofsd - - - - ${lib.getExe pkgs.virtiofsd}"
  ];
}
