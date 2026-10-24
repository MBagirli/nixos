{ config, ... }:
let
  home = config.home.homeDirectory;
in
{
  xdg.enable = true;

  # Creates the directories and writes ~/.config/user-dirs.dirs, which is
  # what file managers, screenshot tools and save dialogs read.
  xdg.userDirs = {
    enable = true;
    createDirectories = true;

    desktop     = "${home}/Desktop";
    documents   = "${home}/Documents";
    download    = "${home}/Downloads";
    music       = "${home}/Music";
    pictures    = "${home}/Pictures";
    videos      = "${home}/Videos";
    templates   = "${home}/Templates";
    publicShare = "${home}/Public";

    # Anything not in the freedesktop spec goes here.
    extraConfig = {
      XDG_PROJECTS_DIR    = "${home}/Projects";
      XDG_SCREENSHOTS_DIR = "${home}/Pictures/Screenshots";
    };
  };

  # Default applications, so xdg-open and "Open with" do the right thing.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "inode/directory" = "org.gnome.Nautilus.desktop";
      "image/png" = "imv.desktop";
      "image/jpeg" = "imv.desktop";
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "application/pdf" = "firefox.desktop";
    };
  };
}
