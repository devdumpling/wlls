package config

import (
	"fmt"
	"net"
	"net/url"
	"os"
	"strings"
	"time"
)

type Environment string

const (
	Development Environment = "development"
	Production  Environment = "production"
)

type Config struct {
	Environment Environment
	HTTP        HTTP
	Site        Site
}

type HTTP struct {
	Address         string
	ShutdownTimeout time.Duration
}

type Site struct {
	BaseURL *url.URL
}

func Load() (Config, error) {
	cfg := Config{
		Environment: Environment(value("WLLS_ENV", string(Development))),
		HTTP: HTTP{
			Address:         value("WLLS_ADDR", "127.0.0.1:8080"),
			ShutdownTimeout: 10 * time.Second,
		},
	}

	baseURL, err := url.Parse(value("WLLS_BASE_URL", "http://localhost:8080"))
	if err != nil {
		return Config{}, fmt.Errorf("parse WLLS_BASE_URL: %w", err)
	}
	cfg.Site.BaseURL = baseURL

	if raw := os.Getenv("WLLS_SHUTDOWN_TIMEOUT"); raw != "" {
		cfg.HTTP.ShutdownTimeout, err = time.ParseDuration(raw)
		if err != nil {
			return Config{}, fmt.Errorf("parse WLLS_SHUTDOWN_TIMEOUT: %w", err)
		}
	}

	if err := cfg.Validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func (c Config) Validate() error {
	if c.Environment != Development && c.Environment != Production {
		return fmt.Errorf("WLLS_ENV must be %q or %q", Development, Production)
	}
	if _, err := net.ResolveTCPAddr("tcp", c.HTTP.Address); err != nil {
		return fmt.Errorf("invalid WLLS_ADDR %q: %w", c.HTTP.Address, err)
	}
	if c.HTTP.ShutdownTimeout <= 0 {
		return fmt.Errorf("WLLS_SHUTDOWN_TIMEOUT must be positive")
	}
	if c.Site.BaseURL == nil || (c.Site.BaseURL.Scheme != "http" && c.Site.BaseURL.Scheme != "https") || c.Site.BaseURL.Host == "" {
		return fmt.Errorf("WLLS_BASE_URL must be an absolute http or https URL")
	}
	if c.Site.BaseURL.RawQuery != "" || c.Site.BaseURL.Fragment != "" {
		return fmt.Errorf("WLLS_BASE_URL must not contain a query or fragment")
	}
	if strings.Trim(c.Site.BaseURL.Path, "/") != "" {
		return fmt.Errorf("WLLS_BASE_URL must not contain a path")
	}
	return nil
}

func value(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}
