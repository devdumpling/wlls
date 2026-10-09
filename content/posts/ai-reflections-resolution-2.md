---
title: "AI Reflections: Latency"
topic: "Engineering"
date: "2026-10-08"
description: "Part 3: On latency and craft."
draft: true
---

> This is Part 3 in a series of reflections on AI over the past couple of years ([Part 1: Skepticism](https://wlls.dev/blog/ai-reflections), [Part 2: Fatigue](https://wlls.dev/blog/ai-reflections-fatigue)). Presented as my thoughts and emotions, written by me and me alone.

## Oh, joyous toy

Summer 2021, I was toying around with the OG technical preview for GitHub Copilot.

I pulled my coworker, Brad, into a Slack huddle, as I often did when I found something shiny. I liked working with Brad. He was pragmatic and would humor my delusions. I'd rant to him about whatever was on my mind, and he would nod along until I felt heard. Then, we'd both go back to writing Next.js and GraphQL and pretending things were ok. Everyone should have a Brad[footnote here about how if you are a Brad, thank you].

I remember that huddle, the awe at the awkward-but-functional autocomplete Copilot spat out to Leetcode problems we threw at it. I remember Brad mostly not saying anything. A lot of "...huh."

Not a good sign from Brad--he's supposed to bring me back down.

Back then the UX was... dodgy? Make comment, hit tab, get code. In the eternal words of Ryan Lockwood ([Streets 1:12](https://www.youtube.com/watch?v=oYmqJl4MoNI)), _what a rush._

Brad and I (innocently) joked about how maybe kids wouldn't have to learn to code anymore! Just press tab, ha ha. That made me remember how I wrote my first programs: flailing around in DOS, frustrated, my dad consoling me... "no, no, that's how it's _supposed_ to feel."

And he was right. That _is_ how it's supposed to feel. The challenge prepended the reward. It came slowly, a nice drippity droppity of dopamine that kept me coming back for decades.

Conversely, Copilot was all rush, minimal flailing. But is that it? Obviously I think not, otherwise I wouldn't be writing this. Much of AI discourse is polarizing. Give me sweet nuance!

In this essay, I'll present some of my current thoughts on the nuance:

- hand coding (and really, everything surrounding it, e.g. communication, thinking via writing, planning) is more valuable than ever
- agentic engineering is powerful and easy to misuse
- there is a middle ground that is worth exploring

## The pendulum

Over the past 5 years (??? seriously how has it been that long) of using AI, I have swung on the pro-anti AI pendulum back and forth, back and forth. I have drunk and administered the kool-aid. I have _also_ been a staunch critic. I have questioned my relationship to AI, the ethics surrounding it, and its impact on the environment, society, and communities. Big, scary existenstial questions.

[move to marginalia]> I know I'm going to play into the trope, but I've been an ethical vegan for going on two decades. I can't die on every hill, but the ones I do die on I try to take seriously.

I have feverishly run agents well into the night. I have also sworn off AI for weeks at a time, citing burnout symptoms and apathy.

What kept pulling me back, every time, was _latency_, particularly low latency. Latency is a funny word. I'm going to say it a lot, so let me be precise about it.

By latency I mean the time between an intention and a result. I have a thought, an input, a bit of information and I'm looking for a response.

[a definition component of some sort] Latent + cy; delay between stimulus and response.

In the paradise that is product development, we like to pretend latency is a means to an end, something only Steve, our grizzled performance engineer, cares about. We picture him hunched over his flame graphs, shaking his balding head at no one in particular.

But Steve _knows_ things. Steve has seen some proverbial shit. Steve knows Latency is the difference between MapQuest and Google Maps. Between a working product and an incident.

Latency is two-faced. [Low] latency is what made Copilot feel like a slot machine. [Low] latency is _also_ what makes a lab instrument useful. You try something crazy, see the result, adjust, try again. It's the same property either way. The difference is what you do with the result.

At the start of this year, I ran [a structured experiment on myself](https://wlls.dev/blog/devex) and wrote up [what I found](https://wlls.dev/blog/ai-reflections-fatigue). tldr: with heavy AI use, I started more low-value things and finished fewer. I shipped more and was ambivalent about what I shipped.

[This should be marginalia--maybe we make the DX results mostly marginalia / footnote as well, citing highlights] Oh! There's real data on all of this now too, and I'll get to some of it. But this essay is mostly about feelings.

So like any good burnt out dad, I took some time off. When I came back, I tried to use AI more intentionally. AI allowed in dayjob. No random side projects. Hand-coding katas. That felt sustainable, and I carried it through the spring and into summer.

## Done coding with AI

Then, midsummer, the pendulum swung again.

I was sitting on my back porch eating lunch and watching YouTube when I came across an innocuous video titled "[I'm done coding with AI](https://www.youtube.com/watch?v=2ZU3j4GQ4K8)" by Brett Codes.

Brett describes a journey similar to mine, back and forth on the pendulum. He expresses issues he has had with it, some I agree with more than others. What got me, though, was how he didn't feel his experience with AI was aligning _with his values_. Brett values integrity, something I cherish in my work these days.

Maybe it was my general annoyance at the results I was seeing, maybe the midsummer Ohio sun hitting me just right, but Brett's uncut monologue resonated.

I stopped using AI for three weeks after that. I turned it off in Zed, dropped my harnesses from my nix setup, hung up my tokens at work, and toggled it off in my search engines. I didn't go around criticizing people who got value from it--it felt like a personal decision.

However, during those three weeks, I didn't feel the kind of uplifting energy that Brett did. I _did_ feel better, enjoying the friction, the satisfaction of coding and problem solving by hand. I felt better not throwing tiny things at my clanker which didn't warrant clanking on, or shouldn't have been clanked in the first place.

But it didn't feel like all was somehow right in the world.

Part of the problem, I realized, is that I'm genuinely fascinated by the science and technology behind LLMs. I grew up in ye olde early 90s, young enough to be infatuated with the rapidly evolving digital world and early enough to have to figure most of it out myself.

[move to marginalia] (or I'd ask my Dad, to mixed success. he was the epitome of the "are ya winning son" meme).

Part of me felt like I was rejecting my fascination in favor of some mushy idealized version of craftsmanship, wherein AI usage is binary and absolute. I think this is a trap.

One of my favorite quotes is from Anne Lamott's _Bird by Bird_:

[ move to marginalia] (which is a book cleverly disguised as "writing advice" but is actually Anne explaining that in order to do that interesting thing you want to do you're going to creatively spiral into the abyss and come out with tentacles for eyes but it'llbeworthittrustmebro)

> "I used to think that paired opposites were a given, that love was the opposite of hate, right the opposite of wrong. But now I think we sometimes buy into these concepts because it is so much easier to embrace absolutes than to suffer reality. I don't think anything is the opposite of love. Reality is unforgivingly complex."

Adam Grant makes a similar case in [Think Again](https://adamgrant.net/book/think-again/): when we argue about complex things, we like to reduce them to neat little buckets, and the buckets isolate us from each other. Adding nuance moves the conversation forward.

"Use AI" or "don't use AI" is a pair of leaky buckets, a false, slightly damp dichotomy that smells of rust and mildew.

## The smithy and their anvil

Craft, to me, is active. It implies process, direction, and intention. It's creating something in a way that puts your identity into the work, and in turn, the work imprints on your identity. The smithy shapes the metal on the anvil, and over years of smithing, the anvil shapes the blacksmith too.

I think AI is _part_ of the anvil. A new, magical Anvil that sometimes tells you useful things and sometimes throws up on your apron, which you have to then explain to your fellow smithies.

[marginalia] I, uh, recognize the wee bit of irony in using the vestigial profession blacksmithing as my analogy.

And so we have a dilemma. My biggest (personal) concerns are still skill atrophy and cognitive debt, the smithy slowly degrading, producing homogenous longswords instead of anything interesting.

I _love_ programming and building software, and I know (I measured!) that I grok what I'm building better when I'm primarily writing it by hand. I'm in it for the long haul.

However, and maybe it's the copium talking, but I'm not sure the answer is to throw out the anvils, rolling our eyes at our coworkers' vomit covered aprons, as self-gratifying as that may be. I think there's a way to use AI to improve the craft and hone the crafter, to expand what's possible without degrading the smithy.

In practice, right now, that means a split.

I hand-write the code that _is_ the craft, e.g. API design, the parts I need to understand deeply and be able to explain in a meeting, the parts I don't fully intuit. The parts that make me happy. I use AI for the instruments _around_ the craft... the comparisons, the benchmarks, test generators, prototypes, approximate migrations, research where I don't care about the journey to the answer, where I'm not looking for the detour that might be on the way to the waterfall. Or where I just need to hold my nose and pump out some React components.

## Latency, in practice

I've recently been spending a lot of time with [Datastar](https://data-star.dev), a hypermedia framework that's making waves in some bleeding-edge corners of the frontend hivemind. When I build a feature, I can build it in Datastar _and_ in React (or [insert competing technology]). I can safely ship the boring React one, keep my health insurance, get an approximation in my Datastar stack, and then measure, benchmark, and observe the two.

Okay? So what? I could do all of that without AI.

Yes, and... it's an investment! Often that investment is worth it, often it's a frustrating argument with stakeholders.

Building the same solution twice, the benchmarking suite, and still having time to do the quality analysis I want is a _much_ harder sell to my boss. With a relatively trivial amount of effort, AI gives me the approximation, and I get _hard numbers_ to inform an actual engineering decision. It's still work, but the latency is low enough that the possibility space for how I work has opened up.

[marginalia here] I want to stress that the point I'm trying to make is not to move quality engineering or analysis wholesale to AI. I'm using this as an example of high-leverage information/work that might otherwise be too costly or inaccessible in an organization. It can still be extremely valuable to measure yourself, and always double check results, folks! But there is no world where I'm going to parse thousands of lines of logs or unravel HAR files faster than an LLM. While that's a useful skill that I still keep, it's not _the skill_ I'm interested in.

It reminds me of a Bret Victor talk [Inventing on Principle](https://vimeo.com/36579366). In it he demonstrates how critical the feedback loop is for inventing. When you can see the result of a change immediately, solutions open up that you'd never consider if you were waiting minutes, hours, or days. He goes further, emphasizing that missed ideas are a kind of moral wrong, and encourages us to build interfaces that give us more control over faster feedback loops.

Generalizing, more control and faster feedback means higher quality and a bigger possibility space, which means novel solutions.

Consider performance engineering.

[see: _measuring, the horror... in marginalias]

Perf is fashionably left to the periphery of our industry, done only in large orgs with hallmark enterprise lethargy, after they're forced to pay attention to the "sudden" influx of user complaints on marginal devices. AI makes building the measurement cheap enough that I actually do it.

The benefit I'm seeing isn't some 2, 5, or 10x in development speed. It's that I can take the _ideas_ in works like Cal Newport's _Slow Productivity_ (Do Fewer Things, Work At A Natural Pace, Obsess Over Quality) and use the low latency of AI in service of them. Slow work, fast loop.

## What the data says

I teased some data.

[DX](https://getdx.com) has been tracking AI's impact across hundreds of engineering orgs, and this year they started publishing some longitudinal results. Grain of salt: DX sells developer productivity measurement, their customers skew toward orgs that already invest in developer experience, and with 90%+ adoption across the industry there's no real "control" group anymore. Still, it's an interesting dataset at scale, and selfishly it mirrors my N=1 self-study.

[TODO: verify every number below against the reports/PDF before publishing.]

**The speedup is modest.** Across 400+ orgs over 16 months, AI adoption rose 65% while median PR throughput rose [just under 8%](https://getdx.com/blog/ai-productivity-gains-more-modest-than-expected/). Not 2x. Not 10x. Eight percent.

**The time savings are real, but they aren't converting.** In the [Q2 2026 report](https://getdx.com/blog/the-state-of-ai-impact-in-engineering-q2-2026/), developers report saving about 6 hours a week (up from about 3 a year earlier). Over the same period, the share of engineering time going to new work barely moved, from 57% to 58%. Hours saved, but not hours spent on anything new. That sounds a lot like the pseudowork I found in Part 2.

**Individual loops got faster, team loops got slower.** DX's Developer Experience Index _fell_ for the first time in their dataset [67 to 65]. Median PR size freaking _doubled_. IOW, individual feedback loop go up, while team feedback loops _around_ us (reviews, small incremental changes, incidents) are getting worse.

**The code is easier to read and harder to trust.** Code maintainability went up 3.8%. Change confidence went _down_ 6.1%. The code looks fine, and nobody quite knows what it does. Yay.

**But there are bright spots.** Documentation quality and onboarding improved. Smaller orgs (15 to 99 engineers) are pulling well ahead of large ones on throughput. Some teams really are using this well.

IMO this is the anvil shaping a whole industry, mostly in ways nobody chose. Not necessarily a bad thing, but... murky?

## Discipline

In the words of Brad, "...huh."

I'm figuring it out. It's hard. It isn't an all-in acceptance of AI doing everything, which I'm still staunchly critical of, nor is it an outright rejection of the potential value of AI as part of my workflow.

Using AI well requires extraordinary discipline, and I'm positive the conversation isn't as simple as I might want it to be.

Not everything _should_ be built. Just because you can, doesn't mean you should. Every time I reach for an agent, the question is whether the result will feed my understanding. Will it shape me the way I want to be shaped? Is this vomit on my apron or sweat?

## We are the art

And let me double triple extra emphasize that using AI _is_ pressing the easy button. If the _act_ of what you're doing is the important part, offloading it to AI robs you of exactly that. This is ABSOLUTELY CRITICAL in art and anything creative.

Brandon Sanderson says it best in [this talk](https://www.youtube.com/watch?v=mb3uK-_QkOo):

> "We are the art."

The point of making art isn't the artifact (lol).

Please, please, please, I do not want to read your AI novel. I do not want to hear your AI music. I do not want to play your slop game (okay, maybe for the irony if it's a good idle game). It may be _technically_ fascinating that you can do it, but why make art at all if you skip the part that makes it art?

## Values

Which brings me back to Brett, and to integrity.

I said abstaining felt like a personal decision. That's the part I can't fully square. I've been vegan for almost two decades, and for a long time I reached for that as the comparison. Here's a technology with real costs to the environment and to communities, built by labs that wave away the legal and ethical questions. Shouldn't I just abstain, the way I do with animal products?

Is it a fair comparison? Veganism, at least as it applies to non-human animals, feels more cut and dry to me. Look inside a factory farm and you either hold that reality at arm's length, or you acknowledge it and abstain. (It isn't actually that simple either, as many will point out, but you get what I mean.) AI doesn't resolve that cleanly, at least not for me. It's one of Lamott's false paired opposites.

I would like to see a world where AI is used and built responsibly and we don't plummet head first into another social media disaster or worse. My gut is that means getting _more involved_, rather than putting my head in the sand and scoffing at the juniors DeStRoYiNg programming.

[insert meme about AI building crappy SaaS]

## Resolve

It's not much of a conclusion, but this is where I'm at. I'm committed to staying introspective, calling a spade a spade, looking for data, and keeping an open mind.

I reserve the right to change my mind. Right now, I feel a lot like I did 5 years ago, watching Copilot in awe for the first time: conflicted, curious.

Conflicted because of the packaging around AI, the obsession with commoditizing it, and the shaky societal impacts looming as we plunge into a technology on the heels of seeing the destruction social media has wrought. Because of the environmental and community impacts, and the general blasé hand-waving of frontier labs at the legal and ethical dilemmas being raised.

Curious because I, perhaps naively, am optimistic about what responsible, disciplined use of LLMs for building could look like: use that doesn't delegate away the satisfaction or lead to burnout and apathy. Use that doesn't glaze over 10,000 lines of code and rubber stamp it.

"no, no that's how it's supposed to feel."

Thank you, Dad.

Until next time.
