export interface Post {
	slug: string;
	title: string;
	topic?: string;
	date: string;
	description: string;
}

export interface Metadata {
	title?: string;
	date?: string;
	description?: string;
	topic?: string;
	layout?: string;
}

export interface TocItem {
	id: string;
	text: string;
}
