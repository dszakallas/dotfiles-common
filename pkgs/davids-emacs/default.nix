{
  emacs,
  lib,
  stdenv,
  ...
}:
# These patches mainly fix GUI issues on macOS, I sourced them from
# https://github.com/d12frosted/homebrew-emacs-plus
let
  darwinPatches = [
    ./osx-fix-window-role.patch
    ./osx-round-undecorated-frame.patch
    ./osx-system-appearance.patch
  ];
in
(emacs.override {
  withMailutils = false;
  # Has been reported not-working in macOS 15.4:
  # https://github.com/NixOS/nixpkgs/issues/395169
  # however, I have not seen any issues on macOS 15.5
  withNativeCompilation = true;
}).overrideAttrs
  (prev: {
    patches = (prev.patches or [ ]) ++ lib.optionals stdenv.hostPlatform.isDarwin darwinPatches;
  })
