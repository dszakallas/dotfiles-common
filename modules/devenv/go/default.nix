_:
{ pkgs, ... }:

{
  packages = with pkgs; [
    delve
    gci
    godef
    gofumpt
    golangci-lint
    gopkgs
    gopls
  ];
  languages.go.enable = true;
}
