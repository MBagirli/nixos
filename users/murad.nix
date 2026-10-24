{ osConfig, lib, pkgs, ... }:
let
  hyprctl = "${osConfig.programs.hyprland.package}/bin/hyprctl";
  jq = "${pkgs.jq}/bin/jq";

  # Zoom on Linux never quits when its window is closed — it stays running
  # in the tray, and none of its settings change that (CloseToQuit,
  # ExitOnClose, MinimizeToNotificationArea and forceEnableTrayIcon=false
  # were all tried). So this watcher quits it: it follows Hyprland's
  # window events, remembers which windows are Zoom's, and when the last
  # of them closes it waits 3 s (Zoom swaps windows when joining a
  # meeting) and, if no Zoom window came back, asks Zoom to quit.
  # Closing other apps never touches Zoom, and neither does starting it.
  zoomAutoquit = pkgs.writeShellScript "zoom-autoquit" ''
    set -u
    declare -A zoomwin
    while read -r a; do [ -n "$a" ] && zoomwin[$a]=1; done < <(
      ${hyprctl} clients -j | ${jq} -r '.[] | select(.class | ascii_downcase == "zoom") | .address | ltrimstr("0x")')
    sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$sock" | while IFS= read -r ev; do
      case "$ev" in
        openwindow\>\>*)
          IFS=, read -r addr _ws class _title <<<"''${ev#openwindow>>}"
          case "$class" in zoom|Zoom) zoomwin[$addr]=1 ;; esac ;;
        closewindow\>\>*)
          addr=''${ev#closewindow>>}
          [ -n "''${zoomwin[$addr]+x}" ] || continue
          unset "zoomwin[$addr]"
          [ "''${#zoomwin[@]}" -eq 0 ] || continue
          sleep 3
          if ! ${hyprctl} clients -j | ${jq} -e 'any(.[]; .class | ascii_downcase == "zoom")' >/dev/null \
             && ${pkgs.procps}/bin/pgrep -x zoom >/dev/null; then
            echo "last Zoom window closed: quitting Zoom"
            ${pkgs.procps}/bin/pkill -TERM -x zoom
          fi ;;
      esac
    done
  '';
in
{
  # Personal settings only. Packages are NOT listed here any more — they
  # are declared in defaults/system/packages.nix and switched on by name
  # in users/default.nix, so every package in the system has one home.
  programs.git = {
    enable = true;
    settings.user.name = "mbagirli";
    settings.user.email = "mbagirli2505@gmail.com";
  };

  systemd.user.services.zoom-autoquit = {
    Unit = {
      Description = "Quit Zoom when its last window is closed";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${zoomAutoquit}";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Zoom: stay on XWayland (xwayland=true; native Wayland opened its side
  # panels off-screen, see the Zoom rules in defaults/home/hyprland.nix);
  # no transparent "alpha" surfaces (under Hyprland's glass they showed as
  # a full-screen frosted pane while sharing) and no X11 frame window
  # around the shared screen. Zoom rewrites ~/.config/zoomus.conf itself,
  # so it cannot be a managed file; each rebuild re-applies these keys
  # instead. Takes effect the next time Zoom starts.
  home.activation.zoomSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="$HOME/.config/zoomus.conf"
    if [ -f "$f" ]; then
      run sed -i -e 's/^xwayland=.*/xwayland=true/' \
                 -e 's/^enableAlphaBuffer=.*/enableAlphaBuffer=false/' \
                 -e 's/^showframewindow=.*/showframewindow=false/' "$f"
    fi
  '';
}
