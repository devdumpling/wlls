package app

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/devdumpling/wlls/internal/assets"
	"github.com/devdumpling/wlls/internal/hello"
)

type App struct {
	server *http.Server
}

func New(addr string) *App {
	return &App{
		server: &http.Server{
			Addr:              addr,
			Handler:           Routes(),
			ReadHeaderTimeout: 5 * time.Second,
			IdleTimeout:       60 * time.Second,
		},
	}
}

func Routes() http.Handler {
	helloHandler := hello.Handler{}
	mux := http.NewServeMux()

	mux.Handle("GET /static/", http.StripPrefix("/static/", assets.Handler()))
	mux.HandleFunc("GET /healthz", health)
	mux.HandleFunc("GET /{$}", helloHandler.Page)
	mux.HandleFunc("POST /hello", helloHandler.Greet)

	return mux
}

func (a *App) Run(ctx context.Context) error {
	errs := make(chan error, 1)
	go func() {
		slog.Info("server started", "addr", a.server.Addr)
		errs <- a.server.ListenAndServe()
	}()

	select {
	case err := <-errs:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := a.server.Shutdown(shutdownCtx); err != nil {
			return err
		}

		err := <-errs
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	}
}

func health(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok\n"))
}
