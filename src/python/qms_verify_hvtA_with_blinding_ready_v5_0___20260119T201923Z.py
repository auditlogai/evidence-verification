#!/usr/bin/env python3
"""
Fail-closed verifier for hvtA_comparisons__WITH_BLINDING.csv

Checks:
- all analysis-readiness invariants from v5_0 verifier still hold
- blinding columns exist and are complete
- mapping coverage is total (no NA)
- classification_correct is 0/1
- Node03 Positive Controls rows are flagged as manual override
"""

from __future__ import annotations
import argparse, csv, json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Tuple

SCRIPT_NAME = "qms_verify_hvtA_with_blinding_ready_v5_0.py"
SCRIPT_VERSION = "5.0.0"

@dataclass(frozen=True)
class Issue:
    level: str
    code: str
    message: str
    path: str

def _now():
    return datetime.now(timezone.utc).isoformat().replace("+00:00","Z")

def read_csv(p: Path) -> List[Dict[str,str]]:
    with p.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True, help="Path to hvtA_comparisons__WITH_BLINDING.csv")
    ap.add_argument("--out-dir", required=True, help="Output dir for verify log/summary")
    ap.add_argument("--non-strict", action="store_true")
    args = ap.parse_args()

    strict = not args.non_strict
    out_dir = Path(args.out_dir).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    issues: List[Issue] = []
    def err(code,msg,path):
        issues.append(Issue("ERROR",code,msg,path))
        if strict:
            raise RuntimeError(f"{code}: {msg} :: {path}")

    def info(code,msg,path):
        issues.append(Issue("INFO",code,msg,path))

    p = Path(args.csv).expanduser().resolve()
    if not p.exists():
        err("MISSING_INPUT", "CSV not found", p.as_posix())

    rows = read_csv(p)
    if len(rows) != 96:
        err("ROWCOUNT_UNEXPECTED", f"Expected 96 rows, got {len(rows)}", p.as_posix())

    # Required columns
    required_cols = [
        "hv_record_id","node_id","group","arm","compare_folder","candidate_label","pass_fail",
        "expected_match_candidate","expected_mismatch_candidate",
        "is_expected_match_candidate","observed_match_via_pass","classification_correct",
        "blinding_map_source_sha256","blinding_map_job_id","blinding_map_manual_override_flag"
    ]
    for c in required_cols:
        if c not in rows[0]:
            err("MISSING_COLUMN", f"Missing required column: {c}", p.as_posix())

    hv_ids = [r["hv_record_id"].strip() for r in rows]
    if any(not x for x in hv_ids):
        err("MISSING_HV_RECORD_ID", "Empty hv_record_id present", p.as_posix())
    if len(set(hv_ids)) != 96:
        err("HV_RECORD_ID_NOT_UNIQUE", "hv_record_id not unique", p.as_posix())

    nodes = sorted({r["node_id"].strip() for r in rows})
    if nodes != ["Node02_HVT_A_COMPLETED","Node03_HVT_A_COMPLETED"]:
        err("NODES_UNEXPECTED", f"Expected Node02+Node03, got {nodes}", p.as_posix())

    # Completeness: 2 operators per (node,group,arm,compare_folder) and both candidates per (node,group,arm)
    by_key: Dict[Tuple[str,str,str,str], int] = {}
    by_arm: Dict[Tuple[str,str,str], set] = {}

    for r in rows:
        node = r["node_id"].strip()
        group = r["group"].strip()
        arm = r["arm"].strip()
        cf = r["compare_folder"].strip()

        if not group or not arm or not cf:
            err("MISSING_FIELDS", "Missing group/arm/compare_folder", p.as_posix())

        by_key[(node,group,arm,cf)] = by_key.get((node,group,arm,cf), 0) + 1
        by_arm.setdefault((node,group,arm), set()).add(r["candidate_label"].strip())

        # Candidate label sanity
        if r["candidate_label"].strip() not in ("QMSv5_01","QMSv5_02"):
            err("BAD_CANDIDATE_LABEL", f"Unexpected candidate_label={r['candidate_label']}", p.as_posix())

        # PASS/FAIL sanity
        if r["pass_fail"].strip() not in ("PASS","FAIL"):
            err("BAD_PASSFAIL", f"Unexpected pass_fail={r['pass_fail']}", p.as_posix())

        # Blinding fields sanity
        if r["expected_match_candidate"].strip() not in ("QMSv5_01","QMSv5_02"):
            err("BAD_EXPECTED_MATCH", f"Bad expected_match_candidate={r['expected_match_candidate']}", p.as_posix())
        if r["expected_mismatch_candidate"].strip() not in ("QMSv5_01","QMSv5_02"):
            err("BAD_EXPECTED_MISMATCH", f"Bad expected_mismatch_candidate={r['expected_mismatch_candidate']}", p.as_posix())
        if r["expected_match_candidate"].strip() == r["expected_mismatch_candidate"].strip():
            err("EXPECTED_MATCH_EQUALS_MISMATCH", "expected_match_candidate == expected_mismatch_candidate", p.as_posix())

        if not r["blinding_map_source_sha256"].strip():
            err("MISSING_MAP_SHA", "blinding_map_source_sha256 empty", p.as_posix())

        if r["classification_correct"].strip() not in ("0","1"):
            err("BAD_CLASSIFICATION_CORRECT", f"classification_correct must be 0/1, got {r['classification_correct']}", p.as_posix())

    for k, n in by_key.items():
        if n != 2:
            err("OPERATOR_COUNT_BAD", f"Expected 2 rows for {k}, got {n}", p.as_posix())

    for k, s in by_arm.items():
        if s != {"QMSv5_01","QMSv5_02"}:
            err("CANDIDATE_PAIR_INCOMPLETE", f"Expected both candidates for {k}, got {sorted(s)}", p.as_posix())

    # Node03 Positive Controls must be manual override flag==1
    for r in rows:
        if r["node_id"].strip() == "Node03_HVT_A_COMPLETED" and r["group"].strip() == "Positive_Controls":
            if r["blinding_map_manual_override_flag"].strip() != "1":
                err("NODE03_PC_OVERRIDE_FLAG_MISSING", "Node03 Positive Controls must have manual override flag = 1", p.as_posix())

    info("OK","WITH_BLINDING analysis readiness verification passed", p.as_posix())

    summary = {
        "ts": _now(),
        "verifier": SCRIPT_NAME,
        "verifier_version": SCRIPT_VERSION,
        "csv": p.as_posix(),
        "rows": len(rows),
        "unique_hv_record_id": len(set(hv_ids)),
        "nodes": nodes,
        "errors": len([i for i in issues if i.level=="ERROR"]),
        "notes": "Fail-closed verification of merged WITH_BLINDING dataset."
    }

    logp = out_dir / "hvtA_with_blinding_verify_log.ndjson"
    sump = out_dir / "hvtA_with_blinding_verify_summary.json"

    with logp.open("w", encoding="utf-8") as f:
        f.write(json.dumps({"ts":summary["ts"],"event":"HVT_A_WITH_BLINDING_VERIFY_RUN","errors":summary["errors"]}, sort_keys=True)+"\n")
        for i in issues:
            f.write(json.dumps({"ts":_now(),"level":i.level,"code":i.code,"message":i.message,"path":i.path}, sort_keys=True)+"\n")

    with sump.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, sort_keys=True)

    print(f"Wrote: {logp}")
    print(f"Wrote: {sump}")

    return 0 if summary["errors"] == 0 else 1

if __name__ == "__main__":
    raise SystemExit(main())