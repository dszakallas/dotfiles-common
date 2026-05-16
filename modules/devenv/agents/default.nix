_:
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
            description = "Type of MCP server connection.";
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
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "URL for HTTP MCP servers.";
          };
          headers = lib.mkOption {
            type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
            default = null;
            description = "HTTP headers for HTTP MCP servers (e.g., for authentication).";
          };
        };
      }
    );
    default = {
      devenv = {
        type = "stdio";
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
          type = "stdio";
          command = lib.getExe pkgs.awslabs-iam-mcp-server;
          args = [ ];
          env = { };
        };
        github = {
          type = "http";
          url = "https://api.githubcopilot.com/mcp/";
          headers = {
            Authorization = "Bearer GITHUB_PAT";
          };
        };
        linear = {
          type = "http";
          url = "https://mcp.linear.app/mcp";
        };
        devenv = {
          type = "stdio";
          command = "devenv";
          args = [ "mcp" ];
          env = {
            DEVENV_ROOT = config.devenv.root;
          };
        };
      }
    '';
  };
  convertMcpServersToAgentFormat =
    agent: value:
    lib.mapAttrs (
      name: server:
      let
        serverType = server.type or null;

        # Validate mutually exclusive fields
        stdioFields = [
          "command"
          "args"
          "env"
        ];
        httpFields = [
          "url"
          "headers"
        ];

        hasStdioField = builtins.any (field: server.${field} or null != null) stdioFields;
        hasHttpField = builtins.any (field: server.${field} or null != null) httpFields;

        validated =
          if serverType == "stdio" && hasHttpField then
            throw "MCP server '${name}': stdio type cannot have 'url' or 'headers' fields"
          else if (serverType == "http" || serverType == "sse") && hasStdioField then
            throw "MCP server '${name}': http/sse type cannot have 'command', 'args', or 'env' fields"
          else
            server;

        # Filter out null values and mutually exclusive fields
        filtered = lib.filterAttrs (_: v: v != null) validated;

        cleanedServer =
          if serverType == "stdio" then
            builtins.removeAttrs filtered (httpFields ++ [ "type" ])
          else if serverType == "http" || serverType == "sse" then
            builtins.removeAttrs filtered (stdioFields ++ [ "type" ])
          else
            builtins.removeAttrs filtered [ "type" ];
      in
      if agent == "gemini" then
        if serverType == "http" then
          builtins.removeAttrs (
            cleanedServer
            // {
              httpUrl = filtered.url;
            }
          ) [ "url" ]
        else
          cleanedServer
      else
        cleanedServer
    ) value;
in
{
  options = {
    agents.augment.enable = lib.mkEnableOption "Enable augment coding agent.";
    agents.augment.settings.enable = lib.mkEnableOption "Enable augment coding agent setting configuration.";
    agents.augment.settings.mcpServers = mcpServers;

    agents.gemini.enable = lib.mkEnableOption "Enable gemini coding agent.";
    agents.gemini.settings.enable = lib.mkEnableOption "Enable gemini coding agent setting configuration.";
    agents.gemini.settings.mcpServers = mcpServers;

    agents.vscode.enable = lib.mkEnableOption "Enable VSCode Copilot coding agent.";
    agents.vscode.settings.enable = lib.mkEnableOption "Enable VSCode Copilot coding agent setting configuration.";
    agents.vscode.settings.mcpServers = mcpServers;
  };

  config = {
    # I do this horrible hack for now, as auggie does not support
    # workspace config for mcp servers and I don't want to pull
    # in a derivation just yet.
    scripts.auggie = lib.mkIf config.agents.augment.enable {
      exec = ''
        AUGGIE_PATH=$(which auggie)
        AUGGIE_DIR=$(dirname "$AUGGIE_PATH")
        export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "^$AUGGIE_DIR$" | tr '\n' ':' | sed 's/:$//')
        $(which auggie) --mcp-config "$DEVENV_ROOT/.augment/mcp.json" "$@"
      '';
    };

    tasks = {
      "augment:setup" = lib.mkIf (config.agents.augment.enable && config.agents.augment.settings.enable) {
        description = "Setup Augment coding agent.";
        exec = ''
          mkdir -p ${config.devenv.root}/.augment
          cat << EOF > $DEVENV_ROOT/.augment/mcp.json
          ${builtins.toJSON {
            mcpServers = convertMcpServersToAgentFormat "augment" config.agents.augment.settings.mcpServers;
          }}
          EOF
          chmod 600 $DEVENV_ROOT/.augment/mcp.json
        '';
        before = [ "devenv:enterShell" ];
      };
      "vscode:setup" = lib.mkIf (config.agents.vscode.enable && config.agents.vscode.settings.enable) {
        description = "Setup VSCode Copilot coding agent.";
        exec = ''
          mkdir -p ${config.devenv.root}/.vscode
          cat << EOF > $DEVENV_ROOT/.vscode/mcp.json
          ${builtins.toJSON {
            servers = convertMcpServersToAgentFormat "vscode" config.agents.vscode.settings.mcpServers;
          }}
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
          ${builtins.toJSON {
            mcpServers = convertMcpServersToAgentFormat "gemini" config.agents.gemini.settings.mcpServers;
            context = {
              fileName = [ "AGENTS.md" ];
            };
          }}
          EOF
          chmod 600 $DEVENV_ROOT/.gemini/settings.json
        '';
        before = [ "devenv:enterShell" ];
      };
    };
  };
}
