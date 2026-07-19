{ self, packages, ... }@ctx:
{
  config,
  lib,
  pkgs,
  system,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    ;
  moduleName = "davids-dotfiles-common/home/gpg";
in
{
  options =
    let
      inherit (types)
        str
        ;
    in
    {
      davids.gpg.enable = mkEnableOption "GPG goodies";
      davids.gpg.defaultKey = mkOption {
        type = str;
        description = "Default GPG key to use";
        default = "";
      };
    };
  config = {
    home = {
      packages = [ pkgs.gnupg ];
      file.".gnupg/gpg-agent.conf" = mkIf config.davids.gpg.enable {
        text = ctx.lib.textRegion {
          name = moduleName;
          content = ''
            default-cache-ttl 600
            max-cache-ttl 7200
            enable-ssh-support
          '';
        };
      };
      file.".gnupg/gpg.conf" = mkIf config.davids.gpg.enable {
        text = ctx.lib.textRegion {
          name = moduleName;
          content = ''
            auto-key-retrieve
            no-emit-version
            personal-digest-preferences SHA512
            cert-digest-algo SHA512
            default-preference-list SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed
          ''
          + (
            if (config.davids.gpg.defaultKey != "") then
              ''
                default-key ${config.davids.gpg.defaultKey};
              ''
            else
              ""
          );
        };
      };
    };
  };
}
