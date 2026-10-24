{ config, lib, pkgs, ... }:
let
  # Read straight out of the option that defines them, so this menu is
  # generated from the same data zsh is. Adding an alias in zsh.nix makes
  # it appear here with no second list to maintain — the same guarantee
  # hypr-keys gives for keybinds, except this needs no parsing at all
  # because the aliases are already a Nix attrset at build time.
  #
  # Do NOT be tempted to shell out to `zsh -ic alias` instead: -i makes
  # the shell interactive, so the fastfetch greeting in zsh.nix would be
  # printed straight into the menu.
  aliases = config.programs.zsh.shellAliases;

  width = lib.foldl'
    (m: n: let l = lib.stringLength n; in if l > m then l else m)
    0 (lib.attrNames aliases);

  padRight = n: s: s + lib.concatStrings (lib.replicate (n - lib.stringLength s) " ");

  rows = lib.concatStringsSep "\n"
    (lib.mapAttrsToList (k: v: "${padRight (width + 3) k}${toString v}") aliases);
in
{
  home.packages = [
    # Super+T — shell alias cheatsheet.
    # Reuses keybinds.rasi (defaults/home/keybinds.nix) so the two
    # cheatsheets look identical; they are the same kind of list.
    (pkgs.writeShellScriptBin "hypr-aliases" ''
      ${pkgs.coreutils}/bin/cat <<'ALIASES' \
        | ${pkgs.rofi}/bin/rofi -dmenu -i \
            -no-custom \
            -p "aliases" \
            -theme "$HOME/.config/rofi/keybinds.rasi" \
        > /dev/null
${rows}
ALIASES
    '')
  ];
}
