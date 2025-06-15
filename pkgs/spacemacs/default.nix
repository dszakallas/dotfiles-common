{
  stdenvNoCC,
  fetchFromGitHub,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "spacemacs";
  version = "2024-03-08-develop";
  src = fetchFromGitHub {
    owner = "syl20bnr";
    repo = "spacemacs";
    rev = "60882558329524ffc2d51e75d8a1c10f8bdac152";
    hash = "sha256-aSGqV5VAVrO7ZOAhd8c8FGHH8LudC0Q9f5CDyNS2s+g=";
  };

  patches = [
    ./elpa-in-userdir.diff
    ./quelpa-build-writable.diff
  ];

  installPhase = ''
    mkdir -p $out/share/spacemacs
    cp -r * .lock $out/share/spacemacs
  '';
}
