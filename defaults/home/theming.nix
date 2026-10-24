{ pkgs, ... }:
let
  t = import ../theme.nix;
in
{
  # ---- cursor ----
  # home.pointerCursor (rather than just gtk.cursorTheme) also writes the
  # X11 and Hyprland cursor config and exports XCURSOR_THEME /
  # XCURSOR_SIZE, which is what stops the
  # "Unable to load hand2 from the cursor theme" spam.
  home.pointerCursor = {
    enable = true;          # required explicitly since HM 25.11
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
  };

  # ---- GTK (dark) ----
  gtk = {
    enable = true;

    theme = {
      package = pkgs.colloid-gtk-theme.override {
        themeVariants = [ "purple" ];
        colorVariants = [ "dark" ];
        tweaks = [ "rimless" ];
      };
      name = "Colloid-Purple-Dark";
    };

    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };

    font = {
      name = "Noto Sans";
      size = 11;
    };

    # gtk-decoration-layout drops the maximise button from CSD titlebars,
    # which are wasted pixels under a tiling compositor.
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-decoration-layout = "appmenu:close";
      gtk-enable-animations = 1;
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle = "hintslight";
      gtk-xft-rgba = "rgb";
    };

    # Liquid glass for GTK3 apps (network settings, VMware dialogs, ...):
    # the same idea as the gtk4 CSS below — translucent backgrounds,
    # opaque text — derived from the Colloid theme's own colours.
    #
    # Only decorated app windows (.csd): layer-shell surfaces such as eww
    # and waybar have no decorations, and this file outranks their own
    # stylesheets — a bare window.background rule painted them grey.
    gtk3.extraCss = ''
      window.background.csd, window.background.solid-csd {
        background-color: alpha(@theme_bg_color, 0.78);
      }
      headerbar, .titlebar:not(headerbar) {
        background-color: alpha(@theme_bg_color, 0.50);
        background-image: none;
      }
      .view, textview text, iconview { background-color: alpha(@theme_base_color, 0.55); }
    '';

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-decoration-layout = "appmenu:close";
    };

    # Frosted glass for libadwaita apps (Nautilus, pwvucontrol,
    # Overskride, ...). libadwaita paints every surface from these
    # variables, so making them translucent lets Hyprland's blur show
    # through while text stays fully opaque — unlike a window opacity
    # rule, which fades the text too. Accent follows theme.nix.
    gtk4.extraCss = ''
      :root {
        --window-bg-color: rgba(${t.rgbBg}, 0.74);
        --view-bg-color: rgba(${t.rgbBg}, 0.40);
        --headerbar-bg-color: rgba(24, 24, 37, 0.50);
        --headerbar-backdrop-color: rgba(24, 24, 37, 0.50);
        --sidebar-bg-color: rgba(24, 24, 37, 0.55);
        --sidebar-backdrop-color: rgba(24, 24, 37, 0.55);
        --secondary-sidebar-bg-color: rgba(24, 24, 37, 0.45);
        --popover-bg-color: rgba(${t.rgbBg}, 0.94);
        --dialog-bg-color: rgba(${t.rgbBg}, 0.94);
        --card-bg-color: rgba(255, 255, 255, 0.05);
        --accent-bg-color: #${t.accent};
        --accent-fg-color: #${t.bg};
        --accent-color: #${t.accent};
      }
    '';
  };

  # ---- Qt (dark, follows GTK) ----
  # platformTheme "gtk3" rather than the deprecated "gtk". This sets
  # QT_QPA_PLATFORMTHEME itself, so do not also set it in
  # home.sessionVariables — two definitions is a build error.
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
    style.package = pkgs.adwaita-qt;
  };

  # ---- portal / desktop colour-scheme preference ----
  # color-scheme is what Firefox, Electron apps and anything using the
  # freedesktop appearance portal read. Without it you get dark window
  # frames but light web content.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Colloid-Purple-Dark";
      icon-theme = "Papirus-Dark";
      cursor-theme = "Bibata-Modern-Classic";
      cursor-size = 24;
      font-name = "Noto Sans 11";
      monospace-font-name = "${t.font} ${toString t.fontSize}";
    };
  };

  # NOTE: GTK_THEME is deliberately NOT set here. It is a hard override
  # that bypasses the settings daemon, breaks per-app theme choices and
  # makes some GTK4 apps render with no theme at all. gtk.theme.name plus
  # the dconf key above is the supported route and does the same job.
  #
  # QT_QPA_PLATFORMTHEME is likewise omitted — qt.platformTheme.name
  # already sets it.
}
