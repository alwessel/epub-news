# Export Heise Newsticker as EPUB

This repo uses a GitHub Action to trigger the **generate-heise-epub.sh** script once a day.
It's executed within the **[linuxserver/calibre:latest](https://github.com/linuxserver/docker-calibre)** docker image
in order to use a Calibre recipe to export heise.de newsticker as an EPUB file.

## Usage

### GitHub Actions (Automated)
The workflow runs automatically on schedule:
- Daily at 16:40 UTC
- Weekend mornings at 09:40 UTC (Saturday and Sunday)

Generated EPUBs are created with the filename format: `heise-DD.MM.YYYY.epub`

### Local Usage
To generate an EPUB locally, you need Calibre installed:

```bash
docker run --rm -it -v $(pwd):/src --entrypoint /bin/bash linuxserver/calibre:latest
./generate-heise-epub.sh
```

This will create a file named `heise-DD.MM.YYYY.epub` in the current directory.

### Heise Login (Optional)
To access premium content, set environment variables:
```bash
export HEISE_USER="your_username"
export HEISE_PASSWORD="your_password"
./generate-heise-epub.sh
```

## Requirements
- Calibre (includes `ebook-convert` command)
- Bash shell

## Schedule
The GitHub Action runs via cron schedule:
- `40 16 * * *` - Daily at 16:40 UTC
- `40 9 * * 0,6` - Weekends at 09:40 UTC

Note: GitHub Actions may take up to 15 minutes to start scheduled workflows.
