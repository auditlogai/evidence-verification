# evidence-verification
Deterministic, hash-only verification artefacts, extraction scripts, and statistical code supporting a blinded, multi-operator, single-site proof-of-concept study of zero-custody post-export audit verification for clinical and regulatory evidence. Public release enables independent reproduction and falsification.

## Execution Overview

This repository supports deterministic reproduction of all reported Stage IV (HVT-A) analyses using released hash-only verification artefacts and disclosed analysis scripts. Complete instructions are contained in REPRODUCIBILITY.md. Two reproduction modes are provided.

---

## Mode A — Analysis from Released Tables (Recommended)

This is the fastest and recommended reproduction pathway.

Use this mode to regenerate reported tables and figures presented in the manuscript, without re-running Python extractors.

Steps:
	1.	Download the repository release.
	2.	Confirm that the following directories are present:
	•	__EXTRACT_OUT__/ — analysis-ready CSV tables
	•	__VERIFY_READY__/ — verification and consistency certificates (JSON/NDJSON)
	3.	Run the R entrypoint script:

R script RUN_ALL_HVT_A_FINAL.R

---

## Mode B — Full Regeneration from Hash-Only Artefacts

This mode performs a full, end-to-end regeneration of analysis-ready tables from released QMS hash-only summary outputs.

Use this mode if you want to independently verify:
	•	extractor correctness,
	•	verification logic, and
	•	analysis-readiness checks prior to statistical modeling.

Steps:
	1.	Run the Python extractors to regenerate __EXTRACT_OUT__/ from hash-only artefacts.
	2.	Run the Python verification scripts to populate __VERIFY_READY__/.
	3.	Run the R entrypoint script as in Mode A.

---

## Notes on Reproducibility Scope
	•	All analyses reported in the main manuscript are reproducible using Mode A or Mode B, except Manuscript Table 4, which requires direct access to execution environments (Nodes 01–03) and is explicitly documented as non-reproducible from disclosed hash-only exports.
	•	Detailed, step-by-step instructions (directory layout, command sequences, and environment requirements) are provided in REPRODUCIBILITY.md.

---
