{
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "spacemacs";
  version = "2026-01-17-develop";
  src = fetchFromGitHub {
    owner = "syl20bnr";
    repo = "spacemacs";
    rev = "e5b6fbb74618716dbaa24c1ac6b6cd2061058a24";
    hash = "sha256-QG3Xqwr49n0p9B8t5fIOid3JfCb1tDg3XpfHfi1XZLM=";
  };

  patches = [
    ./quelpa-build-writable.diff
  ];

  installPhase = ''
    mkdir -p $out/share/spacemacs
    cp -r * .lock $out/share/spacemacs
  '';
}
