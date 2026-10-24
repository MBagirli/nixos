{ pkgs, ... }:
let
  t = import ../theme.nix;
in
{
  # Keybind cheatsheet. Parsed live out of hyprland.conf so it can never
  # drift from the actual binds — add a bind there and it shows up here.
  home.packages = [
    (pkgs.writeShellScriptBin "hypr-keys" ''
      conf="$HOME/.config/hypr/hyprland.conf"

      ${pkgs.gnugrep}/bin/grep -E '^[[:space:]]*bind[a-z]* = ' "$conf" \
        | ${pkgs.gnused}/bin/sed -E 's/^[[:space:]]*bind[a-z]* = //' \
        | ${pkgs.gawk}/bin/awk -F', *' '
            function keys(s) {
              gsub(/\$mod/, "Super", s); gsub(/SUPER/, "Super", s)
              gsub(/SHIFT/, "Shift", s);  gsub(/CTRL/, "Ctrl", s)
              gsub(/ALT/, "Alt", s)
              gsub(/mouse:272/, "Drag", s); gsub(/mouse:273/, "Resize", s)
              gsub(/^left$/, "\u2190", s); gsub(/^right$/, "\u2192", s)
              gsub(/^up$/, "\u2191", s);   gsub(/^down$/, "\u2193", s)
              gsub(/Return/, "Enter", s)
              return s
            }

            function describe(act, arg,   cmd) {
              cmd = arg
              gsub(/\$term/, "kitty", cmd); gsub(/\$menu/, "rofi", cmd)
              gsub(/\$files/, "nautilus", cmd); gsub(/\$browser/, "firefox", cmd)

              if (act == "exec") {
                if (cmd ~ /kitty/)      return "\uf120  Terminal"
                if (cmd ~ /rofi/)       return "\uf002  App launcher"
                if (cmd ~ /nautilus/)   return "\uf07b  File manager"
                if (cmd ~ /firefox/)    return "\uf269  Browser" (cmd ~ /-P/ ? " (work profile)" : "")
                if (cmd ~ /swaync/)     return "\uf0f3  Notifications"
                if (cmd ~ /control-center/) return "\uf1de  Quick settings"
                if (cmd ~ /uwsm stop/)  return "\uf08b  Log out"
                if (cmd ~ /sddm-wallpaper/) return "\uf03e  Login screen wallpaper"
                if (cmd ~ /wallpaper/)  return "\uf03e  Wallpaper"
                if (cmd ~ /hyprlock/)   return "\uf023  Lock screen"
                if (cmd ~ /hypr-keys/)  return "\uf11c  This cheatsheet"
                if (cmd ~ /hypr-aliases/) return "\uf0ca  Shell aliases"
                if (cmd ~ /power-menu/) return "\uf011  Power menu"
                if (cmd ~ /screenshot/) return "\uf030  Screenshot region"
                if (cmd ~ /nwg-displays/) return "\uf108  Display layout"
                if (cmd ~ /luminance/)  return "\uf185  Brightness (all monitors)"
                return "\uf120  " cmd
              }
              if (act == "killactive")      return "\uf00d  Close window"
              if (act == "fullscreen")      return "\uf065  Fullscreen"
              if (act == "togglefloating")  return "\uf2d2  Toggle floating"
              if (act == "exit")            return "\uf08b  Quit Hyprland"
              if (act == "movefocus")       return "\uf0b2  Focus " arg
              if (act == "workspace")       return "\uf009  Workspace " arg
              if (act == "movetoworkspace") return "\uf0c9  Send to workspace " arg
              if (act == "movetoworkspacesilent") return "\uf0c9  Send to workspace " arg
              if (act == "resizeactive")    return "\uf065  Resize window"
              if (act == "togglespecialworkspace") return "\uf2d0  Scratchpad"
              if (act == "movewindow")      return "\uf0b2  Move window"
              if (act == "resizewindow")    return "\uf065  Resize window"
              return act (arg == "" ? "" : "  " arg)
            }

            {
              mod = keys($1); key = keys($2); act = $3
              arg = ""
              for (i = 4; i <= NF; i++) arg = arg (i > 4 ? ", " : "") $i

              # media / brightness keys are noise in a cheatsheet
              if ($2 ~ /XF86/) next

              combo = (mod == "" ? key : mod " + " key)
              printf "%-20s %s\n", combo, describe(act, arg)
            }' \
        | ${pkgs.rofi}/bin/rofi -dmenu -i \
            -no-custom \
            -theme "$HOME/.config/rofi/keybinds.rasi" \
            > /dev/null
    '')
  ];

  # Dedicated rasi theme — separate from the launcher so tweaking one
  # does not affect the other.
  xdg.configFile."rofi/keybinds.rasi".text = ''
    * {
      bg:      rgba(${t.rgbBg}, ${t.glass});
      fg:      #${t.fg};
      fg-dim:  #${t.fgDim};
      accent:  #${t.accent};
      accent2: #${t.accent2};

      background-color: transparent;
      text-color:       @fg;
      font:             "${t.font} ${toString t.fontSize}";
    }

    window {
      width:            660px;
      background-color: @bg;
      background-image: ${t.glassSheenRasi};
      border:           1px;
      border-color:     ${t.glassEdge};
      border-radius:    22px;
      padding:          0px;
      children:         [ mainbox ];
    }

    mainbox {
      children: [ inputbar, listview ];
      spacing:  0px;
    }

    /* Search field sits in its own band with a hairline under it */
    inputbar {
      children:         [ entry ];
      background-color: rgba(${t.rgbSurface}, 0.35);
      border:           0px 0px 1px 0px;
      border-color:     rgba(${t.rgbSurface}, 0.8);
      border-radius:    18px 18px 0px 0px;
      padding:          16px 24px;
    }

    entry {
      cursor:         text;
      vertical-align: 0.5;
      text-color:     @fg;
    }

    listview {
      lines:            12;
      columns:          1;
      spacing:          0px;
      padding:          10px 14px 16px 14px;
      background-color: transparent;
      scrollbar:        false;
      dynamic:          true;
    }

    /* Uniform rows — no alternating stripe */
    element {
      padding:       10px 14px;
      border-radius: 10px;
      spacing:       0px;
      background-color: transparent;
      text-color:       @fg;
    }

    element selected {
      background-color: rgba(${t.rgbAccent}, 0.22);
      text-color:       @fg;
    }

    element-text {
      background-color: transparent;
      text-color:       inherit;
      vertical-align:   0.5;
    }
  '';
}
