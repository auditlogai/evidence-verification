# KEY_STAGEIV_ANCHORS

This document maps the *ordinal position* of each Stage IV anchor per node to its execution meaning.

**Authoritative data source:** `provenance/ANCHOR_INDEX_StageIV.ndjson`

## Deterministic ordering rule
For each node separately:
1) Sort by `block_height` ascending
2) The resulting list positions define the run meaning below.

No TXIDs, blocks, or payloads are repeated here. Refer to `ANCHOR_INDEX_StageIV.ndjson`.

---

## Node_02 (Windows) - Stage IV Anchors (positions 1-9)

| Position | Description |
|---------:|-------------|
| 1 | MULTI Baseline A |
| 2 | AuditLog.AI Baseline A |
| 3 | MULTI Baseline B (repeatability) |
| 4 | AuditLog.AI Baseline B (repeatability) |
| 5 | MULTI Tamper (HMAC deletion) |
| 6 | AuditLog.AI Tamper (HMAC deletion) |
| 7 | MULTI Positive Control (USS) |
| 8 | AuditLog.AI Positive Control (USS) |
| 9 | Aggregator |

---

## Node_03 (Windows) - Stage IV Anchors (positions 1-9)

| Position | Description |
|---------:|-------------|
| 1 | MULTI Baseline A |
| 2 | AuditLog.AI Baseline A |
| 3 | MULTI Baseline B (repeatability) |
| 4 | AuditLog.AI Baseline B (repeatability) |
| 5 | MULTI Tamper (HMAC deletion) |
| 6 | AuditLog.AI Tamper (HMAC deletion) |
| 7 | Positive Control (USS) - run 10 |
| 8 | Positive Control (USS) - run 11 |
| 9 | Aggregator - run 12 |

**Note (pre-Stage IV internal testing):**
Node_03 had QMSv4 internal testing runs (7/8/9) to confirm the v4 enumeration failure was reproducible (as disclosed in Amendment A). Those runs are not part of the Stage IV anchor mapping above.