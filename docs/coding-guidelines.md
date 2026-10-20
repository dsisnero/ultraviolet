# Coding Guidelines

## Behavior first

- `vendor/ultraviolet/` is the source of truth. Match Go behavior before
  choosing a Crystal-idiomatic shape.
- Port behavior, not formatting or naming style.
- Preserve public API names and semantics where Crystal allows it. Document
  intentional divergences in `plans/parity.md`.

## Crystal style

- Follow the Crystal formatter. Use `make format` before committing.
- Use two-space indentation, `snake_case` methods and variables, `CamelCase`
  types and modules, and `SCREAMING_SNAKE_CASE` only for true constants when it
  matches the surrounding file.
- Prefer `property?` for boolean readers.
- Use `Nil` returns for void operations and avoid raising from terminal control
  methods unless the Go API also reports an error.
- Keep shard-specific compatibility code isolated (for example,
  `ansi_compat.cr` or `program_status.cr`) instead of spreading shims through
  core modules.

## Tests

- Add or port the upstream test before changing behavior.
- Never weaken assertions, skip cases, or edit fixtures merely to make a spec
  green.
- Put pure unit behavior in the matching `spec/*_spec.cr`; keep interactive
  terminal cases under `spec/manual/` when they cannot run unattended.

## Dependencies

- Do not edit `lib/` or `vendor/` as part of a feature. Update them explicitly
  through `shards update` or the vendor-refresh process.
- Prefer an existing maintained shard over a new local port when the API and
  behavior match the Go dependency.
