{ lib, ... }:
{
  # Auto-imports every .nix file under defaults/system/.
  # defaults/home/ is NOT imported here — accounts.nix imports it per user.
  # Only *.nix, so a stray foo.nix.bak or editor backup is not loaded.
  # Flakes only see files git tracks — `git add` a new module, or it is
  # silently skipped.
  imports = lib.filter (lib.hasSuffix ".nix") (lib.filesystem.listFilesRecursive ./system);
}
