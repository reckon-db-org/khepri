#!/usr/bin/env bash
# make-sovereign.sh — execute the hard fork.
#
# Renames the hex PACKAGE + OTP APPLICATION `khepri` -> `reckon_khepri` while
# KEEPING every module name (`khepri`, `khepri_tree`, ...), so downstream code
# keeps calling `khepri:foo/N` unchanged and only the DEP name changes:
#     {khepri, "0.17.2"}  ->  {reckon_khepri, "X.Y.Z"}
#
# This is DORMANT until run. Do NOT run it unless a trigger in HARD_FORK.md has
# tripped. It is intentionally mechanical: rename the .app.src, fix the handful
# of internal `application:*(khepri, ...)` calls, retarget ex_doc. Idempotent-ish
# (safe to inspect the diff before committing).
set -euo pipefail
OLD=khepri
NEW=reckon_khepri
cd "$(dirname "$0")/.."

echo "== renaming OTP application ${OLD} -> ${NEW} (module names unchanged) =="

# 1. The .app.src (package/app identity).
git mv "src/${OLD}.app.src" "src/${NEW}.app.src"
sed -i -E "s/\{application,\s*${OLD}\b/{application, ${NEW}/" "src/${NEW}.app.src"

# 2. Internal app-name references (application:get_env/ensure_all_started/etc.).
#    Only the app ATOM changes; module calls (khepri_*:) must NOT be touched.
grep -rlE "application:[a-z_]+\(\s*${OLD}\b" src/ | while read -r f; do
  sed -i -E "s/(application:[a-z_]+\(\s*)${OLD}\b/\1${NEW}/g" "$f"
done

# 3. ex_doc / hex metadata source_url, if present.
[ -f rebar.config ] && sed -i -E "s#(reckon-db-org|rgfaber)/${OLD}#\1/${NEW}#g" rebar.config || true

echo "== remaining bare-atom 'khepri' app references to review by hand: =="
grep -rnE "\b${OLD}\b" src/*.app.src src/*.erl | grep -vE "khepri_[a-z]|%%|\"" | grep -iE "application|\bkhepri\b," || echo "  (none obvious)"

cat <<EOF

Next steps (manual, deliberate):
  1. rebar3 compile && rebar3 eunit          # prove the rename holds
  2. bump vsn in src/${NEW}.app.src (e.g. 0.17.2-sovereign.1)
  3. commit, tag, push to codeberg
  4. publish to hex as '${NEW}' (package name = app name in .app.src)
  5. in reckon_db: replace {khepri, "..."} with {${NEW}, "..."} in rebar.config
     (module calls unchanged); drop the parksim git-override entirely.
EOF
