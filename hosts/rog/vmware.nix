{ config, pkgs, ... }:
{
  virtualisation.vmware.host.enable = true;
  # polkit is enabled in defaults/system/desktop.nix.

  # Run `vmnet-editor` to open the VMware Virtual Network Editor as root.
  environment.systemPackages = with pkgs; [
    xhost
    (writeShellScriptBin "vmnet-editor" ''
      ${xhost}/bin/xhost +si:localuser:root >/dev/null
      trap '${xhost}/bin/xhost -si:localuser:root >/dev/null' EXIT
      /run/wrappers/bin/sudo -E ${config.virtualisation.vmware.host.package}/bin/vmware-netcfg "$@"
    '')
  ];
}
