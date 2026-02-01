#!/usr/bin/env python3
"""
qms_extract_hvtA_metadata_v5_3_1.py

Deterministic extractor for QMSv5 HVT-A HV_METADATA JSON into R-ready CSVs.

v5.3.1 changes (vs 5.3.0):
  - PASS/FAIL is authoritative from adjacent COMPARE_SUMMARY.json:
      result == "HASH PARITY PASS" | "HASH PARITY FAIL"
  - Fail-closed strict mode enabled by default:
      any discrepancy or missing required artifact => ERROR and stop
  - Node ID derived per HV_METADATA path:
      supports Node02_HVT_A_COMPLETED / Node03_HVT_A_COMPLETED and mixed roots
  - Optional SWAP_CANDIDATES.ndjson detection (Stage IIIA fail cases)
  - Adds hv_validator_name_raw + hv_validator_name_norm (no mutation of source)
  - Adds is_architect_operator + is_blinded_primary_operator flags

Outputs (CSV, R-ready):
  1) hvtA_comparisons.csv
  2) hvtA_artifacts.csv
  3) hvtA_extract_log.ndjson

Determinism constraints:
  - stable file discovery ordering (lexicographic by posix path)
  - stable row ordering
  - stable column order
  - read-only scanning; mtimes not used for ordering
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

SCRIPT_NAME = "qms_extract_hvtA_metadata_v5_3_1.py"
SCRIPT_VERSION = "5.3.1"

EMPTY_SHA256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
EMPTY_R160 = "b472a266d0bd89c13706a4132ccfb16f7c3b9fcb"

ESF_FILENAME = "ESF_SET_EQUIVALENCE_QMS.json"
SUMMARY_FILENAME = "COMPARE_SUMMARY.json"
SWAP_CANDIDATES_FILENAME = "SWAP_CANDIDATES.ndjson"

SUMMARY_PASS = "HASH PARITY PASS"
SUMMARY_FAIL = "HASH PARITY FAIL"


@dataclass(frozen=True)
class ExtractIssue:
    level: str  # "WARN" | "ERROR" | "INFO"
    code: str
    message: str
    hv_metadata_path: str


def _normalize_slashes(s: str) -> str:
    return (s or "").replace("\\", "/")


def _safe_get(d: Dict[str, Any], key: str, default: Any = None) -> Any:
    return d.get(key, default)


def _load_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def _iter_hv_metadata_files(root: Path) -> List[Path]:
    return sorted(root.rglob("HV_METADATA_QMSv5___*.json"), key=lambda p: p.as_posix())


def _utc_parse(ts: Optional[str]) -> Optional[datetime]:
    if ts is None:
        return None
    s = ts.strip()
    if not s:
        return None
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(s)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _ripemd160_hex_of_bytes(b: bytes) -> Optional[str]:
    # macOS python builds commonly support this; strict per your environment.
    try:
        h = hashlib.new("ripemd160")
    except Exception:
        return None
    h.update(b)
    return h.hexdigest()


def _r160_of_sha256_hex(sha256_hex: str) -> Optional[str]:
    try:
        b = bytes.fromhex(sha256_hex)
    except Exception:
        return None
    return _ripemd160_hex_of_bytes(b)


def _artifact_role_from_path(p: str) -> str:
    base = os.path.basename(_normalize_slashes(p))
    if base == SUMMARY_FILENAME:
        return "COMPARE_SUMMARY"
    if base == "MISSING_GLOBAL.ndjson":
        return "MISSING_GLOBAL"
    if base == "EXTRAS_GLOBAL.ndjson":
        return "EXTRAS_GLOBAL"
    if base == ESF_FILENAME:
        return "ESF_SET_EQUIVALENCE"
    if base == SWAP_CANDIDATES_FILENAME:
        return "SWAP_CANDIDATES"
    return f"OTHER:{base}"


def _build_hv_record_id(compare_dir: str, ts_generated_utc: str, hv_final_sha256: str) -> str:
    s = f"{compare_dir}|{ts_generated_utc}|{hv_final_sha256}".encode("utf-8")
    return hashlib.sha256(s).hexdigest()


def _find_compare_folder_index(parts: List[str]) -> Optional[int]:
    for i, p in enumerate(parts):
        if p.startswith("COMPARE_A_vs_QMSv5_"):
            return i
    return None


def _derive_path_fields(root: Path, hv_path: Path) -> Tuple[Optional[str], Optional[str], Optional[str], Optional[str], str]:
    rel = hv_path.relative_to(root)
    rel_parts = list(rel.parts)
    relpath_str = rel.as_posix()

    idx = _find_compare_folder_index(rel_parts)
    if idx is None:
        group = rel_parts[0] if len(rel_parts) > 0 else None
        arm = rel_parts[1] if len(rel_parts) > 1 else None
        compare_folder = rel_parts[2] if len(rel_parts) > 2 else None
    else:
        group = rel_parts[idx - 2] if idx >= 2 else (rel_parts[0] if rel_parts else None)
        arm = rel_parts[idx - 1] if idx >= 1 else (rel_parts[1] if len(rel_parts) > 1 else None)
        compare_folder = rel_parts[idx]

    candidate_label = None
    if compare_folder and "_vs_" in compare_folder:
        candidate_label = compare_folder.split("_vs_", 1)[1]

    return (group, arm, compare_folder, candidate_label, relpath_str)


def _parse_compare_dir_windows(compare_dir: str) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    if not compare_dir:
        return (None, None, None)
    parts = [p for p in _normalize_slashes(compare_dir).split("/") if p]
    if len(parts) < 3:
        return (None, None, None)
    return (parts[-3], parts[-2], parts[-1])


def _derive_node_id_from_hv_path(root: Path, hv_path: Path) -> Optional[str]:
    rel = hv_path.relative_to(root)
    parts = list(rel.parts)

    # Prefer exact stage node folder names
    for p in parts:
        if p in ("Node02_HVT_A_COMPLETED", "Node03_HVT_A_COMPLETED"):
            return p

    # Fallback patterns
    for p in parts:
        if p.startswith("Node02"):
            return "Node02_HVT_A_COMPLETED"
        if p.startswith("Node03"):
            return "Node03_HVT_A_COMPLETED"
        if p.startswith("Node_02"):
            return "Node_02"
        if p.startswith("Node_03"):
            return "Node_03"
        if p.startswith("Node_"):
            return p

    return None


def _find_esf_equivalence_json(arm_dir: Path, pass_fail: str) -> Tuple[Optional[Path], str]:
    # Per your canonical rule:
    #   PASS => arm/match/ESF_SET_EQUIVALENCE_QMS.json
    #   FAIL => arm/ESF_SET_EQUIVALENCE_QMS.json
    if pass_fail == "PASS":
        for p in (arm_dir / "match" / ESF_FILENAME, arm_dir / "Match" / ESF_FILENAME, arm_dir / "MATCH" / ESF_FILENAME):
            if p.exists() and p.is_file():
                return p, "PASS->arm/match"
        return None, "PASS->arm/match"
    if pass_fail == "FAIL":
        p = arm_dir / ESF_FILENAME
        if p.exists() and p.is_file():
            return p, "FAIL->arm/root"
        return None, "FAIL->arm/root"
    return None, "NA"


def _derive_summary_path(hv_path: Path) -> Path:
    return hv_path.parent / SUMMARY_FILENAME


def _derive_swap_candidates_path(hv_path: Path) -> Path:
    return hv_path.parent / SWAP_CANDIDATES_FILENAME


def _norm_name(s: str) -> str:
    raw = (s or "").strip()
    if not raw:
        return ""
    x = re.sub(r"\s+", " ", raw)
    # standardize common prefixes
    x = re.sub(r"^dr\.\s*", "Dr. ", x, flags=re.IGNORECASE)
    return x


def extract(root: Path, strict: bool = True) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]], List[ExtractIssue]]:
    issues: List[ExtractIssue] = []
    comparisons: List[Dict[str, Any]] = []
    artifacts_rows: List[Dict[str, Any]] = []

    hv_files = _iter_hv_metadata_files(root)
    if not hv_files:
        issues.append(ExtractIssue("ERROR", "NO_FILES", f"No HV_METADATA_QMSv5___*.json found under root: {root}", str(root)))
        return comparisons, artifacts_rows, issues

    def _err(code: str, msg: str, path: str) -> None:
        issues.append(ExtractIssue("ERROR", code, msg, path))
        if strict:
            raise RuntimeError(f"{code}: {msg} ({path})")

    def _warn(code: str, msg: str, path: str) -> None:
        # In strict mode, treat WARN as ERROR only when it indicates a discrepancy.
        issues.append(ExtractIssue("WARN", code, msg, path))

    for hv_path in hv_files:
        hv_path_str = hv_path.as_posix()

        try:
            data = _load_json(hv_path)
        except Exception as e:
            _err("JSON_PARSE_FAIL", f"Failed to parse HV metadata JSON: {e}", hv_path_str)
            continue

        schema = str(_safe_get(data, "schema", ""))
        if schema != "SentinelQMSv5_HV_Metadata@1.0":
            _err("SCHEMA_UNEXPECTED", f"Unexpected schema '{schema}'", hv_path_str)

        ts_generated_utc = str(_safe_get(data, "ts_generated_utc", ""))
        compare_dir = str(_safe_get(data, "compare_dir", ""))

        node_id = _derive_node_id_from_hv_path(root, hv_path)
        if not node_id:
            _err("NODE_ID_UNRESOLVED", "Could not derive node_id from path. Expected Node02/Node03 folder in path.", hv_path_str)

        group, arm, compare_folder, candidate_label, relpath_str = _derive_path_fields(root, hv_path)
        win_group, win_arm, win_compare_folder = _parse_compare_dir_windows(compare_dir)

        # Path mismatch is a discrepancy because you said all folder structures are standardized.
        if (group and win_group and group != win_group) or (arm and win_arm and arm != win_arm) or (compare_folder and win_compare_folder and compare_folder != win_compare_folder):
            _err("PATH_MISMATCH", f"fs=({group},{arm},{compare_folder}) vs win=({win_group},{win_arm},{win_compare_folder})", hv_path_str)

        hv_start_utc = str(_safe_get(data, "hv_start_utc", ""))
        hv_end_utc = str(_safe_get(data, "hv_end_utc", ""))
        hv_duration_seconds = _safe_get(data, "hv_duration_seconds", None)

        dt_start = _utc_parse(hv_start_utc)
        dt_end = _utc_parse(hv_end_utc)
        if dt_start and dt_end and isinstance(hv_duration_seconds, (int, float)):
            computed = (dt_end - dt_start).total_seconds()
            if abs(computed - float(hv_duration_seconds)) > 2.0:
                _err("DURATION_MISMATCH", f"hv_duration_seconds={hv_duration_seconds} computed={computed:.3f}", hv_path_str)

        hv_final_artifact = str(_safe_get(data, "hv_final_artifact", ""))
        hv_final_type = str(_safe_get(data, "hv_final_type", ""))
        hv_final_sha256 = str(_safe_get(data, "hv_final_sha256", ""))
        hv_final_ripemd160 = str(_safe_get(data, "hv_final_ripemd160", ""))

        hv_validator_name_raw = str(_safe_get(data, "hv_validator_name", ""))
        hv_validator_name_norm = _norm_name(hv_validator_name_raw)

        is_architect_operator = 1 if hv_validator_name_norm in ("Dr. Fernando Telles", "DRTELLES-ARCHITECT") else 0
        is_blinded_primary_operator = 0 if is_architect_operator == 1 else 1

        hv_start_source = str(_safe_get(data, "hv_start_source", ""))
        hv_start_artifact = str(_safe_get(data, "hv_start_artifact", ""))
        hv_start_artifact_mtime_utc = str(_safe_get(data, "hv_start_artifact_mtime_utc", ""))

        derived_pdf = _safe_get(data, "derived_pdf", None)
        derived_pdf_sha256 = _safe_get(data, "derived_pdf_sha256", None)
        derived_pdf_ripemd160 = _safe_get(data, "derived_pdf_ripemd160", None)

        script_name = str(_safe_get(data, "script_name", ""))
        script_version = str(_safe_get(data, "script_version", ""))
        notes = str(_safe_get(data, "notes", ""))

        compare_artifacts = _safe_get(data, "compare_artifacts", {}) or {}
        required_list = compare_artifacts.get("required", []) or []
        optional_list = compare_artifacts.get("optional", []) or []

        role_to_sha: Dict[str, str] = {}
        role_to_r160: Dict[str, str] = {}

        def _process_art_list(items: Iterable[Dict[str, Any]], reqopt: str) -> None:
            for it in items:
                p = str(it.get("path", ""))
                sha = str(it.get("sha256", ""))
                r160 = str(it.get("ripemd160", ""))
                role = _artifact_role_from_path(p)

                artifacts_rows.append({
                    "hv_record_id": None,
                    "hv_metadata_relpath": relpath_str,
                    "hv_metadata_path": hv_path_str,
                    "node_id": node_id,
                    "group": group,
                    "arm": arm,
                    "compare_folder": compare_folder,
                    "candidate_label": candidate_label,
                    "compare_dir": compare_dir,
                    "artifact_role": role,
                    "artifact_path": p,
                    "artifact_sha256": sha,
                    "artifact_ripemd160": r160,
                    "required_optional": reqopt,
                })

                if role in {"COMPARE_SUMMARY", "MISSING_GLOBAL", "EXTRAS_GLOBAL"}:
                    role_to_sha[role] = sha
                    role_to_r160[role] = r160

        _process_art_list(required_list, "required")
        _process_art_list(optional_list, "optional")

        # Required roles must exist in HV metadata.
        for needed in ("COMPARE_SUMMARY", "MISSING_GLOBAL", "EXTRAS_GLOBAL"):
            if needed not in role_to_sha or not role_to_sha[needed]:
                _err("MISSING_REQUIRED_ARTIFACT", f"Missing required artifact role in HV metadata: {needed}", hv_path_str)

        missing_sha = role_to_sha["MISSING_GLOBAL"].lower()
        extras_sha = role_to_sha["EXTRAS_GLOBAL"].lower()

        missing_empty = 1 if (missing_sha == EMPTY_SHA256) else 0
        extras_empty = 1 if (extras_sha == EMPTY_SHA256) else 0

        # ===== Authoritative PASS/FAIL from COMPARE_SUMMARY.json =====
        sp = _derive_summary_path(hv_path)
        if not (sp.exists() and sp.is_file()):
            _err("SUMMARY_MISSING_ON_DISK", f"Missing on-disk {SUMMARY_FILENAME} adjacent to HV_METADATA", hv_path_str)

        summary_found = 1
        summary_path = sp.as_posix()
        try:
            sd = _load_json(sp)
        except Exception as e:
            _err("SUMMARY_PARSE_FAIL", f"Failed to parse COMPARE_SUMMARY.json: {e}", hv_path_str)
            raise

        summary_ts_utc = str(_safe_get(sd, "ts_utc", "") or "")
        summary_result = str(_safe_get(sd, "result", "") or "")

        if summary_result not in (SUMMARY_PASS, SUMMARY_FAIL):
            _err("SUMMARY_RESULT_UNEXPECTED", f"Unexpected summary result: '{summary_result}'", hv_path_str)

        pass_fail = "PASS" if summary_result == SUMMARY_PASS else "FAIL"

        counts = _safe_get(sd, "counts", {}) or {}
        missing_count_summary = _safe_get(counts, "missing_count", None)
        extras_count_summary = _safe_get(counts, "extras_count", None)
        distinct_pairs_union = _safe_get(counts, "distinct_pairs_union", None)
        source_total_rows_read = _safe_get(counts, "source_total_rows_read", None)
        windows_total_rows_read = _safe_get(counts, "windows_total_rows_read", None)
        source_valid_rows = _safe_get(counts, "source_valid_rows", None)
        windows_valid_rows = _safe_get(counts, "windows_valid_rows", None)

        if not isinstance(missing_count_summary, int) or not isinstance(extras_count_summary, int):
            _err("SUMMARY_COUNTS_TYPE", "missing_count/extras_count must be int in COMPARE_SUMMARY.json", hv_path_str)

        fps = _safe_get(sd, "fingerprints", {}) or {}
        match_val = _safe_get(fps, "match", None)
        if not isinstance(match_val, bool):
            _err("SUMMARY_FINGERPRINT_MATCH_TYPE", "fingerprints.match must be boolean in COMPARE_SUMMARY.json", hv_path_str)
        fingerprint_match = match_val

        src_fp = _safe_get(fps, "source", {}) or {}
        win_fp = _safe_get(fps, "windows", {}) or {}
        source_sha256_fingerprint = str(_safe_get(src_fp, "sha256_fingerprint", "") or "")
        source_ripemd160_fingerprint = str(_safe_get(src_fp, "ripemd160_fingerprint", "") or "")
        windows_sha256_fingerprint = str(_safe_get(win_fp, "sha256_fingerprint", "") or "")
        windows_ripemd160_fingerprint = str(_safe_get(win_fp, "ripemd160_fingerprint", "") or "")

        # ===== Strict consistency checks =====
        # 1) Empty-hash consistency (hv-metadata sidecars)
        if pass_fail == "PASS" and not (missing_empty == 1 and extras_empty == 1):
            _err("EMPTY_HASH_INCONSISTENT", "SUMMARY says PASS but missing/extras hashes are not empty-hash", hv_path_str)
        if pass_fail == "FAIL" and (missing_empty == 1 and extras_empty == 1):
            _err("EMPTY_HASH_INCONSISTENT", "SUMMARY says FAIL but missing/extras hashes are empty-hash", hv_path_str)

        # 2) Summary counts consistency
        if pass_fail == "PASS" and not (missing_count_summary == 0 and extras_count_summary == 0 and fingerprint_match is True):
            _err("SUMMARY_COUNTS_INCONSISTENT", "SUMMARY says PASS but counts/fingerprint do not satisfy PASS criteria", hv_path_str)

        if pass_fail == "FAIL" and (missing_count_summary == 0 and extras_count_summary == 0 and fingerprint_match is True):
            _err("SUMMARY_COUNTS_INCONSISTENT", "SUMMARY says FAIL but counts/fingerprint satisfy PASS criteria", hv_path_str)

        # 3) Tamper feature flags
        tamper_deletion_detected = 1 if missing_count_summary > 0 else 0
        tamper_addition_detected = 1 if extras_count_summary > 0 else 0
        tamper_substitution_possible = 1 if (tamper_deletion_detected == 1 and tamper_addition_detected == 1) else 0
        tamper_k = int(missing_count_summary) + int(extras_count_summary)

        # ===== ESF integration =====
        arm_dir = hv_path.parent.parent if hv_path.parent and hv_path.parent.parent else None
        if not arm_dir or not arm_dir.exists():
            _err("ARM_DIR_DERIVE_FAIL", "Could not derive arm_dir for ESF lookup.", hv_path_str)

        esf_equiv_found = 0
        esf_equiv_path = ""
        esf_equiv_result = ""
        esf_match: Optional[int] = None
        esf_mapping_rule = ""
        baseline_esf_rows = None
        audit_esf_rows = None
        baseline_distinct_esf = None
        audit_distinct_esf = None
        baseline_only_count = None
        audit_only_count = None
        baseline_esf_packet = ""
        audit_esf_packet = ""
        out_diff_ndjson = ""
        esf_policy_qms_safe = None
        esf_policy_container_identity = ""

        esf_path, esf_mapping_rule = _find_esf_equivalence_json(arm_dir, pass_fail)
        if not (esf_path and esf_path.exists() and esf_path.is_file()):
            _err("ESF_NOT_FOUND", f"ESF not found with rule '{esf_mapping_rule}' under arm_dir={arm_dir.as_posix()}", hv_path_str)

        esf_equiv_found = 1
        esf_equiv_path = esf_path.as_posix()
        try:
            esf_data = _load_json(esf_path)
        except Exception as e:
            _err("ESF_PARSE_FAIL", f"Failed to parse ESF equivalence JSON: {e}", hv_path_str)
            raise

        esf_equiv_result = str(_safe_get(esf_data, "result", "") or "")
        baseline_esf_rows = _safe_get(esf_data, "baseline_esf_rows", None)
        audit_esf_rows = _safe_get(esf_data, "audit_esf_rows", None)
        baseline_distinct_esf = _safe_get(esf_data, "baseline_distinct_esf", None)
        audit_distinct_esf = _safe_get(esf_data, "audit_distinct_esf", None)
        baseline_only_count = _safe_get(esf_data, "baseline_only_count", None)
        audit_only_count = _safe_get(esf_data, "audit_only_count", None)
        baseline_esf_packet = str(_safe_get(esf_data, "baseline_esf_packet", "") or "")
        audit_esf_packet = str(_safe_get(esf_data, "audit_esf_packet", "") or "")
        out_diff_ndjson = str(_safe_get(esf_data, "out_diff_ndjson", "") or "")
        policy = _safe_get(esf_data, "policy", {}) or {}
        esf_policy_qms_safe = _safe_get(policy, "qms_safe", None)
        esf_policy_container_identity = str(_safe_get(policy, "container_identity", "") or "")

        if esf_equiv_result == "ESF SET EQUIVALENT":
            esf_match = 1
        elif esf_equiv_result == "ESF SET NOT EQUIVALENT":
            esf_match = 0
        else:
            _err("ESF_RESULT_UNEXPECTED", f"Unexpected ESF result: '{esf_equiv_result}'", hv_path_str)

        # ESF must not contradict summary PASS/FAIL
        if pass_fail == "PASS" and esf_match != 1:
            _err("ESF_INCONSISTENT", "PASS but ESF SET NOT EQUIVALENT", hv_path_str)
        if pass_fail == "FAIL" and esf_match != 0:
            _err("ESF_INCONSISTENT", "FAIL but ESF SET EQUIVALENT", hv_path_str)

        # Record ESF artifact digest
        esf_sha256 = _sha256_file(esf_path)
        esf_r160 = _r160_of_sha256_hex(esf_sha256)
        if not esf_r160:
            _err("RIPEMD160_UNAVAILABLE", "hashlib ripemd160 unavailable; cannot compute ESF r160.", hv_path_str)

        # Add ESF as derived artifact row
        hv_record_id = _build_hv_record_id(compare_dir, ts_generated_utc, hv_final_sha256)

        for row in artifacts_rows:
            if row["hv_metadata_path"] == hv_path_str and row["hv_record_id"] is None:
                row["hv_record_id"] = hv_record_id

        artifacts_rows.append({
            "hv_record_id": hv_record_id,
            "hv_metadata_relpath": relpath_str,
            "hv_metadata_path": hv_path_str,
            "node_id": node_id,
            "group": group,
            "arm": arm,
            "compare_folder": compare_folder,
            "candidate_label": candidate_label,
            "compare_dir": compare_dir,
            "artifact_role": "ESF_SET_EQUIVALENCE",
            "artifact_path": esf_equiv_path,
            "artifact_sha256": esf_sha256,
            "artifact_ripemd160": esf_r160,
            "required_optional": "derived",
        })

        # Optional SWAP_CANDIDATES for IIIA fail
        swap_candidates_present = 0
        swap_path = _derive_swap_candidates_path(hv_path)
        if swap_path.exists() and swap_path.is_file():
            swap_candidates_present = 1
            swap_sha256 = _sha256_file(swap_path)
            swap_r160 = _r160_of_sha256_hex(swap_sha256) or ""
            if not swap_r160:
                _err("RIPEMD160_UNAVAILABLE", "hashlib ripemd160 unavailable; cannot compute SWAP_CANDIDATES r160.", hv_path_str)
            artifacts_rows.append({
                "hv_record_id": hv_record_id,
                "hv_metadata_relpath": relpath_str,
                "hv_metadata_path": hv_path_str,
                "node_id": node_id,
                "group": group,
                "arm": arm,
                "compare_folder": compare_folder,
                "candidate_label": candidate_label,
                "compare_dir": compare_dir,
                "artifact_role": "SWAP_CANDIDATES",
                "artifact_path": swap_path.as_posix(),
                "artifact_sha256": swap_sha256,
                "artifact_ripemd160": swap_r160,
                "required_optional": "optional_detected",
            })

        comparisons.append({
            # identity / stratification
            "hv_record_id": hv_record_id,
            "schema": schema,
            "ts_generated_utc": ts_generated_utc,
            "node_id": node_id,
            "group": group,
            "arm": arm,
            "compare_folder": compare_folder,
            "candidate_label": candidate_label,
            "compare_dir": compare_dir,
            "win_group": win_group,
            "win_arm": win_arm,
            "win_compare_folder": win_compare_folder,
            "path_mismatch_flag": 0,
            # hv timing
            "hv_validator_name_raw": hv_validator_name_raw,
            "hv_validator_name_norm": hv_validator_name_norm,
            "is_architect_operator": is_architect_operator,
            "is_blinded_primary_operator": is_blinded_primary_operator,
            "hv_start_utc": hv_start_utc,
            "hv_end_utc": hv_end_utc,
            "hv_duration_seconds": hv_duration_seconds,
            "hv_start_source": hv_start_source,
            "hv_start_artifact": hv_start_artifact,
            "hv_start_artifact_mtime_utc": hv_start_artifact_mtime_utc,
            # hv artifact digests
            "hv_final_artifact": hv_final_artifact,
            "hv_final_type": hv_final_type,
            "hv_final_sha256": hv_final_sha256,
            "hv_final_ripemd160": hv_final_ripemd160,
            "derived_pdf": derived_pdf,
            "derived_pdf_sha256": derived_pdf_sha256,
            "derived_pdf_ripemd160": derived_pdf_ripemd160,
            # compare artifacts (hash pointers from HV metadata)
            "compare_summary_sha256": role_to_sha.get("COMPARE_SUMMARY", ""),
            "compare_summary_ripemd160": role_to_r160.get("COMPARE_SUMMARY", ""),
            "missing_global_sha256": role_to_sha.get("MISSING_GLOBAL", ""),
            "missing_global_ripemd160": role_to_r160.get("MISSING_GLOBAL", ""),
            "extras_global_sha256": role_to_sha.get("EXTRAS_GLOBAL", ""),
            "extras_global_ripemd160": role_to_r160.get("EXTRAS_GLOBAL", ""),
            # authoritative decision from summary
            "pass_fail": pass_fail,
            "summary_found": summary_found,
            "summary_path": summary_path,
            "summary_ts_utc": summary_ts_utc,
            "summary_result": summary_result,
            "missing_count_summary": missing_count_summary,
            "extras_count_summary": extras_count_summary,
            "distinct_pairs_union": distinct_pairs_union,
            "fingerprint_match": fingerprint_match,
            "source_total_rows_read": source_total_rows_read,
            "windows_total_rows_read": windows_total_rows_read,
            "source_valid_rows": source_valid_rows,
            "windows_valid_rows": windows_valid_rows,
            "source_sha256_fingerprint": source_sha256_fingerprint,
            "source_ripemd160_fingerprint": source_ripemd160_fingerprint,
            "windows_sha256_fingerprint": windows_sha256_fingerprint,
            "windows_ripemd160_fingerprint": windows_ripemd160_fingerprint,
            # hv-metadata empty-hash derived signals (kept for QC/provenance)
            "missing_empty": missing_empty,
            "extras_empty": extras_empty,
            # tamper signals
            "tamper_deletion_detected": tamper_deletion_detected,
            "tamper_addition_detected": tamper_addition_detected,
            "tamper_substitution_possible": tamper_substitution_possible,
            "tamper_k": tamper_k,
            # ESF
            "esf_equiv_found": esf_equiv_found,
            "esf_equiv_path": esf_equiv_path,
            "esf_equiv_result": esf_equiv_result,
            "esf_match": esf_match,
            "baseline_esf_rows": baseline_esf_rows,
            "audit_esf_rows": audit_esf_rows,
            "baseline_distinct_esf": baseline_distinct_esf,
            "audit_distinct_esf": audit_distinct_esf,
            "baseline_only_count": baseline_only_count,
            "audit_only_count": audit_only_count,
            "baseline_esf_packet": baseline_esf_packet,
            "audit_esf_packet": audit_esf_packet,
            "out_diff_ndjson": out_diff_ndjson,
            "esf_policy_qms_safe": esf_policy_qms_safe,
            "esf_policy_container_identity": esf_policy_container_identity,
            "esf_mapping_rule": esf_mapping_rule,
            # optional IIIA field
            "swap_candidates_present": swap_candidates_present,
            # provenance
            "script_name": script_name,
            "script_version": script_version,
            "notes": notes,
            "hv_metadata_relpath": relpath_str,
            "hv_metadata_path": hv_path_str,
            "extractor_script": SCRIPT_NAME,
            "extractor_version": SCRIPT_VERSION,
        })

    comparisons.sort(key=lambda r: (
        str(r.get("node_id") or ""),
        str(r.get("group") or ""),
        str(r.get("arm") or ""),
        str(r.get("compare_folder") or ""),
        str(r.get("ts_generated_utc") or ""),
        str(r.get("hv_validator_name_norm") or ""),
        str(r.get("hv_metadata_relpath") or ""),
    ))

    artifacts_rows.sort(key=lambda r: (
        str(r.get("node_id") or ""),
        str(r.get("group") or ""),
        str(r.get("arm") or ""),
        str(r.get("compare_folder") or ""),
        str(r.get("hv_record_id") or ""),
        str(r.get("artifact_role") or ""),
        str(r.get("artifact_path") or ""),
    ))

    return comparisons, artifacts_rows, issues


def _write_csv(path: Path, rows: List[Dict[str, Any]], fieldnames: List[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            out = {k: row.get(k, None) for k in fieldnames}
            w.writerow(out)


def _write_ndjson_log(path: Path, issues: List[ExtractIssue], root: Path, files_count: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    with path.open("w", encoding="utf-8") as f:
        header = {
            "ts": now,
            "event": "HVT_A_METADATA_EXTRACT_RUN",
            "extractor": SCRIPT_NAME,
            "extractor_version": SCRIPT_VERSION,
            "root": root.as_posix(),
            "hv_metadata_files_found": files_count,
            "warnings": len([w for w in issues if w.level == "WARN"]),
            "errors": len([w for w in issues if w.level == "ERROR"]),
        }
        f.write(json.dumps(header, sort_keys=True) + "\n")
        for w in issues:
            rec = {"ts": now, "level": w.level, "code": w.code, "message": w.message, "hv_metadata_path": w.hv_metadata_path}
            f.write(json.dumps(rec, sort_keys=True) + "\n")


def main() -> int:
    ap = argparse.ArgumentParser(description="Deterministically extract QMSv5 HVT-A HV_METADATA JSON into R-ready CSVs (strict fail-closed by default).")
    ap.add_argument("--root", required=True, help="Root directory to recursively scan for HV_METADATA_QMSv5___*.json")
    ap.add_argument("--out-dir", default=None, help="Output directory for CSVs (default: <root>/__EXTRACT_OUT__)")
    ap.add_argument("--prefix", default="hvtA", help="Filename prefix for output CSVs (default: hvtA)")
    ap.add_argument("--non-strict", action="store_true", help="Do not stop on first error (NOT RECOMMENDED).")
    args = ap.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.exists() or not root.is_dir():
        print(f"ERROR: --root is not a directory: {root}")
        return 2

    strict = not args.non_strict
    out_dir = Path(args.out_dir).expanduser().resolve() if args.out_dir else (root / "__EXTRACT_OUT__")

    try:
        comparisons, artifacts_rows, issues = extract(root, strict=strict)
    except RuntimeError as e:
        # ensure log still written (best-effort)
        comparisons, artifacts_rows, issues = [], [], [ExtractIssue("ERROR", "STRICT_STOP", str(e), str(root))]

    # Column order: keep stable; new fields are additive.
    comparisons_fields = [
        "hv_record_id","schema","ts_generated_utc","node_id","group","arm","compare_folder","candidate_label","compare_dir",
        "win_group","win_arm","win_compare_folder","path_mismatch_flag",
        "hv_validator_name_raw","hv_validator_name_norm","is_architect_operator","is_blinded_primary_operator",
        "hv_start_utc","hv_end_utc","hv_duration_seconds","hv_start_source","hv_start_artifact","hv_start_artifact_mtime_utc",
        "hv_final_artifact","hv_final_type","hv_final_sha256","hv_final_ripemd160","derived_pdf","derived_pdf_sha256","derived_pdf_ripemd160",
        "compare_summary_sha256","compare_summary_ripemd160","missing_global_sha256","missing_global_ripemd160","extras_global_sha256","extras_global_ripemd160",
        "pass_fail","summary_found","summary_path","summary_ts_utc","summary_result",
        "source_total_rows_read","windows_total_rows_read","source_valid_rows","windows_valid_rows",
        "missing_count_summary","extras_count_summary","distinct_pairs_union","fingerprint_match",
        "source_sha256_fingerprint","source_ripemd160_fingerprint","windows_sha256_fingerprint","windows_ripemd160_fingerprint",
        "missing_empty","extras_empty",
        "tamper_deletion_detected","tamper_addition_detected","tamper_substitution_possible","tamper_k",
        "esf_equiv_found","esf_equiv_path","esf_equiv_result","esf_match",
        "baseline_esf_rows","audit_esf_rows","baseline_distinct_esf","audit_distinct_esf",
        "baseline_only_count","audit_only_count","baseline_esf_packet","audit_esf_packet","out_diff_ndjson",
        "esf_policy_qms_safe","esf_policy_container_identity","esf_mapping_rule",
        "swap_candidates_present",
        "script_name","script_version","notes","hv_metadata_relpath","hv_metadata_path","extractor_script","extractor_version"
    ]

    artifacts_fields = [
        "hv_record_id","hv_metadata_relpath","hv_metadata_path","node_id","group","arm","compare_folder","candidate_label","compare_dir",
        "artifact_role","artifact_path","artifact_sha256","artifact_ripemd160","required_optional"
    ]

    comparisons_csv = out_dir / f"{args.prefix}_comparisons.csv"
    artifacts_csv = out_dir / f"{args.prefix}_artifacts.csv"
    log_ndjson = out_dir / f"{args.prefix}_extract_log.ndjson"

    _write_csv(comparisons_csv, comparisons, comparisons_fields)
    _write_csv(artifacts_csv, artifacts_rows, artifacts_fields)
    _write_ndjson_log(log_ndjson, issues, root, len(_iter_hv_metadata_files(root)))

    print(f"Wrote: {comparisons_csv}")
    print(f"Wrote: {artifacts_csv}")
    print(f"Wrote: {log_ndjson}")
    print(f"Rows: comparisons={len(comparisons)} artifacts={len(artifacts_rows)}")

    err_count = len([w for w in issues if w.level == "ERROR"])
    if err_count:
        print(f"ERRORS={err_count}. See log: {log_ndjson}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())