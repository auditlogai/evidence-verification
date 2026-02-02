# VERIFICATION_MODEL

This document defines the verification model used by AuditLog.AI and QMSv5 software.  
It describes **what is verified**, **how verification is performed**, and **how outcomes are determined**, without reference to execution environments, filenames, or proprietary systems.

The model is designed for inspection readiness and independent verification.

---

## Software Model

1)  AuditLog.AI (Anchoring system): At baseline (T₀) and audit timepoints (T₁), evidence artefacts are cryptographically frozen and Bitcoin-anchored to establish publicly verifiable timestamps. Anchoring commits evidence state without exporting raw evidence.

2) QMSv5 Auditor (Audit-verification system): Performs deterministic paired comparison of independently anchored states (T₀ vs T₁), generating hash-only verification packets and summary reports. Exported artefacts contain cryptographic identifiers and deterministic outcomes only (no raw evidence or human-readable identifiers).

---

## Scope

This document explains:

- Hash-only verification (file integrity and evidence membership)
- Deterministic PASS / FAIL semantics
- The role of Evidence Set Fingerprints (ESF)
- The distinction between required and optional human verification time (HVT-A vs HVT-B)

It does **not** describe system implementation details, pricing, trials, or operational onboarding.

---

## Overview of the verification model

AuditLog.AI and QMSv5 Auditor are software that operate under a hash-first, zero-authority verification model.

Verification is based solely on cryptographic invariants derived from evidence bytes and evidence membership.  
No trust in authors, vendors, execution platforms, or storage systems is required.

**Figure 1** illustrates the end-to-end proof-of-unchanged reproducibility pipeline, from evidence selection through independent verification (`Reproducibility_Pipeline_Fig1.html`).

---

## Verification primitives

### 1. File integrity (Layer 1)
Each evidence file is represented by a dual cryptographic digest:

- **SHA-256(file bytes)**
- **RIPEMD-160(SHA-256)**

These values uniquely identify the exact byte content of a file.  
Any change to the file content, metadata, or encoding produces a different digest.

Filenames, paths, timestamps, and storage locations are explicitly excluded from verification.

### 2. Evidence membership integrity (Layer 2)
Verification also requires confirming **which files belong to the evidence set**.

This is achieved using an **Evidence Set Fingerprint (ESF)**, computed from the complete set of per-file hash identifiers:

- All `(SHA-256, RIPEMD-160)` pairs are collected
- The set is deterministically ordered
- A single cryptographic fingerprint (ESF) is derived

The ESF changes if **any file is added, removed, replaced, or altered**, regardless of naming or directory structure.

---

## Deterministic outcomes: PASS and FAIL

All verification outcomes are deterministic and reproducible.

### PASS
A verification **PASS** occurs when:

- All per-file hash identifiers match
- Evidence Set Fingerprints (ESF) match
- No missing or extra identifiers are present

PASS indicates that the evidence has **not changed** relative to the reference state.

### FAIL
A verification **FAIL** occurs when **any** of the following is true:

- A file hash does not match
- The ESF does not match
- Missing identifiers are detected
- Extra identifiers are detected

FAIL outcomes are **explicit and enumerable**.  
The verification output identifies exactly what differs.

FAIL is an acceptable and informative outcome; it requires no interpretation or discretionary judgment.

---

## Human verification time (HVT)

Human involvement is limited to verification, not investigation or interpretation.

### HVT-A: Cryptographic verification (required)

HVT-A is the time required for a human to:

- Verify machine-deterministic HVT-A report
- Confirm PASS or FAIL deterministically
- In Stage IV, HVT-A involved comparison of hash-only artefacts reported by the system against pre-anchored ground-truth keys derived from Stage IIIA and IIIB tamper events. Verification confirmed that all enumerated FAIL outcomes at both the evidence and membership layers matched the expected cryptographic divergence.

HVT-A establishes proof-of-unchanged (or divergence hash-only enumeration per evidence and per Evidence Set Fingerprint membership).  
It does **not** require filenames, paths, or execution environments.

---

### HVT-B: Representational interpretation (optional)

HVT-B is optional and occurs **after** HVT-A.

It may involve:
- Mapping hashes back to filenames or paths locally
- Preparing regulatory narratives
- Reconciling findings with operational documentation

**HVT-B is not required for verification of Proof-of-Unchanged.** 

In Stage IV, HVT-B was invoked as a bounded, declared complement for swap enumeration only when swapped evidence pair were unaltered, byte-identical, and already present within audit corpus. In this case, although swap detection is deterministic at the membership layer, enumeration of byte-identical artefacts that are rearranged, but not altered (byte-identical), is not decidable from hash-only membership signals alone. 

---

## Deterministic verification as a distinct audit modality

The verification model implemented by AuditLog.AI and QMSv5 Auditor constitutes a **distinct audit modality**, not an extension of traditional system-based audit trails.

Conventional audit approaches frequently bind integrity assurance to:
- continued operation of the originating system,
- access-control or role-based authorization layers, or
- vendor-managed logging infrastructure.

In contrast, the hash-first, zero-custody model evaluated here binds integrity claims **directly to exported evidence artefacts**, enabling independent verification without privileged access, proprietary infrastructure, or continued system availability.

Verification under this model is a **reproducible mathematical operation**, not a procedural reconstruction. Outcomes can be independently re-derived by any third party using retained evidence copies and publicly anchored commitments, supporting verification across institutional, temporal, and jurisdictional boundaries.

---

## Interpretation and authority boundaries

Deterministic PASS and FAIL outcomes **do not constitute findings of misconduct, error, or regulatory non-compliance**.

A PASS outcome indicates cryptographic equivalence between two independently anchored evidence states.

A FAIL outcome indicates **byte-level or membership-level divergence** relative to a reference state and is accompanied by explicit, enumerable cryptographic identifiers describing what differs.

The system verifies **integrity and membership**, not:
- semantic correctness,
- scientific validity,
- procedural appropriateness, or
- regulatory acceptability.

Benign and expected processes such as archival migration, format normalization, line-ending conversion, or export tooling, may alter byte-level representations and therefore legitimately produce FAIL outcomes requiring contextual interpretation.

---

## Relationship to CRO and regulator authority

This verification model does **not** replace CRO quality systems, sponsor oversight, or regulatory judgment.

Instead, it functions as a **selective verification layer** that:

- deterministically bounds the scope of review,
- distinguishes unchanged evidence from changed evidence,
- enumerates divergence without interpretation,
- and directs human effort proportionally.

CROs, sponsors, and regulators retain full authority to:
- interpret the significance of detected divergence,
- determine acceptability under applicable SOPs and regulations,
- assess root cause, intent, and impact,
- and make all regulatory or governance decisions.

Deterministic verification reduces ambiguity; it does not remove accountability.

---

## Zero-authority in the technical sense

The term *zero-authority* refers solely to the **technical verification layer**:

- No individual, vendor, or institution can override cryptographic PASS or FAIL outcomes.
- Outcomes are derived solely from computation over disclosed inputs.
- Any independent party can reproduce the same outcome using the same artefacts.

Authority over **interpretation, disposition, and regulatory action** remains explicitly human and institutional.

---

## Anchoring and public verification

Post-export evidence states are anchored to a neutral public timestamping substrate without continued validator participation using Bitcoin OP_RETURN.

Anchoring records:
- cryptographic digests only with no identifiers

Anchoring does not store evidence, filenames, or semantics.  
It provides an immutable, time-ordered public reference for independent verification.

--- 

## Summary

Deterministic cryptographic verification reframes auditability from a trust-based process to a falsifiable, reproducible verification task.

By separating **verification** (what changed) from **judgment** (what it means), this model enables:

- proportional review,
- reduced investigative burden,
- clearer escalation pathways,
- and alignment with established principles of audit independence and regulatory oversight.

This approach preserves CRO and regulator authority while improving the reliability, transparency, and reproducibility of post-export evidence verification.


---

## Relationship to other documents

- `CRO_QUICKSTART.md`:procedural guide for CROs and inspectors  
- `REPRODUCIBILITY.md`: instructions for reproducing reported results  
- `ANCHOR_INDEX_StageIV.ndjson`:** authoritative mapping of execution events to anchored proofs  

---
