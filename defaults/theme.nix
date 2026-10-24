# Single source of truth for the look.
# Hex values have NO leading '#' — each app adds the prefix it needs.
{
  bg       = "1e1e2e";
  surface  = "313244";
  fg       = "cdd6f4";
  fgDim    = "a6adc8";
  inactive = "45475a";

  accent   = "89b4fa";
  accent2  = "cba6f7";
  ok       = "a6e3a1";
  warn     = "f9e2af";
  urgent   = "f38ba8";

  # Decimal RGB triplets for CSS rgba(). GTK3 cannot parse 8-digit hex,
  # so translucent backgrounds need these rather than the values above.
  # Keep in sync: rgbBg matches bg, rgbSurface matches surface.
  rgbBg      = "30, 30, 46";
  rgbFg      = "205, 214, 244";
  rgbSurface = "49, 50, 68";
  rgbAccent  = "137, 180, 250";
  rgbUrgent  = "243, 139, 168";

  # Liquid glass: how opaque the translucent surfaces are. Hyprland blurs
  # what shows through (decoration:blur + layerrules in
  # defaults/home/hyprland.nix), so lower means clearer glass, higher
  # means more legible.
  glass      = "0.42";   # panels, launcher, notifications
  glassBar   = "0.36";   # waybar pills — small, so they can go thinner
  glassEdge  = "rgba(255, 255, 255, 0.13)";   # 1px rim
  # The "liquid" part: light catching the top of the glass. A soft sheen
  # fading down the surface, plus a 1px inner highlight on the top edge.
  # GTK takes these as-is.
  glassSheen = "linear-gradient(to bottom, rgba(255, 255, 255, 0.11), rgba(255, 255, 255, 0.02) 55%, rgba(255, 255, 255, 0))";
  glassShine = "inset 0 1px 0 rgba(255, 255, 255, 0.16)";
  # rofi parses gradients more strictly (no % colour stops).
  glassSheenRasi = "linear-gradient(to bottom, rgba(255, 255, 255, 0.11), rgba(255, 255, 255, 0.02), rgba(255, 255, 255, 0))";

  font     = "JetBrainsMono Nerd Font";
  fontSize = 11;
  # Same letters, but each icon's advance matches its real width. In the
  # plain variant icons overflow their 1-cell advance to the right, so an
  # icon centred in a pill or a round button sits 2-9px right of centre.
  # Used wherever an icon is centred in a box (bar, quick settings).
  fontUi   = "JetBrainsMono Nerd Font Propo";

  gaps     = 6;
  gapsOut  = 10;
  rounding = 8;
  border   = 2;
}
