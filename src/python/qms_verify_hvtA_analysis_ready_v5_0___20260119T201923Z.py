#!/usr/bin/env python3
"""
qms_verify_hvtA_analysis_ready_v5_0.py

Fail-closed verifier for "analysis readiness" of QMSv5 HVT-A dataset.

Goal:
  Ensure all data points used for statistical analyses are:
    - present (complete dataset)
    - parseable (valid types / timestamps)
    - consistent with current on-disk authoritative COMPARE_SUMMARY.json
    - extracted deterministically with no extractor errors/warnings

Explicitly NOT a forensic digest parity verifier:
  - It does not require HV_METADATA-embedded digests to match shared compare artifacts,
    because compare folders may have been overwritten by operator re-execution.
"""

from __future__ import annotations

import argparse
import csv
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Tuple, Optional


SCRIPT_NAME = "qms_verify_hvtA_analysis_ready_v5_0.py"
SCRIPT_VERSION = "5.0.0"

SUMMARY_PASS = "HASH PARITY PASS"
SUMMARY_FAIL = "HASH PARITY FAIL"


@dataclass(frozen=True)
class Issue:
    level: str  # INFO/WARN/ERROR
    code: str
    message: str
    path: str


def _now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _fail(msg: str) -> None:
    raise RuntimeError(msg)


def _load_json(p: Path) -> Dict[str, Any]:
    with p.open("r", encoding="utf-8") as f:
        return json.load(f)


def _read_csv(p: Path) -> List[Dict[str, str]]:
    with p.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def _parse_utc(ts: str) -> Optional[datetime]:
    if not ts:
        return None
    s = ts.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(s)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _summary_passfail(summary: Dict[str, Any]) -> str:
    res = str(summary.get("result") or "")
    if res == SUMMARY_PASS:
        return "PASS"
    if res == SUMMARY_FAIL:
        return "FAIL"
    return "UNKNOWN"


def verify(root: Path, extract_out: Path, strict: bool = True) -> Tuple[bool, List[Issue], Dict[str, Any]]:
    issues: List[Issue] = []

    def err(code: str, msg: str, path: str) -> None:
        issues.append(Issue("ERROR", code, msg, path))
        if strict:
            _fail(f"{code}: {msg} :: {path}")

    def info(code: str, msg: str, path: str) -> None:
        issues.append(Issue("INFO", code, msg, path))

    # Required files
    comparisons_csv = extract_out / "hvtA_comparisons.csv"
    artifacts_csv = extract_out / "hvtA_artifacts.csv"
    extract_log = extract_out / "hvtA_extract_log.ndjson"

    for p in (comparisons_csv, artifacts_csv, extract_log):
        if not p.exists():
            err("MISSING_INPUT", f"Missing required file: {p.name}", p.as_posix())

    # Extractor log must report 0 errors/warnings (fail-closed)
    try:
        with extract_log.open("r", encoding="utf-8") as f:
            header = json.loads(f.readline().strip())
        if int(header.get("errors", 0)) != 0:
            err("EXTRACTOR_ERRORS", f"Extractor errors != 0 ({header.get('errors')})", extract_log.as_posix())
        if int(header.get("warnings", 0)) != 0:
            err("EXTRACTOR_WARNINGS", f"Extractor warnings != 0 ({header.get('warnings')})", extract_log.as_posix())
    except Exception as e:
        err("EXTRACT_LOG_PARSE_FAIL", f"Failed to parse extractor log header: {e}", extract_log.as_posix())

    # Load CSVs
    try:
        comp = _read_csv(comparisons_csv)
        art = _read_csv(artifacts_csv)
    except Exception as e:
        err("CSV_PARSE_FAIL", f"Failed reading CSV: {e}", extract_out.as_posix())
        comp, art = [], []

    if not comp:
        err("NO_COMPARISONS", "hvtA_comparisons.csv has zero rows", comparisons_csv.as_posix())

    # Row-level basics
    hv_ids = [r.get("hv_record_id","").strip() for r in comp]
    if any(not x for x in hv_ids):
        err("MISSING_HV_RECORD_ID", "At least one comparisons row missing hv_record_id", comparisons_csv.as_posix())

    unique_ids = set(hv_ids)
    if len(unique_ids) != len(hv_ids):
        err("DUPLICATE_HV_RECORD_ID", "Duplicate hv_record_id detected in comparisons", comparisons_csv.as_posix())

    # Expected global size
    if len(comp) != 96:
        err("ROWCOUNT_UNEXPECTED", f"Expected 96 comparisons rows, got {len(comp)}", comparisons_csv.as_posix())

    # Expected nodes
    nodes = sorted({(r.get("node_id") or "").strip() for r in comp})
    if "Node02_HVT_A_COMPLETED" not in nodes or "Node03_HVT_A_COMPLETED" not in nodes:
        err("NODES_UNEXPECTED", f"Expected Node02_HVT_A_COMPLETED and Node03_HVT_A_COMPLETED, got {nodes}", comparisons_csv.as_posix())

    # Expected per-node counts: 48
    per_node = {}
    for r in comp:
        n = (r.get("node_id") or "").strip()
        per_node[n] = per_node.get(n, 0) + 1
    for n in ("Node02_HVT_A_COMPLETED", "Node03_HVT_A_COMPLETED"):
        if per_node.get(n, 0) != 48:
            err("NODE_ROWCOUNT_UNEXPECTED", f"Expected 48 rows for {n}, got {per_node.get(n,0)}", comparisons_csv.as_posix())

    # Completeness: each (node, group, arm, compare_folder) must have exactly 2 operators
    # and each (node, group, arm) must have both candidates 01 and 02
    by_key: Dict[Tuple[str,str,str,str], List[Dict[str,str]]] = {}
    by_arm: Dict[Tuple[str,str,str], set] = {}

    for r in comp:
        node = (r.get("node_id") or "").strip()
        group = (r.get("group") or "").strip()
        arm = (r.get("arm") or "").strip()
        cf = (r.get("compare_folder") or "").strip()

        if not group or not arm or not cf:
            err("MISSING_PATH_FIELDS", f"Missing group/arm/compare_folder for hv_record_id={r.get('hv_record_id')}", comparisons_csv.as_posix())

        by_key.setdefault((node, group, arm, cf), []).append(r)
        by_arm.setdefault((node, group, arm), set()).add(cf)

    for k, rows in by_key.items():
        if len(rows) != 2:
            err("OPERATOR_COUNT_BAD", f"Expected 2 operator rows for {k}, got {len(rows)}", comparisons_csv.as_posix())

    for k, cfs in by_arm.items():
        if not ("COMPARE_A_vs_QMSv5_01" in cfs and "COMPARE_A_vs_QMSv5_02" in cfs):
            err("CANDIDATES_MISSING", f"Expected both candidates for {k}, got {sorted(cfs)}", comparisons_csv.as_posix())

    # Validate time fields + pass_fail + on-disk summary consistency
    for r in comp:
        hv_path = (r.get("hv_metadata_path") or "").strip()
        if not hv_path:
            err("MISSING_HV_METADATA_PATH", f"Missing hv_metadata_path for hv_record_id={r.get('hv_record_id')}", comparisons_csv.as_posix())

        hvp = Path(hv_path)
        if not hvp.exists():
            err("HV_METADATA_MISSING_ON_DISK", "hv_metadata_path does not exist on disk", hv_path)

        # Duration parse
        dur_raw = (r.get("hv_duration_seconds") or "").strip()
        try:
            dur = float(dur_raw)
        except Exception:
            err("DURATION_NOT_NUMERIC", f"hv_duration_seconds not numeric: '{dur_raw}'", hv_path)

        # Start/end parse and duration agreement
        dt_s = _parse_utc((r.get("hv_start_utc") or "").strip())
        dt_e = _parse_utc((r.get("hv_end_utc") or "").strip())
        if not dt_s or not dt_e:
            err("HV_TIME_PARSE_FAIL", "hv_start_utc or hv_end_utc not parseable ISO8601 UTC", hv_path)

        computed = (dt_e - dt_s).total_seconds()
        if abs(computed - dur) > 2.0:
            err("DURATION_MISMATCH", f"duration mismatch: csv={dur} computed={computed}", hv_path)

        # pass_fail must be PASS/FAIL
        pf = (r.get("pass_fail") or "").strip()
        if pf not in ("PASS", "FAIL"):
            err("PASSFAIL_BAD", f"pass_fail must be PASS/FAIL, got '{pf}'", hv_path)

        # On-disk summary must exist and agree
        summary_path = hvp.parent / "COMPARE_SUMMARY.json"
        if not summary_path.exists():
            err("SUMMARY_MISSING_ON_DISK", "COMPARE_SUMMARY.json missing adjacent to HV_METADATA", summary_path.as_posix())

        try:
            sd = _load_json(summary_path)
        except Exception as e:
            err("SUMMARY_PARSE_FAIL", f"Failed to parse COMPARE_SUMMARY.json: {e}", summary_path.as_posix())
            continue

        spf = _summary_passfail(sd)
        if spf == "UNKNOWN":
            err("SUMMARY_RESULT_BAD", f"Unexpected summary result: {sd.get('result')}", summary_path.as_posix())

        if spf != pf:
            err("PASSFAIL_DISAGREE_WITH_SUMMARY", f"CSV pass_fail={pf} but summary={spf}", summary_path.as_posix())

        counts = sd.get("counts") or {}
        missing_ct = counts.get("missing_count")
        extras_ct = counts.get("extras_count")
        if not isinstance(missing_ct, int) or not isinstance(extras_ct, int):
            err("SUMMARY_COUNTS_TYPE_BAD", "missing_count/extras_count must be int", summary_path.as_posix())

        fps = sd.get("fingerprints") or {}
        match_val = fps.get("match")
        if not isinstance(match_val, bool):
            err("SUMMARY_FP_MATCH_TYPE_BAD", "fingerprints.match must be boolean", summary_path.as_posix())

        pass_criteria = (missing_ct == 0 and extras_ct == 0 and match_val is True)
        if spf == "PASS" and not pass_criteria:
            err("SUMMARY_INTERNAL_INCONSISTENT", "Summary says PASS but pass criteria not satisfied", summary_path.as_posix())
        if spf == "FAIL" and pass_criteria:
            err("SUMMARY_INTERNAL_INCONSISTENT", "Summary says FAIL but pass criteria satisfied", summary_path.as_posix())

    # Artifacts CSV sanity: each row must point to an existing hv_record_id
    if not art:
        err("NO_ARTIFACT_ROWS", "hvtA_artifacts.csv has zero rows", artifacts_csv.as_posix())

    comp_ids = set(unique_ids)
    for a in art:
        hid = (a.get("hv_record_id") or "").strip()
        if not hid:
            err("ART_ROW_MISSING_HV_ID", "Artifact row missing hv_record_id", artifacts_csv.as_posix())
        if hid not in comp_ids:
            err("ART_ROW_UNKNOWN_HV_ID", f"Artifact hv_record_id not found in comparisons: {hid}", artifacts_csv.as_posix())

    info("OK", "Analysis readiness verification passed", root.as_posix())

    summary = {
        "ts": _now(),
        "verifier": SCRIPT_NAME,
        "verifier_version": SCRIPT_VERSION,
        "root": root.as_posix(),
        "extract_out": extract_out.as_posix(),
        "comparisons_rows": len(comp),
        "artifacts_rows": len(art),
        "unique_hv_record_id": len(unique_ids),
        "nodes": nodes,
        "node_counts": per_node,
        "errors": len([i for i in issues if i.level == "ERROR"]),
        "notes": "Analysis readiness verifier: completeness + parseability + summary consistency; tolerates overwritten shared compare artifacts.",
    }
    passed = summary["errors"] == 0
    return passed, issues, summary


def main() -> int:
    ap = argparse.ArgumentParser(description="Fail-closed analysis readiness verifier for QMSv5 HVT-A dataset.")
    ap.add_argument("--root", required=True, help="Root directory (e.g., /Users/rosmontos/QMSv5.StageIV/EXEC_HVT_A_FINAL)")
    ap.add_argument("--extract-out", default=None, help="Path to __EXTRACT_OUT__ (default: <root>/__EXTRACT_OUT__)")
    ap.add_argument("--out-dir", default=None, help="Output directory (default: <root>/__VERIFY_READY__)")
    ap.add_argument("--non-strict", action="store_true", help="Do not stop on first error (NOT RECOMMENDED).")
    args = ap.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.exists() or not root.is_dir():
        print(f"ERROR: invalid --root: {root}")
        return 2

    extract_out = Path(args.extract_out).expanduser().resolve() if args.extract_out else (root / "__EXTRACT_OUT__")
    if not extract_out.exists() or not extract_out.is_dir():
        print(f"ERROR: invalid --extract-out: {extract_out}")
        return 2

    out_dir = Path(args.out_dir).expanduser().resolve() if args.out_dir else (root / "__VERIFY_READY__")
    out_dir.mkdir(parents=True, exist_ok=True)

    strict = not args.non_strict

    try:
        passed, issues, summary = verify(root, extract_out, strict=strict)
    except RuntimeError as e:
        passed = False
        issues = [Issue("ERROR", "STRICT_STOP", str(e), root.as_posix())]
        summary = {
            "ts": _now(),
            "verifier": SCRIPT_NAME,
            "verifier_version": SCRIPT_VERSION,
            "root": root.as_posix(),
            "extract_out": extract_out.as_posix(),
            "errors": 1,
            "strict_stop": str(e),
        }

    # Write outputs
    log_path = out_dir / "hvtA_analysis_ready_log.ndjson"
    sum_path = out_dir / "hvtA_analysis_ready_summary.json"

    with log_path.open("w", encoding="utf-8") as f:
        f.write(json.dumps({
            "ts": summary.get("ts"),
            "event": "HVT_A_ANALYSIS_READY_VERIFY_RUN",
            "verifier": SCRIPT_NAME,
            "verifier_version": SCRIPT_VERSION,
            "root": root.as_posix(),
            "extract_out": extract_out.as_posix(),
            "errors": summary.get("errors", 0),
        }, sort_keys=True) + "\n")
        for i in issues:
            f.write(json.dumps({"ts": _now(), "level": i.level, "code": i.code, "message": i.message, "path": i.path}, sort_keys=True) + "\n")

    with sum_path.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, sort_keys=True)

    print(f"Wrote: {log_path}")
    print(f"Wrote: {sum_path}")

    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())