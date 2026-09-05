package app

import (
	"log/slog"
	"net/http"
	"net/url"

	"github.com/devdumpling/wlls/internal/about"
	"github.com/devdumpling/wlls/internal/assets"
	"github.com/devdumpling/wlls/internal/blog"
	"github.com/devdumpling/wlls/internal/health"
	"github.com/devdumpling/wlls/internal/httpx"
	"github.com/devdumpling/wlls/internal/site"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

type RouteDependencies struct {
	Logger     *slog.Logger
	BaseURL    *url.URL
	Assets     *assets.Bundle
	ViewAssets site.Assets
	Posts      *blog.Repository
	About      about.Page
}

func Routes(dependencies RouteDependencies) (http.Handler, error) {
	compress, err := httpx.Compression()
	if err != nil {
		return nil, err
	}

	blogHandler := blog.NewHandler(dependencies.Posts, dependencies.BaseURL, dependencies.ViewAssets, dependencies.Logger)
	aboutHandler := about.NewHandler(dependencies.About, dependencies.BaseURL, dependencies.ViewAssets, dependencies.Logger)
	healthHandler := health.Handler{}
	assetHandler := dependencies.Assets.Handler()

	router := chi.NewRouter()
	router.Use(middleware.RequestID)
	router.Use(middleware.GetHead)
	router.Use(httpx.RequestLogger(dependencies.Logger))
	router.Use(compress)
	router.Use(httpx.Recoverer(dependencies.Logger))
	router.Use(securityHeaders)

	router.Get("/", blogHandler.Latest)
	router.Get("/blog", blogHandler.Index)
	router.Get("/blog/{slug}", blogHandler.Post)
	router.Get("/about", aboutHandler.ServeHTTP)
	router.Get("/feed.xml", blogHandler.Feed)
	router.Get("/rss.xml", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", httpx.DiscoveryCache)
		http.Redirect(w, r, "/feed.xml", http.StatusPermanentRedirect)
	})
	router.Get("/sitemap.xml", blogHandler.Sitemap)
	router.Get("/robots.txt", blogHandler.Robots)
	router.Get("/healthz", healthHandler.Live)
	router.Get("/readyz", healthHandler.Ready)

	fingerprintedPrefix := "/static/" + dependencies.Assets.Version()
	router.Handle(fingerprintedPrefix+"/*", httpx.CacheControl(httpx.ImmutableCache, http.StripPrefix(fingerprintedPrefix+"/", assetHandler)))
	for _, prefix := range []string{"/images/", "/fonts/"} {
		router.Handle(prefix+"*", httpx.CacheControl(httpx.StaticCache, assetHandler))
	}
	router.Handle("/favicon.svg", httpx.CacheControl(httpx.StaticCache, assetHandler))

	router.NotFound(blogHandler.NotFound)
	router.MethodNotAllowed(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Allow", http.MethodGet+", "+http.MethodHead)
		w.Header().Set("Cache-Control", httpx.NoStore)
		httpx.Text(w, http.StatusMethodNotAllowed, "Method Not Allowed\n")
	})
	return router, nil
}

func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		next.ServeHTTP(w, r)
	})
}
