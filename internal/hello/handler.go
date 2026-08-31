package hello

import (
	"log/slog"
	"net/http"

	"github.com/starfederation/datastar-go/datastar"
)

type Handler struct{}

func (Handler) Page(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := Page().Render(r.Context(), w); err != nil {
		slog.Error("render hello page", "error", err)
	}
}

func (Handler) Greet(w http.ResponseWriter, r *http.Request) {
	sse := datastar.NewSSE(w, r)
	if err := sse.PatchElementTempl(Greeting("Hello from a Datastar SSE response.")); err != nil {
		slog.Error("patch greeting", "error", err)
	}
}
