package about

import (
	"log/slog"
	"net/http"
	"net/url"

	"github.com/devdumpling/wlls/internal/httpx"
	"github.com/devdumpling/wlls/internal/site"
)

type Handler struct {
	page    Page
	baseURL *url.URL
	assets  site.Assets
	logger  *slog.Logger
}

func NewHandler(page Page, baseURL *url.URL, assets site.Assets, logger *slog.Logger) *Handler {
	return &Handler{page: page, baseURL: baseURL, assets: assets, logger: logger}
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", httpx.DocumentCache)
	metadata := site.Metadata{
		Title:       "About | wlls.dev",
		Description: h.page.Description,
		Canonical:   site.Canonical(h.baseURL, "/about"),
		Type:        "website",
	}
	if err := httpx.Render(w, r, http.StatusOK, site.Document(metadata, h.assets, View(h.page))); err != nil {
		httpx.ServerError(h.logger, w, r, err)
	}
}
