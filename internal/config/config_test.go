package config

import (
	"testing"
	"time"
)

func TestLoadDefaults(t *testing.T) {
	for _, name := range []string{"WLLS_ENV", "WLLS_ADDR", "WLLS_BASE_URL", "WLLS_SHUTDOWN_TIMEOUT"} {
		t.Setenv(name, "")
	}
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Environment != Development || cfg.HTTP.Address != "127.0.0.1:8080" || cfg.HTTP.ShutdownTimeout != 10*time.Second {
		t.Fatalf("unexpected defaults: %+v", cfg)
	}
	if got := cfg.Site.BaseURL.String(); got != "http://localhost:8080" {
		t.Fatalf("base URL = %q", got)
	}
}

func TestLoadRejectsInvalidValues(t *testing.T) {
	tests := []struct {
		name  string
		key   string
		value string
	}{
		{"environment", "WLLS_ENV", "staging"},
		{"address", "WLLS_ADDR", "not an address"},
		{"base URL", "WLLS_BASE_URL", "/relative"},
		{"base URL path", "WLLS_BASE_URL", "https://wlls.dev/subpath"},
		{"shutdown timeout", "WLLS_SHUTDOWN_TIMEOUT", "never"},
		{"non-positive shutdown timeout", "WLLS_SHUTDOWN_TIMEOUT", "0s"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			for _, name := range []string{"WLLS_ENV", "WLLS_ADDR", "WLLS_BASE_URL", "WLLS_SHUTDOWN_TIMEOUT"} {
				t.Setenv(name, "")
			}
			t.Setenv(test.key, test.value)
			if _, err := Load(); err == nil {
				t.Fatal("expected an error")
			}
		})
	}
}
