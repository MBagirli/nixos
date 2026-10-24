{ pkgs, ... }:
{
  # A virtual (headless) output plus a VNC server pointed at it, so a
  # tablet or a second laptop can be used as an extra screen.
  #
  #   virtual-monitor create                 make a headless output
  #   virtual-monitor list                   show every output Hyprland has
  #   virtual-monitor remove <name>          delete a headless output
  #   virtual-monitor <name> listen <port>   serve <name> over VNC
  #   virtual-monitor stop                   stop the VNC server
  #
  # `hyprctl` is taken from PATH on purpose: it has to be the one matching
  # the running compositor, which comes from programs.hyprland at system
  # level, not from this profile.
  home.packages = [
    (pkgs.writeShellScriptBin "virtual-monitor" ''
      set -eu

      JQ=${pkgs.jq}/bin/jq
      WAYVNC=${pkgs.wayvnc}/bin/wayvnc

      names() { hyprctl monitors -j | "$JQ" -r '.[].name'; }

      usage() {
        ${pkgs.coreutils}/bin/cat >&2 <<'USAGE'
usage:
  virtual-monitor create                 create a headless output, print its name
  virtual-monitor list                   list every monitor Hyprland has
  virtual-monitor remove <name>          remove a headless output
  virtual-monitor <name> listen <port>   serve <name> over VNC on 0.0.0.0:<port>
  virtual-monitor stop                   stop the VNC server
USAGE
        exit 1
      }

      case "''${1:-}" in
        ""|-h|--help|help) usage ;;

        list)
          hyprctl monitors -j \
            | "$JQ" -r '.[] | "\(.name)\t\(.width)x\(.height)@\(.refreshRate|floor)"'
          ;;

        create)
          before=$(names)
          hyprctl output create headless >/dev/null

          # Hyprland picks the name itself and increments it, so HEADLESS-1
          # is NOT safe to assume — read back which output actually appeared.
          # It shows up a moment after the dispatch returns, hence the wait.
          new=""
          i=0
          while [ "$i" -lt 25 ]; do
            new=$(${pkgs.coreutils}/bin/comm -13 \
                    <(printf '%s\n' "$before" | ${pkgs.coreutils}/bin/sort) \
                    <(names | ${pkgs.coreutils}/bin/sort) || true)
            [ -n "$new" ] && break
            ${pkgs.coreutils}/bin/sleep 0.1
            i=$((i + 1))
          done

          if [ -z "$new" ]; then
            echo "created, but no new output appeared — check: hyprctl monitors" >&2
            exit 1
          fi
          echo "$new"
          ;;

        remove)
          shift
          [ "$#" -eq 1 ] || usage
          hyprctl output remove "$1" >/dev/null
          echo "removed $1"
          ;;

        stop)
          systemctl --user stop wayvnc.service 2>/dev/null || true
          echo "vnc stopped"
          ;;

        *)
          name="$1"
          verb="''${2:-}"
          port="''${3:-5900}"
          [ "$verb" = "listen" ] || usage

          names | ${pkgs.gnugrep}/bin/grep -qx "$name" || {
            echo "no such monitor: $name" >&2
            echo "have: $(names | ${pkgs.coreutils}/bin/tr '\n' ' ')" >&2
            exit 1
          }

          # systemd-run rather than a bare `&`: the server then survives
          # the terminal closing, logs to the journal, and stops cleanly
          # with `virtual-monitor stop`. Same reasoning as the swaybg unit
          # in defaults/home/wallpaper.nix.
          systemctl --user stop wayvnc.service 2>/dev/null || true
          systemd-run --user --unit=wayvnc --collect \
            --description="wayvnc on $name" \
            "$WAYVNC" -o "$name" 0.0.0.0 "$port" >/dev/null

          echo "wayvnc serving $name on 0.0.0.0:$port"
          echo
          echo "port $port is NOT open in the firewall (see defaults/system/core.nix)."
          echo "wayvnc has no encryption or auth of its own, so reach it over ssh:"
          echo "    ssh -L $port:localhost:$port $(hostname)"
          echo "then point the viewer at localhost:$port"
          echo
          echo "logs: journalctl --user -u wayvnc -f"
          ;;
      esac
    '')
  ];
}
