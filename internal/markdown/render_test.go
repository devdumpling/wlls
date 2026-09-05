package markdown

import (
	"strings"
	"testing"
)

func TestRenderProducesOrdinaryMarkdownAndSkipsRawHTML(t *testing.T) {
	rendered, err := New().Render([]byte("## Heading\n\nA **strong** link to [Go](https://go.dev).\n\n<script>alert('no')</script>\n"))
	if err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{`id="heading"`, "<strong>strong</strong>", `href="https://go.dev"`} {
		if !strings.Contains(rendered, expected) {
			t.Errorf("rendered Markdown does not contain %q: %s", expected, rendered)
		}
	}
	if strings.Contains(rendered, "<script") {
		t.Fatalf("raw HTML was rendered: %s", rendered)
	}
}
