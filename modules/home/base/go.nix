{ ... }:
{ config, ... }:
# This should be normally up to devenv or similar tools, but adding it here,
# because I unset the devenv in-project location as it causes issues with some tools (gopls).
# With GOPATH not set, go falls back to its default of $HOME/go, and I just cannot cannot stand
# it littering my home directory.
# Since Go modules, it is a global cache anyway, so setting it to XDG_CACHE_HOME/go makes is
# somewhat justifiable.
let
  addGoPath = ''
    export GOPATH=''${XDG_CACHE_HOME:-$HOME/.cache}/go
  '';
in
{
  programs.zsh.envExtra = addGoPath;
  programs.bash.profileExtra = addGoPath;
}
