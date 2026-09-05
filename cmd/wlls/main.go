package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/devdumpling/wlls/internal/app"
	"github.com/devdumpling/wlls/internal/config"
)

func main() {
	os.Exit(run())
}

func run() int {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg, err := config.Load()
	if err != nil {
		logger.Error("invalid configuration", "error", err)
		return 1
	}

	application, err := app.New(ctx, cfg, logger)
	if err != nil {
		logger.Error("construct application", "error", err)
		return 1
	}
	if err := application.Run(ctx); err != nil {
		logger.Error("application stopped", "error", err)
		return 1
	}
	return 0
}
