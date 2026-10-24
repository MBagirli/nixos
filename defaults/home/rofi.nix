{ config, lib, pkgs, ... }:
let
  t = import ../theme.nix;
  g = import ../glyphs.nix { inherit lib; };
in
{
  programs.rofi = {
    enable = true;
    # rofi-wayland was merged into rofi upstream; plain rofi now has
    # Wayland support built in.
    package = pkgs.rofi;
    terminal = "${pkgs.kitty}/bin/kitty";

    # Must be set here, NOT inside extraConfig. HM emits this as a
    # proper `@theme "path"` line after the configuration block; putting
    # `theme` inside extraConfig produces the deprecated `theme:` option
    # and rofi refuses to start.
    theme = "${config.xdg.configHome}/rofi/theme.rasi";

    extraConfig = {
      modes = "drun,window";
      show-icons = true;
      icon-theme = "Papirus-Dark";
      drun-display-format = "{name}";
      # Match on what people search for, not only the exact app name:
      # "browser" finds Firefox, "files" finds Nautilus.
      drun-match-fields = "name,generic,keywords,categories,exec";
      matching = "fuzzy";
      sort = true;
      sorting-method = "fzf";
      display-drun = "Apps";
      display-window = "Windows";
      window-format = "{c}";
      hover-select = true;
      me-select-entry = "MousePrimary";
      me-accept-entry = "!MousePrimary";
    };
  };

  # Written as a raw rasi file rather than through programs.rofi.theme's
  # attrset form: that needs mkLiteral on nearly every value and cannot
  # express the nested selectors below.
  #
  # A launchpad-style grid on frosted glass (Hyprland blurs the "rofi"
  # layer, see hyprland.nix): search on top, big icons, and tabs at the
  # bottom for the Apps / Windows modes (Ctrl+Tab switches).
  xdg.configFile."rofi/theme.rasi".text = ''
    * {
      bg:      rgba(${t.rgbBg}, ${t.glass});
      edge:    ${t.glassEdge};
      raised:  rgba(255, 255, 255, 0.06);
      fg:      #${t.fg};
      fg-dim:  #${t.fgDim};
      accent:  #${t.accent};

      background-color: transparent;
      text-color:       @fg;
      font:             "Noto Sans 10";
    }

    window {
      width:            760px;
      background-color: @bg;
      background-image: ${t.glassSheenRasi};
      border:           1px;
      border-color:     @edge;
      border-radius:    26px;
      padding:          20px;
    }

    mainbox {
      children: [ inputbar, listview, mode-switcher ];
      spacing:  16px;
    }

    inputbar {
      children:         [ textbox-search, entry ];
      background-color: @raised;
      border:           1px;
      border-color:     @edge;
      border-radius:    16px;
      padding:          12px 16px;
      spacing:          12px;
    }
    textbox-search {
      str:            "${g.search}";
      expand:         false;
      text-color:     @accent;
      font:           "${t.fontUi} 14";
      vertical-align: 0.5;
    }
    entry {
      placeholder:       "Search apps";
      placeholder-color: @fg-dim;
      cursor:            text;
      font:              "Noto Sans 12";
      vertical-align:    0.5;
    }

    listview {
      columns:       6;
      lines:         3;
      fixed-height:  true;
      fixed-columns: true;
      flow:          horizontal;
      spacing:       8px;
      scrollbar:     false;
      cycle:         false;
    }

    element {
      orientation:   vertical;
      padding:       14px 6px 10px 6px;
      spacing:       10px;
      border:        1px;
      border-color:  transparent;
      border-radius: 18px;
      cursor:        pointer;
    }
    element normal.normal, element alternate.normal, element normal.active, element alternate.active {
      background-color: transparent;
    }
    element selected.normal, element selected.active {
      background-color: rgba(${t.rgbAccent}, 0.20);
      border-color:     rgba(${t.rgbAccent}, 0.55);
    }
    element-icon {
      size:             52px;
      horizontal-align: 0.5;
      cursor:           inherit;
    }
    element-text {
      horizontal-align: 0.5;
      vertical-align:   0.5;
      text-color:       inherit;
      cursor:           inherit;
    }

    mode-switcher {
      spacing: 8px;
    }
    button {
      padding:          8px;
      border-radius:    12px;
      background-color: @raised;
      text-color:       @fg-dim;
      cursor:           pointer;
    }
    button selected {
      background-color: rgba(${t.rgbAccent}, 0.85);
      text-color:       #${t.bg};
    }

    message { padding: 0px 4px; }
    textbox { text-color: @fg-dim; }
  '';
}
