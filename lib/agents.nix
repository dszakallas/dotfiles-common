{ nixpkgs, ... }@ctx:
let
  inherit (nixpkgs) lib;

  mcpServersForAgent =
    agent: value:
    let
      formattedServers = lib.mapAttrs (
        name: server:
        let
          serverType = server.type;

          # Validate mutually exclusive fields
          stdioFields = [
            "command"
            "args"
            "env"
          ];
          urlFields = [
            "serverUrl"
            "headers"
          ];

          hasStdioField = builtins.any (field: server.${field} or null != null) stdioFields;
          hasUrlField = builtins.any (field: server.${field} or null != null) urlFields;

          validated =
            if serverType == "stdio" && hasUrlField then
              throw "MCP server '${name}': stdio type cannot have 'serverUrl' or 'headers' fields"
            else if (serverType == "http" || serverType == "sse") && hasStdioField then
              throw "MCP server '${name}': ${serverType} type cannot have 'command', 'args', or 'env' fields"
            else if (serverType == "http" || serverType == "sse") && server.serverUrl or null == null then
              throw "MCP server '${name}': ${serverType} type must have 'serverUrl'"
            else if serverType == "stdio" && server.command or null == null then
              throw "MCP server '${name}': stdio type must have 'command'"
            else
              server;

          # Filter out null values
          filtered = lib.filterAttrs (_: v: v != null) validated;

          cleanedServer =
            if serverType == "stdio" then
              builtins.removeAttrs filtered (urlFields ++ [ "type" ])
            else
              builtins.removeAttrs filtered (stdioFields ++ [ "type" ]);
        in
        if agent == "gemini" then
          if serverType == "http" then
            builtins.removeAttrs (
              cleanedServer
              // {
                httpUrl = filtered.serverUrl;
              }
            ) [ "serverUrl" ]
          else if serverType == "sse" then
            builtins.removeAttrs (
              cleanedServer
              // {
                url = filtered.serverUrl;
              }
            ) [ "serverUrl" ]
          else
            cleanedServer
        else if agent == "antigravity" then
          cleanedServer // { type = serverType; }
        else if agent == "claude" then
          if serverType == "http" || serverType == "sse" then
            builtins.removeAttrs (
              cleanedServer
              // {
                url = filtered.serverUrl;
                type = serverType;
              }
            ) [ "serverUrl" ]
          else
            (cleanedServer // { type = serverType; })
        else if agent == "copilot" then
          if serverType == "sse" then
            lib.warn "MCP server '${name}': sse transport is deprecated for GitHub Copilot." (
              builtins.removeAttrs (
                cleanedServer
                // {
                  url = filtered.serverUrl;
                  type = "sse";
                  tools = [ "*" ];
                }
              ) [ "serverUrl" ]
            )
          else if serverType == "http" then
            builtins.removeAttrs (
              cleanedServer
              // {
                type = serverType;
                tools = [ "*" ];
                url = filtered.serverUrl;
              }
            ) [ "serverUrl" ]
          else
            cleanedServer
            // {
              type = serverType;
              tools = [ "*" ];
            }
        else if agent == "vscode" then
          if serverType == "http" || serverType == "sse" then
            builtins.removeAttrs (
              cleanedServer
              // {
                url = filtered.serverUrl;
                type = serverType;
              }
            ) [ "serverUrl" ]
          else
            (cleanedServer // { type = serverType; })
        else
          cleanedServer // { type = serverType; }
      ) value;
    in
    if agent == "vscode" then { servers = formattedServers; } else { mcpServers = formattedServers; };

in
{
  agents = {
    inherit mcpServersForAgent;
  };
}
