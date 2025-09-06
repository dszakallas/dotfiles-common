# Standalone build of the OpenSSH security key support library
# Needed on macOS where the system OpenSSH does not include it
# https://github.com/Yubico/libfido2/issues/464
# https://github.com/openssh/openssh-portable/commit/ca0697a90e5720ba4d76cb0ae9d5572b5260a16c
{
  libfido2,
  zlib,
  autoconf,
  automake,
  stdenv,
  fetchFromGitHub,
  lib,
  pkg-config,
}:
stdenv.mkDerivation rec {

  pname = "openssh-sk-standalone";
  version = "10.0p2";

  src = fetchFromGitHub {
    owner = "openssh";
    repo = "openssh-portable";
    rev = "V_${builtins.replaceStrings [ "." "p" ] [ "_" "_P" ] version}";
    sha256 = "sha256-+hYVcNByprz104Ly/h4mQXwO3GWQHIC7YIVCgWhh9As=";
  };

  preConfigure = ''
    # Setting LD causes `configure' and `make' to disagree about which linker
    # to use: `configure' wants `gcc', but `make' wants `ld'.
    unset LD
  '';

  nativeBuildInputs = [
    autoconf
    automake
    pkg-config
  ];

  buildInputs = [
    libfido2
    zlib
  ];

  configurePhase = ''
    ./configure --prefix=$out --with-security-key-standalone
  '';

  installPhase = ''
    lib=$(grep -Po '(?<=SK_STANDALONE=).*' Makefile)
    mkdir -p $out/lib
    cp $lib $out/lib/
  '';
}
