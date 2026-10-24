{ pkgs, ... }:
{
  # Wi-Fi/Bluetooth firmware Ubuntu ships by default (Realtek, Intel, MediaTek).
  hardware.enableRedistributableFirmware = true;

  # Correct regulatory domain = all channels + full transmit power.
  hardware.wirelessRegulatoryDatabase = true;

  # Newer kernel: better Wi-Fi drivers and Renoir support.
  # If the NVIDIA driver fails to build, remove this line.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # The card is a MediaTek MT7921 (mt7921e); the Realtek/Intel power-save
  # options that used to be here matched no loaded driver. If the link
  # drops under load, the MT7921 knob is `options mt7921e disable_aspm=1`.
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom="AZ"
  '';

  # NetworkManager is already enabled in defaults/system/core.nix.
  # This is the power-save switch that actually reaches mt7921e.
  networking.networkmanager.wifi.powersave = false;

  # Proper DNS caching/resolution.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      # Avahi (defaults/system/hardware.nix) is the mDNS responder; two of
      # them on UDP 5353 made .local names and printer discovery flaky.
      MulticastDNS = false;
      # LLMNR answers single-label name lookups from anyone on the LAN —
      # the classic Responder spoofing vector on public Wi-Fi.
      LLMNR = false;
    };
  };
}
