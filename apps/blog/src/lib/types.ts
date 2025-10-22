export interface Post {
	slug: string;
	title: string;
	topic?: string;
	date: string;
	description: string;
	archive?: boolean;
}

export interface Metadata {
	title?: string;
	date?: string;
	description?: string;
	topic?: string;
	layout?: string;
	archive?: boolean;
}

export interface TocItem {
	id: string;
	text: string;
}
