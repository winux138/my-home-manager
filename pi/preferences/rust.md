# Rust Preferences

## CLI

- Use `clap` for CLI parsing. Do not hand-roll argument parsing for non-trivial CLIs.

## Logging and stubs

- Do not use `eprintln!` for application diagnostics/logging.
- Use `tracing` for logs/events.
- Use `todo!` only for intentionally unimplemented paths explicitly deferred by the approved slice.

## Errors and Result

- Use `thiserror` for typed library/crate errors.
- For `Result`, always spell both type parameters explicitly with `std::result::Result<T, E>`.
- Do not use a `Result` alias.
- Do not use stringly error types such as `std::result::Result<T, String>` unless the value is truly user-facing text and not an error model.

## JSON and serialization

- Never parse API/domain JSON into `serde_json::Value`.
- Always deserialize into concrete typed structs/enums.
- Dynamic API shapes should still be modeled with typed structs, maps, or enums.

## Types and API design

- Prefer modeling domain concepts with explicit types.
- Avoid raw `String`, `usize`, etc. when the value has domain meaning.
- Raw strings are acceptable at external boundaries, URLs/text bodies, and display text.
- Avoid public constructors for domain/provider values unless construction is truly part of the public API.
- Prefer dedicated APIs/adapters to construct domain values.
- Do not create getters just for the sake of getters.
- Use methods when fields have invariants, representation concerns, or future evolution needs.
- Public read-model structs can have public fields when they are simple output DTOs.
- Use `#[non_exhaustive]` only when it adds real value.
- If fields are private and constructors are crate-private, `#[non_exhaustive]` is usually unnecessary.

## Absence and enums

- Do not lazily use `Option<T>` when absence has meaningful domain semantics.
- Prefer exhaustive enums for meaningful absence.

Example:

```rust
enum CommentAuthor {
    Known(GitHubActor),
    Deleted,
}
```

## Mutability

- Avoid function parameters of type `&mut T` unless there is a very strong reason.
- Prefer owned values transformed into owned values, immutable borrows, or local internal mutability hidden inside a function.
- Local `mut` inside a function is fine when it keeps the public API simple.
- Pixel/canvas style code can justify `&mut` if documented.

## Function size

- Target functions at 40 lines or less.
- Exceptions should be rare and justified by readability.
- Split into helper functions/modules when a function grows.

## Traits and modularity

- Use traits when they express a real boundary, such as provider-owned concrete types consumed by core logic.
- Do not add traits before there is a real modularity/test/composition need.

## Async/runtime

- Avoid Tokio unless the need is strong.
- Prefer `async-io`/small runtime choices when async is needed.
- For blocking subprocess work, standard library threads are acceptable and often simpler.

## Derives

- Derive common useful traits when appropriate: `Debug`, `Clone`, `PartialEq`, `Eq`, `Hash`, `Ord` as needed.
- Do not derive traits blindly if they are not meaningful.

## Dates and time

- Prefer typed date/time values over raw timestamp strings.
- Use `jiff` for date/time handling when needed.
