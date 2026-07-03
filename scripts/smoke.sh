#!/usr/bin/env bash
# Earmark post-deploy smoke test.
#   ./scripts/smoke.sh https://<your-app>.fly.dev
# Exits non-zero on the first failure. Safe to run repeatedly, but note:
# it writes and then deletes a test snapshot, so only run it BEFORE real
# use, or against a fresh deployment.
set -u
BASE="${1:?usage: smoke.sh https://your-app.fly.dev}"
BASE="${BASE%/}"
pass=0; fail=0
ok(){ echo "PASS  $1"; pass=$((pass+1)); }
bad(){ echo "FAIL  $1"; fail=$((fail+1)); }

code(){ curl -s -o /dev/null -w '%{http_code}' "$@"; }

# 1. health (Fly checks + client probe alias)
[ "$(code "$BASE/healthz")" = "200" ]      && ok "healthz 200" || bad "healthz"
[ "$(code "$BASE/api/healthz")" = "200" ]  && ok "api/healthz 200 (client mode probe)" || bad "api/healthz"

# 2. UI served, correct build
body=$(curl -s "$BASE/")
echo "$body" | grep -q "Earmark"      && ok "UI served" || bad "UI served"
echo "$body" | grep -q "detectMode"   && ok "UI is the API-aware build" || bad "UI build (missing detectMode — stale image?)"
echo "$body" | grep -q 'data-theme'   && ok "theme system present" || bad "theme system"

# 3. HTTPS enforced (Fly force_https)
if [ "${BASE#https://}" != "$BASE" ]; then
  insecure="http://${BASE#https://}"
  c=$(code -L -o /dev/null "$insecure" || true)
  c2=$(curl -s -o /dev/null -w '%{http_code}' "$insecure")
  case "$c2" in 301|302|308) ok "http → https redirect ($c2)";; *) bad "http redirect (got $c2)";; esac
fi

# 4. workspace persistence round-trip
snap='{"v":1,"calls":[],"flags":[],"phrases":[{"id":1,"text":"smoke-test"}],"team":[],"audit":[],"meta":{"signedIn":false,"theme":"aura","smoke":true}}'
[ "$(code -X PUT -H 'content-type: application/json' -d "$snap" "$BASE/api/workspace")" = "200" ] \
  && ok "PUT snapshot" || bad "PUT snapshot"
got=$(curl -s "$BASE/api/workspace")
[ "$got" = "$snap" ] && ok "GET round-trips byte-identical" || bad "GET round-trip"
[ "$(code -X POST -H 'content-type: application/json' -d "$snap" "$BASE/api/workspace")" = "200" ] \
  && ok "POST alias (beacon flush)" || bad "POST alias"

# 5. validation still enforced in prod
[ "$(code -X PUT -d '' "$BASE/api/workspace")" = "400" ]            && ok "rejects empty (400)" || bad "empty→400"
[ "$(code -X PUT -d 'not json' "$BASE/api/workspace")" = "400" ]    && ok "rejects non-JSON (400)" || bad "nonjson→400"

# 6. clean up the smoke snapshot so first real use starts fresh
[ "$(code -X DELETE "$BASE/api/workspace")" = "200" ] && ok "DELETE cleans up" || bad "DELETE"
[ "$(code "$BASE/api/workspace")" = "404" ] && ok "workspace empty after cleanup" || bad "cleanup verify"

echo
echo "$pass passed, $fail failed"
[ $fail -eq 0 ] && echo "SMOKE TEST PASS — open $BASE and sign in." || exit 1
