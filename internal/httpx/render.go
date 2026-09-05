package httpx

import (
	"bytes"
	"fmt"
	"net/http"

	"github.com/a-h/templ"
)

func Render(w http.ResponseWriter, r *http.Request, status int, component templ.Component) error {
	var body bytes.Buffer
	if err := component.Render(r.Context(), &body); err != nil {
		return fmt.Errorf("render component: %w", err)
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	if _, err := body.WriteTo(w); err != nil {
		return fmt.Errorf("write rendered component: %w", err)
	}
	return nil
}
