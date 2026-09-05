package health

import (
	"net/http"

	"github.com/devdumpling/wlls/internal/httpx"
)

type Handler struct{}

func (Handler) Live(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Cache-Control", httpx.NoStore)
	httpx.Text(w, http.StatusOK, "ok\n")
}

func (Handler) Ready(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Cache-Control", httpx.NoStore)
	httpx.Text(w, http.StatusOK, "ready\n")
}
