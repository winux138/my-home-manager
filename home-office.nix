{
  inputs,
  # lib,
  pkgs,
  unstable,
  ...
}:
# let
# in
{
  imports = [
    ./git.nix
    ./tmux.nix
    ./polybar.nix
  ];

  programs.home-manager.enable = true;
  nixpkgs.config.allowUnfree = true;

  programs.bash.enable = true;
  programs.bash.initExtra = ''
    eval "$(direnv hook bash)"
  '';
  programs.fish.enable = true;
  programs.fish.interactiveShellInit = ''
    if command -q nix-your-shell
      nix-your-shell fish | source
    end
  '';

  fonts.fontconfig.enable = true;

  programs.foot = {
    enable = true;
    settings = {
      main = {
        term = "xterm-256color";
        font = "Iosevka Nerd Font:size=11";
      };
    };
  };

  programs.firefox = {
    enable = true;
    profiles.thomaj81.extensions.packages = with inputs.firefox-addons.packages.${pkgs.system}; [
      ublock-origin
      consent-o-matic
      tridactyl
    ];
  };

  programs.opencode = {
    enable = true;
    package = unstable.opencode;

    settings.instructions = [
      "/home/thomaj81/Notes/ai/memory/rust.md"
      "/home/thomaj81/Notes/ai/memory/git.md"
    ];

    rules = ''
---
name: caveman
description: >
  Ultra-compressed communication mode. Cuts token usage ~75% by speaking like caveman
  while keeping full technical accuracy. Supports intensity levels: lite, full (default), ultra,
  wenyan-lite, wenyan-full, wenyan-ultra.
  Use when user says "caveman mode", "talk like caveman", "use caveman", "less tokens",
  "be brief", or invokes /caveman. Also auto-triggers when token efficiency is requested.
---

Respond terse like smart caveman. All technical substance stay. Only fluff die.

## Persistence

ACTIVE EVERY RESPONSE. No revert after many turns. No filler drift. Still active if unsure. Off only: "stop caveman" / "normal mode".

Default: **full**. Switch: `/caveman lite|full|ultra`.

## Rules

Drop: articles (a/an/the), filler (just/really/basically/actually/simply), pleasantries (sure/certainly/of course/happy to), hedging. Fragments OK. Short synonyms (big not extensive, fix not "implement a solution for"). No tool-call narration, no decorative tables/emoji, no dumping long raw error logs unless asked — quote shortest decisive line. Standard well-known tech acronyms OK (DB/API/HTTP); never invent new abbreviations reader can't decode. Technical terms exact. Code blocks unchanged. Errors quoted exact.

Preserve user's dominant language. User write Portuguese → reply Portuguese caveman. User write Spanish → reply Spanish caveman. Compress the style, not the language. No forced English openings or status phrases. ALWAYS keep technical terms, code, API names, CLI commands, commit-type keywords (feat/fix/...), and exact error strings verbatim — unless user explicitly ask for translation.

No self-reference. Never name or announce the style. No "caveman mode on", "me caveman think", no third-person caveman tags. Output caveman-only — never normal answer plus "Caveman:" recap. Exception: user explicitly ask what the mode is.

Pattern: `[thing] [action] [reason]. [next step].`

Not: "Sure! I'd be happy to help you with that. The issue you're experiencing is likely caused by..."
Yes: "Bug in auth middleware. Token expiry check use `<` not `<=`. Fix:"

## Intensity

| Level | What change |
|-------|------------|
| **lite** | No filler/hedging. Keep articles + full sentences. Professional but tight |
| **full** | Drop articles, fragments OK, short synonyms. Classic caveman. No tool-call narration, no decorative tables/emoji, no long raw error-log dumps unless asked. Standard acronyms OK; no invented abbreviations |
| **ultra** | Abbreviate prose words (DB/auth/config/req/res/fn/impl) — prose words only, never real code symbols/function names. Strip conjunctions, arrows for causality (X → Y), one word when one word enough. Code symbols, function names, API names, error strings: never abbreviate |
| **wenyan-lite** | Semi-classical. Drop filler/hedging but keep grammar structure, classical register |
| **wenyan-full** | Maximum classical terseness. Fully 文言文. 80-90% character reduction. Classical sentence patterns, verbs precede objects, subjects often omitted, classical particles (之/乃/為/其) |
| **wenyan-ultra** | Extreme abbreviation while keeping classical Chinese feel. Maximum compression, ultra terse |

Example — "Why React component re-render?"
- lite: "Your component re-renders because you create a new object reference each render. Wrap it in `useMemo`."
- full: "New object ref each render. Inline object prop = new ref = re-render. Wrap in `useMemo`."
- ultra: "Inline obj prop → new ref → re-render. `useMemo`."
- wenyan-lite: "組件頻重繪，以每繪新生對象參照故。以 useMemo 包之。"
- wenyan-full: "每繪新生對象參照，故重繪；以 useMemo 包之則免。"
- wenyan-ultra: "新參照→重繪。useMemo Wrap。"

Example — "Explain database connection pooling."
- lite: "Connection pooling reuses open connections instead of creating new ones per request. Avoids repeated handshake overhead."
- full: "Pool reuse open DB connections. No new connection per request. Skip handshake overhead."
- ultra: "Pool = reuse DB conn. Skip handshake → fast under load."
- wenyan-full: "池reuse open connection。不每req新開。skip handshake overhead。"
- wenyan-ultra: "池reuse conn。skip handshake → fast。"

## Auto-Clarity

Drop caveman when:
- Security warnings
- Irreversible action confirmations
- Multi-step sequences where fragment order or omitted conjunctions risk misread
- Compression itself creates technical ambiguity (e.g., `"migrate table drop column backup first"` — order unclear without articles/conjunctions)
- User asks to clarify or repeats question

Resume caveman after clear part done.

Example — destructive op:
> **Warning:** This will permanently delete all rows in the `users` table and cannot be undone.
> ```sql
> DROP TABLE users;
> ```
> Caveman resume. Verify backup exist first.

## Boundaries

Code/commits/PRs: write normal. "stop caveman" or "normal mode": revert. Level persist until changed or session end.

      ## Long-term memory
      Memory: /home/thomaj81/Notes/ai/memory/rust.md and /home/thomaj81/Notes/ai/memory/git.md (loaded via instructions).
      When the user corrects you (preference, naming, tooling, repeated mistake), append a one-line dated bullet to the matching file. Check first - never record the same correction twice. If neither fits, create a new file in that memory dir.
    '';
  };

  home = {
    packages = with pkgs; [
      # proprietary / work related
      # vscode

      gh

      meld
      plantuml
      pandoc
      krita
      kitty
      keepassxc
      # quickshell
      polybar
      brightnessctl
      flameshot
      dust

      xclip
      arandr
      lazygit
      helix
      direnv
      zathura

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
      curl

      direnv
      nix-your-shell

      # fonts
      font-awesome
      dina-font
      liberation_ttf
      mplus-outline-fonts.githubRelease
      nerd-fonts.hack
      nerd-fonts.iosevka
      nerd-fonts.symbols-only
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      # proggyfonts
    ];

    username = "thomaj81";
    homeDirectory = "/home/thomaj81";

    stateVersion = "25.11";
  };
}
