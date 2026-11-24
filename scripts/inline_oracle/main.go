// Command inline_oracle writes the inline cursor-movement golden used by
// spec/terminal_renderer_inline_spec.cr.
//
// It drives the *vendored* Go renderer through the inline ("relative cursor")
// and fullscreen movement paths and prints the bytes each step writes, so the
// expected sequences come from upstream rather than from the Crystal port it is
// meant to check.
//
// Two things are pinned here:
//
//   - An inline downward move must be made with newlines, not a cursor-down
//     sequence, because only a newline scrolls the screen to make room. How far
//     the renderer has already scrolled must not change that; a remembered
//     scroll height used to, and it silently switched long jumps to `CSI n B`.
//
//   - A frame that fills its last column leaves the cursor pending wrap (the
//     "phantom" cell), and the next frame has to cancel it with CR before it
//     steps anywhere, or the move starts from the wrapped column.
//
// Regenerate the golden with `make inline-golden`.
package main

import (
	"bytes"
	"fmt"
	"os"
	"strings"

	uv "github.com/charmbracelet/ultraviolet"
)

const (
	width  = 70
	height = 2
)

// moveCase is one golden row. Either it replays cursor moves (`moves`), or it
// renders whole frames of the given text (`frames`, one cell per rune, wrapped
// at the buffer width).
type moveCase struct {
	name       string
	fullscreen bool
	moves      [][2]int
	frames     []string
}

var moveCases = []moveCase{
	{name: "inline down 1", moves: [][2]int{{0, 1}}},
	{name: "inline down 6", moves: [][2]int{{0, 6}}},
	{
		name:  "inline down 6, up 4, down 6",
		moves: [][2]int{{0, 6}, {0, 2}, {0, 6}},
	},
	{name: "inline right 6", moves: [][2]int{{6, 0}}},
	{name: "fullscreen down 2", fullscreen: true, moves: [][2]int{{0, 2}}},
	{name: "fullscreen down 6", fullscreen: true, moves: [][2]int{{0, 6}}},
	{
		name: "inline frames: full row, then one change",
		frames: []string{
			"0123456789012345678901234567890123456789012345678901234567890123456789",
			"0123456789012345678901234567890123x456789012345678901234567890123456789",
		},
	},
}

// escape renders bytes the way the Crystal spec writes them: escapes and
// control bytes in \xNN form so a row stays on one line.
func escape(b []byte) string {
	var sb strings.Builder
	for _, c := range b {
		switch {
		case c == 0x1b:
			sb.WriteString(`\x1b`)
		case c < 0x20 || c == 0x7f:
			fmt.Fprintf(&sb, "\\x%02x", c)
		default:
			sb.WriteByte(c)
		}
	}
	return sb.String()
}

// fill writes one cell per rune, wrapping at the buffer width, the way an
// application's view lands on the render buffer.
func fill(buf *uv.RenderBuffer, s string) {
	x, y := 0, 0
	for _, r := range s {
		buf.SetCell(x, y, &uv.Cell{Content: string(r), Width: 1})
		x++
		if x >= buf.Width() {
			x = 0
			y++
		}
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: inline_oracle <output.tsv>")
		os.Exit(2)
	}

	var out strings.Builder
	for _, c := range moveCases {
		var buf bytes.Buffer
		r := uv.NewTerminalRenderer(&buf, []string{"TERM=xterm-256color"})
		r.SetFullscreen(c.fullscreen)
		r.SetRelativeCursor(!c.fullscreen)

		var steps []string

		if len(c.frames) > 0 {
			for _, frame := range c.frames {
				render := uv.NewRenderBuffer(width, height)
				fill(render, frame)
				r.Render(render)
				_ = r.Flush()
				steps = append(steps, escape(buf.Bytes()))
				buf.Reset()
			}

			fmt.Fprintf(&out, "%s\trender\t%s\t%s\n", c.name,
				strings.Join(c.frames, "|"), strings.Join(steps, "|"))
			continue
		}

		// Start at the origin so the first move is a pure vertical or
		// horizontal one, as it is mid-frame.
		r.SetPosition(0, 0)

		var moves []string
		for _, m := range c.moves {
			r.MoveTo(m[0], m[1])
			_ = r.Flush()
			steps = append(steps, escape(buf.Bytes()))
			moves = append(moves, fmt.Sprintf("%d,%d", m[0], m[1]))
			buf.Reset()
		}

		mode := "inline"
		if c.fullscreen {
			mode = "fullscreen"
		}
		fmt.Fprintf(&out, "%s\t%s\t%s\t%s\n", c.name, mode,
			strings.Join(moves, ";"), strings.Join(steps, "|"))
	}

	if err := os.WriteFile(os.Args[1], []byte(out.String()), 0o644); err != nil {
		fmt.Fprintln(os.Stderr, "write:", err)
		os.Exit(1)
	}
	fmt.Printf("wrote %s (%d cases)\n", os.Args[1], len(moveCases))
}
