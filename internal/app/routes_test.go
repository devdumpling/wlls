package app

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/andybalholm/brotli"
	"github.com/devdumpling/wlls/content"
	"github.com/devdumpling/wlls/internal/about"
	"github.com/devdumpling/wlls/internal/assets"
	"github.com/devdumpling/wlls/internal/blog"
	"github.com/devdumpling/wlls/internal/httpx"
	markdownrenderer "github.com/devdumpling/wlls/internal/markdown"
	"github.com/devdumpling/wlls/internal/site"
	"github.com/klauspost/compress/zstd"
)

func TestRoutes(t *testing.T) {
	handler, bundle := testRoutes(t)
	tests := []struct {
		path        string
		status      int
		contentType string
		cache       string
		contains    string
	}{
		{"/", http.StatusOK, "text/html", httpx.DocumentCache, "AI Reflections: Fatigue"},
		{"/blog", http.StatusOK, "text/html", httpx.DocumentCache, "Writing"},
		{"/blog/devex", http.StatusOK, "text/html", httpx.DocumentCache, "my N=1 Experiment"},
		{"/about", http.StatusOK, "text/html", httpx.DocumentCache, "Roots"},
		{"/feed.xml", http.StatusOK, "application/rss+xml", httpx.DiscoveryCache, "<rss"},
		{"/sitemap.xml", http.StatusOK, "application/xml", httpx.DiscoveryCache, "/blog/devex"},
		{"/robots.txt", http.StatusOK, "text/plain", httpx.DiscoveryCache, "Sitemap:"},
		{"/healthz", http.StatusOK, "text/plain", httpx.NoStore, "ok\n"},
		{"/missing", http.StatusNotFound, "text/html", httpx.DocumentCache, "Page not found"},
		{"/static/" + bundle.Version() + "/css/site.css", http.StatusOK, "text/css", httpx.ImmutableCache, "@layer"},
		{"/images/avatars/dev.webp", http.StatusOK, "image/webp", httpx.StaticCache, ""},
	}
	for _, test := range tests {
		t.Run(test.path, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodGet, test.path, nil)
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, request)
			result := response.Result()
			defer result.Body.Close()
			body, err := io.ReadAll(result.Body)
			if err != nil {
				t.Fatal(err)
			}
			if result.StatusCode != test.status {
				t.Errorf("status = %d, want %d", result.StatusCode, test.status)
			}
			if got := result.Header.Get("Content-Type"); !strings.HasPrefix(got, test.contentType) {
				t.Errorf("Content-Type = %q, want prefix %q", got, test.contentType)
			}
			if got := result.Header.Get("Cache-Control"); got != test.cache {
				t.Errorf("Cache-Control = %q, want %q", got, test.cache)
			}
			if test.contains != "" && !strings.Contains(string(body), test.contains) {
				t.Errorf("body does not contain %q", test.contains)
			}
		})
	}
}

func TestCompressionNegotiation(t *testing.T) {
	handler, _ := testRoutes(t)
	tests := []struct {
		name     string
		accept   string
		encoding string
		decode   func(io.Reader) (io.Reader, error)
	}{
		{"zstd preferred", "br, zstd", "zstd", func(reader io.Reader) (io.Reader, error) { return zstd.NewReader(reader) }},
		{"brotli fallback", "br", "br", func(reader io.Reader) (io.Reader, error) { return brotli.NewReader(reader), nil }},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodGet, "/blog", nil)
			request.Header.Set("Accept-Encoding", test.accept)
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, request)
			result := response.Result()
			defer result.Body.Close()
			if got := result.Header.Get("Content-Encoding"); got != test.encoding {
				t.Fatalf("Content-Encoding = %q, want %q", got, test.encoding)
			}
			if !strings.Contains(result.Header.Get("Vary"), "Accept-Encoding") {
				t.Fatalf("Vary = %q", result.Header.Get("Vary"))
			}
			reader, err := test.decode(result.Body)
			if err != nil {
				t.Fatal(err)
			}
			body, err := io.ReadAll(reader)
			if err != nil {
				t.Fatal(err)
			}
			if !strings.Contains(string(body), "Writing") {
				t.Fatal("decoded response is not the blog index")
			}
		})
	}
}

func testRoutes(t *testing.T) (http.Handler, *assets.Bundle) {
	t.Helper()
	bundle, err := assets.New()
	if err != nil {
		t.Fatal(err)
	}
	renderer := markdownrenderer.New()
	posts, err := blog.Load(content.Files, renderer)
	if err != nil {
		t.Fatal(err)
	}
	aboutPage, err := about.Load(content.Files, renderer)
	if err != nil {
		t.Fatal(err)
	}
	baseURL, _ := url.Parse("https://wlls.dev")
	handler, err := Routes(RouteDependencies{
		Logger:  slog.New(slog.NewTextHandler(io.Discard, nil)),
		BaseURL: baseURL,
		Assets:  bundle,
		ViewAssets: site.Assets{
			Stylesheet: bundle.URL("css/site.css"),
			Datastar:   bundle.URL("js/datastar.js"),
			Favicon:    bundle.URL("favicon.svg"),
		},
		Posts: posts,
		About: aboutPage,
	})
	if err != nil {
		t.Fatal(err)
	}
	return handler, bundle
}
