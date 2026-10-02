# Next steps

Follow-ups from the redesign (field-notes theme, left column + rail shell,
landing terminal, image plates). Nothing here blocks shipping except the
first section.

## Before deploying

- [x] **Stage new files before `nix build`.** Flakes only see files git
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
- [x] **CSP.** Static policy in `src/httpx/headers.odin`; no inline scripts
      (the import map is gone and `cd` navigates with `data-init`). It keeps
      `'unsafe-eval'` for Datastar expressions; see `docs/templating.md`.
- [x] **Production pass behind Caddy.** Confirm `POST /terminal` responses
      arrive zstd-encoded, `/healthz` and `/readyz` respond, and fingerprinted
      assets resolve on the real domain.

## Design

- [x] **About is unlinked.** The rail has a fourth row, `whoami`, linking
      `/about`.
- [x] **"posts" vs `/blog`.** Everything says blog: the rail, the index
      heading and title, and the terminal's `cd` hints (`cd posts` still works).
- [x] **Post dates.** A mono date stamp above each post's title; nowhere else
      on pages (still in feed and sitemap).
- [x] **`theme-color` meta** so mobile browser chrome matches the paper.
- [x] **Footnote refs orphaning.** The Markdown pipeline puts a word joiner
      (U+2060) before each ref, binding it to the preceding word.
- [x] **404 copy** reads "this this page".

## Terminal and game

- [ ] **Hidden commands** to reward curiosity: `sudo`, `vim` (and `:q`),
      `cat`, `rm -rf /`, `man`.
- [ ] **Tab completion** answered by the server over SSE, like commands.
- [x] **Terminal on every page.** `/` opens it anywhere; off the landing
      page it lives in a bottom sheet behind a trigger in the breadcrumb row.
      `exit` closes it.
- [ ] **`play` page.** Give the Odin → WASM/WGSL game module its own page
      (`/play`), and have `play` navigate there like `cd`.
- [x] **Persist command history** per visitor (`localStorage`).

## Stack features (after the design settles)

- [x] **Sidenotes.** Footnotes hang in the margin beside their reference on
      wide screens (`src/content/footnotes.odin`); narrow screens keep the
      notes section and popovers. Replaces reader marginalia, which would
      mostly be empty margins plus moderation.
- [x] **Live hub.** Every page opens one `GET /live?path=…` stream; a hub
      isolate tracks who is here and wakes the streams whose topics changed
      (`src/app/live.odin`). `who` lists visitors by adjective-animal handle.
- [x] **Guestbook** at `/guestbook` (rail `:)`, `cd guestbook`, `sign <note>`):
      SQLite (`src/sqlite`), moderated with `sudo` in the terminal, approved
      entries pushed live. Needs `/etc/wlls/wlls.env` on the Droplet
      (`deploy/README.md`).
- [x] **`msg` and `nick`.** `#lobby`, a terminal chatroom on the live hub
      (`src/app/chat.odin`): in-memory history (last 40 lines), membership per
      visitor so the room follows you across pages, a send limit (5 burst,
      then 1/s), and root's `/mute`, `/unmute`, `/rm <name>`, `/wipe`. Nicks
      are in memory too and reset on deploy.
- [ ] **Faster leave.** A closed tab stays in `who` for up to ~50 s, until a
      heartbeat write fails. A `pagehide` beacon could unsubscribe at once.
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
- [x] **Lighthouse / a11y pass** on the new shell, especially keyboard use of
      the rail and terminal.
