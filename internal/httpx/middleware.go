package httpx

import (
	"log/slog"
	"net/http"
	"runtime/debug"
	"time"

	"github.com/CAFxX/httpcompression"
	brotliprovider "github.com/CAFxX/httpcompression/contrib/andybalholm/brotli"
	zstdprovider "github.com/CAFxX/httpcompression/contrib/klauspost/zstd"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/klauspost/compress/zstd"
)

func Compression() (func(http.Handler) http.Handler, error) {
	zstdCompressor, err := zstdprovider.New(zstd.WithEncoderLevel(zstd.SpeedFastest))
	if err != nil {
		return nil, err
	}
	brotliCompressor, err := brotliprovider.New(brotliprovider.Options{Quality: 4})
	if err != nil {
		return nil, err
	}

	return httpcompression.Adapter(
		httpcompression.Compressor(zstdprovider.Encoding, 2, zstdCompressor),
		httpcompression.Compressor(brotliprovider.Encoding, 1, brotliCompressor),
		httpcompression.Prefer(httpcompression.PreferServer),
		httpcompression.MinSize(0),
		httpcompression.ContentTypes([]string{
			"application/atom+xml",
			"application/javascript",
			"application/json",
			"application/rss+xml",
			"application/xml",
			"image/svg+xml",
			"text/css",
			"text/event-stream",
			"text/html",
			"text/javascript",
			"text/plain",
		}, false),
	)
}

func RequestLogger(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			started := time.Now()
			wrapped := middleware.NewWrapResponseWriter(w, r.ProtoMajor)
			next.ServeHTTP(wrapped, r)
			logger.InfoContext(r.Context(), "request",
				"request_id", middleware.GetReqID(r.Context()),
				"method", r.Method,
				"path", r.URL.Path,
				"status", wrapped.Status(),
				"bytes", wrapped.BytesWritten(),
				"duration", time.Since(started),
			)
		})
	}
}

func Recoverer(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if recovered := recover(); recovered != nil {
					logger.ErrorContext(r.Context(), "panic serving request", "panic", recovered, "stack", string(debug.Stack()))
					w.Header().Set("Cache-Control", NoStore)
					Text(w, http.StatusInternalServerError, "Internal Server Error\n")
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}
