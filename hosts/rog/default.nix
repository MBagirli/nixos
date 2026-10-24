{ inputs, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./gpu.nix
    ./asus.nix
    ./network.nix
    ./vmware.nix
    # ./gaming.nix          # uncomment for steam / gamemode / gamescope

    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
  ];

  networking.hostName = "rog";

  # Never change after the first build.
  system.stateVersion = "26.05";

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;   # 1G ESP: keeps NVIDIA initrds from filling it
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # G513IE panel — 1920x1080 @ 144Hz.
  # Consumed by defaults/home/hyprland.nix.
  my.monitors = [ "eDP-1,1920x1080@144,0x0,1" ];

  environment.systemPackages = with pkgs; [
    powertop
    acpi
    lm_sensors
  ];
}
