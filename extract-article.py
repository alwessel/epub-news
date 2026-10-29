'''
Reduce a saved web page (e.g. from SingleFile) to its main article content
using Calibre's bundled Readability port.

Usage: calibre-debug -e extract-article.py input.html output.html
Prints the detected article title to stdout.
Exits with code 2 if the extracted text is too short to be the article.
'''

import re
import sys
from html import escape

from calibre.ebooks.readability import readability
from calibre.utils.logging import Log, Stream

MIN_TEXT_LENGTH = 500

src, dst = sys.argv[1], sys.argv[2]
with open(src, 'rb') as f:
    raw = f.read().decode('utf-8', errors='replace')

# log to stderr, stdout is reserved for the title
log = Log(level=Log.WARN)
log.outputs = [Stream(sys.stderr)]

doc = readability.Document(raw, log)
title = (doc.short_title() or doc.title() or '').strip()
summary = doc.summary()

text = re.sub(r'<[^>]+>', ' ', summary)
text = re.sub(r'\s+', ' ', text).strip()
if len(text) < MIN_TEXT_LENGTH:
    print(title)
    sys.exit(2)

body = re.sub(r'^.*?<body[^>]*>|</body>.*$', '', summary, flags=re.S | re.I)
if not re.search(r'<h1[\s>]', body, re.I):
    body = f'<h1>{escape(title)}</h1>{body}'
with open(dst, 'w', encoding='utf-8') as f:
    f.write(
        '<!DOCTYPE html><html><head><meta charset="utf-8">'
        f'<title>{escape(title)}</title></head>'
        f'<body>{body}</body></html>'
    )

print(title)
