{ lib, pkgs, ... }:
let
  t = import ../theme.nix;
  g = import ../glyphs.nix { inherit lib; };

  rofi    = "${pkgs.rofi}/bin/rofi";
  nmcli   = "${pkgs.networkmanager}/bin/nmcli";
  btctl   = "${pkgs.bluez}/bin/bluetoothctl";
  notify  = "${pkgs.libnotify}/bin/notify-send";
  rfkill  = "${pkgs.util-linux}/bin/rfkill";

  # Shared by both menus: a rofi list under the bar, plus pango-escaping
  # for names that come from the outside world (SSIDs, device aliases).
  common = ''
    THEME="''${XDG_CONFIG_HOME:-$HOME/.config}/rofi/menu.rasi"

    menu() {   # menu <prompt> <message> [rofi args...]  — rows on stdin
      local prompt=$1 mesg=$2; shift 2
      ${rofi} -dmenu -i -markup-rows -no-custom \
        -p "$prompt" -mesg "$mesg" -theme "$THEME" "$@"
    }

    ask_password() {   # ask_password <network>
      ${rofi} -dmenu -password -p "Password" \
        -mesg "Enter the password for <b>$(esc "$1")</b>" \
        -theme "$THEME" -theme-str 'listview { enabled: false; }' </dev/null
    }

    # \& because bash 5.2 turns a bare & in the replacement into the match.
    esc() { local s=$1; s=''${s//&/\&amp;}; s=''${s//</\&lt;}; s=''${s//>/\&gt;}; printf '%s' "$s"; }
    dim() { printf "<span alpha='55%%'>%s</span>" "$1"; }
  '';

  wifiMenu = pkgs.writeShellScriptBin "wifi-menu" ''
    set -u
    ${common}
    note() { ${notify} -a "Wi-Fi" -i network-wireless "$@"; }

    if [ "$(${nmcli} radio wifi)" != enabled ]; then
      pick=$(printf '%s\n' "${g.wifiOff}  Turn Wi-Fi on" | menu "Wi-Fi" "Wi-Fi is off") || exit 0
      [ -n "$pick" ] && ${nmcli} radio wifi on && note "Wi-Fi turned on"
      exit 0
    fi

    # IN-USE:SIGNAL:SECURITY:SSID — SSID goes last because it is the only
    # field that can contain ':' (nmcli escapes it as '\:'), so `read`
    # hands the whole remainder to it. One SSID can appear once per
    # access point; keep the strongest.
    declare -A signal security
    current=""
    while IFS=: read -r inuse sig sec ssid; do
      ssid=''${ssid//\\:/:}
      [ -n "$ssid" ] || continue                     # hidden networks
      [ "$inuse" = "*" ] && current=$ssid
      if [ -z "''${signal[$ssid]+x}" ] || [ "$sig" -gt "''${signal[$ssid]}" ]; then
        signal[$ssid]=$sig
        security[$ssid]=$sec
      fi
    done < <(${nmcli} -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan auto 2>/dev/null)

    declare -A saved
    while IFS=: read -r name type; do
      [ "$type" = 802-11-wireless ] && saved[''${name//\\:/:}]=1
    done < <(${nmcli} -t -f NAME,TYPE connection show 2>/dev/null)

    icon() {
      local s=$1
      if   [ "$s" -ge 80 ]; then printf '%s' "${lib.elemAt g.wifi 4}"
      elif [ "$s" -ge 60 ]; then printf '%s' "${lib.elemAt g.wifi 3}"
      elif [ "$s" -ge 40 ]; then printf '%s' "${lib.elemAt g.wifi 2}"
      elif [ "$s" -ge 20 ]; then printf '%s' "${lib.elemAt g.wifi 1}"
      else                       printf '%s' "${lib.elemAt g.wifi 0}"
      fi
    }

    # Connected network first, then strongest to weakest.
    rows=(); keys=(); active=""
    while IFS=$'\t' read -r _ ssid; do
      [ -n "$ssid" ] || continue
      extra=""
      [ -n "''${security[$ssid]}" ] && [ "''${security[$ssid]}" != "--" ] && extra+="  $(dim "${g.lock}")"
      if   [ "$ssid" = "$current" ]; then extra+="  $(dim "Connected")"; active=''${#rows[@]}
      elif [ -n "''${saved[$ssid]+x}" ]; then extra+="  $(dim "Saved")"
      fi
      rows+=("$(icon "''${signal[$ssid]}")   $(esc "$ssid")$extra")
      keys+=("$ssid")
    done < <(
      for s in "''${!signal[@]}"; do
        p=''${signal[$s]}; [ "$s" = "$current" ] && p=1000
        printf '%s\t%s\n' "$p" "$s"
      done | sort -t$'\t' -k1,1nr
    )

    rows+=("${g.refresh}   Scan again");          keys+=("@rescan")
    rows+=("${g.wifiOff}   Turn Wi-Fi off");      keys+=("@off")
    rows+=("${g.cog}   Advanced network settings"); keys+=("@settings")

    if [ -n "$current" ]; then mesg="Connected to <b>$(esc "$current")</b>"; else mesg="Not connected"; fi
    idx=$(printf '%s\n' "''${rows[@]}" | menu "Wi-Fi" "$mesg" -format i ''${active:+-a "$active"}) || exit 0
    [ -n "$idx" ] || exit 0
    choice=''${keys[$idx]}

    case "$choice" in
      @rescan)   ${nmcli} device wifi rescan 2>/dev/null; sleep 3; exec "$0" ;;
      @off)      ${nmcli} radio wifi off && note "Wi-Fi turned off"; exit 0 ;;
      @settings) exec ${pkgs.networkmanagerapplet}/bin/nm-connection-editor ;;
    esac

    if [ "$choice" = "$current" ]; then
      conn=$(${nmcli} -t -f NAME,TYPE connection show --active | awk -F: '$2=="802-11-wireless"{print $1; exit}')
      act=$(printf '%s\n' "${g.close}   Disconnect" "${g.close}   Forget this network" \
              | menu "$choice" "Connected · signal ''${signal[$choice]}%" -format i) || exit 0
      case "$act" in
        0) ${nmcli} connection down id "$conn" >/dev/null && note "Disconnected from $choice" ;;
        1) ${nmcli} connection delete id "$conn" >/dev/null && note "Forgot $choice" ;;
      esac
      exit 0
    fi

    secured=0
    [ -n "''${security[$choice]}" ] && [ "''${security[$choice]}" != "--" ] && secured=1

    rc=0
    if [ -n "''${saved[$choice]+x}" ]; then
      note "Connecting to $choice…"
      ${nmcli} connection up id "$choice" >/dev/null 2>&1 || rc=$?
      if [ "$rc" != 0 ] && [ "$secured" = 1 ]; then
        # The stored password no longer works (changed on the router).
        pw=$(ask_password "$choice") || exit 0
        [ -n "$pw" ] || exit 0
        rc=0
        { ${nmcli} connection modify id "$choice" wifi-sec.psk "$pw" &&
          ${nmcli} connection up id "$choice" >/dev/null 2>&1; } || rc=$?
      fi
    elif [ "$secured" = 1 ]; then
      pw=$(ask_password "$choice") || exit 0
      [ -n "$pw" ] || exit 0
      note "Connecting to $choice…"
      ${nmcli} device wifi connect "$choice" password "$pw" >/dev/null 2>&1 || rc=$?
    else
      note "Connecting to $choice…"
      ${nmcli} device wifi connect "$choice" >/dev/null 2>&1 || rc=$?
    fi

    if [ "$rc" = 0 ]; then
      note "Connected to $choice"
    else
      # Do not leave a half-made profile with a wrong password behind.
      [ -z "''${saved[$choice]+x}" ] && ${nmcli} connection delete id "$choice" >/dev/null 2>&1
      note -u critical "Could not connect to $choice" "Check the password and try again."
      exit 1
    fi
  '';

  btMenu = pkgs.writeShellScriptBin "bt-menu" ''
    set -u
    ${common}
    note() { ${notify} -a "Bluetooth" -i bluetooth "$@"; }

    if ! ${btctl} show | grep -q "Powered: yes"; then
      pick=$(printf '%s\n' "${g.bluetooth}   Turn Bluetooth on" | menu "Bluetooth" "Bluetooth is off") || exit 0
      [ -n "$pick" ] || exit 0
      ${rfkill} unblock bluetooth 2>/dev/null
      ${btctl} power on >/dev/null && note "Bluetooth turned on"
      exit 0
    fi

    kind() {
      case "$1" in
        audio-headset)              printf '%s' "${g.headset}" ;;
        audio-headphones)           printf '%s' "${g.headphones}" ;;
        audio-card|audio-speakers)  printf '%s' "${g.speaker}" ;;
        input-mouse|input-tablet)   printf '%s' "${g.mouse}" ;;
        input-keyboard)             printf '%s' "${g.keyboard}" ;;
        input-gaming)               printf '%s' "${g.gamepad}" ;;
        phone)                      printf '%s' "${g.phone}" ;;
        computer)                   printf '%s' "${g.laptop}" ;;
        *)                          printf '%s' "${g.bluetooth}" ;;
      esac
    }

    rows=(); macs=(); names=(); state=(); active=""; connected=0
    while read -r _ mac name; do
      info=$(${btctl} info "$mac")
      icon=$(awk -F': ' '/^\s*Icon:/{print $2; exit}' <<<"$info")
      batt=$(sed -n 's/.*Battery Percentage:.*(\([0-9]*\)).*/\1/p' <<<"$info")
      status=""
      if grep -q "Connected: yes" <<<"$info"; then
        status="Connected"; state+=(1); connected=$((connected + 1))
        active=''${active:+$active,}''${#rows[@]}
      else
        state+=(0)
      fi
      [ -n "$batt" ] && status="''${status:+$status · }$batt% battery"
      rows+=("$(kind "$icon")   $(esc "$name")''${status:+  $(dim "$status")}")
      macs+=("$mac"); names+=("$name")
    done < <(${btctl} devices Paired)

    n=''${#macs[@]}
    rows+=("${g.plus}   Pair a new device");      macs+=("@pair")
    rows+=("${g.bluetoothOff}   Turn Bluetooth off"); macs+=("@off")

    case "$connected" in
      0) mesg="No devices connected" ;;
      1) mesg="1 device connected" ;;
      *) mesg="$connected devices connected" ;;
    esac

    idx=$(printf '%s\n' "''${rows[@]}" | menu "Bluetooth" "$mesg" -format i ''${active:+-a "$active"}) || exit 0
    [ -n "$idx" ] || exit 0

    case "''${macs[$idx]}" in
      @pair) exec ${pkgs.overskride}/bin/overskride ;;
      @off)  ${btctl} power off >/dev/null && note "Bluetooth turned off"; exit 0 ;;
    esac

    mac=''${macs[$idx]}; name=''${names[$idx]}
    if [ "''${state[$idx]}" = 1 ]; then
      ${btctl} disconnect "$mac" >/dev/null && note "Disconnected $name"
    else
      note "Connecting to $name…"
      if ${btctl} connect "$mac" | grep -q "Connection successful"; then
        note "Connected to $name"
      else
        note -u critical "Could not connect to $name" "Make sure it is switched on and in range."
      fi
    fi
  '';
in
{
  home.packages = [ wifiMenu btMenu ];

  # A list that drops down from the right end of the bar, next to the
  # icons that open it.
  xdg.configFile."rofi/menu.rasi".text = ''
    * {
      bg:      rgba(${t.rgbBg}, ${t.glass});
      edge:    ${t.glassEdge};
      fg:      #${t.fg};
      fg-dim:  #${t.fgDim};
      accent:  #${t.accent};

      background-color: transparent;
      text-color:       @fg;
      font:             "${t.font} ${toString t.fontSize}";
    }

    window {
      location:         northeast;
      anchor:           northeast;
      x-offset:         -10px;
      y-offset:         8px;
      width:            440px;
      background-color: @bg;
      background-image: ${t.glassSheenRasi};
      border:           1px;
      border-color:     @edge;
      border-radius:    20px;
      padding:          14px;
    }

    mainbox  { children: [ inputbar, message, listview ]; spacing: 10px; }

    inputbar {
      children:         [ prompt, entry ];
      background-color: rgba(255, 255, 255, 0.06);
      border-radius:    12px;
      padding:          10px 14px;
      spacing:          12px;
    }
    prompt   { text-color: @accent; font: "${t.font} Bold ${toString t.fontSize}"; }
    entry    { placeholder: "Type to filter"; placeholder-color: @fg-dim; cursor: text; }

    message  { padding: 0px 6px; }
    textbox  { text-color: @fg-dim; }

    listview {
      lines:        9;
      dynamic:      true;
      fixed-height: false;   /* shrink to the rows there are */
      scrollbar:  false;
      spacing:    2px;
    }

    element {
      padding:       10px 12px;
      border-radius: 12px;
    }
    element normal.normal, element alternate.normal { background-color: transparent; }
    element normal.active, element alternate.active { background-color: transparent; text-color: @accent; }
    element selected.normal { background-color: rgba(${t.rgbAccent}, 0.22); }
    element selected.active { background-color: rgba(${t.rgbAccent}, 0.30); text-color: @accent; }
    element-text { text-color: inherit; vertical-align: 0.5; }
  '';

  # nm-applet and blueman-applet autostart from /etc/xdg/autostart, but the
  # bar has no tray for them and the menus above replace them. A Hidden
  # entry in ~/.config/autostart overrides the system one.
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=nm-applet
    Hidden=true
  '';
}
