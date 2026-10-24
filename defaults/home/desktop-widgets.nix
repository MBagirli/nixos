{ config, osConfig, lib, pkgs, ... }:
let
  t = import ../theme.nix;
  g = import ../glyphs.nix { inherit lib; };

  # Must be the one matching the running compositor.
  hyprctl = "${osConfig.programs.hyprland.package}/bin/hyprctl";

  # Where the weather is for. Open-Meteo needs no API key; find a place's
  # coordinates on open-meteo.com or any map.
  place = { name = "Baku"; lat = "40.41"; lon = "49.87"; };

  eww = "${config.programs.eww.package}/bin/eww";
  jq  = "${pkgs.jq}/bin/jq";

  # ---- weather: Open-Meteo, every 15 min, cached ----
  # Always prints the full JSON shape (falling back to the last good
  # reading, then to placeholders), so the widget never meets a missing
  # key. The lock screen reads the same cache (hyprlock.nix).
  weatherFeed = pkgs.writeShellScript "desktop-weather" ''
    set -u
    cache="''${XDG_CACHE_HOME:-$HOME/.cache}/desktop-weather.json"
    url='https://api.open-meteo.com/v1/forecast?latitude=${place.lat}&longitude=${place.lon}&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=4'

    if raw=$(${pkgs.curl}/bin/curl -fsS --max-time 10 "$url") && out=$(${jq} -c \
        --arg place "${place.name}" --argjson icons '${builtins.toJSON g.weather}' '
      def kind($c; $day):
        if   $c == 0 then (if $day then "clear" else "clearNight" end)
        elif $c <= 2 then (if $day then "partly" else "partlyNight" end)
        elif $c == 3 then "cloudy"
        elif $c == 45 or $c == 48 then "fog"
        elif $c == 65 or $c == 82 then "pouring"
        elif $c == 66 or $c == 67 then "sleet"
        elif ($c >= 51 and $c <= 63) or $c == 80 or $c == 81 then "rain"
        elif ($c >= 71 and $c <= 77) or $c == 85 or $c == 86 then "snow"
        elif $c >= 95 then "storm"
        else "cloudy" end;
      def text($c):
        { "0": "Clear", "1": "Mostly clear", "2": "Partly cloudy", "3": "Overcast",
          "45": "Fog", "48": "Freezing fog", "51": "Light drizzle", "53": "Drizzle",
          "55": "Heavy drizzle", "56": "Freezing drizzle", "57": "Freezing drizzle",
          "61": "Light rain", "63": "Rain", "65": "Heavy rain", "66": "Freezing rain",
          "67": "Freezing rain", "71": "Light snow", "73": "Snow", "75": "Heavy snow",
          "77": "Snow grains", "80": "Showers", "81": "Showers", "82": "Heavy showers",
          "85": "Snow showers", "86": "Snow showers", "95": "Thunderstorm",
          "96": "Thunderstorm", "99": "Thunderstorm" }[$c | tostring] // "Unknown";
      .current as $n | .daily as $d |
      { ok: true, place: $place,
        temp: ($n.temperature_2m | round), feels: ($n.apparent_temperature | round),
        wind: ($n.wind_speed_10m | round), humidity: $n.relative_humidity_2m,
        desc: text($n.weather_code), icon: $icons[kind($n.weather_code; $n.is_day == 1)],
        days: [ range(1; 4) as $i | {
          name: ($d.time[$i] | strptime("%Y-%m-%d") | mktime | strftime("%a")),
          icon: $icons[kind($d.weather_code[$i]; true)],
          hi: ($d.temperature_2m_max[$i] | round), lo: ($d.temperature_2m_min[$i] | round) } ] }
      ' <<<"$raw"); then
      mkdir -p "$(dirname "$cache")"
      printf '%s\n' "$out" > "$cache"
      printf '%s\n' "$out"
    elif [ -s "$cache" ]; then
      cat "$cache"
    else
      ${jq} -nc --arg place "${place.name}" '{ ok: false, place: $place, temp: "--", feels: "--",
        wind: "--", humidity: "--", desc: "Weather unavailable", icon: "",
        days: [range(3) | { name: "", icon: "", hi: "", lo: "" }] }'
    fi
  '';

  # ---- calendar: this month as a pango-markup grid, today highlighted ----
  calendarFeed = pkgs.writeShellScript "desktop-calendar" ''
    set -u
    ym=$(date +%Y-%m); today=$(date +%-d)
    first=$(date -d "$ym-01" +%w)                       # 0 = Sunday
    ndays=$(date -d "$ym-01 +1 month -1 day" +%-d)
    grid="<span foreground='#${t.accent}'><b>Su Mo Tu We Th Fr Sa</b></span>"
    line=""; dow=$first
    for ((i = 0; i < first; i++)); do line+="   "; done
    for ((d = 1; d <= ndays; d++)); do
      cell=$(printf '%2d' "$d")
      if [ "$d" -eq "$today" ]; then
        cell="<span background='#${t.accent}' foreground='#${t.bg}'><b>$cell</b></span>"
      elif [ "$dow" -eq 0 ] || [ "$dow" -eq 6 ]; then
        cell="<span foreground='#${t.fgDim}'>$cell</span>"
      fi
      line+="$cell"
      if [ "$dow" -eq 6 ]; then grid+=$'\n'"$line"; line=""; dow=0
      else line+=" "; dow=$((dow + 1)); fi
    done
    [ -n "$line" ] && grid+=$'\n'"''${line% }"
    ${jq} -nc --arg month "$(date +'%B %Y')" --arg grid "$grid" '{month: $month, grid: $grid}'
  '';

  # ---- audio visualizer: cava -> 4 rows of block characters ----
  # cava prints one line per frame: 36 levels 0..32, ';'-separated. Each
  # bar becomes a column 4 characters tall (8 steps per character), each
  # row its own colour so the bars fade blue -> mauve upwards. At rest a
  # thin baseline stays: the "lines" under the wallpaper. Identical frames
  # are dropped, and cava's sleep_timer stops output after 3 s of silence,
  # so an idle desktop costs nothing.
  bars = 36;
  cavaConf = pkgs.writeText "cava-desktop.conf" ''
    [general]
    framerate = 30
    bars = ${toString bars}
    sleep_timer = 3

    [input]
    method = pipewire
    source = auto

    [output]
    method = raw
    raw_target = /dev/stdout
    data_format = ascii
    ascii_max_range = 32
    bar_delimiter = 59
    frame_delimiter = 10

    [smoothing]
    monstercat = 1
    noise_reduction = 77
  '';
  # cava exits when PipeWire is not up yet — which is the case when the
  # session starts — and eww never re-runs a finished deflisten, so the
  # bars froze for the whole session. Restart cava whenever it exits;
  # awk (and eww's view of the stream) stays alive throughout.
  visualizerFeed = pkgs.writeShellScript "desktop-visualizer" ''
    while :; do
      ${pkgs.cava}/bin/cava -p ${cavaConf} 2>/dev/null
      sleep 2
    done | ${pkgs.gawk}/bin/awk -v nbars=${toString bars} \
      -v q="'" -v c3="#cba6f7" -v c2="#b4befe" -v c1="#${t.accent}" -v c0="#74c7ec" '
      BEGIN {
        b[0] = " "; b[1] = "▁"; b[2] = "▂"; b[3] = "▃"; b[4] = "▄"
        b[5] = "▅"; b[6] = "▆"; b[7] = "▇"; b[8] = "█"
        col[3] = c3; col[2] = c2; col[1] = c1; col[0] = c0
      }
      $0 == last { next }
      {
        last = $0
        n = split($0, v, ";")
        if (n != nbars + 1) next      # partial frame from a starting/dying cava
        out = ""
        for (r = 3; r >= 0; r--) {
          line = ""
          for (i = 1; i < n; i++) {
            l = v[i] - r * 8
            if (l < 0) l = 0
            if (l > 8) l = 8
            if (r == 0 && l == 0) l = 1
            line = line b[l]
          }
          out = out (r < 3 ? "\\n" : "") "<span foreground=" q col[r] q ">" line "</span>"
        }
        printf "{\"m\":\"%s\"}\n", out
        fflush()
      }'
  '';

  restLine = lib.concatStrings (lib.replicate bars "▁");
in
{
  programs.eww.yuckConfig = ''
    ;; ---- desktop widgets (desktop-widgets.nix) ----
    (defpoll deskcal :interval "60s" :initial '{"month":"","grid":""}' `${calendarFeed}`)
    (defpoll weather :interval "900s"
      :initial '{"ok":false,"place":"${place.name}","temp":"--","feels":"--","wind":"--","humidity":"--","desc":"","icon":"","days":[{"name":"","icon":"","hi":"","lo":""},{"name":"","icon":"","hi":"","lo":""},{"name":"","icon":"","hi":"","lo":""}]}'
      `${weatherFeed}`)
    (deflisten vis :initial '{"m":"${restLine}"}' `${visualizerFeed}`)

    ;; Everything centred in the card. The grid label is centred as a
    ;; block; its lines stay left-aligned to each other, so the columns
    ;; still line up.
    (defwidget desk-clock []
      (box :class "desk-card clock-card" :orientation "v" :space-evenly false
        (label :class "desk-time" :halign "center" :text {formattime(EWW_TIME, "%H:%M")})
        (label :class "desk-date" :halign "center" :text {formattime(EWW_TIME, "%A, %d %B")})
        (box :class "desk-sep")
        (label :class "cal-month" :halign "center" :text {deskcal.month})
        (label :class "cal-grid" :halign "center" :justify "left" :markup {deskcal.grid})))

    (defwidget wday [i]
      (box :class "w-day" :space-evenly false :spacing 12
        (label :class "w-dname" :halign "start" :xalign 0 :width 44 :text {weather.days[i].name})
        (label :class "w-dicon" :text {weather.days[i].icon})
        (label :class "w-dtemps" :halign "end" :hexpand true
               :text {weather.days[i].hi == "" ? "" : "''${weather.days[i].hi}°  ''${weather.days[i].lo}°"})))

    (defwidget desk-weather []
      (box :class "desk-card weather-card" :orientation "v" :space-evenly false
        (box :space-evenly false :spacing 8
          (label :class "w-place" :halign "start" :hexpand true :text "${g.pin}  ''${weather.place}")
          (label :class "w-desc" :halign "end" :text {weather.desc}))
        (box :class "w-now" :space-evenly false :spacing 16
          (label :class "w-icon" :text {weather.icon})
          (label :class "w-temp" :text "''${weather.temp}°")
          (box :orientation "v" :valign "center" :space-evenly false :spacing 2
            (label :class "w-meta" :halign "start" :text "Feels like ''${weather.feels}°")
            (label :class "w-meta" :halign "start" :text "${g.wind}  ''${weather.wind} km/h")
            (label :class "w-meta" :halign "start" :text "${g.humidity}  ''${weather.humidity}%")))
        (box :class "desk-sep")
        (wday :i 0)
        (wday :i 1)
        (wday :i 2)))

    ;; line_height < 1 lets the rows of block characters touch, so the
    ;; bars have no seams where one row meets the next.
    (defwidget desk-visualizer []
      (label :class "vis" :markup "<span line_height='0.94'>''${vis.m}</span>"))

    ;; On the "bottom" layer: above the wallpaper, below every window.
    (defwindow desk-clock [screen]
      :monitor screen
      :geometry (geometry :x "48px" :y "40px" :anchor "top left")
      :stacking "bottom" :exclusive false :focusable false :namespace "eww-desktop"
      (desk-clock))
    (defwindow desk-weather [screen]
      :monitor screen
      :geometry (geometry :x "48px" :y "40px" :anchor "top right")
      :stacking "bottom" :exclusive false :focusable false :namespace "eww-desktop"
      (desk-weather))
    (defwindow desk-visualizer [screen]
      :monitor screen
      :geometry (geometry :y "70px" :anchor "bottom center")
      :stacking "bottom" :exclusive false :focusable false :namespace "eww-visualizer"
      (desk-visualizer))
  '';

  programs.eww.scssConfig = ''
    /* ---- desktop widgets ---- */
    .desk-card {
      background-color: rgba(${t.rgbBg}, 0.30);
      background-image: ${t.glassSheen};
      box-shadow: ${t.glassShine};
      border: 1px solid ${t.glassEdge};
      border-radius: 28px;
      padding: 22px 26px;
    }
    .desk-sep {
      min-height: 1px;
      background-color: rgba(255, 255, 255, 0.10);
      margin: 14px 0 12px 0;
    }

    .clock-card { min-width: 330px; }
    .desk-time {
      font-family: "Noto Sans";
      font-size: 60pt;
      font-weight: 200;
      color: #${t.fg};
    }
    .desk-date {
      font-family: "Noto Sans";
      font-size: 14pt;
      color: rgba(${t.rgbFg}, 0.80);
    }
    .cal-month {
      font-family: "Noto Sans";
      font-size: 11pt;
      font-weight: bold;
      color: #${t.accent2};
      margin-bottom: 6px;
    }
    .cal-grid {
      font-family: "${t.font}";
      font-size: 12pt;
      color: #${t.fg};
    }

    .weather-card { min-width: 320px; }
    .w-place { font-size: 11pt; color: #${t.fgDim}; }
    .w-desc  { font-family: "Noto Sans"; font-size: 11pt; color: #${t.fg}; }
    .w-now   { margin-top: 8px; }
    .w-icon  { font-size: 42pt; color: #${t.warn}; }
    .w-temp  { font-family: "Noto Sans"; font-size: 44pt; font-weight: 300; color: #${t.fg}; }
    .w-meta  { font-size: 10pt; color: #${t.fgDim}; }
    .w-day   { min-height: 26px; }
    .w-dname { font-family: "Noto Sans"; font-size: 11pt; color: #${t.fg}; }
    .w-dicon { font-size: 14pt; color: #${t.warn}; }
    .w-dtemps { font-family: "Noto Sans"; font-size: 11pt; color: #${t.fgDim}; }

    .vis {
      font-family: "${t.font}";
      font-size: 20pt;
      letter-spacing: 5px;
      text-shadow: 0 0 14px rgba(${t.rgbAccent}, 0.55);
    }
  '';

  # One set of widgets per monitor, reopened whenever a monitor is plugged
  # in or out. Each copy gets its own eww window id (desk-clock-0,
  # desk-clock-1, ...) so the copies can coexist; all copies share the
  # same data (one weather poll, one cava).
  systemd.user.services.desktop-widgets = {
    # Ordered after graphical-session.target (like eww itself), NOT after
    # eww.service. With After=eww.service and no order to the target,
    # systemd put this unit BEFORE the target (a target is implicitly
    # ordered after what it wants) while eww came AFTER it: a loop, and at
    # boot systemd dropped this job ("Found ordering cycle ... Job
    # desktop-widgets.service/start deleted"). After the target, the
    # session environment (HYPRLAND_INSTANCE_SIGNATURE) is also in place.
    # The script waits for the eww daemon itself.
    Unit = {
      Description = "Desktop widgets: clock, calendar, weather, audio visualizer";
      After = [ "graphical-session.target" ];
      PartOf = [ "eww.service" ];
    };
    Service = {
      ExecStart = "${pkgs.writeShellScript "desktop-widgets" ''
        set -u
        close_all() {
          mapfile -t ids < <(${eww} active-windows 2>/dev/null | cut -d: -f1 | grep '^desk-')
          [ "''${#ids[@]}" -gt 0 ] && ${eww} close "''${ids[@]}"
        }
        open_all() {
          close_all
          n=$(${hyprctl} monitors -j | ${jq} length)
          wins=(); args=()
          for ((i = 0; i < n; i++)); do
            for w in desk-clock desk-weather desk-visualizer; do
              wins+=("$w:$w-$i"); args+=(--arg "$w-$i:screen=$i")
            done
          done
          ${eww} open-many "''${wins[@]}" "''${args[@]}"
        }

        # Wait up to a minute for eww.service. `eww ping` never starts a
        # daemon; `eww open-many` would start a stray one outside the
        # service, so give up (and let Restart= retry) rather than call it
        # with no daemon running.
        up=0
        for _ in $(seq 300); do
          if ${eww} ping >/dev/null 2>&1; then up=1; break; fi
          sleep 0.2
        done
        [ "$up" = 1 ] || { echo "eww daemon not running" >&2; exit 1; }
        open_all

        # Hyprland announces monitor changes on its event socket.
        sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
        ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$sock" | while read -r ev; do
          case "$ev" in
            monitoradded*|monitorremoved*) sleep 1; open_all ;;
          esac
        done
      ''}";
      ExecStopPost = "${pkgs.writeShellScript "desktop-widgets-close" ''
        mapfile -t ids < <(${eww} active-windows 2>/dev/null | cut -d: -f1 | grep '^desk-')
        [ "''${#ids[@]}" -gt 0 ] && ${eww} close "''${ids[@]}"
        exit 0
      ''}";
      # always, not on-failure: if the link to Hyprland's event socket
      # drops (Hyprland restarted, socat killed), the script ends with
      # status 0 — and ExecStopPost has just closed every widget.
      Restart = "always";
      RestartSec = 2;
    };
    # eww.service: reopen them whenever eww restarts.
    # graphical-session.target: lets a rebuild start them right away —
    # with only eww.service here, a switch while eww was already running
    # installed the unit but never started it.
    Install.WantedBy = [ "eww.service" "graphical-session.target" ];
  };
}
