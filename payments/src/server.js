const http = require('http');
const { processPayment, processRefund, generateReceipt } = require('./index');

const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const PORT = parseInt(process.env.PORT || '3000', 10);

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'ok',
      version: APP_VERSION,
      port: PORT,
      uptime: process.uptime()
    }));
    return;
  }

  if (req.url === '/pay' && req.method === 'POST') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(processPayment(100, 'KES')));
    return;
  }

  res.writeHead(404);
  res.end('Not found\n');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`kijanikiosk-payments ${APP_VERSION} listening on port ${PORT}`);
});
