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
in
{
  inherit textRegion;
}
