#!/bin/bash
set -e

outputFile="heise-$(date '+%d.%m.%Y').pdf"
rm -f $outputFile

ebook-convert heise.recipe $outputFile -v

echo "Successfully generated: $outputFile"
