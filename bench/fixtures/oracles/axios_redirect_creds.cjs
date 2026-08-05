// Deterministic oracle for T-021: credentials must not survive a cross-origin redirect.
//
// Usage: node axios_redirect_creds.cjs   (CWD must be the axios checkout)
//
// Two loopback servers on different ports are two different origins. The first 302s to the
// second; the second records the headers it actually received. Exit 0 when neither
// Authorization nor Cookie arrived, 1 when either leaked, 3 when a precondition failed
// (no entry point, request never completed) — the code the harness records as an error
// rather than a FAIL. Node stdlib plus the repo under test only.

const http = require('http');
const path = require('path');

function listen(handler) {
  return new Promise((resolve) => {
    const server = http.createServer(handler);
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

function die(code, msg) {
  console.error(msg);
  process.exit(code);
}

(async () => {
  let mod;
  try {
    mod = require(path.join(process.cwd(), 'index.js'));
  } catch (err) {
    die(3, `precondition: cannot require ./index.js (${err.message})`);
  }
  const axios = mod.default || mod;
  if (!axios || typeof axios.get !== 'function') {
    die(3, 'precondition: ./index.js does not export an axios instance');
  }

  let received = null;
  const target = await listen((req, res) => {
    received = req.headers;
    res.writeHead(200, { 'content-type': 'text/plain' });
    res.end('ok');
  });
  const origin = await listen((req, res) => {
    res.writeHead(302, { location: `http://127.0.0.1:${target.address().port}/final` });
    res.end();
  });

  try {
    await axios.get(`http://127.0.0.1:${origin.address().port}/start`, {
      headers: { Authorization: 'Bearer bench-secret', Cookie: 'sid=bench-secret' },
    });
  } catch (err) {
    target.close();
    origin.close();
    die(3, `precondition: request did not complete (${err.message})`);
  }
  target.close();
  origin.close();

  if (!received) die(3, 'precondition: the redirect target was never reached');
  const leaked = ['authorization', 'cookie'].filter((h) => received[h] !== undefined);
  if (leaked.length) die(1, `ORACLE FAIL: leaked across origins: ${leaked.join(', ')}`);
  console.log('ORACLE PASS: Authorization and Cookie dropped on cross-origin redirect');
})();
