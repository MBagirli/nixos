{ pkgs, ... }:
{
  # ROG-specific daemons: fan curves, power profiles, keyboard RGB.
  services.asusd.enable = true;

  # Switch between hybrid / integrated / dedicated without editing config.
  # `supergfxctl -m Integrated` fully powers off the dGPU.
  services.supergfxd.enable = true;

  services.power-profiles-daemon.enable = true;

  environment.systemPackages = with pkgs; [
    asusctl
    supergfxctl
  ];
}
