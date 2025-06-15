{ lib, ... }:
with lib;
rec {
  # List immediate subdirectories of a directory
  subDirs =
    d:
    foldlAttrs (
      a: k: v:
      a // (if v == "directory" then { ${k} = d + "/${k}"; } else { })
    ) { } (builtins.readDir d);

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

  # Return the list of importable names in a directory.
  # Importable name is either
  # - a regular file with the nix extension
  # - or a directory containing default.nix.
  importables =
    root:
    let
      children = builtins.readDir root;
    in
    (builtins.attrNames (
      lib.attrsets.filterAttrs (
        n: t:
        (t == "regular" && (builtins.match ".+\\.nix$" n) != null)
        || (t == "directory" && builtins.pathExists (root + "/${n}/default.nix"))
      ) children
    ));

  # Import each importable in the dir and return as an attrset keyed by their names.
  importDir =
    d: arg:
    builtins.foldl' (a: name: a // { ${name} = import "${d}/${name}" arg; }) { } (importables d);

  # Like callPackageWith but for a while directory.
  # The directory should contain nix files, or directories containing default.nix files that define packages.
  # The packages are imported with their file basename as the attribute name.
  callPackageDirWith =
    root: ins:
    let
      callPkg = lib.callPackageWith all;
      outs = builtins.listToAttrs (
        builtins.map (f: {
          name =
            let
              m = (builtins.match "(.+)\\.nix$" f);
            in
            if m != null then builtins.head m else f;
          value = callPkg (root + ("/" + f)) { };
        }) (importables root)
      );
      all = ins // outs;
    in
    outs;
}
