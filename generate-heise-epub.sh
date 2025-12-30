#!/bin/bash
set -e

outputFile="heise-$(date '+%d.%m.%Y').pdf"
rm -f $outputFile

# style recommendations from https://remarkable.jms1.info/scripts/rm2-make-pdf.html

ebook-convert heise.recipe "$outputFile" -v \
    --output-profile generic_eink_hd \
    --base-font-size 14 \
    --embed-all-fonts               \
    --subset-embedded-fonts         \
    --unsmarten-punctuation         \
    --disable-font-rescaling \
    --custom-size 1404x1872 \
    --unit devicepixel \
    --pdf-sans-family 'Noto Sans' \
    --pdf-serif-family 'Noto Serif' \
    --pdf-mono-family 'Noto Mono' \
    --pdf-standard-font mono \
    --pdf-page-margin-left 10 \
    --pdf-page-margin-right 10 \
    --pdf-page-margin-top 5 \
    --pdf-page-margin-bottom 5 \
    --preserve-cover-aspect-ratio

echo "Successfully generated: $outputFile"
