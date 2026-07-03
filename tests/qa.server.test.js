/* End-to-end: real front-end (jsdom) ↔ real backend (uvicorn). */
const { JSDOM } = require("jsdom");
const fs = require("fs");
const html = fs.readFileSync(__dirname + "/../static/earmark.html", "utf8");
const BASE = "http://127.0.0.1:8123";

function boot() {
  const dom = new JSDOM(html, {
    runScripts: "dangerously", pretendToBeVisual: true, url: BASE + "/",
    beforeParse(window) {
      window.fetch = (path, opts) => fetch(BASE + path, opts); // real HTTP
      window.matchMedia = () => ({ matches: false });
      window.confirm = () => true;
      window.HTMLElement.prototype.scrollIntoView = function(){};
    },
  });
  return dom;
}
const sleep = ms => new Promise(r => setTimeout(r, ms));
const fails = [];
const ok = (n, c) => { if (!c) fails.push(n); console.log((c?"PASS":"FAIL")+"  "+n); };

(async () => {
  // wait for server
  for (let i = 0; i < 50; i++) {
    try { if ((await fetch(BASE + "/healthz")).ok) break; } catch {}
    await sleep(100);
  }

  /* session 1: sign in, build state against the live API */
  let dom = boot(), w = dom.window, d = w.document, E = c => w.eval(c);
  await sleep(300);
  ok("S1 front-end detected API mode", E("MODE") === "api");
  d.getElementById("si-email").value = "ops.lead@earmark.dev";
  await E("enter()");
  E("loadStarter()");
  E("receiveFiles([{name:'friday_calls.wav'}])");
  E("runScan()");
  await sleep(2600);
  const calls = E("CALLS.length"), flags = E("FLAGS.length");
  ok("S2 scan produced state", calls === 1);
  E("toggleTheme()");
  await sleep(1100); // debounce flush → PUT
  const server = await (await fetch(BASE + "/api/workspace")).json();
  ok("S3 snapshot landed on server", server.meta.signedIn === true && server.phrases.length === 5 && server.calls.length === calls);

  /* session 2: fresh "browser" → restored from server */
  dom = boot(); w = dom.window; d = w.document; E = c => w.eval(c);
  await sleep(400);
  ok("S4 session restored from server", d.getElementById("app").classList.contains("on") && d.getElementById("u-name").textContent === "Ops Lead");
  ok("S5 state intact", E("CALLS.length") === calls && E("FLAGS.length") === flags && E("PHRASES.length") === 5);
  ok("S6 theme intact", d.documentElement.getAttribute("data-theme") === "noir");

  console.log("");
  console.log(fails.length ? "FAILURES: " + fails.join(" | ") : "ALL E2E CHECKS PASS");
  process.exit(fails.length ? 1 : 0);
})();
