package blog

import (
	"errors"
	"fmt"
	"io/fs"
	"path"
	"regexp"
	"slices"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

var (
	ErrNotFound = errors.New("post not found")
	slugPattern = regexp.MustCompile(`^[a-z0-9]+(?:-[a-z0-9]+)*$`)
)

type MarkdownRenderer interface {
	Render([]byte) (string, error)
}

type Repository struct {
	published []Post
	bySlug    map[string]Post
}

type frontMatter struct {
	Title       string `yaml:"title"`
	Description string `yaml:"description"`
	Date        string `yaml:"date"`
	Topic       string `yaml:"topic"`
	Draft       bool   `yaml:"draft"`
}

func Load(fsys fs.FS, renderer MarkdownRenderer) (*Repository, error) {
	names, err := fs.Glob(fsys, "posts/*.md")
	if err != nil {
		return nil, fmt.Errorf("find posts: %w", err)
	}
	if len(names) == 0 {
		return nil, errors.New("no Markdown posts found")
	}

	repository := &Repository{bySlug: make(map[string]Post, len(names))}
	for _, name := range names {
		post, draft, err := loadPost(fsys, renderer, name)
		if err != nil {
			return nil, err
		}
		if draft {
			continue
		}
		if _, exists := repository.bySlug[post.Slug]; exists {
			return nil, fmt.Errorf("duplicate post slug %q", post.Slug)
		}
		repository.bySlug[post.Slug] = post
		repository.published = append(repository.published, post)
	}
	if len(repository.published) == 0 {
		return nil, errors.New("no published posts found")
	}

	slices.SortFunc(repository.published, func(a, b Post) int {
		if order := b.PublishedAt.Compare(a.PublishedAt); order != 0 {
			return order
		}
		return strings.Compare(a.Slug, b.Slug)
	})
	return repository, nil
}

func (r *Repository) Published() []Post {
	return slices.Clone(r.published)
}

func (r *Repository) Latest() Post {
	return r.published[0]
}

func (r *Repository) Find(slug string) (Post, error) {
	post, ok := r.bySlug[slug]
	if !ok {
		return Post{}, ErrNotFound
	}
	return post, nil
}

func loadPost(fsys fs.FS, renderer MarkdownRenderer, name string) (Post, bool, error) {
	source, err := fs.ReadFile(fsys, name)
	if err != nil {
		return Post{}, false, fmt.Errorf("read %q: %w", name, err)
	}
	metadata, body, err := splitFrontMatter(source)
	if err != nil {
		return Post{}, false, fmt.Errorf("parse %q: %w", name, err)
	}

	var values frontMatter
	if err := yaml.Unmarshal(metadata, &values); err != nil {
		return Post{}, false, fmt.Errorf("parse front matter in %q: %w", name, err)
	}
	slug := strings.TrimSuffix(path.Base(name), path.Ext(name))
	if !slugPattern.MatchString(slug) {
		return Post{}, false, fmt.Errorf("post %q must use a lowercase kebab-case filename", name)
	}
	if strings.TrimSpace(values.Title) == "" || strings.TrimSpace(values.Description) == "" || values.Date == "" {
		return Post{}, false, fmt.Errorf("post %q requires title, description, and date", name)
	}
	publishedAt, err := time.Parse("2006-01-02", values.Date)
	if err != nil {
		return Post{}, false, fmt.Errorf("post %q has invalid date %q: %w", name, values.Date, err)
	}
	if values.Draft {
		return Post{Slug: slug}, true, nil
	}

	rendered, err := renderer.Render(body)
	if err != nil {
		return Post{}, false, fmt.Errorf("render %q: %w", name, err)
	}
	return Post{
		Slug:        slug,
		Title:       strings.TrimSpace(values.Title),
		Description: strings.TrimSpace(values.Description),
		Topic:       strings.TrimSpace(values.Topic),
		PublishedAt: publishedAt,
		HTML:        rendered,
	}, false, nil
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
