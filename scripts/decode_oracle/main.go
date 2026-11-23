// Command decode_oracle writes the decode golden used by
// spec/decoder_golden_spec.cr.
//
// It decodes spec/fixtures/decode_inputs.txt with the *vendored* Go decoder, so
// the expected event for each input comes from upstream rather than from the
// Crystal port it is meant to check. Only the families that describe mouse
// tracking and terminal size reports are formatted; anything else is reported as
// "other" so a new input cannot silently pass.
//
// Regenerate with `make decode-golden`.
package main

import (
	"encoding/hex"
	"fmt"
	"os"
	"strconv"
	"strings"

	uv "github.com/charmbracelet/ultraviolet"
)

func signature(ev uv.Event) string {
	switch e := ev.(type) {
	case uv.MultiEvent:
		parts := make([]string, 0, len(e))
		for _, sub := range e {
			parts = append(parts, signature(sub))
		}
		return strings.Join(parts, " ")

	case uv.MouseClickEvent:
		return fmt.Sprintf("click:%d,%d,%d,%d", e.X, e.Y, int(e.Button), int(e.Mod))
	case uv.MouseReleaseEvent:
		return fmt.Sprintf("release:%d,%d,%d,%d", e.X, e.Y, int(e.Button), int(e.Mod))
	case uv.MouseWheelEvent:
		return fmt.Sprintf("wheel:%d,%d,%d,%d", e.X, e.Y, int(e.Button), int(e.Mod))
	case uv.MouseMotionEvent:
		return fmt.Sprintf("motion:%d,%d,%d,%d", e.X, e.Y, int(e.Button), int(e.Mod))
	case uv.PixelSizeEvent:
		return fmt.Sprintf("pixel:%d,%d", e.Width, e.Height)
	case uv.CellSizeEvent:
		return fmt.Sprintf("cell:%d,%d", e.Width, e.Height)
	case uv.WindowSizeEvent:
		return fmt.Sprintf("size:%d,%d", e.Width, e.Height)
	case uv.WindowOpEvent:
		args := make([]string, 0, len(e.Args))
		for _, a := range e.Args {
			args = append(args, strconv.Itoa(a))
		}
		return fmt.Sprintf("winop:%d:[%s]", e.Op, strings.Join(args, ","))
	case uv.UnknownCsiEvent:
		return "unknowncsi"
	default:
		return fmt.Sprintf("other:%T", ev)
	}
}

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: decode_oracle <inputs> <output>")
		os.Exit(2)
	}

	raw, err := os.ReadFile(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	var out strings.Builder
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		fields := strings.SplitN(line, "\t", 2)
		input, err := hex.DecodeString(fields[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "bad hex %q: %v\n", fields[0], err)
			os.Exit(1)
		}

		var sigs []string
		dec := new(uv.EventDecoder)
		buf := input
		for len(buf) > 0 {
			n, ev := dec.Decode(buf)
			if n == 0 || ev == nil {
				sigs = append(sigs, "unparsed")
				break
			}
			sigs = append(sigs, signature(ev))
			buf = buf[n:]
		}
		out.WriteString(fields[0])
		out.WriteString("\t")
		out.WriteString(strings.Join(sigs, " "))
		out.WriteString("\n")
	}

	if err := os.WriteFile(os.Args[2], []byte(out.String()), 0o644); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
