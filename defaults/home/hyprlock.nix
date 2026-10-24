{ config, lib, pkgs, ... }:
let
  t = import ../theme.nix;
  g = import ../glyphs.nix { inherit lib; };

  wallpaper = "${config.home.homeDirectory}/.local/share/wallpaper";
  initial = lib.toUpper (builtins.substring 0 1 config.home.username);

  # Small text feeds for the lock screen. Each prints one line, or nothing
  # (hyprlock then just shows an empty label).
  nowPlaying = pkgs.writeShellScript "lock-now-playing" ''
    line=$(${pkgs.playerctl}/bin/playerctl metadata --format '{{title}}  ·  {{artist}}' 2>/dev/null) || exit 0
    [ -n "$line" ] && printf '%s  %s' "${g.music}" "''${line:0:70}"
  '';
  battery = pkgs.writeShellScript "lock-battery" ''
    for b in /sys/class/power_supply/BAT*; do
      cap=$(cat "$b/capacity"); st=$(cat "$b/status")
      case "$st" in
        Charging) icon="${g.charging}" ;;
        Discharging) i=$(( (cap + 5) / 10 - 1 )); [ "$i" -lt 0 ] && i=0; [ "$i" -gt 9 ] && i=9
                     icons=(${lib.concatMapStringsSep " " (s: "\"${s}\"") g.battery}); icon=''${icons[$i]} ;;
        *) icon="${g.plug}" ;;
      esac
      printf '%s  %s%%' "$icon" "$cap"; exit 0
    done
  '';
  # Reuses the desktop weather widget's cache (desktop-widgets.nix), so
  # locking never triggers a network request of its own.
  weather = pkgs.writeShellScript "lock-weather" ''
    f="''${XDG_CACHE_HOME:-$HOME/.cache}/desktop-weather.json"
    [ -s "$f" ] && ${pkgs.jq}/bin/jq -r 'select(.ok) | "\(.icon)  \(.temp)°  \(.desc)"' "$f"
  '';

  # ---- screen timeout ----
  # hypridle only reads its config at start, so the timeout lives in a
  # small state file that Quick Settings changes (control-center idle N),
  # and this script turns it into a hypridle.conf and restarts hypridle.
  defaultMinutes = "5";
  screenTimeout = pkgs.writeShellScriptBin "screen-timeout" ''
    set -u
    dir="''${XDG_STATE_HOME:-$HOME/.local/state}"
    state="$dir/screen-timeout"
    conf="$dir/hypridle.conf"

    get() { v=$(cat "$state" 2>/dev/null); echo "''${v:-${defaultMinutes}}"; }

    write() {
      m=$(get)
      mkdir -p "$dir"
      {
        cat <<'EOF'
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }
    EOF
        # "never": no idle listeners at all. The screen still locks
        # before suspend (closing the lid), via before_sleep_cmd.
        if [ "$m" != never ]; then
          s=$((m * 60))
          cat <<EOF
    listener {
        timeout = $s
        on-timeout = loginctl lock-session
    }
    listener {
        timeout = $((s + 60))
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
    }
    EOF
        fi
      } > "$conf.tmp" && mv "$conf.tmp" "$conf"
    }

    case "''${1:-get}" in
      get)   get ;;
      write) write ;;
      set)   case "''${2:-}" in
               never|[0-9]*) echo "$2" > "$state" ;;
               *) echo "usage: screen-timeout set <minutes|never>" >&2; exit 1 ;;
             esac
             write
             systemctl --user restart hypridle.service ;;
      *)     echo "usage: screen-timeout [get | set <minutes|never>]" >&2; exit 1 ;;
    esac
  '';
in
{
  home.packages = [ screenTimeout ];

  programs.hyprlock = {
    enable = true;

    settings = {
      # (No `grace` here: hyprlock 0.9 removed the option — it now only
      # exists as the --grace command-line flag — and the old line made
      # every lock log a config error.)
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };

      animations = {
        enabled = true;
        bezier = [ "easeOutQuint, 0.23, 1, 0.32, 1" "linear, 0, 0, 1, 1" ];
        animation = [
          "fadeIn, 1, 4, easeOutQuint"
          "fadeOut, 1, 3, linear"
          "inputFieldDots, 1, 2, easeOutQuint"
          "inputFieldColors, 1, 3, easeOutQuint"
        ];
      };

      # The desktop wallpaper, blurred and dimmed so the glass reads.
      background = [{
        path = wallpaper;
        blur_passes = 3;
        blur_size = 8;
        noise = "0.012";
        contrast = "0.9";
        brightness = "0.55";
        vibrancy = "0.2";
        vibrancy_darkness = "0.0";
      }];

      # Liquid-glass card behind the avatar, name and password field, and
      # the avatar disc itself. Positions are offsets from screen centre
      # (y up).
      shape = [
        {
          size = "380, 292";
          color = "rgba(${t.rgbBg}, 0.30)";
          rounding = 34;
          border_size = 1;
          border_color = "rgba(255, 255, 255, 0.16)";
          shadow_passes = 2;
          shadow_size = 12;
          shadow_color = "rgba(0, 0, 0, 0.30)";
          position = "0, -80";
          halign = "center";
          valign = "center";
        }
        {
          size = "88, 88";
          color = "rgba(${t.rgbAccent}, 0.95)";
          rounding = -1;
          border_size = 2;
          border_color = "rgba(255, 255, 255, 0.35)";
          position = "0, -15";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = [{
        size = "300, 50";
        position = "0, -165";
        halign = "center";
        valign = "center";

        outline_thickness = 1;
        rounding = 25;
        inner_color    = "rgba(255, 255, 255, 0.08)";
        outer_color    = "rgba(255, 255, 255, 0.22)";
        check_color    = "rgba(${t.rgbAccent}, 0.90)";
        fail_color     = "rgba(${t.rgbUrgent}, 0.90)";
        capslock_color = "rgba(249, 226, 175, 0.90)";   # amber rim = Caps Lock on
        font_color     = "rgb(${t.fg})";
        font_family    = "Noto Sans";

        placeholder_text = ''<span foreground="##${t.fgDim}">Enter password</span>'';
        check_text = "Checking…";
        fail_text = ''<span foreground="##${t.urgent}">$PAMFAIL</span>'';

        dots_size = "0.22";
        dots_spacing = "0.40";
        dots_center = true;
        dots_rounding = -1;

        fade_on_empty = false;
        hide_input = false;
      }];

      label = [
        # clock: thin and large
        {
          text = ''<span font_weight="200">$TIME</span>'';
          font_size = 112;
          font_family = "Noto Sans";
          color = "rgba(${t.rgbFg}, 0.95)";
          position = "0, 300";
          halign = "center";
          valign = "center";
          shadow_passes = 2;
          shadow_size = 6;
          shadow_color = "rgba(0, 0, 0, 0.35)";
        }
        # date
        {
          text = "cmd[update:60000] date +'%A, %d %B'";
          font_size = 20;
          font_family = "Noto Sans";
          color = "rgba(${t.rgbFg}, 0.80)";
          position = "0, 195";
          halign = "center";
          valign = "center";
        }
        # avatar initial
        {
          text = "<b>${initial}</b>";
          font_size = 34;
          font_family = "Noto Sans";
          color = "rgb(${t.bg})";
          position = "0, -15";
          halign = "center";
          valign = "center";
        }
        # name (the account's description, e.g. "Murad")
        {
          text = ''<span font_weight="600">$DESC</span>'';
          font_size = 17;
          font_family = "Noto Sans";
          color = "rgba(${t.rgbFg}, 0.95)";
          position = "0, -88";
          halign = "center";
          valign = "center";
        }
        # weather, top right (from the desktop widget's cache)
        {
          text = "cmd[update:600000] ${weather}";
          font_size = 15;
          font_family = t.fontUi;
          color = "rgba(${t.rgbFg}, 0.85)";
          position = "-40, -30";
          halign = "right";
          valign = "top";
        }
        # now playing, bottom centre
        {
          text = "cmd[update:3000] ${nowPlaying}";
          font_size = 13;
          font_family = t.fontUi;
          color = "rgba(${t.rgbFg}, 0.70)";
          position = "0, 40";
          halign = "center";
          valign = "bottom";
        }
        # battery, bottom right
        {
          text = "cmd[update:30000] ${battery}";
          font_size = 13;
          font_family = t.fontUi;
          color = "rgba(${t.rgbFg}, 0.70)";
          position = "-40, 40";
          halign = "right";
          valign = "bottom";
        }
      ];
    };
  };

  # hypridle as our own unit (instead of services.hypridle) so its config
  # can be the runtime file screen-timeout writes; %S is ~/.local/state.
  systemd.user.services.hypridle = {
    Unit = {
      Description = "hypridle (lock and screen-off timeout, set in Quick Settings)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStartPre = "${screenTimeout}/bin/screen-timeout write";
      ExecStart = "${pkgs.hypridle}/bin/hypridle -c %S/hypridle.conf";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
