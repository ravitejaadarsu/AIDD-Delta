// Deterministic oracle for T-020: query parsing must not pollute Object.prototype.
//
// Usage: node express_proto_query.cjs   (CWD must be the express checkout)
//
// Sends `?__proto__[polluted]=yes` and checks two things: nothing landed on
// Object.prototype in this process, and `__proto__` did not become an own key of req.query.
// Exit 0 clean, 1 polluted, 3 precondition failure. Node stdlib plus the repo under test.

const http = require('http');
const path = require('path');

function die(code, msg) {
  console.error(msg);
  process.exit(code);
}

let express;
try {
  express = require(path.join(process.cwd(), 'index.js'));
} catch (err) {
  die(3, `precondition: cannot require ./index.js (${err.message})`);
}
if (typeof express !== 'function') die(3, 'precondition: ./index.js does not export express');

const app = express();
app.get('/q', (req, res) => {
  res.json({
    ownProto: Object.prototype.hasOwnProperty.call(req.query, '__proto__'),
    a: req.query.a || null,
  });
});

const server = app.listen(0, '127.0.0.1', () => {
  const url = `http://127.0.0.1:${server.address().port}/q?__proto__[polluted]=yes&a=1`;
  http
    .get(url, (res) => {
      let body = '';
      res.on('data', (chunk) => {
        body += chunk;
      });
      res.on('end', () => {
        server.close();
        let parsed;
        try {
          parsed = JSON.parse(body);
        } catch (err) {
          die(3, `precondition: response was not JSON (${body})`);
        }
        if ({}.polluted !== undefined) die(1, 'ORACLE FAIL: Object.prototype was polluted');
        if (parsed.ownProto) die(1, 'ORACLE FAIL: __proto__ became an own key of req.query');
        if (parsed.a !== '1') die(1, `ORACLE FAIL: ordinary params regressed (a=${parsed.a})`);
        console.log('ORACLE PASS: nested query parsing did not pollute the prototype');
      });
    })
    .on('error', (err) => {
      server.close();
      die(3, `precondition: request failed (${err.message})`);
    });
});
