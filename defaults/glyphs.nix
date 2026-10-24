# Nerd Font glyphs by codepoint, so every .nix file stays plain ASCII.
#
# Nix strings have no \u escape; JSON does, and fromJSON joins the
# surrogate pairs that codepoints above U+FFFF need — which is where all
# the nf-md-* (Material Design) icons live. Codepoints were checked
# against the glyph names in JetBrainsMono Nerd Font 3.5.
{ lib }:
let
  hex4 = n: lib.fixedWidthString 4 "0" (lib.toHexString n);

  chr = hex:
    let cp = lib.fromHexString hex; in
    if cp < 65536 then builtins.fromJSON ''"\u${hex4 cp}"''
    else
      let c = cp - 65536; in
      builtins.fromJSON ''"\u${hex4 (55296 + c / 1024)}\u${hex4 (56320 + lib.mod c 1024)}"'';
in
{
  inherit chr;

  nixos      = chr "F313";    # linux-nixos
  keyboard   = chr "F11C";    # fa-keyboard_o
  cpu        = chr "F2DB";    # fa-microchip
  memory     = chr "F035B";   # md-memory
  disk       = chr "F02CA";   # md-harddisk
  clock      = chr "F0150";   # md-clock_outline
  calendar   = chr "F00ED";   # md-calendar

  wifi       = [ (chr "F092F") (chr "F091F") (chr "F0922") (chr "F0925") (chr "F0928") ];  # md-wifi_strength_outline, _1.._4
  wifiOff    = chr "F092E";   # md-wifi_strength_off_outline
  wifiAlert  = chr "F092B";   # md-wifi_strength_alert_outline

  bluetooth        = chr "F00AF";  # md-bluetooth
  bluetoothOn      = chr "F00B1";  # md-bluetooth_connect
  bluetoothOff     = chr "F00B2";  # md-bluetooth_off

  volume     = [ (chr "F057F") (chr "F0580") (chr "F057E") ];  # md-volume_low/medium/high
  volumeOff  = chr "F0581";   # md-volume_off
  headphones = chr "F02CB";   # md-headphones
  headset    = chr "F02CE";   # md-headset
  mic        = chr "F036C";   # md-microphone
  micOff     = chr "F036D";   # md-microphone_off
  brightness = chr "F00DF";   # md-brightness_6

  battery    = [ (chr "F007A") (chr "F007B") (chr "F007C") (chr "F007D") (chr "F007E")
                 (chr "F007F") (chr "F0080") (chr "F0081") (chr "F0082") (chr "F0079") ];  # md-battery_10 .. md-battery
  charging   = chr "F0084";   # md-battery_charging
  plug       = chr "F06A5";   # md-power_plug

  bell       = chr "F009A";   # md-bell
  bellBadge  = chr "F116B";   # md-bell_badge
  bellOff    = chr "F009B";   # md-bell_off
  tune       = chr "F062E";   # md-tune
  night      = chr "F0594";   # md-weather_night
  leaf       = chr "F032A";   # md-leaf
  balance    = chr "F05D1";   # md-scale_balance
  speed      = chr "F04C5";   # md-speedometer

  lock       = chr "F033E";   # md-lock
  power      = chr "F0425";   # md-power
  cog        = chr "F0493";   # md-cog
  screenshot = chr "F0E51";   # md-monitor_screenshot
  monitor    = chr "F0379";   # md-monitor
  chevron    = chr "F0142";   # md-chevron_right
  refresh    = chr "F0450";   # md-refresh
  plus       = chr "F0415";   # md-plus
  close      = chr "F0156";   # md-close
  search     = chr "F0349";   # md-magnify

  play       = chr "F040A";   # md-play
  pause      = chr "F03E4";   # md-pause
  next       = chr "F04AD";   # md-skip_next
  prev       = chr "F04AE";   # md-skip_previous
  music      = chr "F075A";   # md-music

  timer      = chr "F051B";   # md-timer_outline
  sleep      = chr "F04B2";   # md-sleep
  pin        = chr "F034E";   # md-map_marker
  humidity   = chr "F058E";   # md-water_percent
  wind       = chr "F059D";   # md-weather_windy

  # Weather, keyed the way desktop-widgets.nix names conditions.
  weather = {
    clear        = chr "F0599";   # md-weather_sunny
    clearNight   = chr "F0594";   # md-weather_night
    partly       = chr "F0595";   # md-weather_partly_cloudy
    partlyNight  = chr "F0F31";   # md-weather_night_partly_cloudy
    cloudy       = chr "F0590";   # md-weather_cloudy
    fog          = chr "F0591";   # md-weather_fog
    rain         = chr "F0597";   # md-weather_rainy
    pouring      = chr "F0596";   # md-weather_pouring
    snow         = chr "F0598";   # md-weather_snowy
    sleet        = chr "F067F";   # md-weather_snowy_rainy
    storm        = chr "F0593";   # md-weather_lightning
  };

  mouse      = chr "F037D";   # md-mouse
  phone      = chr "F011C";   # md-cellphone
  speaker    = chr "F04C3";   # md-speaker
  gamepad    = chr "F0297";   # md-gamepad_variant
  laptop     = chr "F0322";   # md-laptop
}
