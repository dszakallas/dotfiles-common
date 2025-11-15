{
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "spacemacs";
  version = "2025-11-14-develop";
  src = fetchFromGitHub {
    owner = "syl20bnr";
    repo = "spacemacs";
    rev = "ccd3e200c2f88c3eb8b465fc00f34adc4d1d28fd";
    hash = "sha256-gQgeLa8O1NG34XqZ9TWUsfdAbPC4FcLeegXK6dFeZfY=";
  };

  patches = [
    ./quelpa-build-writable.diff
  ];

  installPhase = ''
    mkdir -p $out/share/spacemacs
    cp -r * .lock $out/share/spacemacs
  '';
}
