// 极简静态文件服务器，用于预览 flutter build web 的产物。
// 用法：node tool/preview_server.js [端口]
// 默认端口 8788，目录为项目下的 build/web。
const http = require('http');
const fs = require('fs');
const path = require('path');

const port = Number(process.argv[2] || 8788);
const root = path.join(__dirname, '..', 'build', 'web');

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.map': 'application/json; charset=utf-8',
};

http
  .createServer((req, res) => {
    const urlPath = decodeURIComponent(req.url.split('?')[0]);
    let filePath = path.join(root, urlPath === '/' ? 'index.html' : urlPath);
    if (!filePath.startsWith(root)) {
      res.writeHead(403);
      res.end('forbidden');
      return;
    }
    if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
      filePath = path.join(filePath, 'index.html');
    }
    // 单页应用：找不到的路径回退到 index.html
    if (!fs.existsSync(filePath)) {
      filePath = path.join(root, 'index.html');
    }
    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end('not found');
        return;
      }
      res.writeHead(200, {
        'Content-Type': types[path.extname(filePath)] || 'application/octet-stream',
        'Cache-Control': 'no-cache',
      });
      res.end(data);
    });
  })
  .listen(port, () => {
    console.log(`WU本子预览地址：http://localhost:${port}`);
  });
