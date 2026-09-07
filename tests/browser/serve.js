const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../../site');
const prefix = '/projections-app/';
const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.json': 'application/json', '.wasm': 'application/wasm',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.ico': 'image/x-icon',
  '.woff': 'font/woff', '.woff2': 'font/woff2', '.map': 'application/json',
  '.txt': 'text/plain; charset=utf-8', '.csv': 'text/csv; charset=utf-8',
};

if (!fs.existsSync(path.join(root, 'index.html'))) {
  console.error(`Missing ${root}/index.html. Export Shinylive to site/ before running browser tests.`);
  process.exit(1);
}

http.createServer((req, res) => {
  if (!['GET', 'HEAD'].includes(req.method)) {
    res.writeHead(405).end();
    return;
  }
  let pathname;
  try { pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); }
  catch { res.writeHead(400).end(); return; }
  if (!pathname.startsWith(prefix)) { res.writeHead(404).end(); return; }
  let file = path.resolve(root, pathname.slice(prefix.length));
  if (file !== root && !file.startsWith(root + path.sep)) {
    res.writeHead(403).end(); return;
  }
  try {
    if (fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
    const stat = fs.statSync(file);
    if (!stat.isFile()) throw new Error('Not a file');
    // Deliberately omit COOP/COEP: GitHub Pages does not supply isolation headers.
    res.writeHead(200, {
      'Content-Type': types[path.extname(file)] || 'application/octet-stream',
      'Content-Length': stat.size,
    });
    if (req.method === 'HEAD') res.end();
    else fs.createReadStream(file).on('error', () => res.destroy()).pipe(res);
  } catch { res.writeHead(404).end(); }
}).listen(4173, '127.0.0.1', () => console.log(`Serving ${root} at http://127.0.0.1:4173${prefix}`));
