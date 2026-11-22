# NixOS side of wes's home: the login shell, and the home-manager module that knixl's
# home-manager node has no children for (program config, packages, files, dconf).
{ pkgs, ... }:
{
  programs.zsh.enable = true;
  users.users.wes.shell = pkgs.zsh;

  home-manager.users.wes.imports = [ ./wes.nix ];
}
