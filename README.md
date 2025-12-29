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

### Heise Login (Optional)

To access premium content, set environment variables:
```bash
export HEISE_USER="your_username"
export HEISE_PASSWORD="your_password"
```

## Schedule

The GitHub Action runs via cron schedule, see .github/workflows/