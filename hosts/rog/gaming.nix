{ pkgs, ... }:
{
  # Not imported by default — uncomment the line in hosts/rog/default.nix.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
    gamescopeSession.enable = true;
  };

  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    mangohud
    protonup-qt
  ];

  # Steam pulls tens of GB. On a 512G disk, watch `df -h` after installing.
}
