{ lib, pkgs, ... }:
let
  t = import ../theme.nix;
  g = import ../glyphs.nix { inherit lib; };

  # The greeter has no username field, only the name of whoever logged in
  # last. On a fresh install there is no "last", so fall back to the first
  # admin in the registry instead of a literal "user" nobody can log in as.
  registry = import ../../users;
  admins = lib.attrNames (lib.filterAttrs (_: u: u.admin or false) registry);
  fallbackUser = lib.head (if admins != [ ] then admins else lib.attrNames registry);

  # SDDM runs as its own user before login, so it cannot read anything
  # under /home. The wallpaper has to come from the nix store.
  wallpaper = ../../assets/wallpapers/default.jpg;

  # Login screen: blurred wallpaper, a large thin clock, and a liquid-glass
  # card (avatar, name, password) matching hyprlock. Shakes on a wrong
  # password. Power buttons bottom right.
  #
  # Blur comes from MultiEffect (QtQuick.Effects), which ships inside
  # qtdeclarative itself — unlike Qt5Compat.GraphicalEffects, which is not
  # reliably on the greeter's import path. Preview without logging out:
  #   sddm-greeter-qt6 --test-mode --theme /run/current-system/sw/share/sddm/themes/rog
  mainQml = pkgs.writeText "Main.qml" ''
    import QtQuick 2.15
    import QtQuick.Controls 2.15
    import QtQuick.Effects

    Rectangle {
        id: root
        width: 1920
        height: 1080
        color: "#${t.bg}"

        property color accent:  "#${t.accent}"
        property color accent2: "#${t.accent2}"
        property color fg:      "#${t.fg}"
        property color fgDim:   "#${t.fgDim}"
        property color urgent:  "#${t.urgent}"
        property string uiFont:   "Noto Sans"
        property string iconFont: "${t.fontUi}"

        property string userName: typeof userModel !== "undefined" && userModel.lastUser
                                  ? userModel.lastUser : "${fallbackUser}"

        function doLogin() {
            errorLabel.text = ""
            // Session index 0 is hyprland-uwsm.desktop (it sorts first).
            sddm.login(root.userName, pwInput.text, 0)
        }

        // ---- background ----
        // Mutable path outside the nix store so sddm-wallpaper-set can
        // replace it without a rebuild. Seeded by systemd.tmpfiles below.
        Image {
            id: wall
            anchors.fill: parent
            source: "file:///var/lib/sddm-wallpaper/wallpaper.jpg"
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: false
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wall
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            brightness: -0.10
            saturation: 0.15
        }
        Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.28 }

        // ---- clock ----
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.13
            spacing: 2

            Text {
                id: clock
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.fg
                font.family: root.uiFont
                font.pixelSize: 128
                font.weight: Font.Light
                text: Qt.formatDateTime(new Date(), "HH:mm")
            }
            Text {
                id: dateLabel
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.80)
                font.family: root.uiFont
                font.pixelSize: 22
                text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
            }
            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: {
                    clock.text = Qt.formatDateTime(new Date(), "HH:mm")
                    dateLabel.text = Qt.formatDateTime(new Date(), "dddd, d MMMM")
                }
            }
        }

        // ---- the glass card ----
        Item {
            id: card
            width: 400
            height: 340
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.47
            property real shake: 0
            transform: Translate { x: card.shake }

            Rectangle {
                anchors.fill: parent
                radius: 36
                color: Qt.rgba(0.12, 0.12, 0.18, 0.36)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.16)
            }
            // sheen: light catching the top of the glass
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 35
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
                    GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.02) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 16

                Rectangle {
                    width: 104; height: 104; radius: 52
                    anchors.horizontalCenter: parent.horizontalCenter
                    border.width: 2
                    border.color: Qt.rgba(1, 1, 1, 0.35)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.accent }
                        GradientStop { position: 1.0; color: root.accent2 }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: root.userName.charAt(0).toUpperCase()
                        color: "#${t.bg}"
                        font.family: root.uiFont
                        font.pixelSize: 46
                        font.bold: true
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.userName.charAt(0).toUpperCase() + root.userName.slice(1)
                    color: root.fg
                    font.family: root.uiFont
                    font.pixelSize: 21
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: pwField
                    width: 300; height: 52; radius: 26
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: pwInput.activeFocus ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.85)
                                                      : Qt.rgba(1, 1, 1, 0.20)
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    TextInput {
                        id: pwInput
                        anchors.left: parent.left
                        anchors.right: goBtn.left
                        anchors.leftMargin: 22
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.fg
                        font.family: root.uiFont
                        font.pixelSize: 17
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        focus: true
                        clip: true
                        onAccepted: root.doLogin()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pwInput.text.length === 0
                            text: "Enter password"
                            color: root.fgDim
                            font.family: root.uiFont
                            font.pixelSize: 16
                        }
                    }

                    Rectangle {
                        id: goBtn
                        width: 40; height: 40; radius: 20
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.accent
                        opacity: pwInput.text.length > 0 ? 1.0 : 0.45
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: "${g.chevron}"
                            color: "#${t.bg}"
                            font.family: root.iconFont
                            font.pixelSize: 22
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.doLogin()
                        }
                    }
                }

                Text {
                    id: errorLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 18
                    text: ""
                    color: root.urgent
                    font.family: root.uiFont
                    font.pixelSize: 14
                }
            }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: card; property: "shake"; to: -16; duration: 50 }
                NumberAnimation { target: card; property: "shake"; to: 14;  duration: 70 }
                NumberAnimation { target: card; property: "shake"; to: -10; duration: 60 }
                NumberAnimation { target: card; property: "shake"; to: 6;   duration: 50 }
                NumberAnimation { target: card; property: "shake"; to: 0;   duration: 40 }
            }
        }

        // ---- power, bottom right ----
        component PowerButton: Rectangle {
            id: btn
            property string icon
            property string label
            signal activated()
            width: 52; height: 52; radius: 26
            color: hover.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: btn.icon
                color: root.fg
                font.family: root.iconFont
                font.pixelSize: 22
            }
            Text {
                anchors.top: parent.bottom
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                text: btn.label
                color: root.fgDim
                font.family: root.uiFont
                font.pixelSize: 12
                opacity: hover.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: btn.activated()
            }
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 40
            anchors.bottomMargin: 48
            spacing: 16
            PowerButton { icon: "${g.sleep}"; label: "Sleep";     visible: sddm.canSuspend;  onActivated: sddm.suspend() }
            PowerButton { icon: "${g.refresh}"; label: "Restart"; visible: sddm.canReboot;   onActivated: sddm.reboot() }
            PowerButton { icon: "${g.power}"; label: "Shut down"; visible: sddm.canPowerOff; onActivated: sddm.powerOff() }
        }

        // ---- host, bottom left ----
        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 40
            anchors.bottomMargin: 62
            text: "${g.laptop}   " + sddm.hostName
            color: root.fgDim
            font.family: root.iconFont
            font.pixelSize: 15
        }

        Connections {
            target: sddm
            function onLoginFailed() {
                errorLabel.text = "Wrong password, try again"
                pwInput.text = ""
                pwInput.forceActiveFocus()
                shakeAnim.restart()
            }
        }

        Component.onCompleted: pwInput.forceActiveFocus()
    }
  '';

  metadata = pkgs.writeText "metadata.desktop" ''
    [SddmGreeterTheme]
    Name=rog
    Description=Matches hyprlock
    Author=local
    License=MIT
    Type=sddm-theme
    Version=1.0
    MainScript=Main.qml
    QtVersion=6
  '';

  # Root-only helper. Validates that the argument is a real image before
  # copying, so the sudo rule cannot be used to write arbitrary files.
  setSddmWallpaper = pkgs.writeShellScriptBin "sddm-wallpaper-set" ''
    set -eu
    src="''${1:-}"
    [ -n "$src" ] || { echo "usage: sddm-wallpaper-set <image>" >&2; exit 1; }
    [ -f "$src" ] || { echo "not a file: $src" >&2; exit 1; }
    case "$(${pkgs.file}/bin/file -b --mime-type "$src")" in
      image/*) ;;
      *) echo "not an image: $src" >&2; exit 1 ;;
    esac
    ${pkgs.coreutils}/bin/install -D -m 0644 -o root -g root \
      "$src" /var/lib/sddm-wallpaper/wallpaper.jpg
  '';

  sddmTheme = pkgs.runCommand "sddm-theme-rog" { } ''
    d=$out/share/sddm/themes/rog
    mkdir -p $d
    cp ${mainQml}  $d/Main.qml
    cp ${metadata} $d/metadata.desktop
  '';
in
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;

    # Custom QML theme built above. A QML error in it drops you to a TTY
    # with no desktop: after editing Main.qml, rebuild and run
    # `systemctl restart display-manager` from a TTY, so a failure is one
    # command to undo rather than a reboot.
    theme = "rog";

    extraPackages = with pkgs.kdePackages; [
      qtsvg
      qtdeclarative
      qt5compat
    ];
  };

  environment.systemPackages = [ sddmTheme setSddmWallpaper ];

  # Seed the greeter wallpaper once. "C" copies only if the target does
  # not already exist, so a wallpaper chosen at runtime survives rebuilds.
  systemd.tmpfiles.rules = [
    "d /var/lib/sddm-wallpaper 0755 root root -"
    "C /var/lib/sddm-wallpaper/wallpaper.jpg 0644 root root - ${wallpaper}"
  ];

  # sddm-wallpaper-picker (in defaults/home/wallpaper.nix) calls this via
  # sudo. The rule must name the path the CALLER actually invokes: sudo
  # matches on the command as typed, and PATH resolves this to
  # /run/current-system/sw/bin/... — pointing the rule at the raw store
  # path never matches, and every call falls through to a password
  # prompt.
  #
  # The path is stable but its target changes with each rebuild, so this
  # does not pin one exact binary. What actually constrains the rule is
  # the mime-type check inside the script above.
  security.sudo.extraRules = [{
    groups = [ "wheel" ];
    commands = [{
      command = "/run/current-system/sw/bin/sddm-wallpaper-set";
      options = [ "NOPASSWD" ];
    }];
  }];
}
