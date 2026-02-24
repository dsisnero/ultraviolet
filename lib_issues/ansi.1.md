# Missing: `Ansi.truncate` function

## Problem

The Crystal port of ultraviolet uses `Ansi.truncate` in `src/ultraviolet/terminal.cr:418` but the function is not implemented in the `ansi` shard (or local `Ansi` module). The current implementation in `src/ultraviolet/ansi.cr` is a placeholder that doesn't correctly handle ANSI escape sequences or grapheme clusters.

## Go Reference

The Go code imports `github.com/charmbracelet/x/ansi` and calls `ansi.Truncate(line, t.size.Width, "")`. The function signature in Go is:

```go
func Truncate(s string, maxWidth int, suffix string) string
```

## Required Behavior

1. **ANSI Code Preservation**: The function must preserve ANSI escape sequences in the output while ignoring them for width calculation.
2. **Grapheme Cluster Awareness**: Must handle multi-codepoint grapheme clusters (e.g., emoji, combining characters) as single visual units.
3. **Width Calculation**: Use proper Unicode character width (east Asian width, emoji presentation, etc.).
4. **Suffix Handling**: Append suffix if truncation occurs, ensuring total width doesn't exceed maxWidth.
5. **Empty String Handling**: Return suffix if maxWidth <= suffix width.
6. **Zero/ Negative Width**: Handle edge cases appropriately.

## Current Implementation Issues

The current placeholder in `src/ultraviolet/ansi.cr`:
- Uses `each_char` which breaks grapheme clusters
- Doesn't preserve ANSI escape sequences
- May not handle zero-width joiners, variation selectors, etc.
- Doesn't strip ANSI codes before width calculation (though `Ultraviolet.strip_ansi` exists)

## Dependencies

The ultraviolet project already uses:
- `require "ansi"` (the crystal-ansi shard)
- `UnicodeCharWidth.width()` for character width

## Suggested Implementation Approach

1. Use `UnicodeCharWidth.width()` for character width calculation
2. Use `String#each_grapheme` for proper grapheme cluster iteration
3. Parse and preserve ANSI escape sequences (or strip them for measurement only)
4. Match Go's exact behavior by examining the source implementation

## Testing

Need to verify against Go's test cases. The function should produce identical output for the same inputs.

## Priority

High - This affects terminal rendering when lines exceed screen width.

## Related Files

- `src/ultraviolet/ansi.cr` - Current placeholder
- `src/ultraviolet/terminal.cr:418` - Usage
- `ultraviolet_go/terminal.go:444` - Go reference