# hasu-landing

Static marketing site for **Hasu**, a private iOS app for two people. Its main
job today is hosting the privacy policy that the App Store listing points at.

Live at **https://hasu.hu**.

## Running it

There is nothing to install, build, lint or test. Open the `.html` files
directly, or serve the folder:

```bash
python3 -m http.server 8000
```

## Deploying

GitHub Pages, from `main`. Pushing deploys. `CNAME` maps the site to `hasu.hu`.

### DNS for the apex domain

`hasu.hu` is a bare domain, so it needs **A/AAAA records**, not a CNAME record —
a CNAME at the apex is invalid in DNS. Point it at GitHub Pages:

```
A     @   185.199.108.153
A     @   185.199.109.153
A     @   185.199.110.153
A     @   185.199.111.153
AAAA  @   2606:50c0:8000::153
AAAA  @   2606:50c0:8001::153
AAAA  @   2606:50c0:8002::153
AAAA  @   2606:50c0:8003::153
```

Optionally add `CNAME www → meruem5.github.io` so `www.hasu.hu` redirects.

Then in the repository: **Settings → Pages → Custom domain** = `hasu.hu`, and
tick **Enforce HTTPS** once the certificate is issued (it can take a few minutes
after DNS propagates).

The `CNAME` file in this repo and the Pages setting must agree; GitHub rewrites
the file if you change the setting in the UI, so prefer editing one place.

## Regenerating the raster assets

`assets/og-image.png` and `assets/apple-touch-icon.png` are committed artifacts,
generated from the same lotus geometry as the favicon and the app icon:

```bash
swift scripts/generate-assets.swift
```

This is the only script in the repo and it is not part of serving the site.
