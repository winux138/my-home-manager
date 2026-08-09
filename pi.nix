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
  piLegacyCheckerPath = "${piAgentPath}/agents/checker.md";
  piSettingsPath = "${piAgentPath}/settings.json";
  # Keep extension source coupled to package version; package layout changes fail during build.
  subagentExample = "${piPackage}/lib/node_modules/pi-monorepo/examples/extensions/subagent";
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

    "${piAgentDir}/agents" = {
      source = ./pi/agents;
      force = true;
      recursive = true;
    };

    "${piAgentDir}/prompts" = {
      source = ./pi/prompts;
      force = true;
      recursive = true;
    };

    "${piAgentDir}/skills" = {
      source = ./pi/skills;
      force = true;
      recursive = true;
    };

    "${piAgentDir}/extensions/subagent" = {
      source = subagentExample;
      force = true;
      recursive = true;
    };
  };

  # Keep directory hardening. Remove only checker cleanup after every host has migrated.
  home.activation.preparePiAgentDir =
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
      ''
        run install -d -m700 ${lib.escapeShellArg piAgentPath}
        run rm -f ${lib.escapeShellArg piLegacyCheckerPath}
      '';

  home.activation.writePiSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run install -Dm600 ${settings} ${lib.escapeShellArg piSettingsPath}
  '';
}
