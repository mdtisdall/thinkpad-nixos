{ pkgs, ... }:

{
  # Self-contained on purpose: no Linux/Sway-specific bits, so this file
  # should drop into the Mac's nix-darwin + Home Manager flake unchanged.
  programs.vim = {
    enable = true;

    settings = {
      number = true;
      relativenumber = true;
      ignorecase = true;
      smartcase = true;
      expandtab = true;
      tabstop = 2;
      shiftwidth = 2;
    };

    extraConfig = ''
      set incsearch
      set hlsearch
      set wrap
      set mouse=a
      syntax on
      filetype plugin indent on
    '';

    plugins = with pkgs.vimPlugins; [
      vim-sensible
      vim-surround
      vim-commentary
    ];
  };
}
