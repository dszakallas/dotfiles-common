{ self, packages, ... }@ctx:
{
  config,
  hostPlatform,
  lib,
  options,
  pkgs,
  system,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    flatten
    mapAttrs
    mkEnableOption
    mkForce
    mkIf
    mkMerge
    mkOption
    types
    ;
  moduleName = "davids-dotfiles-common/home/base";
  # Needed on darwin because the system ssh does not ship with sk-libfido2.dylib
  standaloneFIDO2 = "${
    packages.${system}.openssh-sk-standalone
  }/lib/sk-libfido2${hostPlatform.extensions.sharedLibrary}";
in
{
  options =
    let
      inherit (types)
        mergeTypes
        lines
        attrsOf
        submodule
        bool
        ;
    in
    {
      davids.ssh.enable = mkEnableOption "SSH goodies";
      davids.ssh.agent.enable = mkEnableOption "ssh-agent management";
      davids.ssh.knownHostsLines = mkOption {
        description = "Managed known_host file lines";
        type = lines;
        default = "";
      };
      davids.ssh.matchBlocks = mkOption {
        type = attrsOf (
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
    };
  config = {
    launchd.agents = mkIf hostPlatform.isDarwin {
      # Uber-hacky way to redirect the default ssh-agent socket to our agent
      # We can't use the standard /System/Library/LaunchAgents/com.openssh.ssh-agent.plist
      # because we need to customize the arguments to support FIDO2
      # SSH_AUTH_SOCK will always be allocated (unless someone turned off SIP and unloaded the system ssh-agent)
      "com.openssh.ssh-agent" = mkIf (config.davids.ssh.enable) {
        enable = config.davids.ssh.agent.enable;
        config = {
          ProgramArguments = [
            "/bin/sh"
            "-c"
            (concatStringsSep " " [
              "rm -f $SSH_AUTH_SOCK;"
              "exec /usr/bin/ssh-agent"
              "-d"
              "-a $SSH_AUTH_SOCK"
              "-P ${standaloneFIDO2}"
            ])
          ];
          EnableTransactions = true;
          RunAtLoad = true;
        };
      };
    };
    programs = {
      ssh = mkIf config.davids.ssh.enable (
        let
          wildcardHostConfig = {
            forwardAgent = false;
            addKeysToAgent = "no";
            compression = false;
            serverAliveInterval = 0;
            serverAliveCountMax = 3;
            hashKnownHosts = false;
            # default ~/.ssh/known_hosts is unmanaged. ~/.ssh/davids.known_hosts is managed by this module
            userKnownHostsFile = "~/.ssh/known_hosts ~/.ssh/davids.known_hosts";
            controlMaster = "no";
            controlPath = "~/.ssh/master-%r@%n:%p";
            controlPersist = "no";
          };
        in
        {
          enable = true;
          # trace: warning: davidszakallas profile: `programs.ssh` default values will be removed in the future.
          enableDefaultConfig = false;
          # Unmanaged local overrides
          includes = [ "~/.local/share/ssh/config" ];

          matchBlocks = mapAttrs (
            n:
            {
              applyDefaults ? true,
              isFIDO2 ? false,
              identityFile ? null,
              ...
            }@v:
            let
              hasIdentityFile = (v.identityFile or "") != "";
            in
            mkMerge [
              (mkIf (n == "*") wildcardHostConfig)
              (mkIf applyDefaults {
                identitiesOnly = mkIf hasIdentityFile (mkForce true);
                addKeysToAgent = mkIf hasIdentityFile (mkForce "yes");
                extraOptions = mkMerge [
                  (mkIf (pkgs.stdenv.isDarwin && hasIdentityFile) { "UseKeychain" = "yes"; })
                ];
              })
              # the default macOS ssh does not ship sk-libfido2 so we need to
              # use to use a standalone library
              (mkIf (hasIdentityFile && isFIDO2 && pkgs.stdenv.isDarwin) {
                extraOptions = {
                  "SecurityKeyProvider" = "${standaloneFIDO2}";
                };
              })
              (builtins.removeAttrs v [
                "applyDefaults"
                "isFIDO2"
              ])
            ]
          ) ({ "*" = { }; } // config.davids.ssh.matchBlocks);
        }
      );
    };
  };
}
