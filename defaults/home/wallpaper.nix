{ config, lib, pkgs, ... }:
let
  t = import ../theme.nix;

  # The one mutable file. swaybg paints it on every output and hyprlock
  # reads the same path, so desktop and lock screen always match.
  target = "${config.home.homeDirectory}/.local/share/wallpaper";

  # Where the pickers look. Seeded from the flake's assets on first
  # activation; drop your own images in here afterwards.
  library = "${config.home.homeDirectory}/Pictures/Wallpapers";

  # Shared rofi picker body. Prints the chosen filename on stdout.
  pickerBody = prompt: ''
    dir="''${1:-${library}}"
    find -L "$dir" -maxdepth 2 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
         -o -iname '*.webp' -o -iname '*.bmp' \) 2>/dev/null \
      | sort \
      | while read -r f; do
          printf '%s\0icon\x1f%s\n' "$(basename "$f")" "$f"
        done \
      | ${pkgs.rofi}/bin/rofi -dmenu -i \
          -show-icons \
          -p "${prompt}" \
          -no-custom \
          -theme "$HOME/.config/rofi/wallpaper.rasi"
  '';
in
{
  options.my.wallpaper = lib.mkOption {
    type = lib.types.path;
    default = ../../assets/wallpapers/default.jpg;
    description = ''
      Seed wallpaper. Copied to ~/.local/share/wallpaper on first
      activation only — the user can replace that file at runtime and
      rebuilds will not overwrite it.
    '';
  };

  config = {
    # swaybg rather than hyprpaper. hyprpaper 0.8.4 rejects both the
    # ",path" all-monitors wildcard in its config file ("Monitor eDP-1
    # has no target") and the matching IPC commands ("invalid hyprpaper
    # request"). swaybg paints every output from a single -i argument,
    # with no per-monitor config at all.
    systemd.user.services.swaybg = {
      Unit = {
        Description = "wallpaper";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${target} -m fill";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    home.activation.seedWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${target}" ]; then
        run mkdir -p "$(dirname "${target}")"
        run cp ${config.my.wallpaper} "${target}"
        run chmod u+w "${target}"
      fi

      # Seed the library from the flake's assets without clobbering
      # anything already there.
      run mkdir -p "${library}"
      for f in ${../../assets/wallpapers}/*; do
        base="$(basename "$f")"
        if [ ! -e "${library}/$base" ]; then
          run cp "$f" "${library}/$base"
          run chmod u+w "${library}/$base"
        fi
      done
    '';

    home.packages = [
      # Super+W — desktop and lock screen (they share one file).
      (pkgs.writeShellScriptBin "wallpaper-picker" ''
        set -eu
        pick=$(${pickerBody "wallpaper"}) || exit 0
        [ -n "$pick" ] || exit 0

        dir="''${1:-${library}}"
        src="$dir/$pick"
        [ -f "$src" ] || {
          ${pkgs.libnotify}/bin/notify-send -a Wallpaper -i dialog-warning "Wallpaper" "not found: $pick"
          exit 1
        }

        cp "$src" "${target}"
        chmod u+w "${target}"
        systemctl --user restart swaybg
        ${pkgs.libnotify}/bin/notify-send -a Wallpaper -i "${target}" "Wallpaper changed" "Desktop and lock screen now use $pick"
      '')

      # Super+Shift+W — the SDDM greeter. Needs root, because sddm runs
      # as its own user and cannot read /home. The sudo rule for
      # sddm-wallpaper-set lives in defaults/system/sddm.nix.
      (pkgs.writeShellScriptBin "sddm-wallpaper-picker" ''
        set -eu
        pick=$(${pickerBody "login screen"}) || exit 0
        [ -n "$pick" ] || exit 0

        dir="''${1:-${library}}"
        src="$dir/$pick"

        if sudo -n sddm-wallpaper-set "$src" 2>/dev/null; then
          ${pkgs.libnotify}/bin/notify-send -a Wallpaper -i "$src" "Login screen changed" "The login screen now uses $pick"
        else
          ${pkgs.libnotify}/bin/notify-send -u critical -a Wallpaper -i dialog-error "Login screen" \
            "Failed — is the sudo rule in defaults/system/sddm.nix applied?"
        fi
      '')

      # Non-interactive equivalent of the first picker.
      (pkgs.writeShellScriptBin "set-wallpaper" ''
        set -eu
        if [ -z "''${1:-}" ]; then
          echo "usage: set-wallpaper /path/to/image" >&2
          exit 1
        fi
        cp "$1" "${target}"
        chmod u+w "${target}"
        systemctl --user restart swaybg
        echo "wallpaper set"
      '')
    ];

    # Grid of thumbnails, same visual language as the other rofi menus.
    xdg.configFile."rofi/wallpaper.rasi".text = ''
      * {
        bg:     rgba(${t.rgbBg}, ${t.glass});
        fg:     #${t.fg};
        fg-dim: #${t.fgDim};
        accent: #${t.accent};

        background-color: transparent;
        text-color:       @fg;
        font:             "${t.font} ${toString t.fontSize}";
      }

      window {
        width:            1100px;
        background-color: @bg;
        background-image: ${t.glassSheenRasi};
        border:           1px;
        border-color:     rgba(${t.rgbSurface}, 0.8);
        border-radius:    18px;
        padding:          0px;
        children:         [ mainbox ];
      }

      mainbox {
        children: [ inputbar, listview ];
        spacing:  0px;
      }

      inputbar {
        children:         [ prompt, entry ];
        background-color: rgba(${t.rgbSurface}, 0.35);
        border:           0px 0px 1px 0px;
        border-color:     rgba(${t.rgbSurface}, 0.8);
        border-radius:    18px 18px 0px 0px;
        padding:          16px 24px;
        spacing:          10px;
      }

      prompt {
        text-color:     @accent;
        vertical-align: 0.5;
      }

      entry {
        cursor:         text;
        vertical-align: 0.5;
      }

      listview {
        lines:            2;
        columns:          4;
        spacing:          10px;
        padding:          16px;
        background-color: transparent;
        scrollbar:        false;
        fixed-height:     false;
      }

      element {
        orientation:      vertical;
        padding:          8px;
        spacing:          6px;
        border-radius:    12px;
        background-color: transparent;
      }

      element selected {
        background-color: @accent;
        text-color:       #${t.bg};
      }

      element-icon {
        size:             200px;
        border-radius:    8px;
        background-color: transparent;
      }

      element-text {
        horizontal-align: 0.5;
        background-color: transparent;
        text-color:       inherit;
      }
    '';
  };
}
