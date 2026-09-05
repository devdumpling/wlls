package httpx

import "net/http"

const (
	DocumentCache  = "public, max-age=300, s-maxage=3600, stale-while-revalidate=86400"
	DiscoveryCache = "public, max-age=3600, s-maxage=86400, stale-while-revalidate=86400"
	ImmutableCache = "public, max-age=31536000, immutable"
	StaticCache    = "public, max-age=3600, stale-while-revalidate=86400"
	NoStore        = "no-store"
	StreamCache    = "no-cache, no-store, no-transform"
)

func CacheControl(value string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", value)
		next.ServeHTTP(w, r)
	})
}

func Text(w http.ResponseWriter, status int, value string) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(status)
	_, _ = w.Write([]byte(value))
}
