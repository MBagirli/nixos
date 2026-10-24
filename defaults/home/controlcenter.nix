{ config, osConfig, lib, pkgs, ... }:
let
  t = import ../theme.nix;
  g = import ../glyphs.nix { inherit lib; };

  eww       = "${config.programs.eww.package}/bin/eww";
  jq        = "${pkgs.jq}/bin/jq";
  nmcli     = "${pkgs.networkmanager}/bin/nmcli";
  wpctl     = "${pkgs.wireplumber}/bin/wpctl";
  bright    = "${pkgs.brightnessctl}/bin/brightnessctl";
  ddcutil   = "${pkgs.ddcutil}/bin/ddcutil";
  btctl     = "${pkgs.bluez}/bin/bluetoothctl";
  rfkill    = "${pkgs.util-linux}/bin/rfkill";
  ppd       = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl";
  playerctl = "${pkgs.playerctl}/bin/playerctl";
  flock     = "${pkgs.util-linux}/bin/flock";
  setsid    = "${pkgs.util-linux}/bin/setsid";
  swaync    = "${config.services.swaync.package}/bin/swaync-client";
  sunset    = "${pkgs.hyprsunset}/bin/hyprsunset";
  # Must be the one matching the running compositor.
  hyprctl   = "${osConfig.programs.hyprland.package}/bin/hyprctl";

  user    = config.home.username;
  initial = lib.toUpper (builtins.substring 0 1 user);

  nightKelvin = 4500;

  # Everything the panel reads or changes goes through this one script, so
  # the eww config below only ever names `cc <verb>`.
  cc = pkgs.writeShellScriptBin "control-center" ''
    set -u

    # eww kills any onclick/onchange command still running after 200 ms
    # ("command ... timed out" in its log) — which is what made the Wi-Fi
    # and Bluetooth tiles and the chevrons seem dead. So every action
    # re-launches itself detached and returns at once; the real work then
    # runs to completion outside eww's reach.
    case "''${1:-toggle}" in
      status|media) ;;
      *) if [ -z "''${CC_DETACHED:-}" ]; then
           CC_DETACHED=1 ${setsid} -f "$0" "$@" </dev/null >/dev/null 2>&1
           exit 0
         fi ;;
    esac

    rt="''${XDG_RUNTIME_DIR:-/tmp}/control-center"
    mkdir -p "$rt"
    now_ms() { date +%s%3N; }

    # Sliders fire onchange for every pixel of a drag, so dozens of calls
    # can be in flight at once and finish out of order. Each records the
    # value it wants; the lock runs device calls one at a time, and the
    # holder keeps going until what was APPLIED (a file, shared by all of
    # them) matches what is WANTED. Queued calls that find nothing new to
    # do exit at once — re-sending the same value from every queued call
    # was ~30 redundant monitor writes (~2 s of lag) per fast drag.
    set_level() {   # set_level <volume|mic|brightness> <value>
      local kind=$1 v=''${2%.*}
      # A new drag (nothing in the last 1.5 s) starts clean: the level may
      # have been changed meanwhile by the keys or another app.
      recent "$kind" || rm -f "$rt/$kind.applied"
      echo "$v" > "$rt/$kind.want"
      now_ms > "$rt/$kind.touched"
      (
        ${flock} 9
        did=0
        while v=$(cat "$rt/$kind.want"); [ "$v" != "$(cat "$rt/$kind.applied" 2>/dev/null)" ]; do
          case "$kind" in
            volume)     ${wpctl} set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "$v%" ;;
            mic)        ${wpctl} set-volume -l 1.0 @DEFAULT_AUDIO_SOURCE@ "$v%" ;;
            brightness) set_brightness "$(( v < 1 ? 1 : v ))" ;;
          esac
          echo "$v" > "$rt/$kind.applied"
          did=1
        done
        # The drag has settled: show the final number now, not at the
        # next poll (up to 2 s later). The knob is already there.
        if [ "$did" = 1 ]; then
          case "$kind" in
            volume) refresh volume ;; mic) refresh mic ;; brightness) refresh bright ;;
          esac
        fi
      ) 9>"$rt/$kind.lock"
    }

    # For 1.5 s after a slider moved, report the value the user asked for
    # instead of re-reading the device, so the poll cannot yank the knob
    # back while it is still being dragged.
    recent() {
      [ -e "$rt/$1.touched" ] && [ $(( $(now_ms) - $(cat "$rt/$1.touched") )) -lt 1500 ]
    }
    # ...and for as long as writes are still being applied (slow DDC
    # monitors can lag behind the drag), so the knob never snaps back.
    busy() { ! ${flock} -n "$rt/$1.lock" true 2>/dev/null; }
    settling() { recent "$1" || busy "$1"; }

    # ---- brightness of the screen the panel is open on ----
    # The laptop panel has a backlight (brightnessctl); an external
    # monitor is driven over its cable with DDC/CI (ddcutil). open()
    # records which output the panel is on.
    target() { cat "$rt/screen" 2>/dev/null || echo eDP-1; }
    is_internal() { case "$1" in eDP*|LVDS*|DSI*) return 0 ;; *) return 1 ;; esac; }

    # i2c bus of an output's DDC channel, e.g. HDMI-A-1 -> 6 ("none" if the
    # monitor has no DDC/CI or has it switched off in its own menu).
    # Detection takes ~0.4 s, so it is cached until the panel next opens.
    ddc_bus() {
      local f="$rt/ddc-$1"
      if [ ! -s "$f" ]; then
        ${ddcutil} detect --brief 2>/dev/null | awk -v want="$1" '
          /^Display/         { ok = 1 }
          /^Invalid display/ { ok = 0 }
          /I2C bus:/         { bus = $NF; sub(/.*i2c-/, "", bus) }
          /DRM connector:/   { c = $NF; sub(/^card[0-9]+-/, "", c)
                               if (ok && c == want) { print bus; found = 1; exit } }
          END { if (!found) print "none" }' > "$f"
      fi
      cat "$f"
    }
    # --skip-ddc-checks halves each call (~145 -> ~67 ms on the MSI).
    ddc() { ${ddcutil} --bus "$1" --sleep-multiplier 0.2 --skip-ddc-checks "''${@:2}"; }

    set_brightness() {   # percent
      local s bus max
      s=$(target)
      if is_internal "$s"; then
        ${bright} -q set "$1%"
      else
        bus=$(ddc_bus "$s"); [ "$bus" = none ] && return
        max=$(cat "$rt/ddcmax-$s" 2>/dev/null); max=''${max:-100}
        ddc "$bus" --noverify setvcp 10 $(( $1 * max / 100 ))
      fi
    }

    brightness_status() {   # {level, ext, ok}
      local s bus level=0 ok=true ext=false cur max
      s=$(target)
      # Mid-drag: report the wanted value WITHOUT touching the monitor — a
      # DDC read here would queue behind (and slow down) the writes.
      if settling brightness; then
        is_internal "$s" || ext=true
        ${jq} -nc --argjson l "$(cat "$rt/brightness.want")" --argjson e "$ext" '{level: $l, ext: $e, ok: true}'
        return
      fi
      if is_internal "$s"; then
        level=$(${bright} -m | awk -F, '{ gsub("%", "", $4); print $4; exit }')
      else
        ext=true
        bus=$(ddc_bus "$s")
        if [ "$bus" != none ] && read -r _ _ _ cur max < <(ddc "$bus" getvcp 10 --brief 2>/dev/null) && [ "''${max:-0}" -gt 0 ]; then
          echo "$max" > "$rt/ddcmax-$s"
          level=$(( cur * 100 / max ))
        else
          ok=false
        fi
      fi
      ${jq} -nc --argjson l "''${level:-0}" --argjson e "$ext" --argjson o "$ok" '{level: $l, ext: $e, ok: $o}'
    }

    status() {
      case "$1" in
        volume|mic)
          dev=@DEFAULT_AUDIO_SINK@; [ "$1" = mic ] && dev=@DEFAULT_AUDIO_SOURCE@
          read -r _ vol muted < <(${wpctl} get-volume "$dev")
          if settling "$1"; then level=$(cat "$rt/$1.want")
          else level=$(awk -v v="''${vol:-0}" 'BEGIN { printf "%d", v * 100 + 0.5 }')
          fi
          ${jq} -nc --argjson l "$level" --argjson m "$([ -n "''${muted:-}" ] && echo true || echo false)" \
            '{level: $l, muted: $m}' ;;

        brightness) brightness_status ;;

        wifi)
          on=false; ssid=""; signal=0
          if [ "$(${nmcli} radio wifi)" = enabled ]; then
            on=true
            IFS=: read -r _ signal ssid < <(${nmcli} -t -f IN-USE,SIGNAL,SSID device wifi list --rescan no | grep '^\*' | head -1)
            ssid=''${ssid//\\:/:}
          fi
          ${jq} -nc --argjson on "$on" --arg s "$ssid" --argjson sig "''${signal:-0}" \
            '{on: $on, ssid: $s, signal: $sig}' ;;

        bluetooth)
          on=false; count=0; name=""
          if ${btctl} show | grep -q "Powered: yes"; then
            on=true
            mapfile -t devs < <(${btctl} devices Connected | cut -d' ' -f3-)
            count=''${#devs[@]}; name=''${devs[0]:-}
          fi
          ${jq} -nc --argjson on "$on" --argjson c "$count" --arg n "$name" \
            '{on: $on, count: $c, name: $n}' ;;

        dnd)     ${swaync} -D 2>/dev/null || echo false ;;
        night)   systemctl --user is-active --quiet nightlight.service && echo true || echo false ;;
        profile) ${ppd} get 2>/dev/null || echo balanced ;;
        idle)    screen-timeout get 2>/dev/null || echo 5 ;;     # hyprlock.nix
        uptime)  ${pkgs.procps}/bin/uptime -p | sed 's/^up //' ;;

      esac
    }

    refresh() { for v in "$@"; do ${eww} update "$v=$(status "$v")"; done; }

    # Show the new state at once, before the (slow) real change: flip the
    # "on" field of a JSON var, or set a plain var.
    flip_on() { ${eww} update "$1=$(${eww} get "$1" | ${jq} -c '.on = (.on | not)')"; }

    # eww numbers its screens in the order the compositor announced them,
    # which is Hyprland's monitor id order. Prints "<index> <output name>".
    focused_screen() {
      ${hyprctl} monitors -j | ${jq} -r '[sort_by(.id)[]] | (map(.focused) | index(true) // 0) as $i
        | "\($i) \(.[$i].name)"'
    }

    is_open() { ${eww} active-windows 2>/dev/null | grep -q '^controlcenter'; }

    # One eww call opens both windows (the panel and the click catcher
    # behind it) on the focused screen; the rest happens alongside.
    # The "controlcenter" Hyprland submap (hyprland.nix) binds Escape to
    # `control-center close` while the panel is open.
    open() {
      read -r s name < <(focused_screen)
      # The brightness slider follows this screen; forget the last one's
      # DDC details (monitors may have been swapped since).
      echo "$name" > "$rt/screen"
      rm -f "$rt"/ddc-* "$rt/brightness.touched" "$rt/brightness.applied"
      ${eww} open-many cc-closer controlcenter \
        --arg "cc-closer:screen=$s" --arg "controlcenter:screen=$s" &
      ${eww} update cc_open=true &
      ${hyprctl} dispatch submap controlcenter >/dev/null &
      refresh bright &
      wait
    }
    close() {
      ${hyprctl} dispatch submap reset >/dev/null &
      ${eww} close controlcenter cc-closer 2>/dev/null &
      ${eww} update cc_open=false &
      wait
    }

    case "''${1:-toggle}" in
      toggle) if is_open; then close; else open; fi ;;
      open)   open ;;
      close)  close ;;
      status) status "$2" ;;

      # Sliders: eww already shows the new value, no refresh needed.
      volume)     set_level volume "$2" ;;
      mic-level)  set_level mic "$2" ;;
      brightness) set_level brightness "$2" ;;

      mute)     ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle;   refresh volume ;;
      mic-mute) ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle; refresh mic ;;

      wifi)
        flip_on wifi
        if [ "$(${nmcli} radio wifi)" = enabled ]; then ${nmcli} radio wifi off; else ${nmcli} radio wifi on; fi
        sleep 2; refresh wifi ;;          # SSID shows up once it reconnects
      bluetooth)
        flip_on bluetooth
        if ${btctl} show | grep -q "Powered: yes"; then ${btctl} power off >/dev/null
        else ${rfkill} unblock bluetooth 2>/dev/null; ${btctl} power on >/dev/null; fi
        sleep 1; refresh bluetooth ;;
      dnd)
        ${eww} update dnd="$([ "$(${eww} get dnd)" = true ] && echo false || echo true)"
        ${swaync} -d -sw >/dev/null; refresh dnd ;;
      night)
        if systemctl --user is-active --quiet nightlight.service; then
          ${eww} update night=false
          systemctl --user stop nightlight.service
        else
          ${eww} update night=true
          systemd-run --user --unit=nightlight --collect --quiet ${sunset} -t ${toString nightKelvin}
        fi
        sleep 0.3; refresh night ;;
      profile)
        ${eww} update profile="$2"
        ${ppd} set "$2"; refresh profile ;;
      idle)
        ${eww} update idle="$2"
        screen-timeout set "$2"; refresh idle ;;

      # Close the panel first, then let Hyprland start the app so it does
      # not live inside the eww service's cgroup.
      run)
        shift; close
        ${hyprctl} dispatch exec -- "$*" >/dev/null ;;

      # Long-running feed for the media card.
      media)
        ${playerctl} --follow metadata --format $'{{status}}\t{{title}}\t{{artist}}' 2>/dev/null \
          | while IFS=$'\t' read -r st ti ar; do
              ${jq} -nc --arg s "''${st:-Stopped}" --arg t "$ti" --arg a "$ar" \
                '{status: $s, title: $t, artist: $a}'
            done ;;
    esac
  '';

  c = "${cc}/bin/control-center";

  volIcon = v: ''{${v}.muted ? "${g.volumeOff}" : ${v}.level < 34 ? "${lib.elemAt g.volume 0}" : ${v}.level < 67 ? "${lib.elemAt g.volume 1}" : "${lib.elemAt g.volume 2}"}'';
  wifiIcon = ''{!wifi.on ? "${g.wifiOff}" : wifi.ssid == "" ? "${g.wifiAlert}" : wifi.signal >= 75 ? "${lib.elemAt g.wifi 4}" : wifi.signal >= 50 ? "${lib.elemAt g.wifi 3}" : wifi.signal >= 25 ? "${lib.elemAt g.wifi 2}" : "${lib.elemAt g.wifi 1}"}'';
in
{
  home.packages = [ cc ];

  # Home Manager's eww unit has no restart triggers, so after a rebuild a
  # running daemon kept the old widgets and the old GTK stylesheet — which
  # once left grey square corners round the desktop widgets until eww was
  # restarted by hand. Naming the files' store paths here makes a rebuild
  # restart eww (and, via PartOf, the desktop widgets) when they change.
  systemd.user.services.eww.Unit.X-Restart-Triggers = [
    config.xdg.configFile."eww/eww.yuck".source
    config.xdg.configFile."eww/eww.scss".source
    config.xdg.configFile."gtk-3.0/gtk.css".source
  ];

  programs.eww = {
    enable = true;
    systemd.enable = true;

    yuckConfig = ''
      ;; Polls only run while the panel is open (cc_open), so a closed
      ;; panel costs nothing.
      (defvar cc_open false)

      (defpoll volume  :interval "1s"  :run-while cc_open :initial '{"level":0,"muted":false}' `${c} status volume`)
      (defpoll mic     :interval "2s"  :run-while cc_open :initial '{"level":0,"muted":false}' `${c} status mic`)
      (defpoll bright  :interval "2s"  :run-while cc_open :initial '{"level":0,"ext":false,"ok":true}' `${c} status brightness`)
      (defpoll wifi    :interval "4s"  :run-while cc_open :initial '{"on":false,"ssid":"","signal":0}' `${c} status wifi`)
      (defpoll bluetooth :interval "4s" :run-while cc_open :initial '{"on":false,"count":0,"name":""}' `${c} status bluetooth`)
      (defpoll dnd     :interval "3s"  :run-while cc_open :initial "false" `${c} status dnd`)
      (defpoll night   :interval "3s"  :run-while cc_open :initial "false" `${c} status night`)
      (defpoll profile :interval "4s"  :run-while cc_open :initial "balanced" `${c} status profile`)
      (defpoll idle    :interval "10s" :run-while cc_open :initial "5" `${c} status idle`)
      (defpoll uptime  :interval "60s" :run-while cc_open :initial "" `${c} status uptime`)
      (deflisten media :initial '{"status":"Stopped","title":"","artist":""}' `${c} media`)

      ;; ---- building blocks ----

      ;; A quick-settings tile: the big part toggles, the chevron opens
      ;; the full picker for that setting.
      (defwidget tile [icon title sub active onclick ?onmore]
        (box :class {active ? "tile on" : "tile"} :space-evenly false
          (button :class "tile-main" :hexpand true :onclick onclick
            (box :space-evenly false :spacing 12
              (label :class "tile-icon" :text icon)
              (box :orientation "v" :space-evenly false :valign "center"
                (label :class "tile-title" :halign "start" :text title)
                (label :class "tile-sub" :halign "start" :limit-width 15 :text sub))))
          (button :class "tile-more" :visible {onmore != ""} :onclick onmore "${g.chevron}")))

      (defwidget slider [icon value onchange onicon dim ?onmore]
        (box :class {dim ? "slider-row dim" : "slider-row"} :space-evenly false :spacing 8
          (button :class "slider-icon" :onclick onicon (label :text icon))
          (scale :class "slider" :hexpand true :min 0 :max 101 :round-digits 0
                 :value value :onchange onchange)
          (label :class "slider-value" :text "''${value}%")
          (button :class "slider-more" :visible {onmore != ""} :onclick onmore "${g.chevron}")))

      (defwidget pbtn [name icon text]
        (button :class {profile == name ? "pbtn on" : "pbtn"} :hexpand true
                :onclick "${c} profile ''${name}"
          (box :space-evenly false :spacing 6 :halign "center"
            (label :class "pbtn-icon" :text icon)
            (label :text text))))

      ;; One choice in the screen-timeout row.
      (defwidget tbtn [value text]
        (button :class {idle == value ? "tbtn on" : "tbtn"} :hexpand true
                :onclick "${c} idle ''${value}"
          (label :text text)))

      (defwidget hbtn [icon onclick]
        (button :class "hbtn" :onclick onclick (label :text icon)))

      ;; ---- the panel ----

      (defwidget controlcenter []
        (box :class "cc" :orientation "v" :space-evenly false :spacing 14

          (box :class "header" :space-evenly false :spacing 12
            (box :class "avatar" :valign "center" (label :text "${initial}"))
            (box :orientation "v" :space-evenly false :valign "center" :hexpand true
              (label :class "user" :halign "start" :text "${user}")
              (label :class "uptime" :halign "start" :text "up ''${uptime}"))
            (hbtn :icon "${g.screenshot}" :onclick "${c} run screenshot")
            (hbtn :icon "${g.cog}" :onclick "${c} run nwg-displays"))

          (box :orientation "v" :spacing 10
            (box :spacing 10
              (tile :icon ${wifiIcon}
                    :title "Wi-Fi"
                    :sub {!wifi.on ? "Off" : wifi.ssid == "" ? "Not connected" : wifi.ssid}
                    :active {wifi.on}
                    :onclick "${c} wifi"
                    :onmore "${c} run wifi-menu")
              (tile :icon {bluetooth.on ? (bluetooth.count > 0 ? "${g.bluetoothOn}" : "${g.bluetooth}") : "${g.bluetoothOff}"}
                    :title "Bluetooth"
                    :sub {!bluetooth.on ? "Off" : bluetooth.count == 0 ? "No devices" : bluetooth.count == 1 ? bluetooth.name : "''${bluetooth.count} devices"}
                    :active {bluetooth.on}
                    :onclick "${c} bluetooth"
                    :onmore "${c} run bt-menu"))
            (box :spacing 10
              (tile :icon {dnd ? "${g.bellOff}" : "${g.bell}"}
                    :title "Do not disturb"
                    :sub {dnd ? "On" : "Off"}
                    :active dnd
                    :onclick "${c} dnd"
                    :onmore "${c} run ${swaync} -t -sw")
              (tile :icon "${g.night}"
                    :title "Night light"
                    :sub {night ? "On" : "Off"}
                    :active night
                    :onclick "${c} night")))

          (box :class "card" :orientation "v" :space-evenly false :spacing 4
            (slider :icon ${volIcon "volume"}
                    :value {volume.level} :dim {volume.muted}
                    :onchange "${c} volume {}" :onicon "${c} mute"
                    :onmore "${c} run pwvucontrol")
            (slider :icon {mic.muted ? "${g.micOff}" : "${g.mic}"}
                    :value {mic.level} :dim {mic.muted}
                    :onchange "${c} mic-level {}" :onicon "${c} mic-mute"
                    :onmore "${c} run pwvucontrol")
            ;; Brightness of the screen this panel is on: the backlight on the
            ;; laptop panel, DDC/CI on an external monitor (monitor icon).
            ;; Dimmed if that monitor has no DDC/CI (or it is off in its menu).
            (slider :icon {bright.ext ? "${g.monitor}" : "${g.brightness}"}
                    :value {bright.level} :dim {!bright.ok}
                    :onchange "${c} brightness {}" :onicon ""
                    :onmore "${c} run luminance"))

          ;; How long the screen may sit idle before it locks (the display
          ;; turns off a minute later). Never = no idle lock at all.
          (box :class "card timeout" :orientation "v" :space-evenly false :spacing 10
            (box :space-evenly false :spacing 10
              (label :class "row-icon" :text "${g.timer}")
              (label :class "row-title" :halign "start" :hexpand true :text "Screen timeout")
              (label :class "row-value" :text {idle == "never" ? "Never locks" : "Locks after ''${idle} min"}))
            (box :spacing 6
              (tbtn :value "2" :text "2 min")
              (tbtn :value "5" :text "5 min")
              (tbtn :value "10" :text "10 min")
              (tbtn :value "30" :text "30 min")
              (tbtn :value "never" :text "Never")))

          (revealer :reveal {media.status != "Stopped"} :transition "slidedown" :duration "250ms"
            (box :class "card media" :space-evenly false :spacing 12
              (label :class "media-icon" :text "${g.music}")
              (box :orientation "v" :space-evenly false :valign "center" :hexpand true
                (label :class "media-title" :halign "start" :limit-width 24 :text {media.title})
                (label :class "media-artist" :halign "start" :limit-width 28 :text {media.artist}))
              (button :class "media-btn" :onclick "${playerctl} previous" "${g.prev}")
              (button :class "media-btn play" :onclick "${playerctl} play-pause"
                {media.status == "Playing" ? "${g.pause}" : "${g.play}"})
              (button :class "media-btn" :onclick "${playerctl} next" "${g.next}")))

          (box :class "profiles" :spacing 6
            (pbtn :name "power-saver" :icon "${g.leaf}" :text "Saver")
            (pbtn :name "balanced" :icon "${g.balance}" :text "Balanced")
            (pbtn :name "performance" :icon "${g.speed}" :text "Performance"))))

      (defwindow controlcenter [screen]
        :monitor screen
        :geometry (geometry :x "10px" :y "8px" :anchor "top right")
        :stacking "overlay"
        :exclusive false
        :focusable false
        :namespace "eww-controlcenter"
        (controlcenter))

      ;; Transparent full-screen catcher under the panel: a click anywhere
      ;; outside it closes it, like any other popover.
      (defwindow cc-closer [screen]
        :monitor screen
        :geometry (geometry :width "100%" :height "100%" :anchor "center")
        :stacking "fg"
        :exclusive false
        :focusable false
        :namespace "eww-closer"
        (eventbox :onclick "${c} close" :onrightclick "${c} close" :onmiddleclick "${c} close"))
    '';

    scssConfig = ''
      $bg:      rgba(${t.rgbBg}, ${t.glass});
      $edge:    ${t.glassEdge};
      $fg:      #${t.fg};
      $fg-dim:  #${t.fgDim};
      $accent:  #${t.accent};
      $accent2: #${t.accent2};
      $urgent:  #${t.urgent};
      $ok:      #${t.ok};
      $dark:    #${t.bg};
      $raised:  rgba(255, 255, 255, 0.06);
      $hover:   rgba(255, 255, 255, 0.12);

      * {
        all: unset;
        font-family: "${t.fontUi}";
        font-size: ${toString t.fontSize}pt;
        color: $fg;
      }

      /* Liquid glass: translucent fill (Hyprland blurs behind it), a sheen
         fading down from the top edge, a 1px inner highlight, a soft rim. */
      .cc {
        background-color: $bg;
        background-image: ${t.glassSheen};
        box-shadow: ${t.glassShine};
        border: 1px solid $edge;
        border-radius: 26px;
        padding: 18px;
        min-width: 380px;
      }

      tooltip {
        background-color: rgba(${t.rgbBg}, 0.9);
        border: 1px solid $edge;
        border-radius: 10px;
        label { padding: 4px 8px; }
      }

      /* ---- header ---- */
      .avatar {
        background-image: linear-gradient(135deg, $accent, $accent2);
        border-radius: 999px;
        min-width: 42px;
        min-height: 42px;
        label { color: $dark; font-weight: bold; font-size: 15pt; }
      }
      .user   { font-weight: bold; font-size: 12pt; }
      .uptime { color: $fg-dim; font-size: 9pt; }

      .hbtn {
        background-color: $raised;
        border-radius: 999px;
        min-width: 34px;
        min-height: 34px;
        label { font-size: 13pt; }
        &:hover { background-color: $hover; }
      }

      /* ---- tiles ---- */
      .tile {
        background-color: $raised;
        background-image: ${t.glassSheen};
        box-shadow: ${t.glassShine};
        border: 1px solid rgba(255, 255, 255, 0.07);
        border-radius: 18px;
        min-height: 60px;
        transition: background-color 150ms ease;
      }
      .tile-main {
        padding: 8px 12px;
        border-radius: 18px;
        &:hover { background-color: rgba(255, 255, 255, 0.05); }
      }
      .tile-icon  { font-size: 17pt; min-width: 26px; }
      .tile-title { font-weight: bold; font-size: 10pt; }
      .tile-sub   { color: $fg-dim; font-size: 9pt; }
      .tile-more {
        padding: 0 12px;
        border-radius: 0 18px 18px 0;
        border-left: 1px solid rgba(255, 255, 255, 0.08);
        font-size: 13pt;
        &:hover { background-color: rgba(255, 255, 255, 0.08); }
      }
      .tile.on {
        background-color: rgba(${t.rgbAccent}, 0.88);
        label { color: $dark; }
        .tile-sub { color: rgba(${t.rgbBg}, 0.75); }
        .tile-more { border-left-color: rgba(${t.rgbBg}, 0.15); }
      }

      /* ---- sliders ---- */
      .card {
        background-color: rgba(255, 255, 255, 0.04);
        box-shadow: ${t.glassShine};
        border: 1px solid rgba(255, 255, 255, 0.07);
        border-radius: 18px;
        padding: 10px 12px;
      }
      .slider-row { min-height: 34px; }
      .slider-icon {
        min-width: 32px;
        min-height: 32px;
        border-radius: 999px;
        label { font-size: 14pt; }
        &:hover { background-color: $hover; }
      }
      .slider-value { color: $fg-dim; font-size: 9pt; min-width: 36px; }
      .slider-more {
        padding: 0 4px;
        border-radius: 8px;
        color: $fg-dim;
        &:hover { background-color: $hover; color: $fg; }
      }

      scale {
        margin: 0 4px;
        trough {
          background-color: rgba(255, 255, 255, 0.12);
          border-radius: 999px;
          min-height: 8px;
          min-width: 150px;
        }
        highlight {
          background-image: linear-gradient(90deg, $accent, $accent2);
          border-radius: 999px;
        }
        slider {
          background-color: $fg;
          border-radius: 999px;
          min-width: 16px;
          min-height: 16px;
          margin: -4px 0;
          box-shadow: 0 1px 4px rgba(0, 0, 0, 0.45);
        }
      }
      .dim {
        .slider-icon label { color: $urgent; }
        scale highlight { background-image: none; background-color: rgba(255, 255, 255, 0.25); }
      }

      /* ---- media ---- */
      .media-icon   { font-size: 20pt; color: $accent2; min-width: 30px; }
      .media-title  { font-weight: bold; font-size: 10pt; }
      .media-artist { color: $fg-dim; font-size: 9pt; }
      .media-btn {
        min-width: 30px;
        min-height: 30px;
        border-radius: 999px;
        font-size: 13pt;
        &:hover { background-color: $hover; }
        &.play { background-color: $accent; label { color: $dark; } }
      }

      /* ---- screen timeout ---- */
      .row-icon  { font-size: 14pt; min-width: 26px; color: $accent2; }
      .row-title { font-weight: bold; font-size: 10pt; }
      .row-value { color: $fg-dim; font-size: 9pt; }
      .tbtn {
        background-color: $raised;
        border-radius: 10px;
        padding: 6px 2px;
        label { font-size: 9pt; }
        &:hover { background-color: $hover; }
        &.on {
          background-color: rgba(${t.rgbAccent}, 0.88);
          label { color: $dark; }
        }
      }

      /* ---- power profiles ---- */
      .pbtn {
        background-color: $raised;
        border-radius: 12px;
        padding: 8px 4px;
        label { font-size: 9pt; }
        .pbtn-icon { font-size: 11pt; }
        &:hover { background-color: $hover; }
        &.on {
          background-color: rgba(${t.rgbAccent}, 0.88);
          label { color: $dark; }
        }
      }
    '';
  };
}
