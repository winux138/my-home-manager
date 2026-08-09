{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:
let
  piPackage = unstable.pi-coding-agent;
  piAgentDir = ".pi/agent";
  piAgentPath = "${config.home.homeDirectory}/${piAgentDir}";
  piSettingsPath = "${piAgentPath}/settings.json";
  # Delete this list together with its cleanup command after every host has migrated.
  legacyPiFiles = map (path: "${piAgentPath}/${path}") [
    "agents/checker.md"
    "agents/planner.md"
    "agents/reviewer.md"
    "agents/scout.md"
    "agents/worker.md"
    "prompts/implement-and-review.md"
    "prompts/implement.md"
    "prompts/scout-and-plan.md"
    "extensions/subagent/agents.ts"
    "extensions/subagent/index.ts"
  ];
  settings = (pkgs.formats.json { }).generate "pi-settings.json" {
    lastChangelogVersion = piPackage.version;
    defaultProvider = "github-copilot";
    defaultModel = "gpt-5.6-sol";
    defaultThinkingLevel = "high";
    enableInstallTelemetry = false;
    hideThinkingBlock = false;
    theme = "dark";
  };
in
{
  home.packages = [ piPackage ];

  home.sessionVariables = {
    PI_SKIP_VERSION_CHECK = "1";
    PI_TELEMETRY = "0";
  };

  home.file = {
    "${piAgentDir}/AGENTS.md" = {
      source = ./pi/AGENTS.md;
      force = true;
    };

    "${piAgentDir}/skills" = {
      source = ./pi/skills;
      force = true;
      recursive = true;
    };
  };

  home.activation.preparePiAgentDir =
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
      ''
        # Agent directory contains credentials and session data.
        run install -d -m700 ${lib.escapeShellArg piAgentPath}
        # Remove exact pre-Home-Manager resources; retire with legacyPiFiles above.
        run rm -f ${lib.escapeShellArgs legacyPiFiles}
      '';

  home.activation.writePiSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run install -Dm600 ${settings} ${lib.escapeShellArg piSettingsPath}
  '';
}
