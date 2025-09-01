ctx@{ packages, ... }:
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
      daemon = mkOption {
        default = { };
        type = types.submodule {
          options = {
            enable = mkEnableOption "Enable Emacs daemon";
          };
        };
      };
      package = mkOption {
        default = packages.${system}.davids-emacs;
        type = types.package;
        description = "Emacs package";
      };
      spacemacs = mkOption {
        default = { };
        type = types.submodule {
          options = {
            enable = mkEnableOption "Enable Spacemacs management";
            config = mkOption {
              type = types.path;
              description = "Path to Spacemacs configuration";
            };
            source = mkOption {
              type = types.enum [
                "package"
                "local"
              ];
              default = "package";
              description = "Spacemacs source type (package or impure local dir)";
            };
            package = mkOption {
              default = packages.${system}.spacemacs;
              type = types.package;
              description = "Spacemacs package";
            };
            local = mkOption {
              type = types.str;
              description = "Spacemacs local path (used if source is 'local')";
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
      moduleName = "davids-dotfiles-common/home/emacs";
    in
    {
      launchd.agents."eu.szakallas.emacs" = mkIf pkgs.stdenv.hostPlatform.isDarwin {
        enable = config.davids.emacs.daemon.enable;
        config = {
          ProgramArguments = [
            "${config.davids.emacs.package}/Applications/Emacs.app/Contents/MacOS/Emacs"
            "--fg-daemon"
          ];
          KeepAlive = true;
        };
      };

      home.packages =
        with pkgs;
        [
          config.davids.emacs.package
          # lsp dependencies
          nodejs_24
          # vterm build dependencies
          cmakeMinimal
          glibtool
        ]
        ++ (lib.optionals
          (config.davids.emacs.spacemacs.enable && config.davids.emacs.spacemacs.config == "package")
          [
            config.davids.emacs.spacemacs.package
          ]
        );

      davids.git.excludesLines = ctx.lib.textRegion {
        name = moduleName;
        content = builtins.readFile ./gitignore;
      };
      davids.git.configLines = ctx.lib.textRegion {
        name = moduleName;
        content = ''
          [magithub]
            online = false
          [magithub "status"]
            includeStatusHeader = false
            includePullRequestsSection = false
            includeIssuesSection = false
        '';
      };
      home.file.".davids/bin/ect" = {
        text = ''
          #!/bin/sh
          exec ${config.davids.emacs.package}/bin/emacsclient --tty "$@"
        '';
        executable = true;
      };
      home.file.".davids/bin/ecw" = {
        text = ''
          #!/bin/sh
          exec ${config.davids.emacs.package}/bin/emacsclient --reuse-frame -a "" "$@"
        '';
        executable = true;
      };
      home.file.".davids/bin/ec" = {
        text = ''
          #!/bin/sh
          exec ${config.davids.emacs.package}/bin/emacsclient "$@"
        '';
        executable = true;
      };
      home.file.".spacemacs.d" = lib.mkIf config.davids.emacs.spacemacs.enable {
        source = config.davids.emacs.spacemacs.config;
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
      programs.zsh = {
        shellAliases = {
          e = "ect";
        };
        initContent = ctx.lib.textRegion {
          name = moduleName;
          content = ''
            if [ -n "$INSIDE_EMACS" ]; then
              export EDITOR=ec
            fi
          '';
        };
      };
      programs.bash = {
        bashrcExtra = ctx.lib.textRegion {
          name = moduleName;
          content = ''
            if [ -n "$INSIDE_EMACS" ]; then
              export EDITOR=ec
            fi
          '';
        };
      };
    }
  );
}
