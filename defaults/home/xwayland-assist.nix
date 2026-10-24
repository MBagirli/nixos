{ pkgs, ... }:
let
  # What it does and why is at the top of the script.
  assist = pkgs.writers.writePython3 "xwayland-assist" {
    libraries = [ pkgs.python3Packages.xlib ];
    flakeIgnore = [ "E501" "W503" "W504" ];
  } (builtins.readFile ./xwayland-assist.py);
in
{
  # Hyprland leaves two X11 window-manager jobs undone; this does them for
  # every XWayland app. Found through Zoom: its sharing toolbar stopped
  # taking clicks once the meeting window had been focused, and its
  # floating video could only be moved with Super+drag.
  systemd.user.services.xwayland-assist = {
    Unit = {
      Description = "X11 window-manager duties Hyprland skips";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${assist}";
      # Exits with Hyprland/XWayland; comes back with the next one.
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
