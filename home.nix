{ lib, pkgs, ... }:
let
  gitConfig = import ./git.nix { inherit lib pkgs; };
in
{
  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  home = {
    packages = with pkgs; [
      kitty
      keepassxc

      neovim
      lazygit
      helix

      fd
      ripgrep
      ouch
      tmux
      fastfetch
      bat
      bottom
      htop
      fzf
      eza
      dust
      tree
      opencode
      curl

      # fonts
      font-awesome
      dina-font
      liberation_ttf
      mplus-outline-fonts.githubRelease
      nerd-fonts.iosevka
      nerd-fonts.symbols-only
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      # proggyfonts
    ];

    username = "ju";
    homeDirectory = "/home/ju";

    stateVersion = "25.11";
  };

  imports = [ gitConfig ];

  programs.nvf = {
    enable = true;
    enableManpages = true;

    settings.vim = {
      viAlias = false;
      vimAlias = true;

      searchCase = "smart";
      options.scrolloff = 5;
      options.wrap = false;
      options.colorcolumn = "80,120";
      options.autoread = true;

      clipboard = {
        enable = true;
        providers.wl-copy.enable = true;
        registers = "unnamedplus";
      };

      statusline.lualine.enable = true;
      telescope.enable = true;
      autocomplete.nvim-cmp.enable = true;
      dashboard.alpha.enable = true;
      notes.todo-comments.enable = true;

      binds = {
        whichKey.enable = true;
        # cheatsheet.enable = true;
      };

      git = {
        enable = true;
        neogit.enable = true;
      };

      utility = {
        motion.flash-nvim.enable = true;
        surround.enable = true;
      };

      extraPlugins = {
        # Opencode = {
        #   package = pkgs.vimPlugins.opencode-nvim;
        # };
        lush = {
          package = pkgs.vimPlugins.lush-nvim;
        };
        zenbones = {
          package = pkgs.vimPlugins.zenbones-nvim;
          setup = ''
            vim.cmd('colorscheme neobones')
            vim.cmd('set background=light')
          '';
        };
        photon = {
          package = pkgs.vimUtils.buildVimPlugin {
            pname = "photon";
            version = "1.0.0";
            src = pkgs.fetchFromGitHub {
              owner = "axvr";
              repo = "photon.vim";
              rev = "master";
              hash = "sha256-kM7WP03uE20yr0nCusB3ncHzgtEYxqNzoNoQGen9p+o=";
            };
          };
          # setup = ''
          #   vim.cmd('colorscheme antiphoton')
          # '';
        };
      };

      languages = {
        # enableTreesitter = true;
        enableFormat = true;

        nix.enable = true;
        python.enable = true;
        rust = {
          enable = true;
          crates.enable = true;
          lsp.opts = ''
            ['rust-analyzer'] = {
              cargo = {allFeature = true},
              procMacro = {
                enable = true,
              },
            },
          '';
        };
        ts.enable = true;
        clang.enable = true;
      };

      lsp = {
        enable = true;
      };
    };
  };

  programs.tmux = {
    enable = true;
    clock24 = true;
    mouse = true;
    keyMode = "vi";
    baseIndex = 1;
    customPaneNavigationAndResize = true;
    escapeTime = 0;
  };
}
