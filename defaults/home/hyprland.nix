{ osConfig, lib, ... }:
let
  t = import ../theme.nix;
  monitors = lib.concatMapStrings (m: "monitor = ${m}\n") osConfig.my.monitors;

  # Workspace switch + move-window, 1..9
  workspaceBinds = lib.concatMapStrings (i:
    let n = toString i; in ''
      bind = SUPER, ${n}, workspace, ${n}
      bind = SUPER SHIFT, ${n}, movetoworkspacesilent, ${n}
    '') (lib.range 1 9);
in
{
  # NOTE: HM's wayland.windowManager.hyprland module now emits a Lua config
  # whose API does not match the Hyprland build in nixpkgs (hl.animations is
  # nil, keys with $ or - are invalid Lua identifiers). We bypass it and
  # write the classic hyprland.conf, which Hyprland reads when no
  # hyprland.lua is present. The compositor itself comes from
  # programs.hyprland.enable at system level.
  # Screen-sharing portal (xdg-desktop-portal-hyprland).
  # force_shm: hand apps plain memory buffers, never GPU dmabufs. Zoom
  # accepted dmabufs with the AMD iGPU's tiled layout and then shared a
  # black screen; with plain buffers it works. Every app that shares the
  # screen (browsers, OBS) takes these.
  # max_fps: each frame is now copied through the CPU, and the 144 Hz
  # panel would otherwise be captured at up to 120 fps; calls send at
  # most 30. Raise it to 60 for smooth OBS recordings.
  # Read when the portal starts (next login), not on rebuild.
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
        force_shm = true
        max_fps = 30
    }
  '';

  xdg.configFile."hypr/hyprland.conf".text = ''
    # Monitors live in a separate MUTABLE file so nwg-displays can write
    # to them. Seeded once from hosts/rog/default.nix (my.monitors) by the
    # activation script below, then owned by the user — same pattern as
    # the wallpaper.
    source = ~/.config/hypr/monitors.conf
    # nwg-displays writes workspace-to-monitor assignments here.
    source = ~/.config/hypr/workspaces.conf

    $mod     = SUPER
    $term    = kitty
    $menu    = rofi -show drun
    $browser = firefox
    $files   = nautilus --new-window

    # waybar, swaync, eww and swaybg are systemd user services bound to
    # graphical-session.target (UWSM starts it), so nothing to exec here.

    general {
        gaps_in = ${toString t.gaps}
        gaps_out = ${toString t.gapsOut}
        border_size = ${toString t.border}
        # Glass rim: light catching the edge, tinted toward the accent on
        # the focused window, a faint clear edge on the rest.
        col.active_border = rgba(ffffff55) rgba(${t.accent}88) rgba(${t.accent2}66) 45deg
        col.inactive_border = rgba(ffffff1a)
        layout = dwindle
        resize_on_border = true
        extend_border_grab_area = 8
        hover_icon_on_border = true

        snap {
            enabled = true
        }
    }

    decoration {
        # Squircle corners (rounding_power > 2), like Apple's glass.
        rounding = ${toString (t.rounding + 4)}
        rounding_power = 2.4

        # System-wide glass: every window is slightly see-through, so the
        # blur below shows through apps that cannot be themed (browsers,
        # Electron, Qt). Exceptions are the window rules further down.
        # Fullscreen windows are always opaque (fullscreen_opacity).
        active_opacity = 0.96
        inactive_opacity = 0.90
        fullscreen_opacity = 1.0

        # Liquid glass: a wide, multi-pass blur that stays bright and
        # saturated (vibrancy) instead of turning grey, with a touch of
        # noise so it reads as material rather than a smudge.
        blur {
            enabled = true
            size = 10
            passes = 3
            noise = 0.015
            contrast = 1.0
            brightness = 0.9
            vibrancy = 0.25
            vibrancy_darkness = 0.15
            new_optimizations = true
            xray = false
            popups = true
            special = true
        }

        # A soft, wide shadow lifts the glass off whatever is behind it.
        shadow {
            enabled = true
            range = 28
            render_power = 3
            offset = 0 6
            color = rgba(00000050)
        }
    }

    # Things appearing: fast start, long soft landing (easeOutQuint).
    # Things leaving: short and near-linear, so closing feels instant.
    # Speeds are in tenths of a second.
    animations {
        enabled = true
        bezier = easeOutQuint, 0.23, 1, 0.32, 1
        bezier = linear, 0, 0, 1, 1
        bezier = almostLinear, 0.5, 0.5, 0.75, 1

        animation = global, 1, 10, default
        animation = border, 1, 5.4, easeOutQuint
        animation = windows, 1, 4.8, easeOutQuint
        animation = windowsIn, 1, 4.1, easeOutQuint, popin 87%
        animation = windowsOut, 1, 1.5, linear, popin 87%
        animation = fadeIn, 1, 1.7, almostLinear
        animation = fadeOut, 1, 1.5, almostLinear
        animation = fade, 1, 3, easeOutQuint
        animation = layers, 1, 3, easeOutQuint
        animation = layersIn, 1, 2.6, easeOutQuint, fade
        animation = layersOut, 1, 1.4, linear, fade
        animation = fadeLayersIn, 1, 1.6, almostLinear
        animation = fadeLayersOut, 1, 1.2, almostLinear
        animation = workspaces, 1, 3.5, easeOutQuint, slide
        animation = specialWorkspace, 1, 3.5, easeOutQuint, slidevert
    }

    dwindle {
        preserve_split = true
        smart_split = false
        smart_resizing = true
    }

    input {
        kb_layout = us
        follow_mouse = 1
        # focus follows the mouse but does not raise floating windows —
        # stops accidental focus steals when the pointer crosses a dialog
        float_switch_override_focus = 0

        touchpad {
            natural_scroll = true
            disable_while_typing = true
            tap-to-click = true
            scroll_factor = 0.6
        }
    }

    # Software cursors avoid the flicker / disappearing pointer that the
    # NVIDIA driver causes with hardware cursor planes on hybrid laptops.
    cursor {
        no_hardware_cursors = true
        inactive_timeout = 5
    }

    binds {
        # pressing the current workspace's key again returns to the previous
        workspace_back_and_forth = true
        allow_workspace_cycles = true
    }

    misc {
        disable_hyprland_logo = true
        disable_splash_rendering = true
        force_default_wallpaper = 0
        vrr = 1
        focus_on_activate = true
        # a lone window gets no gaps and no border — less visual noise
        # when a terminal is the only thing on a workspace
        # (comment out if you prefer constant framing)
        # no_gaps_when_only = 1
    }

    ecosystem {
        no_update_news = true
        no_donation_nag = true
    }

    xwayland {
        force_zero_scaling = true
    }

    # ---- window rules ----
    # Hyprland 0.53+ syntax: effects first ("float on"), then matchers
    # ("match:class ..."). The old `float, class:^(x)$` form is rejected
    # with "invalid field float: missing a value".
    windowrule = float on, center on, size 900 600, match:class ^(com.saivert.pwvucontrol|pavucontrol|io.github.kaii_lb.Overskride|nm-connection-editor)$
    windowrule = float on, center on, match:class ^(com.sidevesh.Luminance|nwg-displays)$
    windowrule = float on, match:title ^(Picture-in-Picture)$
    windowrule = float on, center on, match:class ^(xdg-desktop-portal-gtk)$

    # No whole-window translucency where it hurts: video, images, VMs and
    # games stay solid. kitty and the libadwaita apps draw their own glass
    # background (kitty.nix, gtk4 css in theming.nix) with fully opaque
    # text, so window opacity on top would only fade their text.
    windowrule = opacity 1.0 override 1.0 override, match:class ^(mpv|imv|vmware|Vmware|vmplayer|steam_app_.*|gamescope|org.gnome.Loupe)$
    windowrule = opacity 1.0 override 1.0 override, match:title ^(Picture-in-Picture)$
    windowrule = opacity 1.0 override 1.0 override, match:class ^(kitty|org.gnome.Nautilus|org.gnome.NautilusPreviewer|com.saivert.pwvucontrol|io.github.kaii_lb.Overskride)$

    # ---- Zoom ----
    # Zoom runs under XWayland (class "zoom"; "Zoom" if ever switched to
    # native Wayland, which broke its side panels: they opened off-screen
    # until the next focus change). Two X11 jobs Hyprland skips are done
    # by xwayland-assist.nix, without which the sharing toolbar stopped
    # taking clicks and the floating video could not be dragged.
    # No glass for Zoom: its sharing surfaces are transparent and turned
    # into a full-screen frosted pane, and a see-through meeting window
    # is no use. Its helper windows (all titled like this) float and never
    # steal focus; the sharing toolbar starts centred just below the bar
    # instead of over it at y=0, the floating video bottom-right.
    windowrule = opacity 1.0 override 1.0 override, no_blur on, no_shadow on, border_size 0, match:class ^([Zz]oom)$
    windowrule = float on, no_initial_focus on, move (monitor_w*0.5-window_w*0.5) 44, match:class ^([Zz]oom)$, match:title ^(as_toolbar)$
    windowrule = float on, no_initial_focus on, move (monitor_w-window_w-24) (monitor_h-window_h-24), match:class ^([Zz]oom)$, match:title ^(zoom_linux_float_video_window)$
    windowrule = float on, no_initial_focus on, match:class ^([Zz]oom)$, match:title ^(as_preview|zoom_linux_float_message_reminder|menu window|zoom)$

    # ---- layer rules: glass ----
    # Blur whatever is behind these translucent surfaces. ignore_alpha
    # keeps the blur to the painted parts (the pills, the panel), not the
    # fully transparent rest of the surface.
    #
    # Animations: launcher and menus pop in; Quick Settings drops from the
    # bar. The notification panel fades: its surface covers the whole
    # screen (that is how click-outside-to-close works), so a slide moved
    # a 1920px-wide surface and the panel only appeared at the very end —
    # the "opens with a delay" effect. A fade does not care about size.
    # swaync slides individual pop-ups in itself (transition-time in
    # notifications.nix). The full-screen click catcher behind Quick
    # Settings is invisible, so it gets no animation at all.
    # The bar's blur is xray: it frosts only the wallpaper. Otherwise the
    # wide blur also reached the top of the windows just below the bar, so
    # its glass came out dark over VS Code and pale over Zoom, and the two
    # screens' bars never matched.
    layerrule = blur on, xray on, ignore_alpha 0.1, blur_popups on, match:namespace waybar
    layerrule = blur on, ignore_alpha 0.1, animation popin 92%, match:namespace rofi
    layerrule = blur on, ignore_alpha 0.1, no_anim on, match:namespace swaync-notification-window
    layerrule = blur on, ignore_alpha 0.1, animation fade, match:namespace swaync-control-center
    layerrule = blur on, ignore_alpha 0.1, animation slide top, match:namespace eww-controlcenter
    layerrule = no_anim on, match:namespace eww-closer
    # Desktop widgets (desktop-widgets.nix): glass cards get the blur; the
    # visualizer is bare bars, so it only fades in.
    layerrule = blur on, ignore_alpha 0.1, match:namespace eww-desktop
    layerrule = animation fade, match:namespace eww-visualizer

    # ---- launch ----
    bind = $mod, Return, exec, $term
    bind = $mod, D, exec, $menu
    bind = $mod, B, exec, $browser
    bind = $mod SHIFT, B, exec, $browser -P work
    bind = $mod, E, exec, $files
    bind = $mod, K, exec, hypr-keys
    bind = $mod, T, exec, hypr-aliases
    bind = $mod, P, exec, nwg-displays
    bind = $mod SHIFT, P, exec, luminance
    bind = $mod, W, exec, wallpaper-picker
    bind = $mod SHIFT, W, exec, sddm-wallpaper-picker
    bind = $mod, L, exec, hyprlock
    bind = $mod SHIFT, E, exec, power-menu
    bind = $mod SHIFT, S, exec, screenshot
    bind = $mod, N, exec, swaync-client -t -sw
    bind = $mod, S, exec, control-center toggle

    # ---- window management ----
    bind = $mod, Q, killactive
    bind = $mod, F, fullscreen, 0
    bind = $mod SHIFT, F, fullscreen, 1        # maximise within gaps
    bind = $mod, V, togglefloating
    bind = $mod, C, centerwindow
    # `uwsm stop` rather than the exit dispatcher, so UWSM shuts the
    # session's services (waybar, swaync, eww, hypridle) down cleanly.
    bind = $mod SHIFT, Q, exec, uwsm stop

    # focus
    bind = $mod, left,  movefocus, l
    bind = $mod, right, movefocus, r
    bind = $mod, up,    movefocus, u
    bind = $mod, down,  movefocus, d
    bind = $mod, Tab,   cyclenext
    bind = $mod SHIFT, Tab, cyclenext, prev

    # move window
    bind = $mod SHIFT, left,  movewindow, l
    bind = $mod SHIFT, right, movewindow, r
    bind = $mod SHIFT, up,    movewindow, u
    bind = $mod SHIFT, down,  movewindow, d

    # resize, held. Super+Alt, because Super+Ctrl+Left/Right already
    # switch workspace below — binding both made one key press do both.
    binde = $mod ALT, left,  resizeactive, -40 0
    binde = $mod ALT, right, resizeactive, 40 0
    binde = $mod ALT, up,    resizeactive, 0 -40
    binde = $mod ALT, down,  resizeactive, 0 40

    # ---- workspaces ----
    ${workspaceBinds}

    bind = $mod, mouse_down, workspace, e+1
    bind = $mod, mouse_up,   workspace, e-1
    bind = $mod CTRL, right, workspace, e+1
    bind = $mod CTRL, left,  workspace, e-1

    # move the focused window to the other monitor
    bind = $mod SHIFT, N, movewindow, mon:+1

    # scratchpad
    bind = $mod, A, togglespecialworkspace, magic
    bind = $mod SHIFT, A, movetoworkspace, special:magic

    bindm = $mod, mouse:272, movewindow
    bindm = $mod, mouse:273, resizewindow

    # ---- media / brightness ----
    bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
    bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindel = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindel = , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    bindel = , XF86MonBrightnessUp, exec, brightnessctl s 5%+
    bindel = , XF86MonBrightnessDown, exec, brightnessctl s 5%-

    bindl = , XF86AudioPlay, exec, playerctl play-pause
    bindl = , XF86AudioNext, exec, playerctl next
    bindl = , XF86AudioPrev, exec, playerctl previous

    # ---- Quick Settings open ----
    # control-center enters this submap when it opens the panel and resets
    # it when it closes. Esc (or Super+S again) closes the panel. Each key
    # also has a plain `submap, reset` bind, so even if the script failed
    # the keyboard could never get stuck here.
    submap = controlcenter
    bind = , escape, exec, control-center close
    bind = , escape, submap, reset
    bind = $mod, S, exec, control-center close
    bind = $mod, S, submap, reset
    submap = reset
  '';

  # Seed monitors.conf once. Guarded, so nwg-displays' changes survive
  # every rebuild. Delete the file and rebuild to reset to the host default.
  home.activation.seedMonitors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/hypr/monitors.conf" ]; then
      run mkdir -p "$HOME/.config/hypr"
      run cat > "$HOME/.config/hypr/monitors.conf" <<'EOF'
${monitors}
EOF
      run chmod u+w "$HOME/.config/hypr/monitors.conf"
    fi
    # Sourced unconditionally above, and Hyprland errors on a missing
    # source file — so make sure an (empty) one exists.
    if [ ! -e "$HOME/.config/hypr/workspaces.conf" ]; then
      run touch "$HOME/.config/hypr/workspaces.conf"
    fi
  '';
}
