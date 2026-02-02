# REFERENCES

This repository provides deterministic, hash-only verification artefacts, scripts, and provenance records supporting the Stage IV cryptographic audit validation program and Ordinal 15 disclosure integrity trial.

All cited materials are publicly available, cryptographically verifiable, and suitable for independent reproduction and falsification. No raw evidence, personal data, or execution environments are required to validate the claims referenced here.

---

## Primary Data Records

### Stage IV Audit Reproducibility Dataset (HVT-A)

Telles, Fernando (2026).  
**“Stage IV Audit Reproducibility Dataset (HVT-A): Deterministic Hash-Based Verification and Human Verification Time Outputs.”**  
*Mendeley Data*, V1.  
DOI: https://doi.org/10.17632/fzw4pzkd83.1

This dataset contains the complete hash-only verification outputs and Human Verification Time (HVT-A) measurements generated during the Stage IV cryptographic audit validation study. The release enables independent reproduction of all reported verification outcomes without access to raw evidence or execution environments.

---

## Supplementary Technical Record

### Supplementary Materials - Stage IV Cryptographic Audit Validation

Telles, F. (2026).  
**“Supplementary Materials for Stage IV Cryptographic Audit Validation: Methods, Protocols, and Reproducibility Outputs.”**  
*Zenodo*.  
DOI: https://doi.org/10.5281/zenodo.18446261

This supplementary record contains detailed audit plans, protocol amendments, results ontologies, execution lineage documentation, and supporting technical outputs associated with the Stage IV study. It contains no discussion or interpretation and is intended to function as a standalone technical record for independent inspection.

**Cryptographic provenance (hash-only):**
- File: `5_Supplementary_Material_FINAL_METADATA___20260201T023421Z.pdf`  
- SHA-256: `c57c3343ee59b6fc4fb6cd7c5080b4d10268f9c0541cae4a5e0df6ebc37dd29a`  
- RIPEMD-160: `ed3c635e54ef8bba8f9f482c0e64d5ecc2bf6747`  
- Bitcoin TXID: `9a0026e5b33068ef0f551609c5dcb019ae038f8cf5ac06c609dab48a604aa374`  
- Block: `934553`

Corresponding proof sidecars are published under `/provenance/supplementary/`.

---

## Disclosure Integrity Trial Record

### Ordinal 15 - Proof-of-Unchanged Zero-Custody Audit Reproducibility Trial

Telles, F. (2026).  
**“Ordinal 15: Proof-of-Unchanged Zero-Custody Audit Reproducibility Trial.”**  
*Zenodo*.  
DOI: https://doi.org/10.5281/zenodo.18452216

Ordinal 15 is a pre-registered disclosure integrity test designed to verify that the publicly disclosed Stage IV analysis dataset matches its cryptographically anchored ground truth. The record contains deterministic audit summaries, Evidence Set Fingerprint (ESF) comparisons, and explicit enumeration of PASS and FAIL outcomes.

No raw data, statistical analyses, filenames, or execution environments are included.

**Cryptographic provenance (hash-only):**
- File: `Ordinal 15 Proof-of-Unchanged Zero-Custody Audit Reproducibility_FINAL_METADATA___20260201T224243Z.pdf`  
- SHA-256: `d8a2d8e2efc66eb996272ea998471673cb0465fe5da894869b4054abea28dc4d`  
- RIPEMD-160: `7152ab0ffdd30982127306539db22725349d168f`  
- OP_RETURN TXID: `3a859ed9b93a24898812329b69ed10e9c301e78433eaceaab809b823243118d9` (Block `934655`)  
- Ordinal TXID: `006e274af867de728c28da77175892cb76821e82f05378033e95e024712912a7` (Block `934659`)

Corresponding proof sidecars are published under `/provenance/ordinal15/`.

---

## Ordinal 15 Verification Packets

Telles, Fernando (2026).  
**“Ordinal 15 Zero-Custody Disclosure Integrity Verification Packets.”**  
*Mendeley Data*, V1.  
DOI: https://doi.org/10.17632/wjj674twb4.1

This dataset contains the hash-only, zero-custody verification packets associated with Ordinal 15. The packets enable independent reproduction of QMSv5 Auditor comparisons to obtain either proof-of-unchanged or explicit byte-level enumeration of divergence.

The release contains no clinical data, personal identifiers, filenames, paths, or interpretive analysis.

---

## Software and Scripts

### Deterministic Extraction and Verification (Python)

AuditLog.AI - Evidence Verification Repository  
https://github.com/auditlogai/evidence-verification/tree/main/src/python

This directory contains deterministic, hash-first extraction and verification scripts used to generate the disclosed audit artefacts and verification packets.

### Statistical Analysis (R)

AuditLog.AI - Evidence Verification Repository  
https://github.com/auditlogai/evidence-verification/tree/main/src/R

This directory contains the statistical analysis scripts used to generate reported HVT-A outputs from the disclosed hash-only datasets.

---

## Provenance and Anchoring Records

- Stage IV anchor audit logs (Node_02, Node_03): `/provenance/anchors/StageIV/`
- Deterministic anchor index: `/provenance/ANCHOR_INDEX_StageIV.ndjson`

These records document the Bitcoin anchoring events associated with Stage IV execution and disclosure artefacts. They contain only cryptographic references, human verification attestations, and chain metadata.

---

## Disclosure Boundary

All materials referenced above are disclosed under a zero-custody, zero-authority model. Verification requires only public records, hash-only artefacts, and the Bitcoin blockchain. No trust in authors, vendors, or execution environments is required.

---