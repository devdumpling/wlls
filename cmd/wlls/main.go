package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/devdumpling/wlls/internal/app"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	addr := os.Getenv("WLLS_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}

	if err := app.New(addr).Run(ctx); err != nil {
		slog.Error("server failed", "error", err)
		os.Exit(1)
	}
}
