{ nixpkgs, ... }@ctx:
let
  inherit (nixpkgs) lib;
  text = import ./text.nix ctx;
  imports = import ./imports.nix ctx;
  agents = import ./agents.nix ctx;
in
text // imports // agents
