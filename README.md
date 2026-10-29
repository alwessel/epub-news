# Export Heise Newsticker as EPUB

This repo uses a GitHub Action to generate a EPUB file of 
the https://www.heise.de/newsticker/classic using the `generate-heise-epub.sh` script.

After that it converts the EPUB to PDF optimized for a 
remarkable-2 [device](https://remarkable.guide/index.html) using the `generate-rm-pdf.sh` script,
followed by an upload to the configured reMarkable account using [rmapi](https://github.com/ddvk/rmapi)
using the `publish-to-rm.sh` script.    

The `generate-*` scripts expected to be executed inside **[linuxserver/calibre:latest](https://github.com/linuxserver/docker-calibre)** docker image
in order to use a Calibre ebook-converter.

## Usage

### Local Usage
To execute the scripts locally, use Calibre images and start an interactive docker terminal with:

```bash
docker run --rm -it -v $(pwd):/src -w /src --entrypoint /bin/bash linuxserver/calibre:latest
```

### Generate Heise Newsticker EPUB

Limit the article by using `export HEISE_ARTICLE_COUNT=50` (default=50) or as an GitHub action env. 

To access premium content, set environment variables:
```bash
export HEISE_USER="your_username"
export HEISE_PASSWORD="your_password"
```
These vars also used by the GitHub Action.

### Upload to Remarkble (Optional)

To enable this feature, set the Git Action secret environment variable 
to be your personal rmapi config file content (base64 encoded):

`export RM_CONFIG="$(base64 -w0 rmapi.conf)"`

## Schedule

The GitHub Action runs via cron schedule, see .github/workflows/

## Send to reMarkable (Inbox)

Pages and files can be sent from Firefox or the share menu (macOS, Android) to the
reMarkable. The content is fetched by the browser, so pages behind a paywall and
downloaded files work as well.

```
SingleFile / HTTP Shortcuts / macOS Shortcuts
        │  POST /upload (multipart: file | url, title?, folder?)  Bearer UPLOAD_TOKEN
        ▼
Cloudflare Worker (worker/) ── stores the file in R2 (bucket rm-inbox)
        │  workflow_dispatch publish-rm.yml with url=https://<worker>/f/<id>/<name>?t=<token>
        ▼
GitHub Action ── download → article extraction (HTML) → Calibre → rmapi put /Inbox/ → DELETE file
```

HTML pages are reduced to the article content with Calibre's bundled Readability
(`extract-article.py`). If the extracted text is too short, the full page is converted.
Uploaded files stay in R2 only until the workflow has published them, at most one day.

### Secrets

| Secret         | Stored in                            | Purpose                                              |
|----------------|--------------------------------------|------------------------------------------------------|
| `RM_CONFIG`    | GitHub Actions secret                | rmapi config (base64), see "Upload to Remarkble"     |
| `GH_TOKEN`     | Cloudflare Worker secret             | Fine-grained PAT to trigger `publish-rm.yml`         |
| `UPLOAD_TOKEN` | Cloudflare Worker secret and clients | Shared token for uploads to the worker               |

None of them is part of the repository. `worker/wrangler.toml` only contains the
repository name, workflow file and bucket name. For local tests with `wrangler dev`, put
the secrets into `worker/.dev.vars` (ignored by git):

```
UPLOAD_TOKEN=...
GH_TOKEN=...
```

The repository is public, so the Actions log is public as well. The workflow masks the
download URL (it contains the per-file token) and the document title.

### Setup

Requirements: a Cloudflare account (free plan, R2 needs a payment method on file) and
Node.js for `npx wrangler`.

**1. GitHub token**

GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens →
Generate new token:
- Repository access: only `alwessel/epub-news`
- Permissions: "Actions: Read and write" (Metadata read-only is added automatically)
- Expiration: e.g. 1 year, note the date for renewal

**2. R2 bucket**

```bash
cd worker
npx wrangler login
npx wrangler r2 bucket create rm-inbox
npx wrangler r2 bucket lifecycle add rm-inbox expire-inbox inbox/ --expire-days 1
```

The same is possible in the Cloudflare dashboard under R2 → Create bucket and
bucket settings → Object lifecycle rules.

**3. Worker secrets**

```bash
openssl rand -hex 32                 # generate the UPLOAD_TOKEN, keep it for the clients
npx wrangler secret put UPLOAD_TOKEN # paste the generated token
npx wrangler secret put GH_TOKEN     # paste the GitHub token from step 1
npx wrangler secret list             # check that both are set
```

**4. Deploy**

```bash
npx wrangler deploy
```

The output shows the worker URL. The upload URL is
`https://rm-inbox.<account>.workers.dev/upload`.

**5. Test**

```bash
curl -X POST https://rm-inbox.<account>.workers.dev/upload \
  -H "Authorization: Bearer <UPLOAD_TOKEN>" \
  -F "file=@some.pdf"
```

The response is `{"ok":true,...}`, a run of "Generate RM PDF from given URL" starts in
the Actions tab and the document appears in `/Inbox/` on the reMarkable after 2–3 minutes.

### Clients

**SingleFile** (web pages, Firefox desktop and Android)

Install [SingleFile](https://addons.mozilla.org/firefox/addon/single-file/) (on Android via
menu → Extensions). In the SingleFile options:
- Destination: "upload to a REST Form API"
  - URL: `https://rm-inbox.<account>.workers.dev/upload`
  - authorization token: `UPLOAD_TOKEN` (without "Bearer", SingleFile adds it)
  - file field name: `file`
  - URL field name: `url`
- File name → template: `{page-title}.html`

Save a page with the SingleFile button (desktop) or menu → Extensions → SingleFile (Android).
The destination applies to every save. Use a separate SingleFile profile if you also archive
pages locally.

**Android: [HTTP Shortcuts](https://http-shortcuts.rmy.ch/)** (downloaded PDF/EPUB files)

1. New shortcut → "Regular HTTP Shortcut", name e.g. "→ reMarkable"
2. Method `POST`, URL: the upload URL
3. Request headers: `Authorization` = `Bearer <UPLOAD_TOKEN>`
4. Request body: "Form Data (multipart)", parameter `file` of type file, taken from the
   share menu

Share a downloaded file (download notification or files app) and pick the shortcut.
Sharing from Firefox's PDF viewer only shares the URL, so download the file first.
For public links, a second shortcut can send a text parameter `url` from a variable with
"Share Into" enabled.

**macOS: Shortcuts app** (downloaded PDF/EPUB files)

1. New shortcut "Send to reMarkable", details: enable "Show in Share Sheet" and
   "Use as Quick Action" (Finder), input type: Files
2. Action "Get Contents of URL":
   - URL: the upload URL, method `POST`
   - Headers: `Authorization` = `Bearer <UPLOAD_TOKEN>`
   - Request body: Form, field `file` of type File = Shortcut Input
3. Optional: "Show Notification" with the result

Use it in Finder via right-click → Quick Actions → "Send to reMarkable" or the share menu.

### Rotating tokens

- `UPLOAD_TOKEN`: generate a new one, `npx wrangler secret put UPLOAD_TOKEN`, then update
  SingleFile, HTTP Shortcuts and the macOS shortcut.
- `GH_TOKEN`: regenerate the fine-grained token on GitHub before it expires and run
  `npx wrangler secret put GH_TOKEN`.

### Troubleshooting

| Symptom                                   | Cause                                                        |
|-------------------------------------------|--------------------------------------------------------------|
| `NetworkError` in SingleFile              | Upload URL without `https://`                                |
| `404 not found: ...`                      | Upload URL does not end with `/upload`                       |
| `401 unauthorized`                        | Wrong `UPLOAD_TOKEN` or missing `Bearer ` prefix             |
| `415 unsupported file type`               | Only PDF, EPUB and HTML are accepted                         |
| `413`                                     | File larger than 100 MB                                      |
| `500 worker is not configured`            | `UPLOAD_TOKEN` or `GH_TOKEN` secret missing                  |
| `502 workflow dispatch failed: 401/403`   | `GH_TOKEN` expired or without "Actions: Read and write"      |
| `502 workflow dispatch failed: 404/422`   | `GH_REPO`, `GH_WORKFLOW` or `GH_REF` in `wrangler.toml` wrong |
| Workflow fails, file not on the device    | Check the Actions log; for Calibre details set `DEBUG: 1` as env of the generate step |

Live logs of the worker: `npx wrangler tail`.

### API

| Method   | Path             | Auth                  | Description                              |
|----------|------------------|-----------------------|------------------------------------------|
| `POST`   | `/upload`        | `Bearer UPLOAD_TOKEN` | Fields `file` or `url`, optional `title`, `folder`. Returns `202` |
| `GET`    | `/f/<id>/<name>` | `?t=<token>`          | Download for the workflow                 |
| `DELETE` | `/f/<id>/<name>` | `?t=<token>`          | Removes the file after publishing         |

Supported types: PDF, EPUB and HTML, up to 100 MB. Without `file`, the workflow downloads
`url` itself, which only works for public links.
