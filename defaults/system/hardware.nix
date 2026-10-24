{ pkgs, ... }:
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;   # exposes headset battery levels
  };
  # No blueman: its applet had nowhere to show (no tray) and its manager
  # was the unfriendly part. The bar's Bluetooth icon opens bt-menu
  # (defaults/home/menus.nix); right-click opens Overskride for pairing.

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # ---- brightness ----
  # Laptop panel (eDP-1): brightnessctl drives the XF86MonBrightness keys
  # (through logind, no extra permissions needed). Luminance writes the
  # sysfs backlight node directly, so the video group gets write access.
  # programs.light was removed from nixpkgs — unmaintained upstream.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video $sys$devpath/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w $sys$devpath/brightness"
  '';

  # External monitors (DP-1): brightness over DDC/CI. Loads i2c-dev and
  # creates the i2c group; users are added to it in
  # defaults/system/accounts.nix. DDC/CI must also be ON in the monitor's
  # own on-screen menu.
  hardware.i2c.enable = true;

  services.printing.enable = true;
  # cups-browsed auto-creates queues for every printer it hears about on
  # the network, and was the entry point of the 2024 CUPS RCE chain.
  # Print dialogs still find network printers via Avahi (driverless IPP).
  services.printing.browsed.enable = false;

  # Avahi is the one mDNS responder; resolved's is switched off in
  # hosts/rog/network.nix so the two do not fight over UDP 5353.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.udisks2.enable = true;
  services.upower.enable = true;
  services.logind.settings.Login.HandleLidSwitch = "suspend";
}
