{ config, pkgs, ... }:

let
  swaylock = "${config.programs.swaylock.package}/bin/swaylock";
  swaymsg = "${pkgs.sway}/bin/swaymsg";

  # Random Voronoi mosaic: 30-60 flat cells, each a color from the palette.
  genLockImage = pkgs.writeShellScript "gen-lock-image" ''
    set -eu
    dir="$XDG_RUNTIME_DIR/lockscreen"
    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    RANDOM=$(${pkgs.coreutils}/bin/od -An -N4 -tu4 /dev/urandom | ${pkgs.coreutils}/bin/tr -d ' ')
    pal=("#ff61c6" "#5cecff" "#f4ff61" "#ff9900" "#375971")
    n=$(( 30 + RANDOM % 31 ))
    pts=""
    for ((i = 0; i < n; i++)); do
      pts+="$(( RANDOM % 1920 )),$(( RANDOM % 1200 )) ''${pal[RANDOM % ''${#pal[@]}]} "
    done
    ${pkgs.imagemagick}/bin/magick -size 1920x1200 xc: -sparse-color Voronoi "$pts" "$dir/next.tmp.png"
    ${pkgs.coreutils}/bin/mv "$dir/next.tmp.png" "$dir/next.png"
  '';

  # Shows the pre-generated image (instant, so lid-close locks in time),
  # then makes the next one in the background.
  lockScreen = pkgs.writeShellScript "lock-screen" ''
    ${pkgs.procps}/bin/pgrep -x swaylock >/dev/null && exit 0
    img="$XDG_RUNTIME_DIR/lockscreen/next.png"
    if [ -f "$img" ]; then
      ${swaylock} -f -i "$img"
    else
      ${swaylock} -f
    fi
    ${genLockImage} >/dev/null 2>&1 &
  '';
in
{
  programs.waybar.enable = true;
  programs.foot.enable = true;
  programs.wofi.enable = true;

  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      color = "375971";
      scaling = "fill";
      show-failed-attempts = true;

      clock = true;
      indicator = true;
      timestr = "%-I:%M %p";
      datestr = "%a %b %-d";
      indicator-radius = 110;
      indicator-thickness = 8;
      fade-in = 0.2;

      inside-color = "0a0c37cc";
      ring-color = "ff61c6";
      key-hl-color = "5cecff";
      bs-hl-color = "ff9900";
      text-color = "f4ff61";
      line-color = "00000000";
      separator-color = "00000000";

      inside-clear-color = "0a0c37cc";
      ring-clear-color = "f4ff61";
      text-clear-color = "f4ff61";

      inside-ver-color = "375971cc";
      ring-ver-color = "5cecff";
      text-ver-color = "5cecff";

      inside-wrong-color = "0a0c37cc";
      ring-wrong-color = "ff9900";
      text-wrong-color = "ff9900";
    };
  };

  # Lid close suspends by default, so before-sleep covers it.
  services.swayidle = {
    enable = true;
    events = {
      before-sleep = "${lockScreen}";
      lock = "${lockScreen}";
    };
    timeouts = [
      { timeout = 300; command = "${lockScreen}"; }
      {
        timeout = 600;
        command = "${swaymsg} 'output * power off'";
        resumeCommand = "${swaymsg} 'output * power on'";
      }
    ];
  };

  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;

    config = {
      modifier = "Mod4";
      terminal = "foot";
      menu = "wofi --show drun";
      bars = [{ command = "waybar"; }];
      fonts = {
        names = [ "Inter" ];
        size = 10.0;
      };

      output."eDP-1".scale = "1.25";

      input = {
        "type:touchpad" = {
          natural_scroll = "enabled";
          scroll_factor = "0.4";
        };
        "type:pointer".natural_scroll = "enabled";
      };
      startup = [{ command = "${genLockImage}"; }];
    };

    extraConfig = ''
      bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindsym XF86MonBrightnessUp exec brightnessctl set +5%
      bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
      bindsym Mod4+Escape exec ${lockScreen}
    '';
  };
}
