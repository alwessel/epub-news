#!/bin/bash
set -euo pipefail

input="${1:-}"
title="${2:-}"
if [ -z "$input" ]; then
  echo "Usage: $0 path_or_url/to/book.(epub|pdf|html) [title]"
  exit 1
fi

scriptDir="$(cd "$(dirname "$0")" && pwd)"
tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

src="$input"

case "$input" in
  http://*|https://*)
    filename="$(basename "${input%%\?*}")"
    if [ -z "$filename" ] || [ "$filename" = "/" ] || [ "$filename" = "." ]; then
      filename="download"
    fi
    src="$tmpdir/$filename"
    echo "Downloading from URL to $src"
    curl -fsSL --retry 3 --retry-delay 1 -o "$src" "$input"
    ;;
esac

if [ ! -f "$src" ]; then
  echo "Input file not found: $src"
  exit 1
fi

# Determine type by extension, fall back to the file content
lower="${src,,}"
ext="${lower##*.}"
case "$ext" in
  epub|pdf|html) ;;
  htm) ext="html" ;;
  *)
    if head -c 4 "$src" | grep -q '%PDF'; then
      ext="pdf"
    elif head -c 64 "$src" | grep -aq 'application/epub+zip'; then
      ext="epub"
    elif head -c 1024 "$src" | grep -aiqE '<(!doctype html|html)'; then
      ext="html"
    else
      echo "Unsupported input type: $(basename "$src") (expected epub, pdf or html)"
      exit 1
    fi
    ;;
esac

stem="$(basename "$src")"
stem="${stem%.*}"

# Calibre selects the input plugin by file extension
if [ "${lower##*.}" != "$ext" ]; then
  cp "$src" "$tmpdir/input.$ext"
  src="$tmpdir/input.$ext"
fi

if [ "$ext" = "html" ]; then
  article="$tmpdir/article.html"
  set +e
  articleTitle="$(calibre-debug -e "$scriptDir/extract-article.py" "$src" "$article")"
  extractStatus=$?
  set -e
  if [ "$extractStatus" -eq 0 ]; then
    src="$article"
  else
    echo "Article extraction failed or too short, converting the full page."
  fi
  if [ -z "$title" ] && [ -n "$articleTitle" ]; then
    title="$articleTitle"
  fi
fi

titleArgs=()
if [ -n "$title" ]; then
  titleArgs=(--title "$title")
else
  title="$stem"
fi

# Keep the title readable on the device, but safe as a file name
safeTitle="$(printf '%s' "$title" | tr -d '\000-\037')"
safeTitle="${safeTitle//[\/\\:]/-}"
safeTitle="${safeTitle:0:100}"

# the repository is public, keep document titles out of the Actions log
if [ -n "${GITHUB_ACTIONS:-}" ] && [ "${#titleArgs[@]}" -gt 0 ]; then
  echo "::add-mask::$title"
  echo "::add-mask::$safeTitle"
fi

outputFile="${safeTitle}-$(date '+%d.%m.%Y').pdf"
rm -f "$outputFile"

verbose=()
if [ "${DEBUG:-}" = "1" ]; then
  verbose=(-v)
fi

ebook-convert "$src" "$outputFile" "${verbose[@]}" "${titleArgs[@]}" \
  --output-profile generic_eink_hd \
  --base-font-size 14 \
  --embed-all-fonts \
  --subset-embedded-fonts \
  --unsmarten-punctuation \
  --extra-css "body,p,li,div{line-height:1.45 !important}" \
  --custom-size 1404x1872 \
  --unit devicepixel \
  --pdf-sans-family "Noto Sans" \
  --pdf-serif-family "Noto Serif" \
  --pdf-mono-family "Noto Mono" \
  --pdf-standard-font sans \
  --pdf-page-margin-left 10 \
  --pdf-page-margin-right 10 \
  --pdf-page-margin-top 5 \
  --pdf-page-margin-bottom 5 \
  --preserve-cover-aspect-ratio

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "file=$outputFile" >> "$GITHUB_OUTPUT"
fi
echo "Successfully generated: $outputFile"
