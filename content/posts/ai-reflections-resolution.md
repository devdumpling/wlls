---
title: "AI Reflections: Resolution"
topic: "Engineering"
date: "2026-10-08"
description: "Part 3: On latency, craft, and the anvil."
draft: true
---

> This is Part 3 in a series of reflections on AI over the past couple of years ([Part 1: Skepticism](https://wlls.dev/blog/ai-reflections), [Part 2: Fatigue](https://wlls.dev/blog/ai-reflections-fatigue)). It's my blog, so these are my thoughts and ugly emotions, written by me and me alone.

## Oh, joyous toy

Summer 2021, I was toying around with the OG technical preview for GitHub Copilot, blissfully ignorant of the moment I was in.

I pulled my friend and coworker, Brad, into a Slack huddle, as I often did when I found something shiny. I liked working with Brad. He was pragmatic and would humor my delusions. I'd rant to him about whatever was on my mind, and he would nod along until I felt heard. Then, we'd both go back to writing Next.js and GraphQL and pretending things were ok. Everyone should have a Brad.

I remember that huddle vividly, the awe at the awkward-but-functional autocomplete Copilot spat out to Leetcode problems we threw at it. I remember Brad mostly not saying anything, a lot of "...huh."

Not a good sign from Brad--he's supposed to bring me back down.

Back then you had to really nudge it, and the UX was terrible. Didn't matter. Make comment, hit tab, "solved" problem appeared. In the eternally quotable words of Ryan Lockwood ([Streets 1:12](https://www.youtube.com/watch?v=oYmqJl4MoNI)), _what a rush._

> Don't you roll your eyes at me

It was a familiar rush, too, or at least I thought so at the time. It reminded me of writing my first programs as a kid with my dad.

Except that wasn't a "rush" at all. Most of it was me flailing around in DOS, frustrated, my dad consoling me... "no, no, that's how it's _supposed_ to feel." The reward came later and it came slowly, a nice drippity droppity of dopamine that kept me coming back for decades.

Conversely, Copilot was the rush without the flailing.

I wrote about this juxtaposition in [my first reflection](https://wlls.dev/blog/ai-reflections), and I still think it's largely true. But my thoughts have evolved a bit.

## The pendulum

Over the past 5 years (??? seriously how has it been that long) of using AI in some form or another, I have swung on the pro-anti AI pendulum back and forth, back and forth. I have drunk and administered the kool-aid to excess. I have _also_ been a staunch critic and existentially questioned my relationship to AI, its ethics, and its impact on the environment, society, and communities, questions I don't take lightly as someone who has been an ethical vegan for almost two decades.

I have feverishly run agents well into the night. I have also sworn off AI entirely for weeks at a time, after noticing the burnout symptoms and general apathy I had toward my work.

What kept pulling me back, every time, was _latency_. I'm going to repeat this word a lot, so let me be precise about it.

By latency I mean the time between an intention and a result. I have an idea, then I see it working (or not). I like tools, especially tools that get out of my way. LLMs don't get out of my way (more on this later), but there's no doubting the latency.

Latency has two faces, though. Low latency is what made Copilot feel like a slot machine: pull the lever, get the hit, pull again. Low latency is _also_ what makes a lab instrument useful: try something, see the result, adjust, try again. It's the same property either way. The difference is what you do with the result, whether it feeds your understanding or replaces it.

Deep breath, sip of wine: that distinction is basically this whole essay.

[TODO: short beat on Part 2, written as a bridge rather than an ad.] At the start of this year, I ran [a structured experiment on myself](https://wlls.dev/blog/devex) and wrote up what I found in [Part 2](https://wlls.dev/blog/ai-reflections-fatigue). tldr: with heavy AI use, I started lots of low value things and finished fewer. I shipped more code and cared about less of it. Also, I simply did not remember the code I was writing. That's the slot machine.

Soooo I took a few weeks off. When I came back, it was gradual, and with more intention. AI allowed in dayjob projects, but used with care. No more random side projects. Much more hand coding. That felt sustainable, and I carried it through the spring and into summer.

Oh! Before I forget. There's real data on all of this now too, and I'll get to some of it. But this essay is mostly about feelings.

## Done coding with AI

Then, midsummer, the pendulum swung again.

I was sitting on my back porch eating lunch when I decided to pull the YouTube slot machine and hit the jackpot: an innocuous but enticing video titled "[I'm done coding with AI](https://www.youtube.com/watch?v=2ZU3j4GQ4K8)" by Brett Codes.

What a banger.

Brett describes a journey similar to mine, back and forth on the pendulum. He expresses issues he has had with it, some I agree with more than others. What got me, though, was how he didn't feel his experience with AI was aligning _with his values_.

Maybe it was my general annoyance at the results I was seeing, or the midsummer Ohio sun hitting me just right, but Brett's uncut monologue resonated.

I stopped using AI entirely for three weeks after that. I turned it off in Zed, dropped my harnesses from my nix setup, hung up my tokens at work, and toggled it off in my search engines. I didn't go around criticizing people who still used it. It felt like a personal decision.

During those three weeks, I didn't feel the kind of uplifting energy that Brett did. I absolutely _did_ feel better enjoying the friction, the satisfaction of coding and problem solving by hand. I felt better not throwing tiny things at my clanker which didn't warrant clanking on, or shouldn't have been clanked in the first place.

But it didn't feel like all was somehow right in the world.

Part of the problem, I realized, is that I'm genuinely fascinated by the science and technology behind LLMs. I grew up in ye olde early 90s, young enough to be infatuated with the rapidly evolving digital world and early enough to have to figure most of it out myself (or ask my Dad who was the epitome of the "are ya winning son" meme).

By abstaining entirely, I felt like I was rejecting that in favor of some mushy, gray definition of craftsmanship that treats AI usage as a binary decision.

One of my favorite quotes is from Anne Lamott's _Bird by Bird_ (which is a book cleverly disguised as "writing advice" but is actually Anne explaining that in order to do that interesting thing you want to do you're going to creatively spiral into the abyss and come out with tentacles for eyes but it'llbeworthittrustmebro):

> "I used to think that paired opposites were a given, that love was the opposite of hate, right the opposite of wrong. But now I think we sometimes buy into these concepts because it is so much easier to embrace absolutes than to suffer reality. I don't think anything is the opposite of love. Reality is unforgivingly complex."

Adam Grant makes a similar case in [Think Again](https://adamgrant.net/book/think-again/): when we argue about complex things, we like to reduce them to neat little buckets, and the buckets isolate us from each other. Adding nuance moves the conversation forward.

"Use AI" or "don't use AI" is a pair of leaky buckets, a false, slightly damp dichotomy that smells of rust and mildew. (Yes I really wrote that pretentious sentence. Cringe if you must.)

So... what to do?

## The blacksmith and the anvil

Here's where I'm at.

Craft, to me, is active. It implies process, direction, and intention. It's creating something in a way that puts your identity into the work, and in turn, the work reflects back on and shapes your identity. The smithy shapes the metal on the anvil, but over years of smithing, the anvil shapes the blacksmith too.

AI is part of the anvil.

I hesitate to make the rote claim that "it's just a tool." That feels... imprecise? A tool you merely use doesn't shape you back. AI does. In [Part 2], I discovered that over-relying on AI made me a manic developer that built fleeting, shitty side projects I wasn't proud of.

My biggest concerns are still skill atrophy and cognitive debt, the smithy slowly degrading. I _love_ programming and building software, and I know (I measured!) that I grok what I'm building better when I'm primarily writing it by hand. I'm in it for the long haul. Letting an LLM do all of my coding doesn't lead to the person I want to be.

Maybe it's the copium talking, but I'm not sure the answer is to throw out the anvil. I think there's a way to use AI to improve the craft and hone the crafter, to expand what's possible without degrading the smithy. Seems like a fine line to walk, yeah.

In practice, right now, that means a split. I hand-write the code that _is_ the craft, e.g. the thing I'm building, the parts I need to understand deeply and be able to explain in a meeting. The parts that make me happy. I use AI for the instruments _around_ the craft... the comparisons, the benchmarks, test generators, approximate migrations, research where I don't care about the journey, the throwaway prototypes whose only job is to answer a question.

## Latency, in practice

A concrete example.

I've recently been spending a lot of time with [Datastar](https://data-star.dev), a hypermedia framework that's making waves in some bleeding-edge corners of the frontend hivemind. When I build a feature, I can build it in Datastar _and_ in React (or [insert competing technology]). I can safely ship the boring React one, keep my health insurance, get an approximation in my Datastar stack, and then measure, benchmark, and observe the two.

Okay? So what? I could do all of that without AI.

Buuuut it's an investment. Building the same solution twice, the benchmarking suite, the static analysis tooling, and still having time to do the quality analysis I want is a _much_ harder sell to my boss. With a relatively trivial amount of effort, AI gives me the approximation, and I get _hard numbers_ to inform an actual engineering decision. It's still work, but the latency is low enough that the possibility space for how I work has opened up.

Now, if you read Part 2, you might notice something. A "frontend stack evaluation tool" and a perf capture tool were both on my list of AI-fueled procrastination projects. I see you there, pitchfork in hand. What changed?

[TODO: your answer. My read: purpose and scope. Then, they were new repos chasing a shiny idea. Now, the comparison serves a decision I already have to make, at work, on something I'm shipping anyway. The instrument serves the craft instead of replacing it.]

It reminds me of Bret Victor's talk [Inventing on Principle](https://vimeo.com/36579366) (though somehow I don't imagine he agrees). In it he demonstrates how critical the feedback loop is for inventing. When you can see the result of a change immediately (it's latency all the way down), solutions open up that you'd never consider if you were waiting minutes, hours, or days. He goes further, calling that lost opportunity of ideas a kind of moral wrong, and encourages us to build interfaces that give us _more control_ over the feedback loop.

Generalizing (sorry again, Bret), more control and faster feedback means higher quality and a bigger possibility space, which means novel solutions.

IMO quality engineering is a good place for this, as is performance eng.

Perf (see: _measuring_, the horror...) is fashionably left to the periphery of our industry, done only in large orgs with trademark enterprise lethargy, after they're forced to pay attention to the "sudden" influx of user complaints on marginal devices. AI makes building the measurement cheap enough that I actually do it.

Unlike many of the hype-y takes, then, the benefit I'm seeing isn't some 2, 5, or 10x in development speed. It's that I can take the _ideas_ in works like Cal Newport's _Slow Productivity_ (Do Fewer Things, Work At A Natural Pace, Obsess Over Quality) and use the low latency of AI in service of them. Slow work, fast loop.

## What the data says

I teased some data.

[DX](https://getdx.com) has been tracking AI's impact across hundreds of engineering orgs, and this year they started publishing some longitudinal results. Grain of salt: DX sells developer productivity measurement, their customers skew toward orgs that already invest in developer experience, and with 90%+ adoption across the industry there's no real "control" group anymore. Still, it's an interesting dataset at scale, and selfishly it mirrors my N=1 self-study.

[TODO: verify every number below against the reports/PDF before publishing.]

**The speedup is modest.** Across 400+ orgs over 16 months, AI adoption rose 65% while median PR throughput rose [just under 8%](https://getdx.com/blog/ai-productivity-gains-more-modest-than-expected/). Not 2x. Not 10x. Eight percent.

**The time savings are real, but they aren't converting.** In the [Q2 2026 report](https://getdx.com/blog/the-state-of-ai-impact-in-engineering-q2-2026/), developers report saving about 6 hours a week (up from about 3 a year earlier). Over the same period, the share of engineering time going to new work barely moved, from 57% to 58%. Hours saved, but not hours spent on anything new. That sounds a lot like the pseudowork I found in Part 2.

**Individual loops got faster, team loops got slower.** DX's Developer Experience Index _fell_ for the first time in their dataset [67 to 65]. Median PR size freaking _doubled_. IOW, individual feedback loop go up, while team feedback loops _around_ us (reviews, small incremental changes, incidents) are getting worse.

**The code is easier to read and harder to trust.** Code maintainability went up 3.8%. Change confidence went _down_ 6.1%. The code looks fine, and nobody quite knows what it does. Yay.

**But there are bright spots.** Documentation quality and onboarding improved. Smaller orgs (15 to 99 engineers) are pulling well ahead of large ones on throughput. Some teams really are using this well.

IMO this is the anvil shaping a whole industry, mostly in ways nobody chose on purpose. Not necessarily a bad thing, but... murky?

## Discipline

In the words of Brad, "...huh."

Shit is hard. It also, at least currently, feels... aggressively fine. It isn't an all-in acceptance of AI doing everything, which I'm still staunchly critical of, nor is it an outright rejection of the _potential_ value of AI as part of my workflow.

Using AI well requires extraordinary discipline. I'm not _sure_ I have that discipline (see: Part 2), but I'm positive the conversation isn't as simple as I might want it to be.

Not everything _should_ be built. Just because you can, doesn't mean you should. Every time I reach for an agent, the question is whether the result will feed my understanding. Will it shape me the way I want to be shaped?

## We are the art

And let me double triple extra emphasize that using AI _is_ pressing the easy button. If the _act_ of what you're doing is the important part, offloading it to AI robs you of exactly that. This is ABSOLUTELY CRITICAL in art and anything creative.

Brandon Sanderson says it best in [this talk](https://www.youtube.com/watch?v=mb3uK-_QkOo):

> "We are the art."

The point of making art isn't the artifact (lol).

Please, please, please, I do not want to read your AI novel. I do not want to hear your AI music. I do not want to play your slop game (okay, maybe for the irony if it's a good idle game). It may be _technically_ fascinating that you can do it, but why make art at all if you skip the part that makes it art?

## Values

Which brings me back to Brett, and to values.

[TODO: this section is the least formed. Your raw thinking is below, lightly organized. It needs your voice most.]

I said abstaining felt like a personal decision. That's the part I can't fully square. I've been vegan for almost two decades, and for a long time I reached for that as the comparison: here's a technology with real costs to the environment and to communities, built by labs that wave away the legal and ethical questions. Shouldn't I just abstain, the way I do with animal products?

But I think that's a false comparison. Veganism, at least as it applies to non-human animals, feels more cut and dry to me. Look inside a factory farm and you either hold that reality at arm's length, or you acknowledge it and abstain. (It isn't actually that simple either, as many will point out, but you get what I mean.) AI doesn't resolve that cleanly, at least not for me. It's one of Lamott's false paired opposites.

[TODO: so how _do_ you reconcile it? Unanswered is a legitimate answer here, if you say so plainly.]

## Resolution

It's not much of a conclusion, but this is where I'm at. I'm calling this "Resolution," though more in the sense of resolve, a commitment to stay introspective.

I reserve the right to change my mind. Right now, I feel a lot like I did 5 years ago, watching Copilot in awe for the first time: conflicted, horrified, ecstatic, curious.

Conflicted because of the packaging around AI, the obsession with commoditizing it, and the shaky societal impacts looming as we plunge into a technology on the heels of seeing the destruction social media has wrought.

Horrified because of the environmental and community impacts, and the general blasé hand-waving of frontier labs at the legal and ethical dilemmas being raised.

Ecstatic because I, perhaps naively, am optimistic about what responsible, disciplined use of LLMs for building could look like: use that doesn't delegate away the satisfaction or lead to burnout and apathy. Use that doesn't glaze over 10,000 lines of code and rubber stamp it.

Curious because that's just who I am.

"no, no that's how it's supposed to feel."

Thank you, Dad.

Until next time.
