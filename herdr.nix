{
  lib,
  pkgs,
  unstable,
  ...
}:
let
  tomlFormat = pkgs.formats.toml { };
in
{
  home.packages = [ unstable.herdr ];

  xdg.configFile."herdr/config.toml" = {
    force = true;
    source = tomlFormat.generate "herdr-config.toml" {
      onboarding = false;

      theme = {
        name = "terminal";
        auto_switch = false;
      };

      terminal = {
        default_shell = "${pkgs.fish}/bin/fish";
      };

      update = {
        version_check = false;
      };

      ui = {
        prompt_new_tab_name = false;
        show_agent_labels_on_pane_borders = true;
        toast.delivery = "system";
        sound.enabled = true;
      };

      experimental = {
        pane_history = true;
      };
    };
  };

  home.activation.installHerdrPiIntegration =
    lib.hm.dag.entryAfter [ "writeBoundary" "preparePiAgentDir" ]
      ''
        run ${lib.getExe unstable.herdr} integration install pi
      '';
}
