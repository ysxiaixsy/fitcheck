const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve('build/web-emulator');
const types = {'.html':'text/html', '.js':'text/javascript', '.json':'application/json',
  '.wasm':'application/wasm', '.svg':'image/svg+xml', '.png':'image/png', '.ttf':'font/ttf'};
http.createServer((request,response)=>{
  const pathname = decodeURIComponent(new URL(request.url, 'http://127.0.0.1').pathname);
  const file = path.resolve(root, '.'+pathname, pathname.endsWith('/') ? 'index.html' : '');
  if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
    response.writeHead(404); response.end(); return;
  }
  response.writeHead(200, {'content-type':types[path.extname(file)] || 'application/octet-stream', 'cache-control':'no-store'});
  fs.createReadStream(file).pipe(response);
}).listen(5174,'127.0.0.1',()=>console.log('FitCheck test build: http://127.0.0.1:5174'));
