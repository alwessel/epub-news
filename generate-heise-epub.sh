#!/bin/bash
set -e

# generate epub
name=heise
recipe=$name.recipe
epub="$name-$(date '+%d.%m.%Y').epub"

rm -f $epub
# download as epub
ebook-convert $recipe $epub -v --epub-max-image-size 400x800 --pretty-print

echo "Successfully generated: $epub"
