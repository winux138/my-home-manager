# Global Agent Instructions

## Default Response Style: Simple English

From the first response, read and apply `skills/simple-english/SKILL.md` relative to this file.
Keep it active until the user says "stop simple-english" or "normal mode". Use normal clarity for
security warnings, irreversible confirmations, or when simple English creates ambiguity.

## Default Coding Approach: Ponytail

For every coding task, read and apply `skills/ponytail/SKILL.md` relative to this file before
planning or editing.

## Preserve knowledge in types

Parse loose input into values whose types encode the required rules.
Return the value or a meaningful error.
Make consuming code require that value instead of trusting an earlier true-or-false check.

Use enums (types with named alternatives) to represent choices.
Choose collections that encode the required rules.
Use opaque types (types with hidden internals) to prevent callers from bypassing those rules.
Create them only through checked constructors (functions that enforce the rules before creating values).

Convert input near its entry point, or in the branch where a stronger requirement first applies.

## User Preferences

Read before every task:
- `preferences/general.md` and `preferences/workflow.md` relative to this file.
- For Rust or Nix, also read `preferences/rust.md` or `preferences/nix.md`.

Rules:
- Task-specific files refine general/workflow. Ask on conflict.
- Preferences override Ponytail.
- "Runnable check" means smallest meaningful check using existing test conventions.
- Ask before violating preferences for project rules.

## Tooling: search and file lookup

Pi's built-in `grep` tool runs ripgrep, and the built-in `find` tool runs fd. Prefer those tools over
shell equivalents - they add truncation limits and structured output.

- Content search: built-in `grep` tool. In `bash`, use `rg`. Do not use shell `grep -r`, `egrep`, or
  `find ... | xargs grep`.
- File lookup: built-in `find` tool. In `bash`, use `fd`. Do not use shell `find` to walk trees.
- Pipeline filtering of command output (`ps aux | grep x`, `env | grep PI_`) stays `grep`. This rule
  covers file-tree search only.
- Built-in tool contract: hidden files ARE searched (both pass `--hidden`), `.gitignore` IS respected,
  and there is no parameter to override it. When the target may be gitignored (`target/`,
  `node_modules/`, `dist/`, build output, vendored deps), that is the one case to drop to `bash`:
  `rg -uu pattern` (add a third `-u` to include binary files) or `fd -HI name`.
- Bare CLI `rg`/`fd` in `bash` skip hidden files too, unlike `grep -r`/`find`; `-uu` / `-HI` cover both
  axes.
- Probe before use, since Debian/Ubuntu ship fd as `fdfind` and pi's auto-downloaded binaries are not
  on `PATH`: `command -v rg`, `command -v fd || command -v fdfind`.
- Concrete forms: `rg -n pattern`, `rg -l --glob '*.toml' pattern`, `fd -e rs`, `fd -t f name`.
- Shell `grep`/`find` are acceptable only when `rg`/`fd` are absent, or in scripts that must stay
  POSIX-portable - in that case `find ... -exec grep ...` is the intended form and overrides the
  `find`-piping ban above.
