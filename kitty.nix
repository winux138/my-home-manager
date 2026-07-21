{ ... }:
{
  programs.kitty = {
    enable = true;

    font.name = "Iosevka Nerd Font";
    themeFile = "Solarized_Light";

    # Kitty configuration goes here.
    settings = {
      background_opacity = 0.95;
    };
  };
}
