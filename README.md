# evidence-verification

Deterministic, hash-only verification artefacts, scripts, and reference materials supporting a blinded, multi-operator, single-site proof-of-concept study of **zero-custody, post-export audit verification** for clinical and regulatory evidence.

This repository enables **independent reproduction, verification, and falsification** of reported results using publicly disclosed cryptographic artefacts.  
No raw evidence, filenames, directory paths, or system logs are included.

---

## What this repository is

This repository contains the **public verification record** for a cryptographic audit methodology evaluated in a clinical-trial context and documented in peer-review targeted materials.

Specifically, it provides:

- Hash-only verification artefacts (NDJSON / JSON)
- Deterministic extraction and verification scripts
- Statistical analysis code for Human Verification Time (HVT-A)
- Public anchoring references (Bitcoin / OpenTimestamps)
- Visual reference material explaining the verification primitives

It is designed so that **any third party** can independently confirm:

- whether evidence was byte-unchanged,
- whether evidence-set membership changed,
- and whether reported outcomes can be reproduced from disclosed artefacts.

---

## What this repository is *not*

- Not a data host  
- Not a clinical system  
- Not an audit opinion or compliance determination  
- Not a software distribution for AuditLog.AI or QMS Auditor  

This repository documents **verification outputs and methodology**, not operational deployments.

---

## Primary public datasets

The complete Stage IV dataset used in the study is available via Mendeley Data:

> **Telles, Fernando (2026).**  
> *Stage IV Audit Reproducibility Dataset (HVT-A): Deterministic Hash-Based Verification and Human Verification Time Outputs.*  
> Mendeley Data, V1.  
> https://doi.org/10.17632/fzw4pzkd83.1

This dataset contains **hash-only summaries and human verification artefacts** sufficient to reproduce all reported analyses.
EXTRACT_OUT/   # Analysis-ready tables
VERIFY_READY/  # Verification certificates (JSON / NDJSON)

---

## Repository structure (high-level)

docs/
├─ C17_Proof-of-Unchanged/        # Canonical methodology document
├─ C18_Big-Four/                  # Assurance-context framing
├─ C19_Big-Tech/                  # AI governance / cloud framing
├─ C20_Regulatory-Scope/          # Negative applicability & scope
├─ International_Audit_Trial/     # Q2 2026 trial protocol
├─ Ordinal_15/                    # Disclosure integrity record
├─ visual_overview/               # Visual verification pack (PDF)
└─ CRO_QUICKSTART.md              # Procedural entry point

src/               # Python & R scripts

---

## Visual overview (recommended starting point)

For readers new to the methodology, a **visual, non-interpretive overview** is provided:

> **Proof-of-Unchanged — Visual Pack (PDF)**  
> `docs/visual_overview/Proof-of-Unchanged_Visual_Pack.pdf`

This pack explains, graphically:

- custody-boundary verification,
- integrity vs membership,
- PASS vs divergence,
- two-system architecture (anchoring vs verification),
- human governance & fail-closed enforcement,
- independent re-verification.

No claims beyond what is documented elsewhere are introduced.

---

## Execution overview

This repository supports deterministic reproduction of all reported **Stage IV (HVT-A)** analyses using released hash-only verification artefacts.

Complete step-by-step instructions are provided in **`REPRODUCIBILITY.md`**.

Two reproduction modes are available.

---

## Mode A — Analysis from Released Tables (Recommended)

This is the fastest and recommended reproduction pathway.

Use this mode to regenerate reported tables and figures presented in the manuscript, without re-running Python extractors.

Steps:
	1.	Download the repository release.
	2.	Confirm that the following directories are present:
- __EXTRACT_OUT__/ — analysis-ready CSV tables
- __VERIFY_READY__/ — verification and consistency certificates (JSON/NDJSON)
	3.	Run the R entrypoint script:

R script RUN_ALL_HVT_A_FINAL.R

---

## Mode B — Full Regeneration from Hash-Only Artefacts

This mode performs a full, end-to-end regeneration of analysis-ready tables from released QMS hash-only summary outputs.

Use this mode if you want to independently verify:
- extractor correctness,
- verification logic, and
- analysis-readiness checks prior to statistical modeling.

Steps:
	1.	Run the Python extractors to regenerate __EXTRACT_OUT__/ from hash-only artefacts.
	2.	Run the Python verification scripts to populate __VERIFY_READY__/.
	3.	Run the R entrypoint script as in Mode A.

---

## Notes on reproducibility scope

- All analyses reported in the main manuscript are reproducible using Mode A or Mode B except Manuscript Table 4, which requires access to execution environments (Nodes 01–03) and is explicitly documented as non-reproducible from hash-only exports.
- This limitation is disclosed transparently and is not a failure of the verification methodology.

---

## Related public documents
- C17 — Proof-of-Unchanged Global Application Matrix
https://doi.org/10.5281/zenodo.18501507
- C12 — AuditLog.AI Global Compliance Matrix
https://doi.org/10.5281/zenodo.17462383
- Ordinal 15 — Disclosure Integrity Record
https://doi.org/10.5281/zenodo.18452216

---

## Contact

For questions about reproducibility, methodology scope, or independent verification:

Dr. Fernando Telles
Protocol Originator — Proof-of-Unchanged
Fernando.Telles@auditlog.ai

---

## This repository documents a verification methodology and its publicly disclosed evaluation.
It does not constitute regulatory advice, audit opinion, or system certification.

---
