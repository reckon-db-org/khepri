# reckon-db-org fork of Khepri

This is a **minimal patched fork** of [rabbitmq/khepri](https://github.com/rabbitmq/khepri),
maintained only to carry fixes reckon-db needs ahead of an upstream release.

- **Base:** upstream tag `v0.17.2` (the version reckon-db pins).
- **App version:** kept at `0.17.2` so it satisfies reckon-db's exact
  `{khepri, "0.17.2"}` constraint when consumed as a top-level git override.
- **Branch:** `reckon`. **Tags:** `v0.17.2-reckonN`.

## Divergence from upstream v0.17.2

### Patch 1 — `khepri_tree:does_path_match/4` must not crash on a deleted node

When a tree event trigger is evaluated for the **deletion** of a node
(`delete_matching_nodes` side effects), the path-condition branch of
`does_path_match/4` queried the node at the changed path. Upstream
hard-matched `{ok, #{CurrentPath := Node}} = find_matching_nodes(...)`;
for the just-deleted node `find_matching_nodes` returns
`{error, {khepri, node_not_found, _}}`, so the match **crashed the Khepri/Ra
state machine**. Because the offending `delete` command is persisted in the
Ra log, it was **replayed on every restart**, crashing the state machine
each time and leaving the store permanently unrecoverable
(`ra_server_sup` → `reached_max_restart_intensity`).

A path-condition that must query a node which no longer exists cannot be
met, so the path simply does not match. The patch wraps the lookup and
returns `false` for the absent-node / error case instead of badmatching.

Discovered via reckon-db's scavenge (retention) deleting event streams that
still had active subscription triggers registered, on the hecate-parksim
deployment.

**Upstream:** to be submitted as a PR to rabbitmq/khepri. Drop this fork
once a fixed release is available.
