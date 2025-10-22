/**
 * Format a date string into a human-readable format
 * @param dateString - The date string to format
 * @param format - The format style: 'full' (Month Day, Year) or 'short' (Month Year)
 * @returns Formatted date string
 */
export function formatDate(
	dateString: string,
	format: "full" | "short" = "full",
): string {
	const date = new Date(dateString);

	if (format === "short") {
		return date.toLocaleDateString("en-US", { year: "numeric", month: "long" });
	}

	return date.toLocaleDateString("en-US", {
		year: "numeric",
		month: "long",
		day: "numeric",
	});
}

/**
 * Calculate estimated reading time for content
 * @param content - The text content to analyze
 * @param wordsPerMinute - Average reading speed (default: 200)
 * @returns Formatted reading time string (e.g., "5 min read")
 */
export function calculateReadTime(
	content: string,
	wordsPerMinute = 200,
): string {
	const words = content.trim().split(/\s+/).length;
	const minutes = Math.ceil(words / wordsPerMinute);
	return `${minutes} min read`;
}

/**
 * Throttle a function to execute at most once per specified time period
 * @param fn - The function to throttle
 * @param delay - Minimum time between executions in milliseconds
 * @returns Throttled function
 */
export function throttle<T extends (...args: unknown[]) => void>(
	fn: T,
	delay: number,
): (...args: Parameters<T>) => void {
	let lastCall = 0;
	let timeoutId: ReturnType<typeof setTimeout> | null = null;

	return (...args: Parameters<T>) => {
		const now = Date.now();

		if (now - lastCall >= delay) {
			lastCall = now;
			fn(...args);
		} else {
			// Schedule the last call to happen after the delay
			if (timeoutId) {
				clearTimeout(timeoutId);
			}
			timeoutId = setTimeout(
				() => {
					lastCall = Date.now();
					fn(...args);
				},
				delay - (now - lastCall),
			);
		}
	};
}
