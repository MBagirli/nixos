{ lib, pkgs, ... }:
let
  t = import ../theme.nix;
in
{
  # Writing a managed .zshrc is also what stops zsh-newuser-install
  # firing on every new shell.
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      share = true;
    };

    shellAliases = {
      # No "#rog": nixos-rebuild picks nixosConfigurations.<hostname>, so
      # the same aliases work on any machine this config is installed on.
      rebuild  = "sudo nixos-rebuild switch --flake /etc/nixos";
      rbtest   = "sudo nixos-rebuild test --flake /etc/nixos";
      rbboot   = "sudo nixos-rebuild boot --flake /etc/nixos";
      nixup    = "sudo nix flake update --flake /etc/nixos";
      # Keeps the newest 5 generations, so there is always a rollback.
      nixclean = "nh clean all --keep 5";
      nixcfg   = "cd /etc/nixos";
      nixadd   = "sudo git -C /etc/nixos add -A";
      nixopt   = "sudo nix-store --optimise";
      root = "sudo -i";

      ls   = "eza --icons --group-directories-first";
      ll   = "eza -l --icons --group-directories-first --git";
      la   = "eza -la --icons --group-directories-first --git";
      lt   = "eza --tree --level=2 --icons";
      cat  = "bat --style=plain --paging=never";
      ff   = "fastfetch";
      # No grep -> rg / du -> dust: they take different flags (rg -E is
      # --encoding), so commands pasted from the web broke. Type rg and
      # dust directly.

      ".." = "cd ..";
      "..." = "cd ../..";
    };

    initContent = ''
      # emacs-style line editing
      bindkey -e
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down

      # colours for completion menus
      zstyle ':completion:*' menu select
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

      setopt AUTO_CD
      setopt INTERACTIVE_COMMENTS
      # NOT extended_glob: it makes '#' a glob operator, which breaks
      # unquoted flake refs like /etc/nixos#rog
      unsetopt EXTENDED_GLOB

      # greeting on every new interactive shell
      if [[ -o interactive ]] && [[ -z "$FASTFETCH_SHOWN" ]]; then
        export FASTFETCH_SHOWN=1
        command -v fastfetch >/dev/null && fastfetch
      fi
    '';
  };

  programs.zsh.historySubstringSearch.enable = true;

  # Prompt. Two lines: context on top, a bare arrow to type against.
  programs.starship = {
    enable = true;
    settings = {
      format = lib.concatStrings [
        "$username"
        "[](#${t.surface})"
        "$directory"
        "[](fg:#${t.surface} bg:none)"
        "$git_branch$git_status"
        "$nix_shell"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      # Only appears as root (and over ssh): a red badge, because root's
      # prompt is otherwise identical (accounts.nix gives root this file).
      username = {
        style_root = "bold fg:#${t.bg} bg:#${t.urgent}";
        style_user = "fg:#${t.fgDim}";
        format = "[ $user ]($style) ";
      };

      directory = {
        style = "fg:#${t.accent} bg:#${t.surface}";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncate_to_repo = false;
      };

      git_branch = {
        symbol = "";
        style = "fg:#${t.accent2}";
        format = "[ $symbol $branch ]($style)";
      };

      git_status = {
        style = "fg:#${t.urgent}";
        format = "[$all_status$ahead_behind ]($style)";
      };

      nix_shell = {
        symbol = "";
        style = "fg:#${t.ok}";
        format = "[ $symbol $name ]($style)";
      };

      cmd_duration = {
        min_time = 2000;
        style = "fg:#${t.warn}";
        format = "[  $duration ]($style)";
      };

      character = {
        success_symbol = "[❯](bold fg:#${t.accent})";
        error_symbol = "[❯](bold fg:#${t.urgent})";
        vimcmd_symbol = "[❮](bold fg:#${t.accent2})";
      };

      add_newline = true;
    };
  };

  # Modern replacements the aliases above depend on. zoxide is
  # installed by programs.zoxide below.
  home.packages = with pkgs; [
    eza
    bat
    dust
  ];

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border=rounded"
      "--color=bg+:#${t.surface},fg+:#${t.fg},hl:#${t.accent},hl+:#${t.accent}"
      "--color=prompt:#${t.accent2},pointer:#${t.accent},marker:#${t.ok}"
    ];
  };
}
