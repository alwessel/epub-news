// Inbox for "Send to reMarkable": accepts uploads (SingleFile, HTTP Shortcuts,
// macOS Shortcuts), stores them in R2 and triggers the publish-rm workflow,
// which downloads the file via /f/<id>/<name>?t=<token> and deletes it afterwards.

const MAX_SIZE = 100 * 1024 * 1024;
const CONTENT_TYPES = {
  pdf: 'application/pdf',
  epub: 'application/epub+zip',
  html: 'text/html; charset=utf-8',
};
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type, Accept',
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (url.pathname === '/upload' && request.method === 'POST') {
      return handleUpload(request, env, url);
    }
    const match = url.pathname.match(/^\/f\/([0-9a-f-]{36})\/([A-Za-z0-9._-]+)$/);
    if (match && (request.method === 'GET' || request.method === 'DELETE')) {
      return handleFile(request, env, `inbox/${match[1]}/${match[2]}`, url.searchParams.get('t'));
    }
    return json({ error: 'not found' }, 404);
  },
};

async function handleUpload(request, env, url) {
  if (!env.UPLOAD_TOKEN || !env.GH_TOKEN) {
    return json({ error: 'worker is not configured' }, 500);
  }
  const auth = request.headers.get('Authorization') || '';
  if (!safeEqual(auth, `Bearer ${env.UPLOAD_TOKEN}`)) {
    return json({ error: 'unauthorized' }, 401);
  }

  let form;
  try {
    form = await request.formData();
  } catch {
    return json({ error: 'expected multipart/form-data' }, 400);
  }
  const file = form.get('file');
  const sourceUrl = form.get('url');
  const title = (form.get('title') || '').toString().trim();
  const folder = (form.get('folder') || '').toString().trim();

  // Without a file, the workflow downloads the given URL itself (public links only)
  if (!(file instanceof File)) {
    if (typeof sourceUrl !== 'string' || !/^https?:\/\//.test(sourceUrl)) {
      return json({ error: 'expected a file or an http(s) url' }, 400);
    }
    const error = await dispatchWorkflow(env, { url: sourceUrl, title, folder });
    return error ? json({ error }, 502) : json({ ok: true, url: sourceUrl }, 202);
  }

  if (file.size === 0 || file.size > MAX_SIZE) {
    return json({ error: `file must be between 1 byte and ${MAX_SIZE} bytes` }, 413);
  }
  const ext = await detectType(file);
  if (!ext) {
    return json({ error: 'unsupported file type (expected pdf, epub or html)' }, 415);
  }

  const stem = file.name.replace(/\.[^.]*$/, '') || 'document';
  const name = `${slugify(stem)}.${ext}`;
  const id = crypto.randomUUID();
  const dlToken = randomHex(32);
  const key = `inbox/${id}/${name}`;

  await env.INBOX.put(key, file, {
    httpMetadata: { contentType: CONTENT_TYPES[ext] },
    customMetadata: { dlToken },
  });

  // For HTML the article extraction finds a cleaner title than the page title in the file name
  const workflowTitle = title || (ext === 'html' ? '' : stem);
  const fileUrl = `${url.origin}/f/${id}/${name}?t=${dlToken}`;
  const error = await dispatchWorkflow(env, { url: fileUrl, title: workflowTitle, folder });
  if (error) {
    await env.INBOX.delete(key);
    return json({ error }, 502);
  }
  return json({ ok: true, id, name }, 202);
}

async function handleFile(request, env, key, token) {
  const object = request.method === 'GET' ? await env.INBOX.get(key) : await env.INBOX.head(key);
  if (!object || !token || !safeEqual(token, object.customMetadata?.dlToken || '')) {
    return json({ error: 'not found' }, 404);
  }
  if (request.method === 'DELETE') {
    await env.INBOX.delete(key);
    return new Response(null, { status: 204 });
  }
  return new Response(object.body, {
    headers: { 'Content-Type': object.httpMetadata?.contentType || 'application/octet-stream' },
  });
}

async function dispatchWorkflow(env, { url, title, folder }) {
  const inputs = { url };
  if (title) inputs.title = title;
  if (folder) inputs.folder = folder;

  const response = await fetch(
    `https://api.github.com/repos/${env.GH_REPO}/actions/workflows/${env.GH_WORKFLOW}/dispatches`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.GH_TOKEN}`,
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'rm-inbox-worker',
      },
      body: JSON.stringify({ ref: env.GH_REF, inputs }),
    },
  );
  if (response.status === 204 || response.status === 200) {
    return null;
  }
  return `workflow dispatch failed: ${response.status} ${await response.text()}`;
}

async function detectType(file) {
  const ext = file.name.toLowerCase().split('.').pop();
  if (ext === 'pdf' || ext === 'epub' || ext === 'html') return ext;
  if (ext === 'htm') return 'html';

  const head = new TextDecoder('latin1').decode(await file.slice(0, 1024).arrayBuffer());
  if (head.startsWith('%PDF')) return 'pdf';
  if (head.startsWith('PK') && head.includes('application/epub+zip')) return 'epub';
  if (/<(!doctype html|html)/i.test(head)) return 'html';
  return null;
}

function slugify(value) {
  const slug = value
    .replace(/ä/g, 'ae').replace(/ö/g, 'oe').replace(/ü/g, 'ue')
    .replace(/Ä/g, 'Ae').replace(/Ö/g, 'Oe').replace(/Ü/g, 'Ue').replace(/ß/g, 'ss')
    .normalize('NFKD')
    .replace(/[^A-Za-z0-9._-]+/g, '-')
    .replace(/^[-.]+|[-.]+$/g, '')
    .slice(0, 80);
  return slug || 'document';
}

function randomHex(bytes) {
  return [...crypto.getRandomValues(new Uint8Array(bytes))]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function safeEqual(a, b) {
  const encoder = new TextEncoder();
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  if (left.byteLength !== right.byteLength) return false;
  return crypto.subtle.timingSafeEqual(left, right);
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
