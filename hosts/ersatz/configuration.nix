{ config, lib, pkgs, ... }:

{
  networking.hostName = "ersatz";
  networking.networkmanager.enable = true;

  # Guessed from your work email's domain (Penn Medicine) — change if wrong.
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

  hardware.enableRedistributableFirmware = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

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
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDqn1Br5WovcAbS3QjLXvVZGgYAKVan7Gwd5REa5hkQPA8nmac1Z+lrTu6ozkheDkZc2uTu/udzPuf0ZWEomJP8D4ReQDBcHzOq727V9HZQHswmcuuIzeTPg7LDy8wHToWrJI/BWCppkHABqykXjP/GNxlqjz8mZe+FzKzUSKzEI95SHexaPhUhHyBUhceqnkb+E5OqraG/k4AaghjTWp1jKSDFi7dA5+KHYYgTYjSTp9eShDOP95yl8cRbNJgJdD/N6wN1ADKWW2COEeK83LkVz5o9pi2GIXh/jFvmu/SLighm2/uhXFPo3F81IvDPQNHvxOt8M6p460n59CdmHDbnEH24+vr8UIQLqMyyUateBWDx1NVIn2yqKc6AmvszyOWcGHlb2B0Lsg3DxBn7TXP2uaykHejddAQAaQ0pR1hhR7gQrehYNLgOD6VUjL2EFafn46Vwq+iKAC8zj3JeWt0xfbQOVi3op6w5yKUh3KFbVl8LX3l5jNlqquY//YAKeMc="
    ];
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
