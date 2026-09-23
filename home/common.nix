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
    # Fill these in — left blank rather than guessed:
    userName = "Dylan Tisdall";
    userEmail = "mtisdall@pennmedicine.upenn.edu";
  };

  programs.bash.enable = true;
}
