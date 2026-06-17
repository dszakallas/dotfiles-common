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
      defaultMcpTarget ? null,
      sessionVariables ? { },
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
          source = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to the source file for the main memory file.";
          };
        };
        rules = mkOption {
          type = types.attrsOf (
            types.submodule {
              options = {
                enable = mkEnableOption "this rule file";
                content = mkOption {
                  type = types.lines;
                  default = "";
                  description = "Content of the rule file.";
                };
                source = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Source path for the rule file.";
                };
              };
            }
          );
          default = { };
          description = "Modular rule files for ${name}.";
        };
        mcp = {
          enable = mkEnableOption "user-level MCP servers for ${name}";
          target = mkOption {
            type = types.nullOr types.str;
            default = defaultMcpTarget;
            description = "Config file (relative to home) that ${name} MCP servers are merged into.";
          };
          servers = mkOption {
            type = types.attrs;
            default = { };
            description = "Agent-shaped MCP servers object (as produced by mcpServersForAgent) merged into ${name}'s config file.";
          };
        };
      };

      config =
        let
          cfg = config.davids.agents.${name};
          memoryFile = "${config.home.homeDirectory}/${cfg.memory.directory}/${cfg.memory.target}";
        in
        mkIf cfg.enable (mkMerge [
          {
            home.packages = if cfg.package == null then [ ] else [ cfg.package ];
            home.sessionVariables = sessionVariables;
          }
          (mkIf (cfg.linkSkills && config.davids.agents.skills.enable) {
            home.file = lib.mapAttrs' (skillName: src: {
              name = "${cfg.skillsDirectory}/${skillName}";
              value = {
                source = src;
              };
            }) config.davids.agents.skills.entries;
          })
          (mkIf (cfg.rules != { }) {
            home.file = lib.mapAttrs' (ruleName: rule: {
              name = "${cfg.userDirectory}/rules/${ruleName}";
              value = if rule.source != null then { source = rule.source; } else { text = rule.content; };
            }) (lib.filterAttrs (_: r: r.enable) cfg.rules);
          })
          (mkIf cfg.memory.enable {
            home.file."${memoryFile}" =
              if cfg.memory.source != null then
                { source = cfg.memory.source; }
              else
                { text = if cfg.memory.content != null then cfg.memory.content else ""; };
          })
          # User-level MCP servers are merged into the agent's own config file
          # (which the agent itself also writes to), so we can't symlink it from
          # the store. Instead replace the managed top-level key while preserving
          # siblings, mirroring the devenv `jq -s '.[0] + .[1]'` merge.
          (mkIf (cfg.mcp.enable && cfg.mcp.target != null) (
            let
              managed = pkgs.writeText "${name}-mcp.json" (builtins.toJSON cfg.mcp.servers);
              mergeScript = pkgs.writeShellScript "${name}-mcp-merge" ''
                set -eu
                target="$1"
                managed="$2"
                mkdir -p "$(dirname "$target")"
                [ -e "$target" ] || echo '{}' > "$target"
                ${pkgs.jq}/bin/jq -s '.[0] + .[1]' "$target" "$managed" > "$target.tmp"
                mv "$target.tmp" "$target"
                chmod 600 "$target"
              '';
            in
            {
              home.activation."${name}Mcp" = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                run ${mergeScript} "${config.home.homeDirectory}/${cfg.mcp.target}" ${managed}
              '';
            }
          ))
        ]);
    };

  geminiModule = mkAgentModule {
    name = "gemini";
    defaultPackage = pkgs.gemini-cli;
    defaultUserDirectory = ".gemini";
    defaultMemoryFile = "GEMINI.md";
    defaultMcpTarget = ".gemini/settings.json";
  };

  claudeModule = mkAgentModule {
    name = "claude";
    defaultPackage = pkgs.claude-code;
    defaultUserDirectory = ".claude";
    defaultMemoryFile = "CLAUDE.md";
    defaultLinkSkills = true;
    defaultMcpTarget = ".claude.json";
    sessionVariables = {
      CLAUDE_CONFIG_DIR = "$HOME/.claude";
    };
  };

  copilotModule = mkAgentModule {
    name = "copilot";
    defaultPackage = pkgs.github-copilot-cli;
    defaultUserDirectory = ".copilot";
    defaultMemoryFile = "copilot-instructions.md";
    defaultMcpTarget = ".copilot/mcp-config.json";
  };

  antigravityModule = mkAgentModule {
    name = "antigravity";
    defaultPackage = null;
    defaultUserDirectory = ".gemini/antigravity-cli";
    defaultMemoryDirectory = ".gemini";
    defaultMemoryFile = "GEMINI.md";
    defaultLinkSkills = true;
  };

  opencodeModule = mkAgentModule {
    name = "opencode";
    defaultPackage = pkgs.opencode;
    defaultUserDirectory = ".config/opencode";
    defaultMemoryFile = "AGENTS.md";
    defaultLinkSkills = true;
    defaultMcpTarget = ".config/opencode/opencode.json";
  };
in
{
  options.davids.agents = {
    enable = mkEnableOption "AI agent tools";
    gemini = geminiModule.options;
    claude = claudeModule.options;
    copilot = copilotModule.options;
    antigravity = antigravityModule.options;
    opencode = opencodeModule.options;
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
    opencodeModule.config
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
