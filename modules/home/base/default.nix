{ self, packages, ... }@ctx:
{
  pkgs,
  config,
  options,
  lib,
  system,
  hostPlatform,
  ...
}:
with lib;
let
  unmanagedFile =
    f:
    ctx.lib.textRegion {
      name = moduleName;
      content = ''
        # Unmanaged local overrides
        [[ -s "$HOME/.local/share/${f}" ]] && source "$HOME/.local/share/${f}"
      '';
    };
  files = with pkgs; [
    age
    bat
    findutils
    fswatch
    gawk
    gnused
    ripgrep
    rsync
    sops
    tree
  ];
  adm = with pkgs; [
    htop
    ncdu
    nmap
    tmux
    dig
  ];
  nix = with pkgs; [
    devenv
  ];
  dev = with pkgs; [
    delta
    jq
    yq-go
  ];
  moduleName = "davids-dotfiles-common/home/base";
in
{
  imports = [
    (import ./fzf.nix ctx)
    (import ./k8s.nix ctx)
  ]
  ++ (lib.optionals hostPlatform.isDarwin [ (import ./darwin ctx) ]);
  options = with types; {
    davids.ssh.enable = mkEnableOption "SSH goodies";
    davids.ssh.knownHostsLines = mkOption {
      description = "Managed known_host file lines";
      type = lines;
      default = "";
    };
    davids.ssh.matchBlocks = mkOption {
      type = types.attrsOf (
        mergeTypes options.programs.ssh.matchBlocks.type.nestedTypes.elemType (submodule {
          options = {
            applyDefaults = mkOption {
              type = bool;
              description = "Whether to apply default settings";
              default = true;
            };
            isFIDO2 = mkOption {
              type = bool;
              description = "Whether to use FIDO2 authentication";
              default = false;
            };
          };
        })
      );
      description = "SSH config matchBlocks";
      default = { };
    };
    davids.gpg.enable = mkEnableOption "GPG goodies";
    davids.gpg.defaultKey = mkOption {
      type = str;
      description = "Default GPG key to use";
      default = "";
    };
    davids.git = {
      enable = mkEnableOption "Git goodies";
      excludesLines = mkOption {
        type = lines;
        description = "Lines to add to the user-wide git excludes file";
        default = "";
      };
      configLines = mkOption {
        type = lines;
        description = "Lines to add to the user-wide git config file";
        default = "";
      };
    };
  };
  config = {
    davids.git.excludesLines = mkIf config.davids.git.enable (
      ctx.lib.textRegion {
        name = moduleName;
        content = builtins.readFile ./gitignore;
      }
    );
    davids.git.configLines = mkIf config.davids.git.enable (
      ctx.lib.textRegion {
        name = moduleName;
        content = builtins.readFile ./gitconfig;
      }
    );
    home = {
      packages = lists.flatten [
        adm
        files
        dev
        nix
      ];
      file.".gitconfig" = mkIf config.davids.git.enable {
        text = config.davids.git.configLines;
      };
      file.".gitexcludes" = mkIf config.davids.git.enable {
        text = config.davids.git.excludesLines;
      };
      file.".vimrc".text = ctx.lib.textRegion {
        name = moduleName;
        comment-char = ''"'';
        content = builtins.readFile ./vimrc;
      };
      # in some shell scripts, alias doesn't work, so we use a wrapper script
      file.".davids/bin/docker" = {
        text = ''
          #!/bin/sh
          exec podman "$@"
        '';
        executable = true;
      };
      sessionVariables = {
        EDITOR = "vim";
        LANG = "en_US.UTF-8";
      };
      shellAliases = mkMerge [
        {
          la = "ls -la";
          v = "vim";
          docker = "podman";
        }
        (mkIf config.davids.git.enable {
          g = "git";
        })
      ];
      file.".ssh/davids.known_hosts" = mkIf config.davids.ssh.enable {
        text = config.davids.ssh.knownHostsLines;
      };
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
            if config.davids.gpg.defaultKey != "" then
              ''
                default-key ${config.davids.gpg.defaultKey};
              ''
            else
              ""
          );
        };
      };
    };
    programs = {
      vim = {
        enable = true;
        plugins = with pkgs.vimPlugins; [
          vim-airline
          vim-fugitive
          vim-surround
          nerdcommenter
          ctrlp-vim
          syntastic
          srcery-vim
          editorconfig-vim
          tagbar
        ];
        settings = {
          ignorecase = true;
        };
      };

      direnv = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };

      ssh = mkIf config.davids.ssh.enable {
        enable = true;
        # Unmanaged local overrides
        includes = [ "~/.local/share/ssh/config" ];

        # default ~/.ssh/known_hosts is unmanaged. ~/.ssh/davids.known_hosts is managed by this module
        userKnownHostsFile = "~/.ssh/known_hosts ~/.ssh/davids.known_hosts";

        matchBlocks = lib.mapAttrs (
          _:
          { applyDefaults, isFIDO2, ... }@v:
          mkMerge [
            (mkIf applyDefaults {
              identitiesOnly = mkForce true;
              extraOptions = lib.mkMerge [
                { "AddKeysToAgent" = "yes"; }
                (mkIf pkgs.stdenv.isDarwin { "UseKeychain" = "yes"; })
              ];
            })
            # the default macOS ssh does not ship sk-libfido2 so we need to
            # use to use a standalone library
            (mkIf (isFIDO2 && pkgs.stdenv.isDarwin) {
              extraOptions = {
                "SecurityKeyProvider" = "${packages.${system}.openssh-sk-standalone}/lib/sk-libfido2.dylib";
              };
            })
            (builtins.removeAttrs v [
              "applyDefaults"
              "isFIDO2"
            ])
          ]
        ) config.davids.ssh.matchBlocks;
      };

      bash = {
        enable = true;
        bashrcExtra = unmanagedFile "bashrc";
        profileExtra = ''
          export PATH="$HOME/.davids/bin:$PATH"
          # Unmanaged executables
          export PATH="$HOME/.local/bin:$PATH"
        ''
        + unmanagedFile "env";
      };

      zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        history = {
          path = "$HOME/.histfile";
        };

        initContent = unmanagedFile "zshrc";
        envExtra = ''
          export PATH="$HOME/.davids/bin:$PATH"
          # Unmanaged executables
          export PATH="$HOME/.local/bin:$PATH"
        ''
        + unmanagedFile "env";

        oh-my-zsh = {
          enable = true;
          plugins = [
            "direnv"
          ]
          ++ lib.optionals config.davids.git.enable [ "git" ];
          theme = "clean";
        };
      };
    };
  };
}
