# Oneleet's agent and the host setup its deb's postinst would otherwise do.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  oneleet = pkgs.oneleet;

  # The daemon builds its software inventory from dpkg-query, so give it the system's
  # and home-manager's packages in the format it asks for.
  installed = lib.unique (
    config.environment.systemPackages
    ++ lib.concatMap (u: u.home.packages) (lib.attrValues (config.home-manager.users or { }))
  );
  inventory = pkgs.writeText "oneleet-inventory.tsv" (
    lib.concatMapStrings (p: "${lib.getName p}\t${lib.getVersion p}\tNixOS\tinstalled\tamd64\n") (
      lib.filter lib.isDerivation installed
    )
  );
  # shortcut: ignores -f and prints the one format the daemon uses; extend if it asks for another.
  dpkg-query = pkgs.writeShellScript "dpkg-query" ''
    if [ "$#" -gt 0 ] && names="$(printf '%s\n' "$@" | ${lib.getExe pkgs.gnugrep} -v '^-')"; then
      ${lib.getExe pkgs.gawk} -F '\t' 'NR == FNR { want[$0]; next } $1 in want' <(printf '%s\n' "$names") ${inventory} | ${lib.getExe pkgs.gnugrep} .
    else
      cat ${inventory}
    fi
  '';
in
{
  # An overlay so CI can build it alone, as nixosConfigurations.fw13.pkgs.oneleet.
  nixpkgs.overlays = [ (final: _: { oneleet = final.callPackage ./package.nix { }; }) ];

  environment.systemPackages = [ oneleet ];

  # The daemon has /opt/Oneleet compiled in. L+ also puts the link back at boot if
  # the self-updater has replaced it with a directory.
  systemd.tmpfiles.rules = [
    "L+ /opt/Oneleet - - - - ${oneleet}/opt/Oneleet"
    # Where the daemon looks first. /usr/bin isn't on NixOS's PATH, so nothing else sees it.
    "L+ /usr/bin/dpkg-query - - - - ${dpkg-query}"
  ];

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
