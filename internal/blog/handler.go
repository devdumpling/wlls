package blog

import (
	"encoding/xml"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"strings"

	"github.com/devdumpling/wlls/internal/httpx"
	"github.com/devdumpling/wlls/internal/site"
	"github.com/go-chi/chi/v5"
)

type Handler struct {
	repository *Repository
	baseURL    *url.URL
	assets     site.Assets
	logger     *slog.Logger
}

func NewHandler(repository *Repository, baseURL *url.URL, assets site.Assets, logger *slog.Logger) *Handler {
	return &Handler{repository: repository, baseURL: baseURL, assets: assets, logger: logger}
}

func (h *Handler) Latest(w http.ResponseWriter, r *http.Request) {
	h.renderPost(w, r, h.repository.Latest(), true, "/")
}

func (h *Handler) Index(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", httpx.DocumentCache)
	metadata := site.Metadata{
		Title:       "Writing | wlls.dev",
		Description: "Devon Wells",
		Canonical:   site.Canonical(h.baseURL, "/blog"),
		Type:        "website",
	}
	if err := httpx.Render(w, r, http.StatusOK, site.Document(metadata, h.assets, Index(h.repository.Published()))); err != nil {
		httpx.ServerError(h.logger, w, r, err)
	}
}

func (h *Handler) Post(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	post, err := h.repository.Find(slug)
	if errors.Is(err, ErrNotFound) {
		h.NotFound(w, r)
		return
	}
	if err != nil {
		httpx.ServerError(h.logger, w, r, err)
		return
	}
	h.renderPost(w, r, post, false, "/blog/"+post.Slug)
}

func (h *Handler) NotFound(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", httpx.DocumentCache)
	metadata := site.Metadata{
		Title:       "Page not found | wlls.dev",
		Description: "The requested page could not be found.",
		Type:        "website",
		NoIndex:     true,
	}
	if err := httpx.Render(w, r, http.StatusNotFound, site.Document(metadata, h.assets, site.NotFound())); err != nil {
		httpx.ServerError(h.logger, w, r, err)
	}
}

func (h *Handler) Feed(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Cache-Control", httpx.DiscoveryCache)
	w.Header().Set("Content-Type", "application/rss+xml; charset=utf-8")
	_, _ = w.Write([]byte(h.feed()))
}

func (h *Handler) Sitemap(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Cache-Control", httpx.DiscoveryCache)
	w.Header().Set("Content-Type", "application/xml; charset=utf-8")
	_, _ = w.Write([]byte(h.sitemap()))
}

func (h *Handler) Robots(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Cache-Control", httpx.DiscoveryCache)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	_, _ = fmt.Fprintf(w, "User-agent: *\nAllow: /\nSitemap: %s\n", site.Canonical(h.baseURL, "/sitemap.xml"))
}

func (h *Handler) renderPost(w http.ResponseWriter, r *http.Request, post Post, latest bool, canonicalPath string) {
	w.Header().Set("Cache-Control", httpx.DocumentCache)
	metadata := site.Metadata{
		Title:       post.Title + " | wlls.dev",
		Description: post.Description,
		Canonical:   site.Canonical(h.baseURL, canonicalPath),
		Type:        "article",
	}
	if err := httpx.Render(w, r, http.StatusOK, site.Document(metadata, h.assets, Article(post, latest))); err != nil {
		httpx.ServerError(h.logger, w, r, err)
	}
}

func (h *Handler) feed() string {
	posts := h.repository.Published()
	var body strings.Builder
	body.WriteString(`<?xml version="1.0" encoding="UTF-8"?>`)
	body.WriteString(`<rss version="2.0"><channel><title>wlls.dev</title><description>Devon Wells</description><link>`)
	body.WriteString(xmlText(site.Canonical(h.baseURL, "/")))
	body.WriteString(`</link><atom:link xmlns:atom="http://www.w3.org/2005/Atom" href="`)
	body.WriteString(xmlText(site.Canonical(h.baseURL, "/feed.xml")))
	body.WriteString(`" rel="self" type="application/rss+xml"/>`)
	for _, post := range posts {
		link := site.Canonical(h.baseURL, "/blog/"+post.Slug)
		body.WriteString(`<item><title>`)
		body.WriteString(xmlText(post.Title))
		body.WriteString(`</title><description>`)
		body.WriteString(xmlText(post.Description))
		body.WriteString(`</description><link>`)
		body.WriteString(xmlText(link))
		body.WriteString(`</link><guid isPermaLink="true">`)
		body.WriteString(xmlText(link))
		body.WriteString(`</guid><pubDate>`)
		body.WriteString(post.PublishedAt.Format("Mon, 02 Jan 2006 15:04:05 GMT"))
		body.WriteString(`</pubDate></item>`)
	}
	body.WriteString(`</channel></rss>`)
	return body.String()
}

func (h *Handler) sitemap() string {
	var body strings.Builder
	body.WriteString(`<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`)
	for _, path := range []string{"/", "/blog", "/about"} {
		body.WriteString(`<url><loc>`)
		body.WriteString(xmlText(site.Canonical(h.baseURL, path)))
		body.WriteString(`</loc></url>`)
	}
	for _, post := range h.repository.Published() {
		body.WriteString(`<url><loc>`)
		body.WriteString(xmlText(site.Canonical(h.baseURL, "/blog/"+post.Slug)))
		body.WriteString(`</loc><lastmod>`)
		body.WriteString(post.PublishedAt.Format("2006-01-02"))
		body.WriteString(`</lastmod></url>`)
	}
	body.WriteString(`</urlset>`)
	return body.String()
}

func xmlText(value string) string {
	var output strings.Builder
	_ = xml.EscapeText(&output, []byte(value))
	return output.String()
}
