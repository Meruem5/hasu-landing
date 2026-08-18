# CLAUDE.md

Guidance for agents working in this repository.

## What this is

Static marketing site for **Hasu**, a private two-person iOS app. Pure HTML and
CSS — **no build step, no framework, no dependencies.** Served as static files
from GitHub Pages.

The site's reason to exist right now is the privacy policy: the App Store listing
and the app's Settings screen both link to `https://hasu.hu/privacy.html`, and
App Review reads it without signing in. Treat that page as the load-bearing one.

The app itself lives in a separate repository (`lotus`), and its
`docs/privacy-policy.md` is the source text for `privacy.html`. **When one
changes, change both** — the published page is what people actually read, so it
is the one that must not go stale.

## Pages and assets

- `index.html` — landing page (hero, three pillars, "deliberately not", privacy link)
- `privacy.html` — the privacy policy
- `assets/style.css` — the **single shared stylesheet** for every page
- `assets/favicon.svg` — the lotus, six petals, dark-mode aware
- `assets/og-image.png`, `assets/apple-touch-icon.png` — generated, see below
- `robots.txt`, `sitemap.xml`, `CNAME` — hosting and crawlers

## Conventions

**All styling is in `assets/style.css`,** driven by custom properties in
`:root` — colours, the `--space-*` scale, radii, type. Reuse the tokens instead
of hardcoding values.

**Dark mode** is one `@media (prefers-color-scheme: dark)` block that overrides
those properties. To theme something, add or adjust a variable there rather than
writing per-component dark rules.

**Class naming is BEM-style** (`.block__element--modifier`).

**Nav and footer markup is duplicated** in each page — there are no includes.
Changing a nav link or the footer means editing every HTML file.

**The palette is the app's palette.** The teal ramp and warm grey come from
`lotus/scripts/generate-palette.py`, which derives the dark values in OKLCH.
Do not invent a dark colour here; take it from that generator's output so the
site and the app stay the same colour.

**The lotus is one drawing in three places** — `assets/favicon.svg`, the inline
SVG in the page headers, and `scripts/generate-assets.swift`. They share petal
counts and proportions on purpose. Change them together.

## Values repeated across files

Grep and update all occurrences when one changes:

- **Domain:** `hasu.hu` — canonical URLs, OG and Twitter tags, `CNAME`,
  `sitemap.xml`, `robots.txt`
- **Contact:** `hello@hasu.hu`
- **Brand:** `Hasu` — titles, OG `site_name`, logo text, copyright
- **Theme colour:** `#0F6E56` (teal 600) in each page's `theme-color` meta

Each page carries canonical, Open Graph and Twitter tags; keep the `<title>`,
meta description, OG and Twitter text aligned. When adding a page, add it to
`sitemap.xml` too.

## Deliberately absent

- **No `apple-itunes-app` meta and no App Store link.** The app is not on sale
  yet, and a Smart App Banner pointing at nothing is worse than none. Add the
  banner, the hero download link, and a `SoftwareApplication` JSON-LD block on
  the day the listing goes live.
- **No analytics.** The app promises no tracking; a tracker on its privacy policy
  page would make that a lie.
- **No JavaScript.** Nothing on the site currently needs it. Keep it that way
  unless something genuinely does.
