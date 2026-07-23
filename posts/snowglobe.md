---
title: "Overengineering a Multiplayer Experience Instead of a Slide Deck"
topic: "Engineering"
date: "2025-12-17"
description: "Something joyful, with SvelteKit and Gleam."
---

A few weeks ago I had a weird dream.

![Pixelated avatar of Devon](/images/avatars/dev.webp)

It was weird because it was 1.) a work dream (usually not my fave) and 2.) goofy as hell.

In it, I was celebrating with my team in a cozy holiday app. I existed as a cursor, a retro/pixelated avatar version of myself, leaving notes in a virtual guestbook. When I woke up, I first decided I needed to spend less time on the internet.

But shortly after that I decided it _was_ kind of a cozy dream, and my mind kept drifting to wanting to build a similar experience IRL.

This year has been special for my team. We got acquired. There's been chaos and uncertainty, but also growth and camaraderie. We typically do a sort of "Year in Review" powerpoint thing, recapping highlights and all that.

Between my desire to not write some slides and the nerd-sniping of my dream, I set to work trying to make something more fun than our usual powerpoint.

> [!NOTE]
> **Try it yourself**
>
> I open-sourced a demo version called [snowglobe](https://snowglobe.devon-wells.workers.dev/) that you can try right now (use party code `demo2025` to create a guest account). It's designed to be forked—all the content is config-driven. Check out the [behind-the-scenes page](https://snowglobe.devon-wells.workers.dev/behind-the-scenes) for a technical deep-dive or grab the [repo](https://github.com/devdumpling/snowglobe).

## Play

> "If you want creative workers, give them enough time to play." — John Cleese

Lately I've been obsessed with this cute language, [gleam](https://gleam.run/). I like it for a lot of reasons, in particular the small surface area (you can learn it in an afternoon), excellent language server, and the fact that it compiles to Erlang (and JS lol).

I didn't have any experience with the BEAM, and this felt like a good project to test things out.

The architecture split naturally: SvelteKit on the front (auth, SSR, the timeline), Gleam for the "alive" stuff (realtime presence, cursor positions, reactions). SvelteKit I know well; it gets out of the way and lets me move fast. Gleam was the adventure.

Why Gleam/Erlang for a side project? The BEAM (Erlang's virtual machine) was built for telecom—millions of tiny conversations happening simultaneously. That's exactly what realtime multiplayer feels like: cursors gossiping across screens, presence pinging every 50ms, reactions bubbling up etc. The actor model handles this elegantly (supposedly, again I'm new here hi).

I didn't spend time stress testing it, but I was able to easily spin up 20-30 sessions happening at once locally on an M1 without my CPU breaking a sweat. Sure, 20-30 sessions is nothing, but it's cool that it "just worked" without me having to think about what happens when any of those sessions failed or whatever.

On the frontend, Svelte 5 made the interactive bits easy to build. If you haven't spent much time in Svelte, I recommend giving it an honest try. There's lots of stuff I could talk about, but wanted to highlight the cursor physics:

```javascript
// springs made easy a la Svelte
const springX = Spring.of(() => x, { stiffness: 0.12, damping: 0.7 });
const springY = Spring.of(() => y, { stiffness: 0.12, damping: 0.7 });
```

Those two lines smooth out the 50ms network updates into fluid motion. When you see someone else's cursor glide across the screen, that's spring physics interpolating between heartbeats.

I sprinkled in features: Konami code triggers confetti, there's a cookie clicker for "liking" events (why not 🤷‍♀️), floating emoji reactions that drift upward and fade. Each one exists purely because it made me smile while building it.

## Ship Your Silly Thing

Was it overengineered? Absolutely. It was also super fun.

Watching my teammates discover their pixelated avatars and trigger the Konami code made the whole thing worth it. After a year of hard work, it feels good to make something off-beat and mostly throwaway.

Highly recommend.

[Come play.](https://snowglobe.devon-wells.workers.dev/)
