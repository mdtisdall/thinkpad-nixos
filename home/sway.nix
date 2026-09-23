{ config, pkgs, ... }:

let
  lock = "${config.programs.swaylock.package}/bin/swaylock -f";
  swaymsg = "${pkgs.sway}/bin/swaymsg";
in
{
  programs.waybar.enable = true;
  programs.foot.enable = true;
  programs.wofi.enable = true;

  programs.swaylock = {
    enable = true;
    settings = {
      color = "000000";
      show-failed-attempts = true;
    };
  };

  # Lid close suspends by default, so before-sleep covers it.
  services.swayidle = {
    enable = true;
    events = {
      before-sleep = lock;
      lock = lock;
    };
    timeouts = [
      { timeout = 300; command = lock; }
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
    };

    extraConfig = ''
      bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindsym XF86MonBrightnessUp exec brightnessctl set +5%
      bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
      bindsym Mod4+Escape exec ${lock}
    '';
  };
}
