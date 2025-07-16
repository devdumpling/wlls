export interface StorySection {
	id: string;
	title: string;
	subtitle: string;
	content: string;
	year: string;
	icon: string;
	extraPaths?: string[];
}

export const storyData: StorySection[] = [
	{
		id: "blue-ridge",
		title: "Blue Ridge Mountains",
		subtitle: "Southern Virginia, Childhood",
		content:
			"Typical 90s nerd. Digimon, Maplestory, and everything in between.",
		year: "1993-2011",
		icon: "M3 18L10 10L14 14L21 7",
	},
	{
		id: "oberlin",
		title: "Oberlin College",
		subtitle: "Liberal Arts & Computer Science",
		content:
			"Four years of deep learning, coops, and the flat unchanging rural Ohio lands.",
		year: "2011-2015",
		icon: "M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z",
		extraPaths: ["M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"],
	},
	{
		id: "madison",
		title: "Madison, WI",
		subtitle: "Teaching & Bartending",
		content:
			"Nights behind the bar, days teaching kids to code. Met my wife at a vegan pizza party.",
		year: "2015-2018",
		icon: "M5 12V7a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v5M5 12l-2 7h8l-2-7",
		extraPaths: ["M11 12h2a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2h-2"],
	},
	{
		id: "columbus",
		title: "Columbus, OH",
		subtitle: "Enterprise & Growth",
		content:
			"Massive energy company. Learned what I didn't want. On the flip side, became a dad.",
		year: "2018-2021",
		icon: "M3 21h18M5 21V7l8-4v18",
		extraPaths: ["M19 21V11l-6-4", "M9 9v.01", "M9 12v.01", "M9 15v.01"],
	},
	{
		id: "current",
		title: "Present Day",
		subtitle: "Craftsmanship & Family Life",
		content:
			"Principal Engineer at CapitalRx, two daughters, and the journey continues. Still learning at the edge of my abilities.",
		year: "2021-Now",
		icon: "M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z",
	},
];
