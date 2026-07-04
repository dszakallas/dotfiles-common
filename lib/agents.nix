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
            else if serverType == "stdio" && server.args or null == null then
              server // { args = [ ]; }
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
        else if agent == "opencode" then
          # opencode uses its own schema: servers live under `mcp`, the transport
          # is `local`/`remote`, stdio command+args collapse into a single array,
          # and env vars are named `environment`.
          if serverType == "http" || serverType == "sse" then
            {
              type = "remote";
              url = filtered.serverUrl;
            }
            // lib.optionalAttrs (filtered ? headers) { inherit (filtered) headers; }
          else
            {
              type = "local";
              command = [ filtered.command ] ++ (filtered.args or [ ]);
            }
            // lib.optionalAttrs (filtered ? env) { environment = filtered.env; }
        else
          cleanedServer // { type = serverType; }
      ) value;
    in
    if agent == "vscode" then
      { servers = formattedServers; }
    else if agent == "opencode" then
      { mcp = formattedServers; }
    else
      { mcpServers = formattedServers; };

  memory = {
    commitConventions = ''
      ## Commit conventions

      Do not add AI attribution postscripts (e.g. `Co-Authored-By: Claude ...`) to commit messages.
    '';
  };

  mkSkill = pkgs: { name, version, src, include ? null, exclude ? [ ] }@args:
    pkgs.stdenvNoCC.mkDerivation {
      pname = name;
      inherit version src;

      includeAll = if include == null then "true" else "false";
      includeList = if include == null then [ ] else include;
      excludeList = exclude;

      dontBuild = true;

      installPhase = ''
        mkdir -p $out

        if [ -d "$src/skills" ]; then
          search_dir="$src/skills"
        else
          search_dir="$src"
        fi

        find "$search_dir" -name SKILL.md | while read -r skill_md; do
          skill_dir=$(dirname "$skill_md")
          
          if [ "$skill_dir" = "$search_dir" ]; then
            skill_name="$pname"
          else
            skill_name=$(basename "$skill_dir")
          fi

          is_included=0
          if [ "$includeAll" = "true" ]; then
            is_included=1
          else
            for item in $includeList; do
              if [ "$item" = "$skill_name" ]; then
                is_included=1
                break
              fi
            done
          fi

          if [ $is_included -eq 1 ]; then
            is_excluded=0
            for item in $excludeList; do
              if [ "$item" = "$skill_name" ]; then
                is_excluded=1
                break
              fi
            done

            if [ $is_excluded -eq 0 ]; then
              if [ "$skill_dir" = "$search_dir" ]; then
                cp -r "$skill_dir"/* "$out/"
              else
                mkdir -p "$out/$skill_name"
                cp -r "$skill_dir"/* "$out/$skill_name/"
              fi
            fi
          fi
        done
      '';
    };

in
{
  agents = {
    inherit mcpServersForAgent memory mkSkill;
  };
}
