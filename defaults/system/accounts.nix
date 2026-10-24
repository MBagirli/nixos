{ config, lib, ... }:
let
  registry = import ../../users;
  # Only *.nix: an editor backup (foo.nix~, .swp) or a README dropped in
  # the directory would otherwise be imported as a module.
  homeDefaults = lib.filter (lib.hasSuffix ".nix") (lib.filesystem.listFilesRecursive ../home);

  personal = name:
    let p = ../../users + "/${name}.nix";
    in lib.optional (builtins.pathExists p) p;

  # Catalog declared in defaults/system/packages.nix. Turning a name from
  # users/default.nix into a real package happens here, so a name that is
  # not in the catalog fails the build with a message that says which user
  # asked for it — rather than being silently ignored.
  catalog = config.my.optionalPackages;

  chosen = name: u: map (p:
    catalog.${p} or (throw ''
      users/default.nix: user "${name}" asks for package "${p}", which is
      not in my.optionalPackages. Add it to defaults/system/packages.nix
      or fix the spelling. Available: ${lib.concatStringsSep ", " (lib.attrNames catalog)}
    '')
  ) (u.packages or [ ]);
in
{
  # Declared here so hosts/rog/default.nix can set my.monitors.
  options.my.monitors = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ",preferred,auto,1" ];
    description = "Hyprland monitor lines for this host.";
  };

  config = {
    users.users =
      # root cannot log in directly; use sudo from a wheel account.
      { root.hashedPassword = "!"; }
      //
      lib.mapAttrs (name: u: {
        isNormalUser = true;
        description = u.description or name;
        # video: laptop backlight (brightnessctl / Luminance)
        # i2c:   external monitor brightness over DDC/CI (ddcutil / Luminance)
        # Not "audio" (PipeWire + logind seat access cover it) and not
        # "input" (raw read access to every keyboard — a keylogger's
        # dream, and nothing here needs it).
        # docker is root-equivalent, so it goes with wheel: otherwise
        # admin = false would not actually mean anything.
        extraGroups = [ "networkmanager" "video" "i2c" ]
          ++ lib.optionals u.admin [ "wheel" "docker" ]
          ++ (u.extraGroups or [ ]);
      }) registry;

    home-manager.users = lib.mapAttrs (name: u: {
      imports = homeDefaults ++ personal name;
      home.stateVersion = "26.05";

      # Per-package opt-in. Everything a user can have is declared once in
      # packages.nix; this line is what actually puts the chosen ones into
      # that user's profile and nobody else's.
      home.packages = chosen name u;
    }) registry // {
      # root gets the same shell as everyone else (prompt, aliases,
      # completion, plugins) and none of the desktop. Without this,
      # `sudo su` dropped into NixOS's bare default zsh prompt.
      root = {
        imports = [ ../home/zsh.nix ];
        home.stateVersion = "26.05";
      };
    };
  };
}
