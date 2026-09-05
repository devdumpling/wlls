package assets

import (
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"fmt"
	"io/fs"
	"net/http"
	"path"
	"sort"
	"strings"
)

//go:embed static
var files embed.FS

type Bundle struct {
	version string
	handler http.Handler
}

func New() (*Bundle, error) {
	static, err := fs.Sub(files, "static")
	if err != nil {
		return nil, fmt.Errorf("open embedded static assets: %w", err)
	}
	version, err := fingerprint(static)
	if err != nil {
		return nil, err
	}
	return &Bundle{version: version, handler: http.FileServer(http.FS(static))}, nil
}

func (b *Bundle) Version() string { return b.version }

func (b *Bundle) URL(name string) string {
	return "/static/" + b.version + "/" + strings.TrimPrefix(path.Clean("/"+name), "/")
}

func (b *Bundle) Handler() http.Handler {
	etag := `"` + b.version + `"`
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("ETag", etag)
		if r.Header.Get("If-None-Match") == etag {
			w.WriteHeader(http.StatusNotModified)
			return
		}
		b.handler.ServeHTTP(w, r)
	})
}

func fingerprint(fsys fs.FS) (string, error) {
	var names []string
	if err := fs.WalkDir(fsys, ".", func(name string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !entry.IsDir() {
			names = append(names, name)
		}
		return nil
	}); err != nil {
		return "", fmt.Errorf("walk embedded assets: %w", err)
	}
	sort.Strings(names)

	hash := sha256.New()
	for _, name := range names {
		data, err := fs.ReadFile(fsys, name)
		if err != nil {
			return "", fmt.Errorf("read embedded asset %q: %w", name, err)
		}
		_, _ = hash.Write([]byte(name))
		_, _ = hash.Write([]byte{0})
		_, _ = hash.Write(data)
	}
	return hex.EncodeToString(hash.Sum(nil)[:8]), nil
}
