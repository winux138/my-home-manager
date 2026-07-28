{ pkgs, ... }:
{
  programs.helix = {
    enable = true;
    # Sets EDITOR and VISUAL to hx globally.
    defaultEditor = true;
    settings = {
      theme = "papercolor-light";
      editor = {
        auto-pairs = false;
        line-number = "relative";
      };

      keys.insert = {
        "C-n" = "completion";
        "C-p" = "completion";
      };
    };

    languages = {
      language-server.crates-lsp.command = "crates-lsp";

      language = [
        {
          name = "toml";
          language-servers = [
            "taplo"
            "crates-lsp"
          ];
        }
      ];
    };

    extraPackages = with pkgs; [
      kdePackages.qtdeclarative
      rust-analyzer
      crates-lsp
      taplo
      nil
    ];
  };
}
