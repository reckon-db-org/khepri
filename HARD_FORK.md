# Hard fork plan (DORMANT)

This branch pre-stages a sovereign hard fork of Khepri for the Reckon stack.
**Nothing here is active.** `reckon-db` and `hecate-parksim` do not consume this
branch. It exists so that *if* we must hard-fork, it is one script + a review,
not a research project.

## Where we are today (the bridge, not the fork)

- `reckon` branch = stock khepri **0.17.2** + two clean patches:
  1. `khepri_tree:does_path_match/4` returns `false` instead of badmatch-crashing
     the Ra state machine when a trigger evaluates a condition against a
     just-deleted node (the poison-pill; upstream PR **#398**, issue **#405**).
  2. `khepri_machine` propagates `process_command` errors from readwrite
     transactions (upstream PR **#400**).
- `hecate-parksim` pins the immutable tag `v0.17.2-reckon.2` (built as an OCI
  image, so a git dep is fine). `reckon-db` itself still declares the stock hex
  `{khepri, "0.17.2}` — it cannot depend on a git fork because it is published
  to hex.

The bridge is minimal, canonical, and TODO'd to remove. It is **not** the fork.

## Triggers — hard-fork only when one trips

1. **Upstream stalls.** PR #398 is not merged into a released `v0.17.x` within a
   reasonable window (approved-in-principle already, so this is the unlikely one).
2. **A hex consumer of `reckon_db` can hit the poison-pill.** Today only parksim
   (OCI) needs the patched khepri, so the parksim-level git override reaches it.
   The moment any *hex* consumer of `reckon_db` needs the fix, the override no
   longer reaches them and we must ship a patched khepri *on hex* — i.e. fork.
3. **Divergence for performance / substance.** We choose to carry changes
   upstream will not take (perf, storage layout), or we start down the road of
   replacing khepri entirely and want a controlled base to peel away from.

## Execution (when a trigger trips)

Run `scripts/make-sovereign.sh` from this branch. It renames the OTP
application + hex package `khepri -> reckon_khepri` while keeping **every module
name** (`khepri`, `khepri_tree`, ...), so consumers keep calling `khepri:foo/N`
and only the dependency name changes. The rename touches only the `.app.src` and
the handful of internal `application:*(khepri, ...)` calls (4 at time of writing).

Then:
1. `rebar3 compile && rebar3 eunit`
2. version as `0.17.x-sovereign.N`, tag, push
3. publish to hex as `reckon_khepri`
4. `reckon_db`: `{khepri, "..."}` -> `{reckon_khepri, "..."}`; drop parksim's
   git override
5. keep an `upstream` remote and rebase the two patches onto each `v0.17.x`
   khepri release so the fork does not become an unmaintained snapshot

## Exit (the happy path)

If #398 + #400 land upstream and khepri cuts a `v0.17.x` release with them,
**delete this branch and the bridge**: bump `reckon_db` to the stock hex khepri
and remove parksim's override. Sovereignty was the fallback; upstream is the
destination.

## Note on "maybe skip khepri"

If the longer-term direction is to replace khepri (a custom Ra state machine, or
a different storage engine) for performance or control, this fork is the
*controlled base* to peel away from incrementally — not a big-bang rewrite.
That is a separate, larger effort; this branch just guarantees we are never
*blocked* by the dependency in the meantime.
