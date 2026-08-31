package main

import (
	"context"
	"embed"
	"errors"
	"io/fs"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"time"

	"github.com/devdumpling/wlls/internal/views"
	"github.com/starfederation/datastar-go/datastar"
)

//go:embed static
var staticFiles embed.FS

func main() {
	if err := run(); err != nil {
		slog.Error("server failed", "error", err)
		os.Exit(1)
	}
}

func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	staticFS, err := fs.Sub(staticFiles, "static")
	if err != nil {
		return err
	}

	mux := http.NewServeMux()
	mux.Handle("GET /static/", http.StripPrefix("/static/", http.FileServer(http.FS(staticFS))))
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("GET /", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		if err := views.Page().Render(r.Context(), w); err != nil {
			slog.Error("render failed", "error", err)
		}
	})
	mux.HandleFunc("POST /hello", func(w http.ResponseWriter, r *http.Request) {
		sse := datastar.NewSSE(w, r)
		sse.PatchElements(`<p id="greeting" role="status">Hello from a Datastar SSE response.</p>`)
	})

	addr := os.Getenv("WLLS_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}

	srv := &http.Server{Addr: addr, Handler: mux}
	errs := make(chan error, 1)
	go func() {
		slog.Info("server started", "addr", addr)
		errs <- srv.ListenAndServe()
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		return srv.Shutdown(shutdownCtx)
	case err := <-errs:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	}
}
