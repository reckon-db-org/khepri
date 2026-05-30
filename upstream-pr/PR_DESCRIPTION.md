# Fix state machine crash when a path-condition trigger matches a deleted node

## Summary

A registered trigger whose event-filter path pattern contains a **condition**
(e.g. `#if_child_list_length{}`, `#if_data_matches{}`, a wildcard) at a
non-terminal position crashes the Khepri/Ra **state machine** when the matching
node is **deleted**. Because the offending `delete` command is persisted in the
Ra log, it is **replayed on every restart** and crashes again each time —
turning a transient delete into a **permanent, unrecoverable store outage**
(`ra_server_sup` → `reached_max_restart_intensity`).

## Root cause

To evaluate a path condition, `khepri_tree:does_path_match/4` looks up the tree
node at the current path:

```erlang
{ok, #{CurrentPath := Node}} = find_matching_nodes(
                                 Tree,
                                 lists:reverse([Component | ReversedPath]),
                                 TreeOptions),
```

When the trigger is evaluated for the **deletion** of that very node,
`find_matching_nodes/3` returns `{error, {khepri, node_not_found, _}}` for the
now-absent node. The hard `{ok, ...} =` match then fails with a `badmatch`,
crashing the state machine inside `ra_server_proc:handle_leader/2`.

Observed crash:

```
** State machine <store> terminating. Reason:
{badmatch,{error,{khepri,node_not_found,#{node_name => <<"...">>, ...}}}}
  khepri_tree:does_path_match/4        (khepri_tree.erl:804)
  khepri_machine:evaluate_trigger/6    (khepri_machine.erl)
  khepri_machine:add_trigger_side_effects/4
  khepri_machine:delete_matching_nodes/4
  ra_server_proc:handle_leader/2
```

Triggers with **literal-only** path patterns are unaffected — those are handled
by the literal-component clauses of `does_path_match/4` and never reach the node
lookup. That is why the existing delete-trigger tests (which use a literal path)
did not surface this.

## Fix

A path condition that must query a node which no longer exists cannot be met, so
the path simply does not match. `does_path_match/4` now returns `false` for the
absent-node / error case instead of badmatching. The post-lookup branch is
extracted into `does_matched_node_path_match/7`.

Behaviour change: a condition-bearing trigger no longer fires for the `delete`
of a matching node (the condition can't be evaluated against a node that is
gone). This matches the prior behaviour for any case where the condition no
longer holds, and is strictly preferable to crashing the state machine. Happy to
adjust if maintainers would rather evaluate the condition against the node's
pre-delete state.

## Test

`test/triggers.erl` gains
`deleting_a_node_matched_by_a_path_condition_does_not_crash_test_/0`, which
registers a trigger with a `#if_child_list_length{}` path condition, creates the
matching node, deletes it, and asserts the store remains responsive. Without the
fix this reproduces the `node_not_found` state-machine crash; with it the suite
is green (`80 tests, 0 failures`).

## How it was found

reckon-db's retention/scavenge deletes event streams that still have active
subscription triggers registered, which deterministically hit this path in
production.
