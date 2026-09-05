package about

import (
	"errors"
	"fmt"
	"io/fs"
	"strings"

	"gopkg.in/yaml.v3"
)

type MarkdownRenderer interface {
	Render([]byte) (string, error)
}

type Page struct {
	Title       string
	Description string
	HTML        string
}

func Load(fsys fs.FS, renderer MarkdownRenderer) (Page, error) {
	source, err := fs.ReadFile(fsys, "pages/about.md")
	if err != nil {
		return Page{}, fmt.Errorf("read about page: %w", err)
	}
	metadata, body, err := splitFrontMatter(source)
	if err != nil {
		return Page{}, fmt.Errorf("parse about page: %w", err)
	}
	var values struct {
		Title       string `yaml:"title"`
		Description string `yaml:"description"`
	}
	if err := yaml.Unmarshal(metadata, &values); err != nil {
		return Page{}, fmt.Errorf("parse about front matter: %w", err)
	}
	if strings.TrimSpace(values.Title) == "" || strings.TrimSpace(values.Description) == "" {
		return Page{}, errors.New("about page requires title and description")
	}
	rendered, err := renderer.Render(body)
	if err != nil {
		return Page{}, fmt.Errorf("render about page: %w", err)
	}
	return Page{Title: strings.TrimSpace(values.Title), Description: strings.TrimSpace(values.Description), HTML: rendered}, nil
}

func splitFrontMatter(source []byte) ([]byte, []byte, error) {
	normalized := strings.ReplaceAll(string(source), "\r\n", "\n")
	if !strings.HasPrefix(normalized, "---\n") {
		return nil, nil, errors.New("missing opening front matter delimiter")
	}
	rest := normalized[4:]
	end := strings.Index(rest, "\n---\n")
	if end < 0 {
		return nil, nil, errors.New("missing closing front matter delimiter")
	}
	return []byte(rest[:end]), []byte(rest[end+5:]), nil
}
