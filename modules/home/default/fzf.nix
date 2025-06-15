{ ... }:
{ pkgs, ... }:
{
  home.packages = with pkgs; [ fzf ];
  programs.bash.bashrcExtra = ''
    eval "$(fzf --bash)";
  '';
  programs.zsh.oh-my-zsh.plugins = [ "fzf" ];
  programs.vim.plugins = with pkgs.vimPlugins; [ fzf-vim ];
}
