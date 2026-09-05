package app

import (
	"context"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"time"

	"github.com/devdumpling/wlls/content"
	"github.com/devdumpling/wlls/internal/about"
	"github.com/devdumpling/wlls/internal/assets"
	"github.com/devdumpling/wlls/internal/blog"
	"github.com/devdumpling/wlls/internal/config"
	markdownrenderer "github.com/devdumpling/wlls/internal/markdown"
	"github.com/devdumpling/wlls/internal/site"
)

type App struct {
	server          *http.Server
	logger          *slog.Logger
	shutdownTimeout time.Duration
	cancel          context.CancelFunc
}

func New(ctx context.Context, cfg config.Config, logger *slog.Logger) (*App, error) {
	appContext, cancel := context.WithCancel(ctx)

	assetBundle, err := assets.New()
	if err != nil {
		cancel()
		return nil, err
	}
	renderer := markdownrenderer.New()
	posts, err := blog.Load(content.Files, renderer)
	if err != nil {
		cancel()
		return nil, err
	}
	aboutPage, err := about.Load(content.Files, renderer)
	if err != nil {
		cancel()
		return nil, err
	}

	viewAssets := site.Assets{
		Stylesheet: assetBundle.URL("css/site.css"),
		Datastar:   assetBundle.URL("js/datastar.js"),
		Favicon:    assetBundle.URL("favicon.svg"),
	}
	handler, err := Routes(RouteDependencies{
		Logger:     logger,
		BaseURL:    cfg.Site.BaseURL,
		Assets:     assetBundle,
		ViewAssets: viewAssets,
		Posts:      posts,
		About:      aboutPage,
	})
	if err != nil {
		cancel()
		return nil, err
	}

	return &App{
		server: &http.Server{
			Addr:              cfg.HTTP.Address,
			Handler:           handler,
			ReadHeaderTimeout: 5 * time.Second,
			IdleTimeout:       90 * time.Second,
			BaseContext: func(_ net.Listener) context.Context {
				return appContext
			},
		},
		logger:          logger,
		shutdownTimeout: cfg.HTTP.ShutdownTimeout,
		cancel:          cancel,
	}, nil
}

func (a *App) Run(ctx context.Context) error {
	listener, err := net.Listen("tcp", a.server.Addr)
	if err != nil {
		a.cancel()
		return err
	}

	serveErrors := make(chan error, 1)
	go func() {
		a.logger.Info("HTTP server started", "address", listener.Addr().String())
		serveErrors <- a.server.Serve(listener)
	}()

	select {
	case err := <-serveErrors:
		a.cancel()
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-ctx.Done():
	}

	a.cancel()
	shutdownContext, cancel := context.WithTimeout(context.Background(), a.shutdownTimeout)
	defer cancel()
	shutdownErr := a.server.Shutdown(shutdownContext)
	if shutdownErr != nil {
		shutdownErr = errors.Join(shutdownErr, a.server.Close())
	}
	serveErr := <-serveErrors
	if errors.Is(serveErr, http.ErrServerClosed) {
		serveErr = nil
	}
	return errors.Join(shutdownErr, serveErr)
}
