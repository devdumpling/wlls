package blog

import "time"

type Post struct {
	Slug        string
	Title       string
	Description string
	Topic       string
	PublishedAt time.Time
	HTML        string
}

func (p Post) DisplayDate() string {
	return p.PublishedAt.Format("January 2, 2006")
}
