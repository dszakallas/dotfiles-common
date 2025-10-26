{ nixpkgs, ... }@ctx:
let
  inherit (nixpkgs) lib;

  # Annotate a region of text for simpler identification of origin
  textRegion =
    {
      name,
      content,
      comment-char ? "#",
    }:
    ''
      ${comment-char} +begin ${name}
      ${content}
      ${comment-char} +end ${name}
    '';

  # Walk a directory of nix files recursively and map each leaf with a function.
  # A leaf is either a nix file or a directory containing default.nix.
  mapRec =
    { node, mapf }:
    if builtins.pathExists (node + "/default.nix") then
      mapf (node + "/default.nix")
    else
      let
        entries = builtins.readDir node;
        files = builtins.filter (f: builtins.match ".+\\.nix$" f != null && f != "default.nix") (
          builtins.attrNames entries
        );
        dirs = builtins.filter (f: entries.${f} == "directory") (builtins.attrNames entries);
        fileAttrs = builtins.listToAttrs (
          builtins.map (f: {
            name =
              let
                m = (builtins.match "(.+)\\.nix$" f);
              in
              if m != null then builtins.head m else f;
            value = mapf "${node}/${f}";
          }) files
        );
        dirAttrs = builtins.listToAttrs (
          builtins.map (f: {
            name = f;
            value = mapRec {
              node = "${node}/${f}";
              inherit mapf;
            };
          }) dirs
        );
        overlappingKeys = builtins.filter (k: builtins.hasAttr k fileAttrs) (builtins.attrNames dirAttrs);
      in
      if overlappingKeys != [ ] then
        throw "importRec: overlapping keys in directory ${node}: ${lib.concatStringsSep ", " overlappingKeys}"
      else
        fileAttrs // dirAttrs;

  # Import a directory of nix files recursively.
  importRec =
    node:
    mapRec {
      inherit node;
      mapf = import;
    };

  # Import a directory of nix files recursively with a given argument.
  importRec1 =
    node: a:
    mapRec {
      inherit node;
      mapf = n: import n a;
    };

  # Like callPackageWith but for a while directory.
  # The directory should contain nix files, or directories containing default.nix files that define packages.
  # The packages are imported with their file basename as the attribute name.
  callPackageWithRec =
    pkgs: node:
    let
      callPkg = lib.callPackageWith all;
      outs = mapRec {
        inherit node;
        mapf = f: callPkg f { };
      };
      all = pkgs // outs;
    in
    outs;

in
{
  inherit
    textRegion
    importRec
    importRec1
    callPackageWithRec
    ;
}
