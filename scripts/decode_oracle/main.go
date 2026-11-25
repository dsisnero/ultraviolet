// Command decode_oracle writes the decode golden used by
// spec/decoder_golden_spec.cr.
//
// It decodes spec/fixtures/decode_inputs.txt with the *vendored* Go decoder, so
// the expected event for each input comes from upstream rather than from the
// Crystal port it is meant to check. The formatted families are the ones the
// port models: keys, mouse, paste, focus, terminal responses and size reports.
// Anything else is reported as "other" so a new input cannot silently pass.
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
	case uv.KeyPressEvent:
		return keySignature(uv.Key(e))
	case uv.KeyReleaseEvent:
		// The port aliases both to one Key struct, so press and release are
		// indistinguishable there and the golden must not distinguish them.
		return keySignature(uv.Key(e))
	case uv.UnknownEvent:
		return fmt.Sprintf("unknown:%x", []byte(e))
	case uv.UnknownSs3Event:
		return fmt.Sprintf("unknownss3:%x", []byte(e))
	case uv.UnknownOscEvent:
		return fmt.Sprintf("unknownosc:%x", []byte(e))
	case uv.UnknownDcsEvent:
		return fmt.Sprintf("unknowndcs:%x", []byte(e))
	case uv.UnknownSosEvent:
		return fmt.Sprintf("unknownsos:%x", []byte(e))
	case uv.UnknownPmEvent:
		return fmt.Sprintf("unknownpm:%x", []byte(e))
	case uv.UnknownApcEvent:
		return fmt.Sprintf("unknownapc:%x", []byte(e))
	case uv.FocusEvent:
		return "focus"
	case uv.BlurEvent:
		return "blur"
	case uv.PasteStartEvent:
		return "pastestart"
	case uv.PasteEndEvent:
		return "pasteend"
	case uv.PasteEvent:
		return fmt.Sprintf("paste:%x", []byte(e.Content))
	case uv.CursorPositionEvent:
		return fmt.Sprintf("cursor:%d,%d", e.X, e.Y)
	case uv.TerminalVersionEvent:
		return fmt.Sprintf("version:%x", []byte(e.Name))
	case uv.ModifyOtherKeysEvent:
		return fmt.Sprintf("modifyotherkeys:%d", e.Mode)
	case uv.KeyboardEnhancementsEvent:
		return fmt.Sprintf("keyboardenhancements:%d", e.Flags)
	case uv.KittyGraphicsEvent:
		return fmt.Sprintf("kittygraphics:%x", e.Payload)
	case uv.PrimaryDeviceAttributesEvent:
		// The port aliases primary and secondary attributes to one Array(Int32),
		// so the golden must not distinguish them.
		return fmt.Sprintf("da:[%s]", intList(e))
	case uv.SecondaryDeviceAttributesEvent:
		return fmt.Sprintf("da:[%s]", intList(e))
	case uv.TertiaryDeviceAttributesEvent:
		return fmt.Sprintf("da3:%x", []byte(string(e)))
	case uv.ModeReportEvent:
		return fmt.Sprintf("modereport:%d,%d", int(e.Mode.Mode()), int(e.Value))
	case uv.DarkColorSchemeEvent:
		return "darkscheme"
	case uv.LightColorSchemeEvent:
		return "lightscheme"
	case uv.UnknownCsiEvent:
		return "unknowncsi"
	default:
		return fmt.Sprintf("other:%T", ev)
	}
}

func keySignature(k uv.Key) string {
	return fmt.Sprintf("key:%d,%d,%d,%d,%t:%x",
		k.Code, int(k.Mod), k.ShiftedCode, k.BaseCode, k.IsRepeat, []byte(k.Text))
}

func intList(values []int) string {
	parts := make([]string, 0, len(values))
	for _, v := range values {
		parts = append(parts, strconv.Itoa(v))
	}
	return strings.Join(parts, ",")
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
