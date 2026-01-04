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