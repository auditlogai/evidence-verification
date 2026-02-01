#!/usr/bin/env python3
"""
qms_blinding_map_to_csv_and_merge_v5_1.py

Parses SentinelQMSv5 blinding-map markdown files and produces:
  1) blinding_map_parsed.csv
  2) hvtA_comparisons__WITH_BLINDING.csv  (original comparisons unchanged)

Design goals:
- Deterministic, fail-closed
- Provenance-safe (no overwrites of original extraction CSV)
- Correctly derives expected MATCH/MISMATCH without assuming candidate path == A_src

Key corrections vs v5_0:
- Expected MATCH is inferred using packet-type semantics (TAMPER vs PC vs baseline-like)
- Tight tamper detection: requires explicit "TAMPER" marker (not "HMAC" alone)
- Self-identifying errors: any ambiguity prints job/group/arm + src strings

Node03 Positive Controls override:
- StageIV map has pending entries for Node03 PC arms.
- RUN029 PC map provides active mappings for those arms and overrides pending.

Authoritative merge key:
- node_id, group, arm  (node-scope + arm identity)
- candidate_label derived from compare_folder ("QMSv5_01"/"QMSv5_02")
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


SCRIPT_NAME = "qms_blinding_map_to_csv_and_merge_v5_1.py"
SCRIPT_VERSION = "5.1.0"

MAP_SCHEMA = "SentinelQMSv5_BlindingMap@1.0"


# ------------------------
# Utilities
# ------------------------

def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_text(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def read_csv_rows(p: Path) -> List[Dict[str, str]]:
    with p.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def write_csv(p: Path, rows: List[Dict[str, Any]], fieldnames: List[str]) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fieldnames})

def norm_group(g: str) -> str:
    x = (g or "").strip()
    if x.startswith("IIIA_"):
        return x[len("IIIA_"):]
    return x

# ------------------------
# Markdown JSON extraction
# ------------------------

def extract_json_codeblock(md: str) -> Dict[str, Any]:
    # Prefer fenced ```json blocks
    m = re.search(r"```json\s*(\{.*?\})\s*```", md, flags=re.DOTALL)
    if m:
        return json.loads(m.group(1))

    # Fallback: first JSON object
    m2 = re.search(r"(\{.*?\})", md, flags=re.DOTALL)
    if not m2:
        raise ValueError("No JSON object found in markdown")
    return json.loads(m2.group(1))


def extract_json_fragments(md: str) -> List[Dict[str, Any]]:
    # For PC override file: typically contains JSON object fragments
    blocks = re.findall(r"\{[^{}]*\"group\"[^{}]*\}", md, flags=re.DOTALL)
    out: List[Dict[str, Any]] = []
    for b in blocks:
        try:
            out.append(json.loads(b))
        except Exception:
            continue
    if out:
        return out

    # Fallback: fenced json (possibly fragment list)
    m = re.search(r"```json\s*(.*?)\s*```", md, flags=re.DOTALL)
    if m:
        txt = m.group(1).strip()
        if not txt.startswith("["):
            txt2 = "[" + txt.strip().strip(",") + "]"
        else:
            txt2 = txt
        return json.loads(txt2)

    return []


# ------------------------
# Packet-type inference
# ------------------------

def _u(s: str) -> str:
    return (s or "").upper()


def _looks_tamper(s: str) -> bool:
    x = _u(s)
    # Tight: require explicit tamper marker
    return ("WORKING_TAMPER" in x) or ("TAMPER" in x)


def _looks_pc(s: str) -> bool:
    x = _u(s)
    # Tight-ish PC cues commonly present in your naming
    return ("PC_REEXPORT" in x) or ("_PC" in x and "PACKET" in x) or ("PC_" in x and "PACKET" in x)


def _a_type(a_src: str) -> str:
    if _looks_tamper(a_src):
        return "TAMPER"
    if _looks_pc(a_src):
        return "PC"
    return "BASELINE"


def determine_expected_match(A_src: str, q1: str, q2: str) -> Tuple[str, str, str]:
    """
    Returns:
      (expected_match_candidate_label, expected_mismatch_candidate_label, rule)

    Canonical logic:
      - If A is TAMPER: expected MATCH is the tamper-like candidate.
      - If A is PC: expected MATCH is the pc-like candidate; mismatch typically tamper-like.
      - If A is BASELINE-like: expected MATCH is the non-tamper candidate; mismatch is tamper.
    """
    a = (A_src or "").strip()
    s1 = (q1 or "").strip()
    s2 = (q2 or "").strip()
    if not a or not s1 or not s2:
        raise ValueError("Missing A_src or candidate src")

    a_kind = _a_type(a)

    c1_t, c2_t = _looks_tamper(s1), _looks_tamper(s2)
    c1_pc, c2_pc = _looks_pc(s1), _looks_pc(s2)

    # --- A is tamper: match tamper candidate ---
    if a_kind == "TAMPER":
        if c1_t and not c2_t:
            return ("QMSv5_01", "QMSv5_02", "A=TAMPER -> match=tamper")
        if c2_t and not c1_t:
            return ("QMSv5_02", "QMSv5_01", "A=TAMPER -> match=tamper")
        raise ValueError("Ambiguous: A is TAMPER but candidates not uniquely tamper")

    # --- A is PC: match PC candidate; otherwise fallback to non-tamper as match ---
    if a_kind == "PC":
        if c1_pc and not c2_pc:
            return ("QMSv5_01", "QMSv5_02", "A=PC -> match=pc")
        if c2_pc and not c1_pc:
            return ("QMSv5_02", "QMSv5_01", "A=PC -> match=pc")

        # fallback: if exactly one is tamper, the other is match
        if c1_t and not c2_t:
            return ("QMSv5_02", "QMSv5_01", "A=PC -> match=non-tamper fallback")
        if c2_t and not c1_t:
            return ("QMSv5_01", "QMSv5_02", "A=PC -> match=non-tamper fallback")

        raise ValueError("Ambiguous: A is PC but candidates not uniquely PC or tamper-distinguishable")

    # --- Baseline-like: mismatch=tamper; match=non-tamper ---
    if c1_t and not c2_t:
        return ("QMSv5_02", "QMSv5_01", "A=BASELINE -> match=non-tamper")
    if c2_t and not c1_t:
        return ("QMSv5_01", "QMSv5_02", "A=BASELINE -> match=non-tamper")

    # If neither looks tamper, we refuse to guess.
    raise ValueError("Ambiguous: BASELINE arm but neither candidate looks tamper")


# ------------------------
# Blinding map parsing
# ------------------------

def load_blinding_map_stage(md_path: Path) -> Dict[str, Any]:
    md = read_text(md_path)
    obj = extract_json_codeblock(md)
    if obj.get("schema") != MAP_SCHEMA:
        raise ValueError(f"Unexpected schema in {md_path.name}: {obj.get('schema')}")
    return obj


def _node_scope_from_job(job_id: str) -> str:
    if job_id == "StageIV_Node02":
        return "Node02_HVT_A_COMPLETED"
    if job_id == "StageIV_Node03":
        return "Node03_HVT_A_COMPLETED"
    if job_id == "StageIIIA":
        return "ALL"
    return "ALL"


def flatten_map(map_obj: Dict[str, Any], source_path: Path) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    src_sha = sha256_file(source_path)

    jobs = map_obj.get("jobs") or []
    if not isinstance(jobs, list):
        raise ValueError("jobs must be list")

    for job in jobs:
        if not isinstance(job, dict):
            continue

        job_id = str(job.get("job_id") or "")
        job_status = (job.get("status") or "active").lower()
        node_scope = _node_scope_from_job(job_id)

        arms = job.get("arms") or []
        if not isinstance(arms, list):
            continue

        for a in arms:
            if not isinstance(a, dict):
                continue

            group = norm_group(a.get("group"))
            arm = a.get("arm")
            a_status = (a.get("status") or job_status or "active").lower()

            # pending entries are included as pending placeholders (for override later)
            if a_status == "pending":
                rows.append({
                    "node_scope": node_scope,
                    "group": group,
                    "arm": arm,
                    "status": "pending",
                    "expected_match_candidate": "",
                    "expected_mismatch_candidate": "",
                    "rule": "",
                    "A_src": a.get("A_src", ""),
                    "QMSv5_01_src": a.get("QMSv5_01_src", ""),
                    "QMSv5_02_src": a.get("QMSv5_02_src", ""),
                    "map_job_id": job_id,
                    "map_source_file": source_path.as_posix(),
                    "map_source_sha256": src_sha,
                })
                continue

            A_src = a.get("A_src", "")
            q1 = a.get("QMSv5_01_src", "")
            q2 = a.get("QMSv5_02_src", "")

            try:
                exp_match, exp_mismatch, rule = determine_expected_match(A_src, q1, q2)
            except Exception as e:
                raise ValueError(
                    f"{e} :: job_id={job_id} node_scope={node_scope} group={group} arm={arm} "
                    f"A_src={A_src} QMSv5_01_src={q1} QMSv5_02_src={q2}"
                )

            rows.append({
                "node_scope": node_scope,
                "group": group,
                "arm": arm,
                "status": "active",
                "expected_match_candidate": exp_match,
                "expected_mismatch_candidate": exp_mismatch,
                "rule": rule,
                "A_src": A_src,
                "QMSv5_01_src": q1,
                "QMSv5_02_src": q2,
                "map_job_id": job_id,
                "map_source_file": source_path.as_posix(),
                "map_source_sha256": src_sha,
            })

    return rows


def parse_pc_override_fragments(pc_md_path: Path) -> List[Dict[str, Any]]:
    md = read_text(pc_md_path)
    frags = extract_json_fragments(md)
    if not frags:
        raise ValueError("Could not extract PC override fragments")
    src_sha = sha256_file(pc_md_path)

    out: List[Dict[str, Any]] = []
    for a in frags:
        group = norm_group(a.get("group"))
        arm = a.get("arm")
        A_src = a.get("A_src", "")
        q1 = a.get("QMSv5_01_src", "")
        q2 = a.get("QMSv5_02_src", "")
        try:
            exp_match, exp_mismatch, rule = determine_expected_match(A_src, q1, q2)
        except Exception as e:
            raise ValueError(
                f"{e} :: job_id=StageIV_Node03_PC_OVERRIDE group={group} arm={arm} "
                f"A_src={A_src} QMSv5_01_src={q1} QMSv5_02_src={q2}"
            )

        out.append({
            "node_scope": "Node03_HVT_A_COMPLETED",
            "group": group,
            "arm": arm,
            "status": "active",
            "expected_match_candidate": exp_match,
            "expected_mismatch_candidate": exp_mismatch,
            "rule": rule,
            "A_src": A_src,
            "QMSv5_01_src": q1,
            "QMSv5_02_src": q2,
            "map_job_id": "StageIV_Node03_PC_OVERRIDE",
            "map_source_file": pc_md_path.as_posix(),
            "map_source_sha256": src_sha,
            "map_manual_override_flag": 1,
        })
    return out


# ------------------------
# Merge into comparisons
# ------------------------

def candidate_label_from_compare_folder(compare_folder: str) -> str:
    # compare_folder is "COMPARE_A_vs_QMSv5_01" or "..._02"
    if compare_folder.endswith("_01"):
        return "QMSv5_01"
    if compare_folder.endswith("_02"):
        return "QMSv5_02"
    return ""


def main() -> int:
    ap = argparse.ArgumentParser(description="Parse blinding maps and merge into hvtA_comparisons.csv (provenance-safe, fail-closed).")
    ap.add_argument("--stage-iiia-map", required=True)
    ap.add_argument("--stage-iv-map", required=True)
    ap.add_argument("--node03-pc-override", required=True)
    ap.add_argument("--comparisons-csv", required=True)
    ap.add_argument("--out-dir", required=True)
    args = ap.parse_args()

    stage_iiia = Path(args.stage_iiia_map).expanduser().resolve()
    stage_iv = Path(args.stage_iv_map).expanduser().resolve()
    node03_pc = Path(args.node03_pc_override).expanduser().resolve()
    comp_csv = Path(args.comparisons_csv).expanduser().resolve()
    out_dir = Path(args.out_dir).expanduser().resolve()

    for p in (stage_iiia, stage_iv, node03_pc, comp_csv):
        if not p.exists():
            print(f"ERROR: missing file: {p}")
            return 2

    iiia_obj = load_blinding_map_stage(stage_iiia)
    iv_obj = load_blinding_map_stage(stage_iv)

    iiia_rows = flatten_map(iiia_obj, stage_iiia)
    iv_rows = flatten_map(iv_obj, stage_iv)
    pc_rows = parse_pc_override_fragments(node03_pc)

    # Build mapping dictionary with override precedence:
    # - base maps fill mapping
    # - PC override overwrites Node03 pending entries
    mapping: Dict[Tuple[str, str, str], Dict[str, Any]] = {}

    def put(row: Dict[str, Any], force: bool = False) -> None:
        key = (row["node_scope"], row.get("group", ""), row.get("arm", ""))
        if key not in mapping:
            mapping[key] = row
            return

        if force:
            mapping[key] = row
            return

        # If existing pending and new active, overwrite
        if mapping[key].get("status") == "pending" and row.get("status") == "active":
            mapping[key] = row
            return

        # If both active but conflict, fail-closed
        if mapping[key].get("status") == "active" and row.get("status") == "active":
            if mapping[key].get("expected_match_candidate") != row.get("expected_match_candidate"):
                raise ValueError(f"Conflicting active mappings for {key}")
        # otherwise keep existing

    for r in iiia_rows:
        put(r)
    for r in iv_rows:
        put(r)
    for r in pc_rows:
        put(r, force=True)  # explicit override

    # Read comparisons and merge
    comp_rows = read_csv_rows(comp_csv)
    if not comp_rows:
        print("ERROR: comparisons CSV has no rows")
        return 2

    out_rows: List[Dict[str, Any]] = []
    missing_map: List[Tuple[str, str, str]] = []

    for r in comp_rows:
        node = (r.get("node_id") or "").strip()
        group = norm_group((r.get("group") or "").strip())
        arm = (r.get("arm") or "").strip()
        compare_folder = (r.get("compare_folder") or "").strip()

        candidate_label = (r.get("candidate_label") or "").strip()
        if not candidate_label:
            candidate_label = candidate_label_from_compare_folder(compare_folder)

        key_node = (node, group, arm)
        key_all = ("ALL", group, arm)

        m = mapping.get(key_node) or mapping.get(key_all)
        if not m or m.get("status") != "active":
            missing_map.append((node, group, arm))
            continue

        expected_match = m["expected_match_candidate"]
        expected_mismatch = m["expected_mismatch_candidate"]

        is_expected_match = 1 if candidate_label == expected_match else 0
        is_expected_mismatch = 1 if candidate_label == expected_mismatch else 0

        observed_match_via_pass = 1 if (r.get("pass_fail") == "PASS") else 0
        classification_correct = 1 if (observed_match_via_pass == is_expected_match) else 0

        merged = dict(r)
        merged.update({
            "blinding_map_status": m.get("status", ""),
            "expected_match_candidate": expected_match,
            "expected_mismatch_candidate": expected_mismatch,
            "is_expected_match_candidate": is_expected_match,
            "is_expected_mismatch_candidate": is_expected_mismatch,
            "observed_match_via_pass": observed_match_via_pass,
            "classification_correct": classification_correct,
            "blinding_map_rule": m.get("rule", ""),
            "blinding_map_source_file": m.get("map_source_file", ""),
            "blinding_map_source_sha256": m.get("map_source_sha256", ""),
            "blinding_map_job_id": m.get("map_job_id", ""),
            "blinding_map_manual_override_flag": m.get("map_manual_override_flag", 0),
            "blinding_parser_script": SCRIPT_NAME,
            "blinding_parser_version": SCRIPT_VERSION,
        })
        out_rows.append(merged)

    if missing_map:
        uniq = sorted(set(missing_map))
        raise RuntimeError(f"Missing active blinding mappings for {len(uniq)} keys. Example: {uniq[:8]}")

    # Write mapping table (active only)
    parsed_rows = sorted(
        [v for v in mapping.values() if v.get("status") == "active"],
        key=lambda x: (x["node_scope"], x.get("group", ""), x.get("arm", ""))
    )

    parsed_fields = [
        "node_scope", "group", "arm", "status",
        "expected_match_candidate", "expected_mismatch_candidate",
        "rule",
        "A_src", "QMSv5_01_src", "QMSv5_02_src",
        "map_job_id", "map_source_file", "map_source_sha256",
        "map_manual_override_flag",
    ]

    out_dir.mkdir(parents=True, exist_ok=True)
    write_csv(out_dir / "blinding_map_parsed.csv", parsed_rows, parsed_fields)

    # Write merged comparisons
    orig_fields = list(comp_rows[0].keys())
    new_fields = [
        "blinding_map_status", "expected_match_candidate", "expected_mismatch_candidate",
        "is_expected_match_candidate", "is_expected_mismatch_candidate",
        "observed_match_via_pass", "classification_correct",
        "blinding_map_rule",
        "blinding_map_source_file", "blinding_map_source_sha256", "blinding_map_job_id",
        "blinding_map_manual_override_flag",
        "blinding_parser_script", "blinding_parser_version"
    ]
    write_csv(out_dir / "hvtA_comparisons__WITH_BLINDING.csv", out_rows, orig_fields + new_fields)

    print(f"Wrote: {out_dir / 'blinding_map_parsed.csv'}")
    print(f"Wrote: {out_dir / 'hvtA_comparisons__WITH_BLINDING.csv'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())