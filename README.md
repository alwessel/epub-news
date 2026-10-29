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

Pages and files can be sent from the browser or the share menu (macOS, Android) to the
reMarkable. The content is fetched by the browser, so pages behind a paywall work as well.

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

### Setup

1. **GitHub token**: create a fine-grained personal access token for this repository
   with the permission "Actions: Read and write".
2. **Cloudflare**: create an R2 bucket `rm-inbox` and add a lifecycle rule that deletes
   objects with the prefix `inbox/` after 1 day.
3. **Deploy the worker**:
   ```bash
   cd worker
   npx wrangler login
   openssl rand -hex 32                      # use as UPLOAD_TOKEN
   npx wrangler secret put UPLOAD_TOKEN
   npx wrangler secret put GH_TOKEN
   npx wrangler deploy
   ```
   The upload URL is `https://rm-inbox.<account>.workers.dev/upload`.

### Clients

**SingleFile** (Firefox desktop and Android), options → Destination:
- "upload to a REST Form API", URL: the upload URL, authorization token: `UPLOAD_TOKEN`
- file field name: `file`, URL field name: `url`
- File name template: `{page-title}.html`

**Android, [HTTP Shortcuts](https://http-shortcuts.rmy.ch/)**: POST to the upload URL with header
`Authorization: Bearer <UPLOAD_TOKEN>` and a form data body with a file parameter `file`
taken from the share menu. A second shortcut with a text parameter `url` sends public links.

**macOS, Shortcuts app**: a shortcut with input "Files and URLs", enabled for the share sheet
and as a Finder quick action, using "Get contents of URL" with method POST, request body
"Form", field `file` (file) or `url` (text) and the `Authorization` header.

### API

| Method   | Path             | Auth                  | Description                              |
|----------|------------------|-----------------------|------------------------------------------|
| `POST`   | `/upload`        | `Bearer UPLOAD_TOKEN` | Fields `file` or `url`, optional `title`, `folder`. Returns `202` |
| `GET`    | `/f/<id>/<name>` | `?t=<token>`          | Download for the workflow                 |
| `DELETE` | `/f/<id>/<name>` | `?t=<token>`          | Removes the file after publishing         |

Supported types: PDF, EPUB and HTML, up to 100 MB.
