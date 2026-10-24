{ pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;

    # Reclaims space from stopped containers and dangling images weekly.
    # Matters on a 512G disk that also holds a nix store.
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" "--filter" "until=168h" ];
    };

    # Start the daemon on first socket use rather than at boot.
    # Saves ~200MB idle and a couple of seconds of boot time.
    enableOnBoot = false;

    # gVisor (runsc) as an OPT-IN runtime, not the default. It is a
    # userspace kernel: container syscalls are serviced by a Go process
    # instead of hitting the host kernel directly, so an escape has to
    # break gVisor first. The cost is real — syscall-heavy workloads are
    # slower, some /proc entries and exotic syscalls are unimplemented,
    # and GPU passthrough does not work.
    #
    # --host-uds=create: without this, a unix socket bound by the
    # container on a bind-mounted volume exists only inside gVisor's
    # virtual filesystem and never appears on the host side of the
    # mount. Anything on the host that connects to a container-served
    # socket (e.g. an orchestrator) breaks silently — the container
    # starts fine, the connect just fails. "create" is the minimal
    # setting for "container serves, host connects"; "open" would be
    # for the reverse direction, "all" for both.
    #
    # Use it per container:
    #   docker run --runtime=runsc <image>
    # or in compose:
    #   services: { foo: { runtime: runsc } }
    daemon.settings = {
      runtimes.runsc = {
        path = "${pkgs.gvisor}/bin/runsc";
        runtimeArgs = [ "--host-uds=create" ];
      };
    };
  };

  # The socket is root:docker 0660 — set by the nixpkgs docker module
  # itself (systemd.sockets.docker.socketConfig), so membership of the
  # docker group is all a user needs. That group is root-equivalent, so
  # accounts.nix only gives it to admins.

  environment.systemPackages = with pkgs; [
    docker-compose
    lazydocker        # TUI, worth having
    gvisor            # provides runsc
  ];
}
