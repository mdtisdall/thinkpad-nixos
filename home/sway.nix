{ config, osConfig, pkgs, ... }:

let
  swaylock = "${config.programs.swaylock.package}/bin/swaylock";
  swaymsg = "${pkgs.sway}/bin/swaymsg";

  # Font Awesome 7 Solid glyph via Pango markup, e.g. faIcon "f1eb" (wifi).
  faIcon = cp: "<span font_family='Font Awesome 7 Free' font_weight='900'>&#x${cp};</span>";

  # Random Voronoi mosaic: 320-480 flat cells, each a color from the palette.
  genLockImage = pkgs.writeShellScript "gen-lock-image" ''
    set -eu
    dir="$XDG_RUNTIME_DIR/lockscreen"
    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    RANDOM=$(${pkgs.coreutils}/bin/od -An -N4 -tu4 /dev/urandom | ${pkgs.coreutils}/bin/tr -d ' ')
    pal=("#ff61c6" "#5cecff" "#f4ff61" "#ff9900" "#375971"
         "#b967ff" "#05ffa1" "#ff2a6d" "#3d1e6d" "#7b8cff")
    n=$(( 320 + RANDOM % 161 ))
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
    # 1Password can't see the screen lock on Wayland, so lock it here.
    # Only if running: --lock would otherwise launch it. Backgrounded so the
    # lock screen isn't delayed before a lid-close suspend.
    if ${pkgs.procps}/bin/pgrep -x 1password >/dev/null; then
      ${osConfig.programs._1password-gui.package}/bin/1password --lock >/dev/null 2>&1 &
    fi
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
  # Polkit agent (e.g. 1Password's system-auth unlock). Unlike Soteria, it
  # starts PAM as soon as the dialog opens, so the fingerprint is offered
  # immediately instead of only after a password is submitted.
  services.polkit-gnome.enable = true;

  # Mac-like menu bar: workspaces left, window title center, status right.
  programs.waybar = {
    enable = true;

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 28;
      spacing = 4;

      modules-left = [ "sway/workspaces" "sway/mode" ];
      modules-center = [ "sway/window" ];
      modules-right = [ "tray" "network" "pulseaudio" "battery" "clock" ];

      "sway/workspaces".disable-scroll = true;
      "sway/window".max-length = 60;
      tray = { icon-size = 16; spacing = 10; };

      network = {
        format-wifi = faIcon "f1eb";
        format-ethernet = faIcon "f796";
        format-disconnected = faIcon "f1eb";
        tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ipaddr}";
        tooltip-format-ethernet = "{ifname}\n{ipaddr}";
        tooltip-format-disconnected = "Disconnected";
        on-click = "foot nmtui";
      };

      pulseaudio = {
        format = "{icon}";
        format-muted = faIcon "f6a9";
        format-icons.default = map faIcon [ "f026" "f027" "f028" ];
        tooltip-format = "Volume {volume}%";
        on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };

      battery = {
        states = { warning = 20; critical = 10; };
        format = "{capacity}%  {icon}";
        format-charging = "{capacity}%  ${faIcon "f0e7"}";
        format-plugged = "{capacity}%  ${faIcon "f1e6"}";
        format-icons = map faIcon [ "f244" "f243" "f242" "f241" "f240" ];
        tooltip-format = "{timeTo}";
      };

      clock = {
        format = "{:%a %b %d  %I:%M %p}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
      };
    };

    # Translucent deep purple with vaporwave accents (same palette as the lock screen).
    style = ''
      * {
        font-family: "Inter", sans-serif;
        font-size: 13px;
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      window#waybar {
        background: rgba(61, 30, 109, 0.55);
        color: #e8e6f5;
      }

      tooltip {
        background: rgba(61, 30, 109, 0.92);
        border: 1px solid #b967ff;
        border-radius: 6px;
      }

      #workspaces button {
        padding: 0 8px;
        background: transparent;
        color: rgba(232, 230, 245, 0.55);
      }
      #workspaces button.focused {
        color: #ff61c6;
        box-shadow: inset 0 -2px #ff61c6;
      }
      #workspaces button.urgent { color: #ff2a6d; }

      #mode { padding: 0 8px; color: #f4ff61; }
      #window { color: rgba(232, 230, 245, 0.8); }

      #tray, #network, #pulseaudio, #battery, #clock { padding: 0 8px; }

      #network { color: #7b8cff; }
      #pulseaudio { color: #b967ff; }
      #battery { color: #05ffa1; }
      #clock { color: #5cecff; }
      #battery.charging, #battery.plugged { color: #f4ff61; }
      #battery.warning:not(.charging) { color: #ff9900; }
      #battery.critical:not(.charging) { color: #ff2a6d; }
      #network.disconnected, #pulseaudio.muted { color: rgba(232, 230, 245, 0.35); }
    '';
  };
  programs.foot.enable = true;

  # Spotlight-style launcher: a centered search box over a short result list,
  # in the same translucent deep purple and vaporwave accents as the bar.
  programs.wofi = {
    enable = true;
    settings = {
      show = "drun";
      location = "center";
      width = 640;
      lines = 8;
      prompt = "Search";
      insensitive = true;
      allow_images = true;
      image_size = 24;
      no_actions = true;
      hide_scroll = true;
    };
    style = ''
      * {
        font-family: "Inter", sans-serif;
        font-size: 15px;
      }

      window {
        background: rgba(61, 30, 109, 0.88);
        border: 1px solid #b967ff;
        border-radius: 12px;
      }

      #outer-box { padding: 10px; }

      #input {
        margin-bottom: 8px;
        padding: 8px 12px;
        font-size: 20px;
        color: #e8e6f5;
        caret-color: #5cecff;
        background: rgba(232, 230, 245, 0.08);
        border: none;
        border-radius: 8px;
        box-shadow: none;
      }
      #input:focus { box-shadow: inset 0 -2px #5cecff; }

      #entry {
        padding: 6px 10px;
        border-radius: 8px;
      }
      #entry:selected {
        background: rgba(255, 97, 198, 0.28);
        outline: none;
      }
      #img { margin-right: 10px; }
      #text { color: #e8e6f5; }
      #text:selected { color: #ffffff; }
    '';
  };

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

      inside-color = "3d1e6dcc";
      ring-color = "ff61c6";
      key-hl-color = "5cecff";
      bs-hl-color = "ff9900";
      text-color = "f4ff61";
      line-color = "00000000";
      separator-color = "00000000";

      inside-clear-color = "3d1e6dcc";
      ring-clear-color = "f4ff61";
      text-clear-color = "f4ff61";

      inside-ver-color = "375971cc";
      ring-ver-color = "5cecff";
      text-ver-color = "5cecff";

      inside-wrong-color = "3d1e6dcc";
      ring-wrong-color = "ff9900";
      text-wrong-color = "ff9900";
    };
  };

  # before-sleep also fires for hibernate and suspend-then-hibernate.
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
      menu = "wofi";
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
          click_method = "clickfinger";
        };
        "type:pointer".natural_scroll = "enabled";
      };
      startup = [
        { command = "${genLockImage}"; }
        # Runs in the tray so the Firefox extension can reach it.
        { command = "1password --silent"; }
      ];
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
