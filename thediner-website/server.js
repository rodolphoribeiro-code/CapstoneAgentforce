const http = require('http');
const fs   = require('fs');
const path = require('path');
const PORT = process.env.PORT || 3000;

http.createServer((req, res) => {
  const file = path.join(__dirname, 'index.html');
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(500); res.end('Error'); return; }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(data);
  });
}).listen(PORT, () => console.log(`The Diner running on port ${PORT}`));
