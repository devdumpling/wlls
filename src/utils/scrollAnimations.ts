import { animate } from "animejs";

interface SectionElement {
	element: HTMLElement;
	content: HTMLElement | null;
	icon: HTMLElement | null;
	svgPaths: NodeListOf<SVGPathElement>;
	textElements: NodeListOf<HTMLElement>;
	animated: boolean;
}

export class ScrollAnimationManager {
	private progressTrunk: HTMLElement | null;
	private progressFlower: HTMLElement | null;
	private scrollTicking: boolean;
	private sectionElements: SectionElement[];
	private finalNav: HTMLElement | null;
	private finalNavAnimated: boolean;

	constructor() {
		this.progressTrunk = document.querySelector(".progress-trunk");
		this.progressFlower = document.querySelector(".progress-flower");
		this.scrollTicking = false;
		this.sectionElements = [];
		this.finalNav = document.querySelector(".final-nav");
		this.finalNavAnimated = false;

		this.init();
	}

	private init(): void {
		this.setupSectionElements();
		this.setupScrollListener();
		this.handleAllAnimations();
	}

	private setupSectionElements(): void {
		const sections = document.querySelectorAll("section[id]");

		sections.forEach((section) => {
			const sectionContent = section.querySelector(".section-content");
			const sectionIcon = section.querySelector(".section-icon");
			const svgPaths = sectionIcon?.querySelectorAll("path") || [];
			const textElements = section.querySelectorAll(".animate-text");

			this.initializeSVGPaths(svgPaths);
			this.setInitialStates(sectionContent, sectionIcon, textElements);

			this.sectionElements.push({
				element: section,
				content: sectionContent,
				icon: sectionIcon,
				svgPaths,
				textElements,
				animated: false,
			});
		});
	}

	private initializeSVGPaths(svgPaths: NodeListOf<SVGPathElement>): void {
		svgPaths.forEach((path) => {
			const pathLength = path.getTotalLength();
			Object.assign(path.style, {
				strokeDasharray: pathLength,
				strokeDashoffset: pathLength,
				strokeWidth: "2",
				fill: "none",
				strokeLinecap: "round",
				strokeLinejoin: "round",
			});
		});
	}

	private setInitialStates(
		content: HTMLElement | null,
		icon: HTMLElement | null,
		textElements: NodeListOf<HTMLElement>,
	): void {
		if (content) {
			Object.assign(content.style, {
				opacity: "0",
				transform: "translateY(60px)",
			});
		}
		if (icon) {
			Object.assign(icon.style, {
				opacity: "0",
				transform: "scale(0)",
			});
		}
		textElements.forEach((el) => {
			Object.assign(el.style, {
				opacity: "0",
				transform: "translateY(20px)",
			});
		});
	}

	private updateTreeProgress(): void {
		const scrollTop = window.scrollY;
		const docHeight = document.documentElement.scrollHeight;
		const winHeight = window.innerHeight;
		const scrollPercent = scrollTop / (docHeight - winHeight);

		if (this.progressTrunk) {
			const trunkHeight = 15 + scrollPercent * 80;
			this.progressTrunk.style.height = `${trunkHeight}%`;
		}

		if (this.progressFlower) {
			if (scrollPercent > 0.8) {
				this.progressFlower.style.opacity = "1";
				this.progressFlower.style.transform = "scale(1)";
			} else {
				this.progressFlower.style.opacity = "0";
				this.progressFlower.style.transform = "scale(0)";
			}
		}
	}

	private handleSectionAnimations(): void {
		const viewportHeight = window.innerHeight;
		const scrollTop = window.scrollY;

		this.sectionElements.forEach(
			({ element, content, icon, svgPaths, textElements, animated }, index) => {
				if (!element) return;

				const rect = element.getBoundingClientRect();
				const elementTop = scrollTop + rect.top;
				const triggerPoint = elementTop - viewportHeight * 0.7;
				const hasEntered = scrollTop > triggerPoint;

				if (hasEntered && !animated) {
					this.sectionElements[index].animated = true;
					this.animateSection(content, icon, svgPaths, textElements);
				}
			},
		);
	}

	private animateSection(
		content: HTMLElement | null,
		icon: HTMLElement | null,
		svgPaths: NodeListOf<SVGPathElement>,
		textElements: NodeListOf<HTMLElement>,
	): void {
		if (content) {
			animate(content, {
				translateY: [60, 0],
				opacity: [0, 1],
				duration: 600,
				easing: "outExpo",
			});
		}

		if (icon) {
			animate(icon, {
				scale: [0, 1],
				opacity: [0, 1],
				duration: 500,
				delay: 100,
				easing: "outBack",
			});
		}

		if (svgPaths.length > 0) {
			animate(svgPaths, {
				strokeDashoffset: 0,
				duration: 1000,
				delay: 200,
				easing: "outExpo",
			});
		}

		if (textElements.length > 0) {
			animate(textElements, {
				translateY: [20, 0],
				opacity: [0, 1],
				duration: 400,
				delay: (_el, i) => 300 + i * 80,
				easing: "outExpo",
			});
		}
	}

	private handleFinalNavAnimation(): void {
		if (!this.finalNav || this.finalNavAnimated) return;

		const rect = this.finalNav.getBoundingClientRect();
		const scrollTop = window.scrollY;
		const elementTop = scrollTop + rect.top;
		const viewportHeight = window.innerHeight;

		const triggerPoint = elementTop - viewportHeight * 0.5;
		const hasEntered = scrollTop > triggerPoint;

		if (hasEntered) {
			this.finalNavAnimated = true;
			animate(this.finalNav, {
				translateY: [30, 0],
				opacity: [0, 1],
				duration: 600,
				easing: "outExpo",
			});
		}
	}

	private handleAllAnimations(): void {
		this.handleSectionAnimations();
		this.handleFinalNavAnimation();
		this.updateTreeProgress();
		this.scrollTicking = false;
	}

	private setupScrollListener(): void {
		window.addEventListener(
			"scroll",
			() => {
				if (!this.scrollTicking) {
					requestAnimationFrame(() => this.handleAllAnimations());
					this.scrollTicking = true;
				}
			},
			{ passive: true },
		);
	}
}
