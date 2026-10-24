# THE REGISTRY — the single list of who exists on this machine.
# The attribute name IS the Linux username and must match the filename.
#
#   admin        adds the user to the wheel group (sudo)
#   description  shown in the login screen and `getent passwd`
#   packages     per-package opt-in, by name, from the catalog in
#                defaults/system/packages.nix. Everyone gets the packages
#                in environment.systemPackages; these are the extras that
#                belong to this user alone.
{
  murad = {
    admin = true;
    description = "Murad";
    packages = [
      "vscode"
      "claude-code"
      "keepass"
      "openconnect"
      "cmatrix"
      "wireshark"
      "volatility3"
      "detect-it-easy"
      "kubectl"
      "kubernetes-helm"
      "kubelogin-oidc"
      "kubelogin"
      "azure-cli"
      "zoom-us"
    ];
  };
}
