# Export Heise Newsticker as EPUB

This repo uses a GitHub Action to trigger the **generate-heise-epub.sh** script once a day.
It's executed within the **[linuxserver/calibre:latest](https://github.com/linuxserver/docker-calibre)** docker image
in order to use a Calibre recipe to export heise.de newsticker as an EPUB file.

## Usage

### Local Usage
To generate an EPUB locally, use Calibre within docker:

```bash
docker run --rm -it -v $(pwd):/src -w /src --entrypoint /bin/bash linuxserver/calibre:latest generate-heise-epub.sh
```

This will create a file named `heise-DD.MM.YYYY.epub` in the current directory.

Limit the article by using `export HEISE_ARTICLE_COUNT=50` (default=50) or as GitHub action env. 

### Heise Login (Optional)

To access premium content, set environment variables:
```bash
export HEISE_USER="your_username"
export HEISE_PASSWORD="your_password"
```
These vars also used by the GitHub Action.

### Upload to Remarkble (Optional)

Within the Github Action, the generated EPUB can be automatically uploaded to a reMarkable tablet using [rmapi]().

To enable this feature, set the Git Action secret environment variable 
to be your personal rmapi config file content (base64 encoded): `export RM_CONFIG="$(base64 -w0 rmapi.conf)"`

## Schedule

The GitHub Action runs via cron schedule, see .github/workflows/