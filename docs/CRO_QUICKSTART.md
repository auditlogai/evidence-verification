# CRO_QUICKSTART

This document provides a concise, procedural guide for Contract Research Organizations (CROs), sponsors, and regulators to understand and independently verify the audit artefacts disclosed in this repository.

No raw evidence, filenames, paths, or execution environments are required.

---

## What this repository contains

This repository supports **deterministic, zero-custody post-export audit verification** for clinical and regulatory evidence.

It contains:

- Deterministic extraction and verification scripts (Python, R)
- Hash-only provenance records
- Bitcoin anchoring receipts
- Reproducibility instructions
- Public references to the complete datasets (DOIs)

All verification is performed using **hash mathematics only**.

---

## What this repository does *not* contain

- No clinical data  
- No personal identifiers  
- No filenames or directory paths  
- No execution environments  
- No interpretation of results  

Verification does not require trust in the authors, the software vendor, or the execution platform.

---

## Core verification model (one minute overview)

AuditLog.AI and Sentinel QMS v5 operate under a **hash-first, zero-authority** audit model:

1. Evidence is hashed locally (SHA-256 + RIPEMD-160).
2. Hash-only artefacts are frozen and time-stamped.
3. A compact payload is anchored to Bitcoin.
4. Verification compares hashes, not systems.

**If the bytes have not changed, the hashes match.  
If anything changes, the hashes diverge.**

---

## What a CRO can verify independently

### 1. Document integrity (Supplementary & Ordinal 15)

Under `/provenance/` you will find hash-only proof artefacts for:

- Stage IV Supplementary Materials
- Ordinal 15 disclosure integrity record

To verify:

1. Download the referenced PDF from its DOI.
2. Recompute SHA-256 and RIPEMD-160 locally.
3. Compare against the published `.hash` / `.2ha` files.
4. (Optional) Verify the OpenTimestamps `.ots` proof and Bitcoin transaction (https://opentimestamps.org/).

No further context is required.

---

### 2. Stage IV anchoring (execution lineage)

Under:

/provenance/anchors/StageIV/

You will find JSON audit logs documenting Bitcoin anchoring events from two independent Windows execution nodes:

- `Node02`
- `Node03`

Each log records:
- human verification
- deterministic payload
- Bitcoin TXID and block height

A consolidated, machine-readable index is provided as:

/provenance/ANCHOR_INDEX_StageIV.ndjson

This file is the authoritative map from execution events to on-chain receipts.

---

### 3. How to read the anchor index

For each node:

1. Filter `ANCHOR_INDEX_StageIV.ndjson` by `node`.
2. Sort by `block_height` ascending (then `txid`).
3. The resulting order corresponds to the Stage IV execution sequence.

No interpretation of JSON logs is required; they are provided for audit traceability only.

---

## What PASS and FAIL mean

All verification outcomes are **deterministic**:

- **PASS**  
  - Hash sets match  
  - Evidence Set Fingerprints (ESF) match  
  - No missing or extra identifiers  

- **FAIL**  
  - Hash mismatch, or  
  - Explicit enumeration of missing or extra identifiers  

There is no partial pass and no discretionary override.

---

## Human verification time (HVT)

Human involvement is limited to **verification**, not investigation:

- **HVT-A**: cryptographic verification using hash-only artefacts  
- **HVT-B**: optional local interpretation (filenames, paths, narratives)

Only HVT-A is required to establish proof-of-unchanged.

---

## Reproducing reported results

### Option A: Using released tables (recommended)

Follow instructions in:

`REPRODUCIBILITY.md`

This mode reproduces reported Stage IV results directly from disclosed tables and hash-only artefacts.

### Option B: Using verification packets (advanced)

Where provided (see `/packets/`), hash-only packets allow full recomputation of PASS/FAIL outcomes without access to raw evidence.

---

## Security, privacy, and custody

- All hashing and verification occur locally.
- Only cryptographic digests are disclosed.
- Bitcoin is used for timestamping and immutability, not storage.
- No PHI, PII, or proprietary data leave the originating environment.

This model is alligned with FDA 21 CFR Part 11, EMA Annex 11, and GxP audit expectations as documented in:

Telles F. C12: AuditLog.AI Global Compliance Matrix [preprint]. Zenodo 2025.
https://doi.org/10.5281/zenodo.17462383.

Telles F. AuditLog.AI: Runtime Execution and System Validation Evidence Dossier [preprint]. Zenodo 2025. 
https://doi.org/10.5281/zenodo.17460850.

---

## If you are a CRO evaluating participation in the audit trial

You do **not** need to integrate systems or migrate data.

A trial consists of:
- selecting representative exported datasets,
- running deterministic hashing locally,
- verifying anchored proofs.

Pricing, scope, and timelines are documented separately and do not affect verification validity.

---

## Summary

This repository allows any CRO, sponsor, or regulator to independently verify:

- that disclosed evidence existed when claimed,
- that it has not changed post-export,
- and that any deviation is immediately detectable.

No trust. 
No custody.  
Just proof.

---
