package markdown

import (
	"bytes"
	"fmt"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/extension"
	"github.com/yuin/goldmark/parser"
)

type Renderer struct {
	markdown goldmark.Markdown
}

func New() Renderer {
	return Renderer{markdown: goldmark.New(
		goldmark.WithExtensions(extension.GFM, extension.Footnote),
		goldmark.WithParserOptions(parser.WithAutoHeadingID()),
	)}
}

func (r Renderer) Render(source []byte) (string, error) {
	var output bytes.Buffer
	if err := r.markdown.Convert(source, &output); err != nil {
		return "", fmt.Errorf("render markdown: %w", err)
	}
	return output.String(), nil
}
