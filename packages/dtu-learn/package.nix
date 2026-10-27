{
  lib,
  fetchFromGitHub,
  python3Packages,
  playwright-driver,
}:

# MCP server + CLI for DTU Learn (Brightspace/D2L), so OpenCode and other MCP
# clients can answer questions about courses, deadlines, slides and lecture
# transcripts. Unofficial student project.
python3Packages.buildPythonApplication rec {
  pname = "dtu-learn";
  version = "0.2.0-post1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "CarlSvejstrup";
    repo = "dtu-learn-mcp";
    rev = "9444a1fd51999d4a0d27d4067d8df2a9a3ea7716"; # main two commits after v0.2.0
    hash = "sha256-4hVU4itt7f786yYDpWvy5CGXrP2XUTiur3Tjz2x1Dds=";
  };

  build-system = with python3Packages; [ hatchling ];

  dependencies = with python3Packages; [
    httpx
    html2text
    mcp
    playwright
    pypdf
    tzdata
  ];

  # nixpkgs ships mcp 2.x while upstream pins mcp<2; mcp 2.x renamed
  # mcp.server.fastmcp.FastMCP to mcp.server.mcpserver.MCPServer, but the
  # surface this app uses (name, instructions, .tool(), .run()) is unchanged.
  pythonRemoveDeps = [ "mcp" ];
  postPatch = ''
    substituteInPlace src/dtulearn/mcp_server.py \
      --replace-fail \
        'from mcp.server.fastmcp import FastMCP' \
        'from mcp.server.mcpserver import MCPServer as FastMCP'
  '';
  pythonImportsCheck = [ "dtulearn" ];

  doCheck = false;

  # Playwright would otherwise download Chromium to ~/.cache on first use,
  # which never works on NixOS; point it at the Nix-built browser instead.
  # Upstream falls back through channels chrome/msedge first, so a system
  # Chrome or Edge still wins when present.
  postFixup = ''
    wrapProgram $out/bin/dtu-learn \
      --set PLAYWRIGHT_BROWSERS_PATH ${playwright-driver.browsers}
  '';

  meta = {
    description = "DTU Learn (Brightspace/D2L) MCP server and CLI for AI assistants";
    homepage = "https://github.com/CarlSvejstrup/dtu-learn-mcp";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "dtu-learn";
  };
}
