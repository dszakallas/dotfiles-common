{
  stdenvNoCC,
  fetchFromGitHub,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "spacemacs";
  version = "2024-06-19-develop";
  src = fetchFromGitHub {
    owner = "syl20bnr";
    repo = "spacemacs";
    rev = "eb104f08c268f255c980886804af15a38ad1e3f8";
    hash = "sha256-tc1IN0EhWlDtu1h4uXLdLw+q8+Ku9g5qhTtIkBXOZcI=";
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
