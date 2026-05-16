_:
{ pkgs, ... }:

{
  # Recommended to always add git, the system version can be outdated.
  # It also resolves a color highlighting issue in the terminal for me.
  packages = with pkgs; [ git ];

  # Always enable nix language support.
  languages.nix.enable = true;

  git-hooks.hooks = {
    nixfmt.enable = true;
    markdownlint = {
      enable = true;
      settings.configuration = {
        MD013.line_length = 120;
      };
    };
    shellcheck.enable = true;
  };
}
