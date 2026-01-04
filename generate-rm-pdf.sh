#!/bin/bash
set -euo pipefail

input="${1:-}"
if [ -z "$input" ]; then
  echo "Usage: $0 path_or_url/to/book.(epub|pdf)"
  exit 1
fi

tmpdir=""
cleanup() {
  if [ -n "${tmpdir:-}" ] && [ -d "$tmpdir" ]; then
    rm -rf "$tmpdir"
  fi
}
trap cleanup EXIT

src="$input"

case "$input" in
  http://*|https://*)
    tmpdir="$(mktemp -d)"
    filename="$(basename "${input%%\?*}")"
    if [ -z "$filename" ] || [ "$filename" = "/" ] || [ "$filename" = "." ]; then
      echo "Cannot determine filename from URL: $input"
      exit 1
    fi
    src="$tmpdir/$filename"
    echo "Downloading from URL: $input to $src"
    curl -fL --retry 3 --retry-delay 1 -o "$src" "$input"
    ;;
esac

if [ ! -f "$src" ]; then
  echo "Input file not found: $src"
  exit 1
fi

lower="${src,,}"
ext="${lower##*.}"
if [ "$ext" != "epub" ] && [ "$ext" != "pdf" ]; then
  echo "Unsupported input type: .$ext (expected .epub or .pdf)"
  exit 1
fi

stem="$(basename "$src")"
stem="${stem%.*}"
outputFile="${stem}-$(date '+%d.%m.%Y').pdf"
rm -f "$outputFile"

if [ "$ext" = "pdf" ]; then
  cp -f "$src" "$outputFile"
  echo "Successfully generated (copied): $outputFile"
  exit 0
fi

ebook-convert "$src" "$outputFile" -v \
  --output-profile generic_eink_hd \
  --base-font-size 14 \
  --embed-all-fonts \
  --subset-embedded-fonts \
  --unsmarten-punctuation \
  --disable-font-rescaling \
  --custom-size 1404x1872 \
  --unit devicepixel \
  --pdf-sans-family "Noto Sans" \
  --pdf-serif-family "Noto Serif" \
  --pdf-mono-family "Noto Mono" \
  --pdf-standard-font mono \
  --pdf-page-margin-left 10 \
  --pdf-page-margin-right 10 \
  --pdf-page-margin-top 5 \
  --pdf-page-margin-bottom 5 \
  --preserve-cover-aspect-ratio

echo "Successfully generated: $outputFile"