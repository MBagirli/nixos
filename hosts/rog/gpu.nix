{ config, pkgs, ... }:
{
  # AMD Renoir iGPU + NVIDIA RTX 3050 Ti (GA107M).
  # Bus IDs come from lspci: 01:00.0 nvidia, 05:00.0 amd.
  # lspci prints hex, NixOS wants decimal — they coincide here.

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # Mesa's radeonsi already provides VAAPI and Vulkan (RADV) on Renoir.
    # Only the VDPAU-over-VAAPI shim is added, for the odd player that
    # still speaks VDPAU. (libva is a library, not a driver, and
    # libva-vdpau-driver is VAAPI-over-VDPAU for GPUs without VAAPI —
    # neither did anything with LIBVA_DRIVER_NAME=radeonsi.)
    extraPackages = with pkgs; [
      libvdpau-va-gl
    ];
  };

  hardware.nvidia = {
    modesetting.enable = true;      # required for Wayland
    nvidiaSettings = true;

    # Ampere supports the open kernel modules, but the proprietary ones
    # are still the safer default. Flip to true once things are stable.
    open = false;

    package = config.boot.kernelPackages.nvidiaPackages.stable;

    powerManagement = {
      enable = true;
      finegrained = true;           # dGPU powers down when idle; needs offload
    };

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;    # provides the `nvidia-offload` wrapper
      };
      amdgpuBusId  = "PCI:5:0:0";
      nvidiaBusId  = "PCI:1:0:0";
    };
  };

  # AMD iGPU drives the display; NVIDIA only wakes for offloaded apps.
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "radeonsi";
    __GLX_VENDOR_LIBRARY_NAME = "mesa";
    # GTK4 apps render with OpenGL (on the AMD iGPU) instead of Vulkan.
    # GTK's Vulkan renderer enumerates every GPU at startup, which wakes
    # the sleeping NVIDIA card (finegrained power management above): that
    # alone took ~1.5 s of Nautilus's 3 s first launch, and woke the dGPU
    # for every GTK4 app (Nautilus, pwvucontrol, Overskride, swaync).
    # Measured: 2993 ms -> 1472 ms, dGPU stays suspended.
    GSK_RENDERER = "ngl";
  };
}
