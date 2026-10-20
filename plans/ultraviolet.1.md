# ultraviolet.1 — Program Status Protocol (OSC 7501) support

**Status:** Completed (2026-10-19)
**Shard:** `ultraviolet` (`github.com/dsisnero/ultraviolet`)
**Upstream reference:** `github.com/charmbracelet/ultraviolet` commit
`6b8d4baf91b4` (2026-10-08)
**Parity plan:** [`plans/parity.md`](parity.md) F7

This file used to describe an unimplemented feature. The shard-side work is now
complete; the remaining steps are downstream in `bubbletea.cr`.

## Resolution

| Requirement | Implementation |
|-------------|----------------|
| Program status types and aliases | `src/ultraviolet/program_status.cr` maps `ProgramStatus`, `ProgramState`, and `ProgramStatusKind` to the `ansi` shard |
| Encoding | `Ultraviolet.encode_program_status`; `nil` clears all records |
| Screen accessors | `TerminalScreen#set_program_status` / `#program_status` |
| Reset/restore | `reset` leaves the record in place; `restore` re-emits it |
| Decoder support reply | `src/ultraviolet/decoder.cr:778-779` maps `OSC 7501 ; ?` to `ProgramStatusSupportEvent` |
| Event alias | `ProgramStatusSupportEvent` is part of `Ultraviolet::Event` |
| Non-support reports | Other `OSC 7501` payloads remain `UnknownOscEvent` |

The implementation uses the `ansi` shard's program status encoder
(`Ansi.set_program_status`), refreshed to match upstream `ansi v0.11.9`
behavior.

## Verification

```bash
crystal spec spec/program_status_spec.cr
# 9 examples, 0 failures
```

The spec covers encoding, clear-by-id, aliases, typed decoder output, the
unknown-OSC fallback, screen accessors, and reset/restore re-emission.

## Downstream follow-up (`bubbletea.cr`)

These steps are outside this shard and remain tracked there:

1. Drop `src/tea/program_status.cr` and alias the shard types.
2. Translate `Ultraviolet::ProgramStatusSupportEvent` in
   `Program#translate_input_event`.
3. Delete the `UnknownOscEvent` fallback parser and its spec.

## Maintenance

`plans/parity.md` is the source of truth for status. When this feature changes,
update F7 there and this file in the same change. Do not leave a “What is
missing” section behind after implementation.
