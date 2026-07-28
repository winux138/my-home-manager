{ pkgs, ... }:
let
  delta = "${pkgs.delta}/bin/delta";
in
{
  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      user.name = "Julien Thomas";
      user.email = "julien.thomas@external.roche.com";

      branch.sort = "-committerdate";
      column.ui = "auto";
      core.editor = "hx";
      commit.verbose = true;
      diff = {
        algorithm = "histogram";
        colorMoved = "plain";
        mnemonicPrefix = true;
        renames = true;
      };

      fetch = {
        all = true;
        prune = true;
        pruneTags = true;
      };

      init.defaultBranch = "main";
      merge.conflictStyle = "zdiff3";
      pull.rebase = true;
      push = {
        autoSetupRemote = true;
        default = "simple";
        followTags = true;
      };
      rebase = {
        autoSquash = true;
        autoStash = true;
        updateRefs = true;
      };
      rerere = {
        autoUpdate = true;
        enabled = true;
      };
      tag.sort = "version:refname";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      dark = true;
      line-numbers = true;
      navigate = true;
    };
  };

  programs.lazygit = {
    enable = true;
    settings = {
      git.pagers = [
        {
          pager = "${delta} --paging=never --hyperlinks --hyperlinks-file-link-format=lazygit-edit://{path}:{line}";
        }
        { } # built-in lazygit diff, available via `|`
      ];
    };
  };

}
