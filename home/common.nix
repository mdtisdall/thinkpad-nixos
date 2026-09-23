{ pkgs, ... }:

{
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    ripgrep
    fd
    htop
    brightnessctl
  ];

  programs.git = {
    enable = true;
    settings.user = {
      name = "Dylan Tisdall";
      email = "mtisdall@pennmedicine.upenn.edu";
    };
  };

  programs.bash.enable = true;
}
