package httpx

import (
	"log/slog"
	"net/http"
)

func ServerError(logger *slog.Logger, w http.ResponseWriter, r *http.Request, err error) {
	logger.ErrorContext(r.Context(), "request failed", "error", err, "method", r.Method, "path", r.URL.Path)
	w.Header().Set("Cache-Control", NoStore)
	Text(w, http.StatusInternalServerError, "Internal Server Error\n")
}
