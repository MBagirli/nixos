{ config, pkgs, ... }:
let
  dir = "${config.home.homeDirectory}/Pictures/Screenshots";
in
{
  xdg.configFile."swappy/config".text = ''
    [Default]
    save_dir=${dir}
    save_filename_format=screenshot-%Y%m%d-%H%M%S.png
    show_panel=true
    line_size=4
    text_size=20
    text_font=${(import ../theme.nix).font}
  '';

  home.activation.screenshotDir =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "${dir}"
    '';

  # Drag a region, annotate in swappy, Ctrl+C to copy or Ctrl+S to save.
  home.packages = [
    (pkgs.writeShellScriptBin "screenshot" ''
      ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - \
        | ${pkgs.swappy}/bin/swappy -f -
    '')
  ];
}
