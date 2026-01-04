#!/bin/bash
set -e

outputFile="${1:-}"
if [ -z "$outputFile" ]; then
  outputFile="heise-$(date '+%d.%m.%Y').epub"
fi
rm -f $outputFile

ebook-convert heise.recipe "$outputFile"
echo "Successfully generated: $outputFile"
