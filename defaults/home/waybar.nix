{ config, lib, ... }:
let
  t = import ../theme.nix;
  g = import ../glyphs.nix { inherit lib; };

  swaync = "${config.services.swaync.package}/bin/swaync-client";

  # ---- VERTICAL GEOMETRY ----
  # These must satisfy: pillHeight + 2*vMargin == barHeight
  # Any slack left over is what makes the pills sit off-centre, because
  # GTK has no rule about where to put an odd remainder. The 1px glass
  # border is part of the pill, so min-height is pillHeight - 2.
  barHeight  = 36;
  vMargin    = 5;
  pillHeight = barHeight - (2 * vMargin);   # = 26

  # Workspaces shown on EVERY output. An empty list means "not pinned to
  # a particular monitor", which is what makes both bars show the same
  # set instead of Hyprland's per-monitor split.
  persistent = lib.listToAttrs
    (map (n: lib.nameValuePair (toString n) [ ]) (lib.range 1 5));

in
{
  # NOTE: power-menu lives in defaults/home/powermenu.nix, hypr-keys in
  # defaults/home/keybinds.nix, wifi-menu / bt-menu in menus.nix and
  # control-center in controlcenter.nix.

  programs.waybar = {
    enable = true;

    # A user service rather than exec-once: it restarts if it crashes,
    # and Home Manager restarts it when this file changes on a rebuild.
    systemd.enable = true;

    settings.main = {
      layer = "top";
      position = "top";
      height = barHeight;
      spacing = 0;            # pill margins provide the separation

      modules-left = [ "custom/launcher" "custom/keybinds" "hyprland/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [
        "tray"
        "group/system"
        "battery"
        "custom/controlcenter"
        "custom/notification"
        "custom/power"
      ];

      # Related modules share one pill.
      "group/system" = {
        orientation = "inherit";
        modules = [ "cpu" "memory" "disk" ];
      };

      # Tooltips: only the clock has one (the calendar). Everything else
      # sets tooltip = false — hover popups over every icon were noise.

      "custom/launcher" = {
        format = g.nixos;
        tooltip = false;
        on-click = "rofi -show drun";
      };

      "custom/keybinds" = {
        format = g.keyboard;
        tooltip = false;
        on-click = "hypr-keys";
      };

      # Hyprland workspaces are virtual desktops.
      #   all-outputs        -> every bar lists every workspace
      #   persistent-workspaces with empty lists -> 1..5 always present on
      #                         all monitors, so the two bars agree
      #   show-special = false -> hides scratchpad pseudo-workspaces
      "hyprland/workspaces" = {
        format = "{id}";
        all-outputs = true;
        sort-by-number = true;
        show-special = false;
        persistent-workspaces = persistent;
        on-click = "activate";
        on-scroll-up = "hyprctl dispatch workspace e+1";
        on-scroll-down = "hyprctl dispatch workspace e-1";
      };

      clock = {
        format = "${g.clock}  {:%H:%M}";
        format-alt = "${g.calendar}  {:%A, %d %B}";
        # {calendar} cannot share a tooltip with a {:%...} time format in
        # this waybar ("invalid arg-id"); the calendar has its own header.
        # Scroll over the clock to page through months.
        tooltip-format = "<tt>{calendar}</tt>";
        calendar = {
          mode = "month";
          on-scroll = 1;
          format = {
            months   = "<span color='#${t.accent2}'><b>{}</b></span>";
            weekdays = "<span color='#${t.accent}'><b>{}</b></span>";
            days     = "<span color='#${t.fg}'>{}</span>";
            today    = "<span color='#${t.bg}' bgcolor='#${t.accent}'><b>{}</b></span>";
          };
        };
        actions = {
          on-scroll-up = "shift_down";
          on-scroll-down = "shift_up";
        };
      };

      tray = {
        icon-size = 16;
        spacing = 10;
      };

      cpu = {
        interval = 3;
        format = "${g.cpu}  {usage}%";
        tooltip = false;
        on-click = "kitty btop";
      };

      memory = {
        interval = 5;
        format = "${g.memory}  {percentage}%";
        tooltip = false;
        on-click = "kitty btop";
      };

      disk = {
        interval = 60;
        path = "/";
        format = "${g.disk}  {percentage_used}%";
        tooltip = false;
      };

      # No network / bluetooth / pulseaudio modules: Wi-Fi, Bluetooth and
      # sound live in Quick Settings (the sliders icon, Super+S).

      battery = {
        interval = 30;
        states = { warning = 30; critical = 15; };
        format = "{icon}  {capacity}%";
        format-charging = "${g.charging}  {capacity}%";
        format-plugged = "${g.plug}  {capacity}%";
        format-full = "${g.plug}  {capacity}%";
        format-icons = g.battery;
        tooltip = false;
        on-click = "control-center toggle";
      };

      "custom/controlcenter" = {
        format = g.tune;
        tooltip = false;
        on-click = "control-center toggle";
      };

      # swaync-client -swb streams JSON: the alt field picks the icon,
      # class drives the colour below.
      "custom/notification" = {
        exec = "${swaync} -swb";
        return-type = "json";
        escape = true;
        restart-interval = 2;   # swaync may come up after the bar
        tooltip = false;
        format = "{icon}";
        format-icons = {
          none = g.bell;
          notification = g.bellBadge;
          inhibited-none = g.bell;
          inhibited-notification = g.bellBadge;
          dnd-none = g.bellOff;
          dnd-notification = g.bellOff;
          dnd-inhibited-none = g.bellOff;
          dnd-inhibited-notification = g.bellOff;
        };
        on-click = "${swaync} -t -sw";
        on-click-right = "${swaync} -d -sw";
      };

      "custom/power" = {
        format = g.power;
        tooltip = false;
        on-click = "power-menu";
      };
    };

    style = lib.mkDefault ''
      /* min-height: 0 on the universal selector is essential — without it
         GTK's default minimum fights the explicit heights below and the
         pills end up taller than intended, which is what pushes them
         off-centre in the bar. */
      * {
        font-family: "${t.fontUi}";
        font-size: ${toString t.fontSize}pt;
        border: none;
        border-radius: 0;
        min-height: 0;
        margin: 0;
        padding: 0;
      }

      /* Fully transparent bar; only the pills are visible. Hyprland blurs
         whatever shows through them (layerrules in hyprland.nix), which
         is the frosted-glass look. */
      window#waybar {
        background: transparent;
        color: #${t.fg};
      }

      /* Every pill. pillHeight + 2*vMargin == barHeight exactly, so there
         is no leftover vertical space for GTK to distribute arbitrarily. */
      #custom-launcher,
      #custom-keybinds,
      #workspaces,
      #clock,
      #tray,
      #system,
      #battery,
      #custom-controlcenter,
      #custom-notification,
      #custom-power {
        background-color: rgba(${t.rgbBg}, ${t.glassBar});
        background-image: ${t.glassSheen};
        box-shadow: ${t.glassShine};
        border: 1px solid ${t.glassEdge};
        border-radius: ${toString (t.rounding + 4)}px;
        min-height: ${toString (pillHeight - 2)}px;
        padding: 0 11px;
        margin: ${toString vMargin}px 3px;
      }

      /* Modules sharing the system pill. */
      #cpu, #memory, #disk {
        padding: 0 7px;
        margin: 2px 0;
        border-radius: ${toString t.rounding}px;
      }
      #system { padding: 0 4px; }

      /* Icon-only pills: no padding, fixed width, glyph centred by GTK */
      #custom-launcher,
      #custom-keybinds,
      #custom-controlcenter,
      #custom-notification,
      #custom-power {
        padding: 0;
        min-width: 34px;
      }
      #custom-launcher { font-size: ${toString (t.fontSize + 2)}pt; }

      /* The only hover effect on the bar: the clock, whose calendar
         tooltip is the one thing hovering is for. */
      #clock:hover { background-color: rgba(${t.rgbSurface}, 0.60); }

      #custom-launcher      { color: #${t.accent}; }
      #custom-keybinds      { color: #${t.accent2}; }
      #custom-controlcenter { color: #${t.accent}; }
      #custom-notification  { color: #${t.fg}; }
      #custom-notification.notification,
      #custom-notification.inhibited-notification { color: #${t.warn}; }
      #custom-notification.dnd-none,
      #custom-notification.dnd-notification,
      #custom-notification.dnd-inhibited-none,
      #custom-notification.dnd-inhibited-notification { color: #${t.fgDim}; }
      #custom-power         { color: #${t.urgent}; }

      /* The workspace container holds buttons rather than a label, so it
         needs its own inner geometry. */
      #workspaces { padding: 0 4px; }

      #workspaces button {
        min-height: ${toString (pillHeight - 6)}px;
        min-width: ${toString (pillHeight - 6)}px;
        padding: 0 6px;
        margin: 2px 1px;
        color: #${t.fgDim};
        background: transparent;
        border-radius: ${toString t.rounding}px;
      }

      /* An empty workspace that only exists because it is persistent is
         dimmed further, so occupied ones stand out. */
      #workspaces button.empty  { color: #${t.inactive}; }
      #workspaces button.active { color: #${t.bg}; background: #${t.accent}; }
      #workspaces button.urgent { color: #${t.bg}; background: #${t.urgent}; }
      /* GTK's default button hover would still apply; pin it to the
         non-hover look. */
      #workspaces button:hover  { background: transparent; box-shadow: none; color: #${t.fgDim}; }
      #workspaces button.active:hover { background: #${t.accent}; color: #${t.bg}; }
      #workspaces button.empty:hover  { color: #${t.inactive}; }
      #workspaces button.urgent:hover { background: #${t.urgent}; color: #${t.bg}; }

      #clock      { color: #${t.accent2}; }
      #cpu        { color: #${t.accent}; }
      #memory     { color: #${t.accent2}; }
      #disk       { color: #${t.warn}; }
      #battery    { color: #${t.ok}; }
      #battery.warning:not(.charging)  { color: #${t.warn}; }
      #battery.critical:not(.charging) { color: #${t.urgent}; }

      /* Tooltips: same glass as the pills, a proportional font for
         prose (the calendar asks for <tt> itself). */
      tooltip {
        background-color: rgba(${t.rgbBg}, 0.70);
        background-image: ${t.glassSheen};
        box-shadow: ${t.glassShine};
        border: 1px solid ${t.glassEdge};
        border-radius: 14px;
      }
      tooltip label {
        font-family: "Noto Sans", "${t.fontUi}";
        color: #${t.fg};
        padding: 6px 8px;
      }

      #tray > .needs-attention { background: rgba(${t.rgbUrgent}, 0.35); border-radius: 8px; }
      menu { background: rgba(${t.rgbBg}, 0.92); border: 1px solid ${t.glassEdge}; border-radius: 12px; padding: 6px; }
      menu menuitem { padding: 6px 10px; border-radius: 8px; }
      menu menuitem:hover { background: rgba(${t.rgbAccent}, 0.25); }
    '';
  };
}
