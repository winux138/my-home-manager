{ ... }:
{
  programs.kitty = {
    enable = true;

    # Medium weight: slightly bolder than Regular.
    font.name = ''family="Iosevka Nerd Font" style="Medium"'';
    themeFile = "Solarized_Light";

    # Kitty configuration goes here.
    settings = {
      background_opacity = 0.95;

      # Bell
      enable_audio_bell = false;
      visual_bell_duration = 0.0;

      # Copy/paste / clipboard
      copy_on_select = "clipboard";
      strip_trailing_spaces = "smart";

      # Links
      detect_urls = true;
      underline_hyperlinks = "always";

      # Shell integration
      shell_integration = "enabled";

      # Performance / updates
      sync_to_monitor = true;
      repaint_delay = 10;
      input_delay = 3;
      update_check_interval = 0;
    };
  };
}
