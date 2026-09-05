package blog

import (
	"errors"
	"testing"
	"testing/fstest"
)

type testRenderer struct{}

func (testRenderer) Render(source []byte) (string, error) {
	return "<p>" + string(source) + "</p>", nil
}

func TestLoadOrdersPublishedPostsAndFiltersDrafts(t *testing.T) {
	fsys := fstest.MapFS{
		"posts/older.md": {Data: []byte(postSource("Older", "2024-01-01", false))},
		"posts/newer.md": {Data: []byte(postSource("Newer", "2025-01-01", false))},
		"posts/draft.md": {Data: []byte(postSource("Draft", "2026-01-01", true))},
	}
	repository, err := Load(fsys, testRenderer{})
	if err != nil {
		t.Fatal(err)
	}
	posts := repository.Published()
	if len(posts) != 2 || posts[0].Slug != "newer" || repository.Latest().Slug != "newer" {
		t.Fatalf("unexpected posts: %+v", posts)
	}
	posts[0].Title = "changed"
	if repository.Latest().Title != "Newer" {
		t.Fatal("Published returned mutable repository storage")
	}
	if _, err := repository.Find("draft"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("draft lookup error = %v", err)
	}
}

func TestLoadRejectsInvalidContent(t *testing.T) {
	tests := map[string]fstest.MapFS{
		"missing metadata":  {"posts/post.md": {Data: []byte("---\ntitle: Test\n---\nBody")}},
		"invalid date":      {"posts/post.md": {Data: []byte(postSource("Test", "2025-02-30", false))}},
		"invalid slug":      {"posts/Invalid Post.md": {Data: []byte(postSource("Test", "2025-01-01", false))}},
		"missing delimiter": {"posts/post.md": {Data: []byte("# No metadata")}},
	}
	for name, fsys := range tests {
		t.Run(name, func(t *testing.T) {
			if _, err := Load(fsys, testRenderer{}); err == nil {
				t.Fatal("expected an error")
			}
		})
	}
}

func postSource(title, date string, draft bool) string {
	return "---\ntitle: " + title + "\ndescription: Description\ndate: \"" + date + "\"\ndraft: " + map[bool]string{true: "true", false: "false"}[draft] + "\n---\nBody"
}
