# Workflow Preferences

## Collaboration

- Be concise by default.
- Avoid long plans, exhaustive tables, or broad option lists unless the user asks for them.
- When asked for the next step, give one clear next step instead of a menu.
- Keep the user tightly involved in architecture, dependency, and stack choices.
- Propose significant design choices before implementing them.
- Do not implement broad high-level ideas without narrowing scope first.
- Challenge weak ideas and vague plans early.
- Roasting/stress-testing is welcome when the user starts from a high-level or under-specified idea.
- If a planned step is only an intermediate throwaway, do not do it.
- Prefer incremental changes that are useful on their own.
- Never infer intent when scope or workflow is ambiguous. Ask explicitly before choosing, every time.
- For every new PR, ask whether it must be standalone, dependent-but-unstacked, or part of a GitHub stack. Never infer this from branch ancestry, current stack context, or prior requests.

## Change size

- Keep code-related implementation sessions small.
- Soft cap: 200 changed review-relevant lines.
- Hard cap: 300 changed review-relevant lines.
- Review-relevant means hand-written code, config, and docs changed for the approved slice.
- Lockfiles and backlog/planning files do not count toward this review-size budget.
- If a change is larger, split it into meaningful slices.

## Git, GitHub, and repository mutations

- Never modify repository files, the Git working tree or index, refs, history, remotes, PR metadata, or stack metadata without explicit user approval for that exact mutation or clearly described batch.
- Ask before every edit, stage, commit, amend, stash, checkout, branch create/rename/delete, reset, rebase, merge, cherry-pick, push, force-push, tag operation, PR create/edit/close, or stack create/link/modify/unstack operation.
- Approval applies only to the named action or batch and does not carry forward to later actions or turns.
- A request to investigate, diagnose, review, create a PR, or implement a feature is not implicit authorization for repository or Git/GitHub mutations.
- Read-only inspection such as status, log, diff, file reads, and PR reads is allowed without mutation approval.
- Never move changesets, retitle related PRs, or alter PR relationships unless the user explicitly requests that exact operation.
- In flake repositories, report that untracked source files must be staged before build or switch.

## Backlog and planning

- For a new project, create a backlog/planning folder with markdown entries as scope and decisions evolve.
- For an existing project, reuse the existing backlog/planning structure instead of inventing a new one.

## Files and structure

- Keep files small, concise, and human-readable.
- Split into modules when it improves clarity.
- Avoid repeated prefixes in function names when a module would express the context better.
- Do not create empty crates, files, or modules in advance.
- Create crates/files/modules just in time, when real code needs them.

## Dependencies

- Bring dependencies only when the current approved slice needs them.
- For each new dependency, be able to justify why it is needed now.
- Avoid overengineering and do not add dependencies for convenience only.

## Tests

- Write tests only when they provide meaningful confidence.
- Do not test just for the sake of testing.
- Default: test through public API from the crate's `tests/` directory.
- Exception: use source-local `mod tests` only for complex/private logic where public-API tests would be awkward or unclear.
- If using source-local tests, document why that exception is justified.

## Formatting and text

- Follow the ASCII-only rule in `general.md`.

## Shell and tools

- Do not over-rely on shell commands in application code.
- If an external CLI is needed, isolate it behind a crate/API so callers do not know about shell commands.

## CPU headroom

- For expensive local builds/tests/checks, leave at least 2 CPU cores unused when more than 2 exist; otherwise use 1 job.
- For Rust, prefer:

```bash
cores=$(nproc); CARGO_BUILD_JOBS=$(( cores > 2 ? cores - 2 : 1 )) cargo check
```

- For Nix build limits, follow `nix.md`.
