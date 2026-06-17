ctx:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  # Merge the managed JSON object into an existing config file, replacing the
  # top-level keys we own (e.g. mcpServers) while preserving any sibling keys.
  # `jq -s '.[0] + .[1]'` is a shallow merge: managed keys overwrite existing
  # ones, keys present only in the existing file are kept.
  mkMergeTask = description: path: managed: {
    inherit description;
    exec = ''
      target="${path}"
      mkdir -p "$(dirname "$target")"
      [ -f "$target" ] || echo '{}' > "$target"
      ${pkgs.jq}/bin/jq -s '.[0] + .[1]' "$target" - << 'EOF' > "$target.tmp"
      ${builtins.toJSON managed}
      EOF
      mv "$target.tmp" "$target"
      chmod 600 "$target"
    '';
    before = [ "devenv:enterShell" ];
  };

  mcpServers = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          type = lib.mkOption {
            type = lib.types.enum [
              "stdio"
              "http"
              "sse"
            ];
            default = "stdio";
            description = "Transport type of the MCP server.";
          };
          command = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Command to execute for stdio MCP servers.";
          };
          args = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
            description = "Arguments to pass to the command for stdio MCP servers.";
          };
          env = lib.mkOption {
            type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
            default = null;
            description = "Environment variables for stdio MCP servers.";
          };
          serverUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "URL for HTTP or SSE MCP servers.";
          };
          headers = lib.mkOption {
            type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
            default = null;
            description = "HTTP headers for HTTP or SSE MCP servers (e.g., for authentication).";
          };
        };
      }
    );
    default = {
      devenv = {
        command = "devenv";
        args = [ "mcp" ];
        env = {
          DEVENV_ROOT = config.devenv.root;
        };
      };
    };
    description = ''
      MCP (Model Context Protocol) servers to configure.
      These servers provide additional capabilities and context to AI coding agents.
    '';
    example = lib.literalExpression ''
      {
        awslabs-iam-mcp-server = {
          command = lib.getExe pkgs.awslabs-iam-mcp-server;
          args = [ ];
          env = { };
        };
        github = {
          serverUrl = "https://api.githubcopilot.com/mcp/";
          headers = {
            Authorization = "Bearer GITHUB_PAT";
          };
        };
        linear = {
          httpUrl = "https://mcp.linear.app/mcp";
        };
        devenv = {
          command = "devenv";
          args = [ "mcp" ];
          env = {
            DEVENV_ROOT = config.devenv.root;
          };
        };
      }
    '';
  };
in
{
  options = {
    agents.mcp.enable = lib.mkEnableOption "Enable generic MCP configuration.";
    agents.mcp.servers = mcpServers;

    agents.claude.enable = lib.mkEnableOption "Enable Claude coding agent.";
    agents.claude.mcp.enable = lib.mkEnableOption "Enable Claude MCP configuration.";
    agents.claude.mcp.servers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Claude MCP servers configuration.";
    };

    agents.copilot.enable = lib.mkEnableOption "Enable GitHub Copilot coding agent.";
    agents.copilot.mcp.enable = lib.mkEnableOption "Enable GitHub Copilot MCP configuration.";
    agents.copilot.mcp.servers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "GitHub Copilot MCP servers configuration.";
    };

    agents.gemini.enable = lib.mkEnableOption "Enable gemini coding agent.";
    agents.gemini.mcp.enable = lib.mkEnableOption "Enable gemini MCP configuration.";
    agents.gemini.mcp.servers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Gemini MCP servers configuration.";
    };

    agents.vscode.enable = lib.mkEnableOption "Enable VSCode Copilot coding agent.";
    agents.vscode.mcp.enable = lib.mkEnableOption "Enable VSCode Copilot MCP configuration.";
    agents.vscode.mcp.servers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "VSCode Copilot MCP servers configuration.";
    };

    agents.opencode.enable = lib.mkEnableOption "Enable opencode coding agent.";
    agents.opencode.mcp.enable = lib.mkEnableOption "Enable opencode MCP configuration.";
    agents.opencode.mcp.servers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "opencode MCP servers configuration.";
    };
  };

  config = {
    tasks = {
      "mcp:setup" = lib.mkIf config.agents.mcp.enable (
        mkMergeTask "Setup generic coding agent configuration." "$DEVENV_ROOT/.agents/mcp_config.json" {
          mcpServers = config.agents.mcp.servers;
        }
      );
      "claude:setup" = lib.mkIf (config.agents.claude.enable && config.agents.claude.mcp.enable) (
        mkMergeTask "Setup Claude coding agent." "$DEVENV_ROOT/.mcp.json" config.agents.claude.mcp.servers
      );
      "copilot:setup" = lib.mkIf (config.agents.copilot.enable && config.agents.copilot.mcp.enable) (
        mkMergeTask "Setup GitHub Copilot coding agent." "$DEVENV_ROOT/.copilot/mcp-config.json"
          config.agents.copilot.mcp.servers
      );
      "vscode:setup" = lib.mkIf (config.agents.vscode.enable && config.agents.vscode.mcp.enable) (
        mkMergeTask "Setup VSCode Copilot coding agent." "$DEVENV_ROOT/.vscode/mcp.json"
          config.agents.vscode.mcp.servers
      );
      "gemini:setup" = lib.mkIf (config.agents.gemini.enable && config.agents.gemini.mcp.enable) (
        mkMergeTask "Setup Gemini coding agent." "$DEVENV_ROOT/.gemini/settings.json"
          config.agents.gemini.mcp.servers
      );
      "opencode:setup" = lib.mkIf (config.agents.opencode.enable && config.agents.opencode.mcp.enable) (
        mkMergeTask "Setup opencode coding agent." "$DEVENV_ROOT/opencode.json"
          config.agents.opencode.mcp.servers
      );
    };
  };
}
