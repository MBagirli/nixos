{ lib, ... }:
let t = import ../theme.nix;
in
{
  programs.kitty = {
    enable = true;

    font = {
      name = lib.mkDefault t.font;
      size = lib.mkDefault (t.fontSize + 1);
    };

    settings = {
      # ---- colours ----
      background = lib.mkDefault "#${t.bg}";
      foreground = lib.mkDefault "#${t.fg}";
      cursor = lib.mkDefault "#${t.accent}";
      cursor_text_color = "#${t.bg}";
      selection_background = "#${t.surface}";
      selection_foreground = "#${t.fg}";
      url_color = "#${t.accent}";

      # catppuccin mocha 16
      color0  = "#45475a"; color8  = "#585b70";
      color1  = "#f38ba8"; color9  = "#f38ba8";
      color2  = "#a6e3a1"; color10 = "#a6e3a1";
      color3  = "#f9e2af"; color11 = "#f9e2af";
      color4  = "#89b4fa"; color12 = "#89b4fa";
      color5  = "#cba6f7"; color13 = "#cba6f7";
      color6  = "#94e2d5"; color14 = "#94e2d5";
      color7  = "#bac2de"; color15 = "#a6adc8";

      # ---- window ----
      background_opacity = lib.mkDefault "0.82";   # glass; Hyprland blurs behind
      background_blur = 32;
      window_padding_width = lib.mkDefault 12;
      window_margin_width = 0;
      placement_strategy = "center";
      hide_window_decorations = "yes";
      confirm_os_window_close = 0;

      # ---- cursor ----
      cursor_shape = "beam";
      cursor_beam_thickness = "1.8";
      cursor_blink_interval = "0.5";
      cursor_stop_blinking_after = 15;

      # ---- tabs ----
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      tab_bar_min_tabs = 2;
      active_tab_background = "#${t.accent}";
      active_tab_foreground = "#${t.bg}";
      active_tab_font_style = "bold";
      inactive_tab_background = "#${t.surface}";
      inactive_tab_foreground = "#${t.fgDim}";

      # ---- behaviour ----
      enable_audio_bell = false;
      scrollback_lines = 20000;
      copy_on_select = "clipboard";
      strip_trailing_spaces = "smart";
      mouse_hide_wait = "2.0";
      repaint_delay = 8;          # 144Hz panel
      sync_to_monitor = true;

      # ---- font rendering ----
      disable_ligatures = "cursor";
      adjust_line_height = "108%";
    };

    keybindings = {
      "ctrl+shift+enter" = "new_window";
      "ctrl+shift+t" = "new_tab";
      "ctrl+shift+w" = "close_window";
      "ctrl+equal" = "change_font_size all +1.0";
      "ctrl+minus" = "change_font_size all -1.0";
      "ctrl+shift+0" = "change_font_size all 0";
    };
  };
}
