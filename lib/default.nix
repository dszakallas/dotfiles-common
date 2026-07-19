{ nixpkgs, ... }@ctx:
let
  inherit (nixpkgs) lib;
  text = import ./text.nix ctx;
  imports = import ./imports.nix ctx;
  agents = import ./agents ctx;
in
text // imports // agents
