# Next steps

Follow-ups from the redesign (field-notes theme, left column + rail shell,
landing terminal, image plates). Nothing here blocks shipping except the
first section.

## Before deploying

- [ ] **Stage new files before `nix build`.** Flakes only see files git
      tracks. New untracked sources include `src/app/route_terminal.odin`,
      `src/content/{plates,headings}.odin`, `src/assets/image_size*.odin`,
      `src/views/terminal.templ`, and all of `src/assets/static/js/`
      (including the new `datastar-rocket.js`). `just build` reads the working
      tree, so it works either way.
- [x] **Terminal replies must fit Tina's egress buffer.** `/terminal` now
      renders into an `httpx.Render_Buffer` and sends through an
      `httpx.Patch_Stream` that resumes on `Send_Ready`. The egress buffer is
      16 KiB (one Datastar event's ceiling); `ls` fits ~100 long slugs in one
      event (`src/app/app_test.odin`). Past that, split the listing into
      several events or cap it.
- [ ] **CSP.** None is set yet. If added, the inline import map needs a hash or
      nonce, and Datastar needs its CSP mode (v1.0.4 supports aliased nonce
      attributes).
- [ ] **Production pass behind Caddy.** Confirm `POST /terminal` responses
      arrive zstd-encoded, `/healthz` and `/readyz` respond, and fingerprinted
      assets resolve on the real domain.

## Design

- [ ] **About is unlinked.** Reachable only via `whoami` / `cd about` in the
      terminal. Add a fourth rail row, or keep it as a discovered page.
- [ ] **"posts" vs `/blog`.** The rail says posts; the URL and breadcrumb say
      blog. Rename the route to `/posts` (with redirects from `/blog/*`) or
      the label to blog.
- [ ] **Post dates.** Removed from pages (still in feed and sitemap). Consider
      a minimal date at the end of the breadcrumb or beside the mono dek.
- [ ] **Generative glyph (phase 3).** Per-post contour/venation mark rendered
      in Odin from the slug hash; use it for the favicon (currently a generic
      "D") and OG images.
- [ ] **`theme-color` meta** so mobile browser chrome matches the paper.
- [ ] **Footnote refs orphaning.** A `[1]` can wrap onto its own line; bind
      it to the preceding word.
- [ ] **Code highlighting.** Code blocks are unstyled; do it server-side in the
      Markdown pipeline to stay zero-JS.
- [ ] **404 copy** reads "this this page".

## Terminal and game

- [ ] **Hidden commands** to reward curiosity: `sudo`, `vim` (and `:q`),
      `cat`, `rm -rf /`, `man`.
- [ ] **Tab completion** answered by the server over SSE, like commands.
- [ ] **`play` hook.** Load the Odin → WASM/WGSL game module and give it a
      canvas in the terminal region; `<wlls-terminal>` and the fold toggle are
      ready to host it.
- [ ] **Persist command history** per visitor (`localStorage`).

## Stack features (after the design settles)

- [ ] **Nods**: a single understated appreciation per post; SQLite + one
      writer isolate (command) + SSE counts (query).
- [ ] **Marginalia**: reader notes pinned to paragraphs, moderated, patched in
      live.
- [ ] **Commons**: the planned GPU landing sim with SQLite-persisted
      plantings.
- [ ] **Webmentions** stored in SQLite, rendered under posts.

## Code health

- [ ] **Tina busy-polls at idle.** The shard loop (`vendor/tina/src/bootstrap_shard.odin`,
      `for { scheduler_tick(shard) }`) never blocks, so `tina-shard-0` pins the
      droplet's one vCPU at 100% even with no traffic. It's harmless for now
      (flat billing, Caddy still gets scheduled), but it makes CPU graphs and
      alerts useless. Fix: an opt-in idle park. After a tick with no work, block
      in `_backend_collect` until `timer_earliest_deadline`, capped at a few ms,
      and wake early with `backend_wake`. Keep the park well under the watchdog's
      heartbeat threshold, or update the heartbeat before parking. Worth
      proposing upstream.

- [x] **Tests**: terminal commands, `views.breadcrumbs` path splitting, and
      every page rendered at startup (`src/app/app_test.odin`).
- [ ] **Docs**: a short CSS section in `docs/templating.md` on the
      structure (`site.css`) vs theme (`garden.css`) split, and the image
      plate syntax (`![alt](src "Caption | wide color raw pixel full")`).
- [ ] **Lighthouse / a11y pass** on the new shell, especially keyboard use of
      the rail and terminal.
