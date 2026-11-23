# Oneleet's agent and the host setup its deb's postinst would otherwise do.
{ lib, pkgs, ... }:
let
  oneleet = pkgs.oneleet;
in
{
  # An overlay so CI can build it alone, as nixosConfigurations.fw13.pkgs.oneleet.
  nixpkgs.overlays = [ (final: _: { oneleet = final.callPackage ./package.nix { }; }) ];

  environment.systemPackages = [ oneleet ];

  # The daemon has /opt/Oneleet compiled in. L+ also puts the link back at boot if
  # the self-updater has replaced it with a directory.
  systemd.tmpfiles.rules = [ "L+ /opt/Oneleet - - - - ${oneleet}/opt/Oneleet" ];

  # The unit `oneleet-daemon install` writes on other distros, under the same name.
  systemd.services.oneleet-daemon = {
    description = "Keeps your computer protected by enforcing secure policies";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # For its disk encryption, firewall and account checks.
    path = with pkgs; [
      util-linux
      cryptsetup
      iptables
      nftables
      shadow
      getent
    ];
    serviceConfig = {
      ExecStart = "/opt/Oneleet/oneleet-daemon";
      Restart = "always";
      RestartSec = 120;
    };
  };
}
