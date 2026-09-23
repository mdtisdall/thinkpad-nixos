{
  config,
  lib,
  pkgs,
  ...
}:

{
  networking.hostName = "ersatz";
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Lanzaboote replaces the systemd-boot module and signs boot files with the
  # keys in pkiBundle (create them with `sbctl create-keys` before enabling).
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
  environment.systemPackages = [ pkgs.sbctl ];

  # Try the TPM first; falls back to the passphrase prompt if the TPM refuses
  # (e.g. Secure Boot off or keys changed). Enroll with systemd-cryptenroll.
  boot.initrd.luks.devices.crypted.crypttabExtraOpts = [ "tpm2-device=auto" ];

  # zram (higher priority) takes everyday swapping; the swapfile on the
  # encrypted root holds the hibernation image. No resume= / resume_offset=:
  # systemd saves the image location in the HibernateLocation EFI variable
  # and the systemd initrd resumes from it.
  zramSwap.enable = true;
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  # Lid close suspends, then hibernates after 2 hours so a forgotten laptop
  # doesn't drain its battery.
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
  systemd.sleep.settings.Sleep.HibernateDelaySec = "2h";

  hardware.enableRedistributableFirmware = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # VA-API driver for Iris Xe, so browsers decode video on the GPU.
    extraPackages = [ pkgs.intel-media-driver ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # Closest free stand-ins for San Francisco and SF Mono.
  fonts.packages = with pkgs; [
    inter
    jetbrains-mono
    font-awesome
  ];
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Inter" ];
    monospace = [ "JetBrains Mono" ];
  };
  # Stem darkening makes glyphs slightly heavier, closer to macOS rendering.
  environment.sessionVariables.FREETYPE_PROPERTIES = "cff:no-stem-darkening=0 autofitter:no-stem-darkening=0";

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "1password"
      "claude-code"
    ];

  # Also installs the setgid 1Password-BrowserSupport helper the Firefox
  # extension uses to talk to the desktop app.
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "dylan" ];
  };

  # Synaptics 06cb:00f9, supported by libfprint's synaptics driver.
  services.fprintd.enable = true;
  # Fingerprint only for polkit prompts (1Password unlock, admin dialogs).
  # Login stays password-only (the disk auto-unlocks via TPM, so the login
  # password is the real boot-time gate); swaylock can't take a fingerprint
  # without blocking password entry; sudo is left as opt-in, like on macOS.
  security.pam.services =
    lib.genAttrs
      [
        "login"
        "greetd"
        "swaylock"
        "sudo"
        "su"
        "sshd"
        "passwd"
        "chsh"
        "chfn"
      ]
      (_: {
        fprintAuth = false;
      })
    // {
      # Unlock the keyring with the login password; keep it in sync on passwd.
      greetd = {
        fprintAuth = false;
        enableGnomeKeyring = true;
      };
      passwd = {
        fprintAuth = false;
        enableGnomeKeyring = true;
      };
    };

  # Secret Service provider. 1Password stores its "trust this device" 2FA
  # token here; without one it asks for the 2FA code on every unlock.
  services.gnome.gnome-keyring.enable = true;

  # Run Electron apps (1Password) natively on Wayland so they stay sharp at
  # fractional scale instead of going through blurry XWayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  security.rtkit.enable = true;
  security.polkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.tlp.enable = true;
  services.thermald.enable = true;
  services.fwupd.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
        user = "greeter";
      };
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };
  xdg.portal.wlr.enable = true;

  # Set with `passwd` after first login.
  users.users.dylan = {
    isNormalUser = true;
    initialPassword = "changeme";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDqn1Br5WovcAbS3QjLXvVZGgYAKVan7Gwd5REa5hkQPA8nmac1Z+lrTu6ozkheDkZc2uTu/udzPuf0ZWEomJP8D4ReQDBcHzOq727V9HZQHswmcuuIzeTPg7LDy8wHToWrJI/BWCppkHABqykXjP/GNxlqjz8mZe+FzKzUSKzEI95SHexaPhUhHyBUhceqnkb+E5OqraG/k4AaghjTWp1jKSDFi7dA5+KHYYgTYjSTp9eShDOP95yl8cRbNJgJdD/N6wN1ADKWW2COEeK83LkVz5o9pi2GIXh/jFvmu/SLighm2/uhXFPo3F81IvDPQNHvxOt8M6p460n59CdmHDbnEH24+vr8UIQLqMyyUateBWDx1NVIn2yqKc6AmvszyOWcGHlb2B0Lsg3DxBn7TXP2uaykHejddAQAaQ0pR1hhR7gQrehYNLgOD6VUjL2EFafn46Vwq+iKAC8zj3JeWt0xfbQOVi3op6w5yKUh3KFbVl8LX3l5jNlqquY//YAKeMc="
    ];
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "26.05";
}
