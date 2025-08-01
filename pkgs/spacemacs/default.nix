{
  stdenvNoCC,
  fetchFromGitHub,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "spacemacs";
  version = "2025-07-30-develop";
  src = fetchFromGitHub {
    owner = "syl20bnr";
    repo = "spacemacs";
    rev = "214de2f3398dd8b7b402ff90802012837b8827a5";
    hash = "sha256-a3EkS4tY+VXWqm61PmLnF0Zt94VAsoe5NmubaLPNxhE=";
  };

  patches = [
    ./quelpa-build-writable.diff
  ];

  installPhase = ''
    mkdir -p $out/share/spacemacs
    cp -r * .lock $out/share/spacemacs
  '';
}
