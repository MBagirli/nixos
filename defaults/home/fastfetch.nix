{ lib, ... }:
let
  g = import ../glyphs.nix { inherit lib; };
  # Nix has no \uXXXX escape; JSON does. For the few BMP glyphs (and the
  # ANSI escape) that glyphs.nix does not name.
  u = s: builtins.fromJSON ''"${s}"'';

  esc = u "\\u001b";
  dim = s: "${esc}[38;5;60m${s}${esc}[0m";

  # Tree branches in front of each key: two groups, software then
  # hardware, each drawn as ╭─ … ├─ … ╰─.
  # Labels are padded here rather than with display.key.width: fastfetch
  # measures keys in bytes, and the branches and icons are multi-byte, so
  # its padding left the values ragged.
  first = "╭─ "; mid = "├─ "; last = "╰─ ";
  pad = s: s + lib.concatStrings (lib.replicate (7 - lib.stringLength s) " ");
  item = branch: icon: label: color: extra:
    { key = "${branch}${icon}  ${pad label}"; keyColor = color; } // extra;
in
{
  programs.fastfetch = {
    enable = true;
    settings = {
      # The small NixOS logo (7 rows) beside one short tree of facts.
      logo = {
        source = "nixos_small";
        padding = { top = 1; right = 3; left = 1; };
      };

      display.separator = " ";

      modules = [
        {
          type = "title";
          format = "{user-name}${dim " @ "}{host-name}";
        }

        (item first g.nixos       "os"     "blue" { type = "os";       format = "{pretty-name}"; })
        (item mid   (u "\\uf17c") "kernel" "blue" { type = "kernel";   format = "{release}"; })
        (item mid   (u "\\uf2d2") "wm"     "blue" { type = "wm";       format = "{pretty-name} {version}"; })
        (item mid   (u "\\uf120") "shell"  "blue" { type = "shell";    format = "{pretty-name} {version}"; })
        (item last  (u "\\uf489") "term"   "blue" { type = "terminal"; format = "{pretty-name} {version}"; })

        (item first g.cpu         "cpu"    "magenta" { type = "cpu";    format = "{name}  ${dim "{cores-logical} threads"}"; })
        (item mid   (u "\\uf108") "gpu"    "magenta" { type = "gpu";    format = "{name}"; })
        (item mid   g.memory      "ram"    "magenta" { type = "memory"; format = "{used} / {total}  ${dim "{percentage}"}"; })
        (item mid   g.disk        "disk"   "magenta" { type = "disk";   folders = "/"; format = "{size-used} / {size-total}  ${dim "{size-percentage}"}"; })
        (item last  (lib.last g.battery) "battery" "magenta" { type = "battery"; format = "{capacity}  ${dim "{status}"}"; })

        (item "   " g.clock "up" "green" { type = "uptime"; })

        "break"
        { type = "colors"; symbol = "circle"; paddingLeft = 3; }
      ];
    };
  };
}
