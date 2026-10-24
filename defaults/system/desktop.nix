{ pkgs, ... }:
{
  # ---- compositor (system-level; HM reuses this package) ----
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # NOTE: the display manager lives in defaults/system/sddm.nix, which
  # builds a custom QML theme from defaults/theme.nix. Do NOT enable
  # services.displayManager.sddm here as well — two definitions of the
  # same option is a build error.

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only     # full glyph set as fallback for missing icons
      noto-fonts
      noto-fonts-color-emoji
      noto-fonts-cjk-sans
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" "Symbols Nerd Font" ];
      sansSerif = [ "Noto Sans" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # Both lines are required. Setting only defaultUserShell without
  # enabling the module gives you a broken login shell.
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  programs.dconf.enable = true;
  security.polkit.enable = true;
  services.gvfs.enable = true;     # Nautilus: trash, network shares, phones

  # Nautilus: "Open in Terminal" in the right-click menu (kitty), and
  # Space for a quick preview of the selected file.
  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "kitty";
  };
  services.gnome.sushi.enable = true;

  # Lets prebuilt Linux binaries find a dynamic loader at the usual path:
  # VS Code extensions with bundled language servers, uv-installed
  # wheels, downloaded CLIs. Without it they fail with "No such file".
  programs.nix-ld.enable = true;

  # hyprlock comes from Home Manager, which cannot create the PAM service
  # it authenticates against; without this it falls back to su's.
  security.pam.services.hyprlock = { };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
