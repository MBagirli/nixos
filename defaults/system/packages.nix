{ lib, pkgs, ... }:
{
  # ---------------------------------------------------------------------
  # THE PACKAGE CATALOG — every package in the system is named in this
  # file, whether it is installed for everyone or only for some people.
  #
  #   environment.systemPackages  installed for EVERY user, plus root
  #   my.optionalPackages         declared here, installed for NOBODY
  #                               until a user opts in by name
  #
  # Opting in happens per package (not per bundle) in users/default.nix:
  #
  #   murad = { admin = true; packages = [ "vscode" "keepass" ]; };
  #
  # Nothing is duplicated on disk by listing a package for several users.
  # A nix package is a content-addressed store path, so pkgs.vscode is the
  # same /nix/store/...-vscode for everyone: it is downloaded and stored
  # ONCE and each user's profile gets a symlink to it. Naming a package
  # under two users costs one symlink, not a second copy.
  # ---------------------------------------------------------------------
  options.my.optionalPackages = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    default = { };
    description = ''
      Apps that exist in the config but are installed only for the users
      who name them in users/default.nix. The attribute name is the name
      users refer to; asking for a name that is not here is a build error
      rather than a silent no-op, so typos are caught at eval time.
    '';
  };

  config = {
    # ---- installed for everyone ----
    # Apps whose config is managed in defaults/home/ do NOT belong here —
    # kitty, waybar, rofi, dunst, hyprlock and fastfetch are installed by
    # their programs.*.enable lines.
    environment.systemPackages = with pkgs; [
      # ---- CLI ----
      git
      wget
      curl
      unzip
      p7zip
      tree
      ripgrep
      fd
      file
      lsof
      vim
      htop
      btop
      brightnessctl
      playerctl
      wl-clipboard
      libnotify
      usbutils
      pciutils
      freerdp
      zip
      gzip
      inetutils
      samba
      cifs-utils
      python3
      # Not pip: it cannot install into the read-only store python, and
      # wheels with compiled code cannot find their libraries on NixOS.
      # `uv venv` / `uv pip install` inside a project venv works.
      uv

      # ---- screenshots ----
      grim
      slurp
      swappy

      # ---- display management ----
      nwg-displays        # GUI: drag monitors around, writes hypr syntax
      wlr-randr           # CLI equivalent, useful for scripts
      wayvnc              # driven by the `virtual-monitor` script
      luminance           # GUI: brightness slider for every monitor
      ddcutil             # DDC/CI backend for external monitor brightness

      # ---- GUI ----
      firefox
      nautilus            # file manager; integration in desktop.nix
      ffmpegthumbnailer   # video thumbnails in Nautilus
      mpv
      imv
      pwvucontrol         # sound mixer (right-click the volume in the bar)
      overskride          # Bluetooth pairing (right-click Bluetooth in the bar)
      networkmanagerapplet  # for nm-connection-editor; the applet itself is hidden

      # ---- icon themes ----
      # papirus is primary; the other two are fallbacks rofi walks when
      # papirus has no match for a .desktop Icon= name
      papirus-icon-theme
      adwaita-icon-theme
      hicolor-icon-theme
    ];

    # ---- declared here, switched on per user in users/default.nix ----
    my.optionalPackages = {
      vscode      = pkgs.vscode;
      claude-code = pkgs.claude-code;
      keepass     = pkgs.keepass;
      openconnect = pkgs.openconnect;
      cmatrix     = pkgs.cmatrix;
      wireshark   = pkgs.wireshark;
      volatility3 = pkgs.volatility3;
      detect-it-easy = pkgs.detect-it-easy;
      kubectl = pkgs.kubectl;
      kubernetes-helm = pkgs.kubernetes-helm;
      kubelogin-oidc = pkgs.kubelogin-oidc;
      kubelogin = pkgs.kubelogin;
      azure-cli = pkgs.azure-cli;
      zoom-us = pkgs.zoom-us;
    };
  };

  # NOTE: no firewall rules here. Ports live in defaults/system/core.nix
  # with the rest of the networking config. 5900 (wayvnc) is deliberately
  # NOT opened — see the comment there.
}
