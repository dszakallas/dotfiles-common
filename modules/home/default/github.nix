{ ... }:
{ pkgs, ... }:
{
  home.packages = with pkgs; [ gh ];
  home.file.".davids/share/gh.zsh".source = ./gh.zsh;
  programs.zsh = {
    initContent = ''
      source "$HOME/.davids/share/gh.zsh";
    '';
    oh-my-zsh.plugins = [ "gh" ];
  };
  home.sessionVariables = {
    GH_PAGER = "cat";
  };
}
