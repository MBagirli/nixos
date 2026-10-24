{ config, ... }:
let
  t = import ../theme.nix;
  pkg = config.services.swaync.package;
in
{
  # SwayNotificationCenter (replaces dunst). Same pop-ups in the top
  # right, plus a panel that slides in from the right edge with the
  # notification history, do-not-disturb and media controls.
  #   Super+N or the bell in the bar   open / close the panel
  #   right-click the bell             toggle do-not-disturb
  services.swaync = {
    enable = true;

    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-layer = "top";
      layer-shell = true;
      layer-shell-cover-screen = true;   # click anywhere outside to close
      cssPriority = "user";
      # Only the style below, not the system GTK theme: Adwaita's list-row
      # focus highlight otherwise draws a square box behind the first card.
      ignore-gtk-theme = true;

      control-center-margin-top = 8;
      control-center-margin-bottom = 10;
      control-center-margin-right = 10;
      control-center-width = 420;
      notification-window-width = 400;
      notification-icon-size = 40;
      notification-body-image-height = 100;
      notification-body-image-width = 200;

      timeout = 8;
      timeout-low = 5;
      timeout-critical = 0;   # critical ones stay until dismissed

      fit-to-screen = true;
      relative-timestamps = true;
      keyboard-shortcuts = true;
      notification-grouping = true;
      image-visibility = "when-available";
      transition-time = 200;   # swaync's own slide-in; Hyprland adds none (hyprland.nix)
      hide-on-clear = false;
      hide-on-action = true;
      text-empty = "You're all caught up";

      widgets = [ "title" "dnd" "mpris" "notifications" ];
      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear all";
        };
        dnd.text = "Do not disturb";
        mpris = {
          autohide = true;
          show-album-art = "always";
        };
        notifications.vexpand = true;
      };
    };

    # Start from the stock theme — it carries all the layout, so a swaync
    # upgrade keeps working — and restyle on top: liquid-glass panel and
    # cards, icon and text sizes, close buttons that appear on hover.
    style = ''
      @import url("file://${pkg}/etc/xdg/swaync/style.css");

      :root {
        --cc-bg: rgba(${t.rgbBg}, ${t.glass});
        --noti-border-color: rgba(255, 255, 255, 0.10);
        /* Used by the stock CSS as rgba(var(--noti-bg), 1) for stacked
           cards — must be a dark colour, or they render white. */
        --noti-bg: ${t.rgbSurface};
        --noti-bg-alpha: 0.5;
        --noti-bg-darker: rgba(17, 17, 27, 0.5);
        --noti-bg-hover: rgba(255, 255, 255, 0.05);
        --noti-bg-focus: transparent;
        --noti-bg-alt: rgba(255, 255, 255, 0.05);
        --noti-close-bg: rgba(255, 255, 255, 0.10);
        --noti-close-bg-hover: rgba(${t.rgbUrgent}, 0.55);
        --text-color: #${t.fg};
        --text-color-disabled: #${t.fgDim};
        --bg-selected: #${t.accent};
        --border-radius: 18px;
        --notification-icon-size: 40px;
        --notification-group-icon-size: 24px;
        --notification-shadow: none;
        --font-size-body: 13px;
        --font-size-summary: 14px;
      }

      * { font-family: "Noto Sans", "${t.fontUi}"; }

      /* ---- the panel: liquid glass ---- */
      .control-center {
        background-color: rgba(${t.rgbBg}, ${t.glass});
        background-image: ${t.glassSheen};
        box-shadow: ${t.glassShine};
        border: 1px solid ${t.glassEdge};
        border-radius: 26px;
        padding: 10px 4px;
      }

      .widget-title { margin: 8px 14px 2px 14px; }
      .widget-title > label { font-size: 1.25rem; font-weight: 800; }
      .widget-title > button {
        background: rgba(255, 255, 255, 0.08);
        color: #${t.fg};
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 999px;
        padding: 4px 14px;
        font-size: 0.85rem;
        font-weight: 600;
      }
      .widget-title > button:hover { background: rgba(${t.rgbUrgent}, 0.35); }

      .widget-dnd {
        margin: 6px 14px 10px 14px;
        padding: 10px 14px;
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid rgba(255, 255, 255, 0.07);
        border-radius: 16px;
      }
      .widget-dnd label { font-size: 0.95rem; }
      .widget-dnd switch {
        background: rgba(255, 255, 255, 0.14);
        border: none;
        border-radius: 999px;
      }
      .widget-dnd switch:checked { background: #${t.accent}; }
      .widget-dnd switch slider { background: #${t.fg}; border-radius: 999px; }

      .widget-mpris .widget-mpris-player { border-radius: 18px; margin: 0 6px; }

      /* Empty state */
      .control-center .control-center-list-placeholder {
        opacity: 0.55;
        font-size: 1rem;
      }

      /* ---- one notification card ---- */
      /* swaync shades the keyboard-focused row behind the card, which read
         as a box inside a box. Focus shows on the card's rim instead. */
      .notification-row:focus { background: transparent; }
      .notification-row:focus .notification-background .notification {
        border-color: rgba(${t.rgbAccent}, 0.45);
      }

      .notification-row .notification-background { padding: 5px 12px; }

      .notification-row .notification-background .notification {
        background-color: rgba(255, 255, 255, 0.06);
        background-image: ${t.glassSheen};
        box-shadow: ${t.glassShine};
        border: 1px solid rgba(255, 255, 255, 0.10);
        border-radius: 18px;
      }

      /* A stack of notifications from one app: the front card needs
         enough body to hide the ones tucked behind it. */
      .notification-group.collapsed .notification-row .notification {
        background-color: rgba(${t.rgbSurface}, 0.85);
      }

      /* Pop-ups float over arbitrary windows, so they carry their own
         glass fill (the panel supplies it for cards inside it), plus a
         shadow to lift them off the page. */
      .floating-notifications .notification-row .notification-background { padding: 8px 14px; }
      .floating-notifications .notification-row .notification-background .notification {
        background-color: rgba(${t.rgbBg}, 0.66);
        box-shadow: ${t.glassShine}, 0 8px 22px rgba(0, 0, 0, 0.35);
        border-color: ${t.glassEdge};
      }

      .notification-row .notification-background .notification.critical {
        border-color: rgba(${t.rgbUrgent}, 0.65);
        background-image: linear-gradient(to right, rgba(${t.rgbUrgent}, 0.20), rgba(${t.rgbUrgent}, 0) 45%);
      }

      .notification-row .notification-background .notification .notification-default-action {
        padding: 10px 12px;
        border-radius: 18px;
      }
      .notification-row .notification-background .notification .notification-default-action:hover {
        background: rgba(255, 255, 255, 0.05);
      }

      .notification-row .notification-background .notification .notification-default-action .notification-content .image {
        border-radius: 12px;
        margin: 2px 12px 2px 0;
      }
      .notification-row .notification-background .notification .notification-default-action .notification-content .text-box .summary {
        font-size: 14px;
        font-weight: 700;
      }
      .notification-row .notification-background .notification .notification-default-action .notification-content .text-box .time {
        font-size: 11px;
        font-weight: 500;
        color: #${t.fgDim};
        margin-right: 30px;
      }
      .notification-row .notification-background .notification .notification-default-action .notification-content .text-box .body {
        font-size: 13px;
        color: #${t.fgDim};
        margin-top: 2px;
      }

      /* The close button only shows on the card you are pointing at. */
      .notification-row .close-button {
        opacity: 0;
        min-width: 22px;
        min-height: 22px;
        margin-top: 10px;
        margin-right: 10px;
        transition: opacity 150ms ease;
      }
      .notification-row:hover .close-button { opacity: 1; }

      /* Action buttons (Reply, Open, ...) as soft pills under the text. */
      .notification-row .notification-background .notification .notification-alt-actions { padding: 0 8px 8px 8px; }
      .notification-row .notification-background .notification .notification-action > button {
        background: rgba(255, 255, 255, 0.08);
        border: none;
        border-radius: 12px;
        margin: 0 4px;
        padding: 6px 10px;
      }
      .notification-row .notification-background .notification .notification-action > button:hover {
        background: rgba(${t.rgbAccent}, 0.30);
      }

      /* Stacked notifications from one app */
      .notification-group .notification-group-headers { margin: 6px 16px 0 16px; }
      .notification-group .notification-group-headers .notification-group-header { font-weight: 700; color: #${t.fgDim}; }
    '';
  };
}
