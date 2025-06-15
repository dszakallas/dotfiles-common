{ packages, ... }:
{
  pkgs,
  config,
  lib,
  system,
  ...
}:
with lib;
{
  options = {
    davids.emacs = {
      enable = mkEnableOption "Emacs configuration";
      spacemacs = mkOption {
        default = { };
        type = types.submodule {
          options = {
            enable = mkEnableOption "Enable Spacemacs management";
            config = mkOption {
              default = ./his.spacemacs.d;
              type = types.path;
              description = "Path to Spacemacs configuration";
            };
            source = mkOption {
              type = types.enum [
                "package"
                "local"
              ];
              default = "package";
              description = "Spacemacs source";
            };
            package = mkOption {
              default = packages.${system}.spacemacs;
              type = types.package;
              description = "Spacemacs package";
            };
            local = mkOption {
              type = types.str;
              description = "Path to Spacemacs source";
            };
          };
        };
      };
    };
  };
  config = mkIf config.davids.emacs.enable (
    let
      pkg = config.davids.emacs.spacemacs.package;
      spacemacs-start-directory =
        if config.davids.emacs.spacemacs.source == "package" then
          "${pkg.out}/share/spacemacs"
        else
          config.davids.emacs.spacemacs.local;
      loadSpacemacsInit = f: ''
        (setq spacemacs-start-directory "${spacemacs-start-directory}/")
        (add-to-list 'load-path spacemacs-start-directory)
        (load "${f}" nil t)
      '';
    in
    {
      home.packages = with pkgs; [
        # lsp dependencies
        nodejs_24
        # vterm build dependencies
        cmakeMinimal
        glibtool
      ];
      home.file.".davids/bin/ect" = {
        text = ''
          #!/bin/sh
          exec emacsclient --tty "$@"
        '';
        executable = true;
      };
      home.file.".davids/bin/ecw" = {
        text = ''
          #!/bin/sh
          exec emacsclient --reuse-frame -a "" "$@"
        '';
        executable = true;
      };
      home.file.".davids/bin/ec" = {
        text = ''
          #!/bin/sh
          exec emacsclient "$@"
        '';
        executable = true;
      };
      programs.zsh.shellAliases = {
        e = "ect";
      };
      home.file.".spacemacs.d" = lib.mkIf config.davids.emacs.spacemacs.enable {
        source = ./his.spacemacs.d;
      };
      home.file.".emacs.d/init.el" = lib.mkIf config.davids.emacs.spacemacs.enable {
        text = loadSpacemacsInit "init";
      };
      home.file.".emacs.d/early-init.el" = lib.mkIf config.davids.emacs.spacemacs.enable {
        text = loadSpacemacsInit "early-init";
      };
      home.file.".emacs.d/dump-init.el" = lib.mkIf config.davids.emacs.spacemacs.enable {
        text = loadSpacemacsInit "dump-init";
      };
    }
  );
}
