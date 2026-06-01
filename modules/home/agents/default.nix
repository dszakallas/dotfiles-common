{ ... }:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    mkMerge
    ;

  mkAgentModule =
    {
      name,
      defaultPackage,
      defaultUserDirectory,
      defaultMemoryDirectory ? defaultUserDirectory,
      defaultMemoryFile,
      defaultLinkSkills ? false,
      defaultSkillsDirectory ? "${defaultUserDirectory}/skills",
    }:
    {
      options = {
        enable = mkEnableOption "${name} agent";
        package = mkOption {
          type = types.nullOr types.package;
          default = defaultPackage;
          description = "The package for the ${name} agent.";
        };
        userDirectory = mkOption {
          type = types.str;
          default = defaultUserDirectory;
          description = "The user directory for ${name} local files.";
        };
        linkSkills = mkOption {
          type = types.bool;
          default = defaultLinkSkills;
          description = "Whether to link agent skills into the ${name} user directory under skills/.";
        };
        skillsDirectory = mkOption {
          type = types.str;
          default = defaultSkillsDirectory;
          description = "The directory where agent skills are linked for ${name}.";
        };
        memory = {
          enable = mkEnableOption "memory management for ${name}";
          directory = mkOption {
            type = types.str;
            default = defaultMemoryDirectory;
            description = "The directory for ${name} memory files.";
          };
          content = mkOption {
            type = types.nullOr types.lines;
            default = null;
            description = "Content of the main memory file.";
          };
          target = mkOption {
            type = types.str;
            default = defaultMemoryFile;
            description = "Path to the target file for the main memory file.";
          };
          extraImports = mkOption {
            type = types.listOf (
              types.submodule {
                options = {
                  enable = mkEnableOption "this memory import";
                  target = mkOption {
                    type = types.str;
                    description = "The target file name in the memory directory.";
                  };
                  content = mkOption {
                    type = types.lines;
                    default = "";
                    description = "Content of the imported memory file.";
                  };
                  source = mkOption {
                    type = types.nullOr types.path;
                    default = null;
                    description = "Source derivation or path for the imported memory file.";
                  };
                };
              }
            );
            default = [ ];
            description = "List of additional memory files to import.";
          };
          source = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to the source file for the main memory file.";
          };
        };
      };

      config =
        let
          cfg = config.davids.agents.${name};
          memoryBaseDir = "${config.home.homeDirectory}/${cfg.memory.directory}";
          memoryFile = "${memoryBaseDir}/${cfg.memory.target}";
          unmanagedFile = "${memoryBaseDir}/unmanaged.MEMORY.MD";
        in
        mkIf cfg.enable (mkMerge [
          {
            home.packages = if cfg.package == null then [ ] else [ cfg.package ];
          }
          (mkIf (cfg.linkSkills && config.davids.agents.skills.enable) {
            home.file = lib.mapAttrs' (skillName: src: {
              name = "${cfg.skillsDirectory}/${skillName}";
              value = {
                source = src;
              };
            }) config.davids.agents.skills.entries;
          })
          (mkIf cfg.memory.enable (mkMerge [
            {
              home.file."${memoryFile}".source = pkgs.runCommand "${name}-memory-with-imports" { } ''
                cat ${
                  if cfg.memory.source != null then
                    cfg.memory.source
                  else
                    pkgs.writeText "content" (if cfg.memory.content != null then cfg.memory.content else "")
                } > $out; echo "" >> $out; echo -n '${
                  lib.concatStringsSep "\n" (
                    map (m: "@./${m.target}") (builtins.filter (m: m.enable) cfg.memory.extraImports)
                  )
                }
                ' >> $out'';
            }
            {
              home.activation."initUnmanagedMemory${name}" = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                  $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "${memoryBaseDir}"
                  if [[ ! -f "${unmanagedFile}" ]]; then
                    $DRY_RUN_CMD cat <<EOF > "${unmanagedFile}"
                # Unmanaged Memory for ${name}

                <!--
                This file is for your private, local-only agent memory.
                Unlike '${cfg.memory.target}', this file is NOT managed by Nix.
                It will never be overwritten, and it is safe to edit manually.

                Use this for:
                - Personal secrets or local-only context.
                - Temporary notes you don't want to commit to your dotfiles.
                - Machine-specific configuration hints.
                -->
                EOF
                    $DRY_RUN_CMD chmod $VERBOSE_ARG 644 "${unmanagedFile}"
                  fi
              '';
            }
            {
              home.file = builtins.listToAttrs (
                map (
                  m:
                  lib.nameValuePair "${memoryBaseDir}/${m.target}" (
                    if m.source != null then { source = m.source; } else { text = m.content; }
                  )
                ) (builtins.filter (m: m.enable) cfg.memory.extraImports)
              );
            }
          ]))
        ]);
    };

  geminiModule = mkAgentModule {
    name = "gemini";
    defaultPackage = pkgs.gemini-cli;
    defaultUserDirectory = ".gemini";
    defaultMemoryFile = "GEMINI.md";
  };

  claudeModule = mkAgentModule {
    name = "claude";
    defaultPackage = pkgs.claude-code;
    defaultUserDirectory = ".claude";
    defaultMemoryFile = "CLAUDE.md";
    defaultLinkSkills = true;
  };

  copilotModule = mkAgentModule {
    name = "copilot";
    defaultPackage = pkgs.github-copilot-cli;
    defaultUserDirectory = ".copilot";
    defaultMemoryFile = "copilot-instructions.md";
  };

  antigravityModule = mkAgentModule {
    name = "antigravity";
    defaultPackage = null;
    defaultUserDirectory = ".gemini/antigravity-cli";
    defaultMemoryDirectory = ".gemini";
    defaultMemoryFile = "GEMINI.md";
    defaultLinkSkills = true;
  };
in
{
  options.davids.agents = {
    enable = mkEnableOption "AI agent tools";
    gemini = geminiModule.options;
    claude = claudeModule.options;
    copilot = copilotModule.options;
    antigravity = antigravityModule.options;
    skills = {
      enable = mkEnableOption "agent skills";
      entries = mkOption {
        type = types.attrsOf types.path;
        default = { };
        description = "Agent skills to install into ~/.agents/skills/. Each attribute name is the skill name and the value is a path or derivation to link.";
      };
    };
  };

  config = mkIf config.davids.agents.enable (mkMerge [
    geminiModule.config
    claudeModule.config
    copilotModule.config
    antigravityModule.config
    (mkIf config.davids.agents.skills.enable {
      home.file = lib.mapAttrs' (name: src: {
        name = ".agents/skills/${name}";
        value = {
          source = src;
        };
      }) config.davids.agents.skills.entries;
    })
  ]);
}
