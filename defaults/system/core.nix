{ ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    max-jobs = 4;          # 16G RAM / 16 threads
    cores = 4;
    # Only cache.nixos.org (the default). Hyprland comes from nixpkgs, so
    # hyprland.cachix.org never had these paths — it only cost a round
    # trip per lookup.
  };

  # /etc/nixos is owned by root (folders 755, files 644). git — and Nix
  # through libgit2 — refuse to even read a repository owned by another
  # user ("repository path ... is not owned by current user"), which
  # broke `git status`, VS Code's git panel and `nix eval` run as a normal
  # user. Listing it as safe in /etc/gitconfig allows that read access;
  # writing still needs root (nixadd, nixup and rebuild use sudo).
  programs.git = {
    enable = true;
    config.safe.directory = "/etc/nixos";
  };

  # Hard-link identical files in the store once a week, instead of
  # auto-optimise-store doing it inside every build.
  nix.optimise.automatic = true;

  # 512G disk holding a nix store plus NVIDIA driver generations.
  # nh keeps the newest 5 generations NO MATTER HOW OLD, plus anything
  # from the last week. `nix.gc --delete-older-than 7d` instead wiped every
  # rollback whenever a week went by without a rebuild.
  programs.nh = {
    enable = true;
    flake = "/etc/nixos";
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 5 --keep-since 7d";
    };
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  time.timeZone = "Asia/Baku";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  networking.networkmanager.enable = true;

  # ---- firewall ----
  # Every TCP port the machine accepts is listed here. 22 is also opened
  # by services.openssh below; naming it explicitly keeps the inbound
  # surface visible in one line. (Avahi additionally opens UDP 5353 for
  # printer discovery — services.avahi.openFirewall in hardware.nix.)
  #
  # 5900 (wayvnc) is deliberately NOT opened. `virtual-monitor listen`
  # binds wayvnc to 0.0.0.0, but wayvnc has no encryption or auth of its
  # own, so opening it would hand the desktop to anyone on the same wifi.
  # Reach it over the ssh you already run:
  #   ssh -L 5900:localhost:5900 rog
  # then point the viewer at localhost:5900.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # Keys only. Passwords on port 22 of a laptop that joins public Wi-Fi
  # invite guessing. To ssh in, put your public key in
  #   users.users.<name>.openssh.authorizedKeys.keys
  # (or ~/.ssh/authorized_keys) first.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  services.btrfs.autoScrub.enable = true;

  nixpkgs.config.allowUnfree = true;
}
