ctx:
{ lib, config, ... }:
let
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
    agents.gemini.settings.enable = lib.mkEnableOption "Enable gemini coding agent setting configuration.";
    agents.gemini.settings.value = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Gemini settings configuration.";
    };

    agents.vscode.enable = lib.mkEnableOption "Enable VSCode Copilot coding agent.";
    agents.vscode.mcp.enable = lib.mkEnableOption "Enable VSCode Copilot MCP configuration.";
    agents.vscode.mcp.servers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "VSCode Copilot MCP servers configuration.";
    };
  };

  config = {
    tasks = {
      "mcp:setup" = lib.mkIf config.agents.mcp.enable {
        description = "Setup generic coding agent configuration.";
        exec = ''
          mkdir -p $DEVENV_ROOT/.agents
          cat << EOF > $DEVENV_ROOT/.agents/mcp_config.json
          ${builtins.toJSON { mcpServers = config.agents.mcp.servers; }}
          EOF
          chmod 600 $DEVENV_ROOT/.agents/mcp_config.json
        '';
        before = [ "devenv:enterShell" ];
      };
      "claude:setup" = lib.mkIf (config.agents.claude.enable && config.agents.claude.mcp.enable) {
        description = "Setup Claude coding agent.";
        exec = ''
          cat << EOF > $DEVENV_ROOT/.mcp.json
          ${builtins.toJSON config.agents.claude.mcp.servers}
          EOF
          chmod 600 $DEVENV_ROOT/.mcp.json
        '';
        before = [ "devenv:enterShell" ];
      };
      "copilot:setup" = lib.mkIf (config.agents.copilot.enable && config.agents.copilot.mcp.enable) {
        description = "Setup GitHub Copilot coding agent.";
        exec = ''
          mkdir -p ${config.devenv.root}/.copilot
          cat << EOF > $DEVENV_ROOT/.copilot/mcp-config.json
          ${builtins.toJSON config.agents.copilot.mcp.servers}
          EOF
          chmod 600 $DEVENV_ROOT/.copilot/mcp-config.json
        '';
        before = [ "devenv:enterShell" ];
      };
      "vscode:setup" = lib.mkIf (config.agents.vscode.enable && config.agents.vscode.mcp.enable) {
        description = "Setup VSCode Copilot coding agent.";
        exec = ''
          mkdir -p ${config.devenv.root}/.vscode
          cat << EOF > $DEVENV_ROOT/.vscode/mcp.json
          ${builtins.toJSON config.agents.vscode.mcp.servers}
          EOF
          chmod 600 $DEVENV_ROOT/.vscode/mcp.json
        '';
        before = [ "devenv:enterShell" ];
      };
      "gemini:setup" = lib.mkIf (config.agents.gemini.enable && config.agents.gemini.settings.enable) {
        description = "Setup Gemini coding agent.";
        exec = ''
          mkdir -p ${config.devenv.root}/.gemini
          cat << EOF > $DEVENV_ROOT/.gemini/settings.json
          ${builtins.toJSON config.agents.gemini.settings.value}
          EOF
          chmod 600 $DEVENV_ROOT/.gemini/settings.json
        '';
        before = [ "devenv:enterShell" ];
      };
    };
  };
}
