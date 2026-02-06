# International Audit Trial
## Proof-of-Unchanged Post-Export Evidence Verification (Methodology Evaluation)

**Anchoring Software:** AuditLog.AI  
**Auditing Software:** QMSv5 Auditor  
**Mode:** Zero-Custody | Human-Verified | Machine-Deterministic  
**Version:** v5  
**Trial Window:** CRO-selected 10-week window within Q2 2026 (non-extendable)  
**Scope:** Post-export, pre-archive verification of audit evidence  
**Audience:** Contract Research Organizations (CROs) and eligible research institutions  
**Disclosure Policy:** Aggregate-only; no institutional attribution or endorsement  

**Protocol Originator:** Dr. Fernando Telles  
**Date:** 07 February 2026  
**Status:** Public audit-trial protocol 
**Classification:** Methodology evaluation (non-clinical, non-interventional)  
**AI_used:** true  (document drafting and analysis support only)
**LLM_used:** LLM1<>LLM2<>LLM4  
**Human_verified:** true HV_FT  

**Linked Canonicals:**  
C12: AuditLog.AI Global Compliance Matrix (DOI: 10.5281/zenodo.17462382)  
C17: Proof-of-Unchanged Global Application Matrix (Ordinal 16; DOI: 10.5281/zenodo.18501507)  
Ordinal 15: Proof-of-Unchanged Zero-Custody Audit Reproducibility Trial (DOI: 10.5281/zenodo.18452216)  

---

## 1. Purpose of the Audit Trial

Regulatory inspections routinely rely on evidence that has been exported from operational systems and subsequently retained, transformed, or re-used.  

A recurring inspection question is:

> After evidence is exported and analyses are completed, how can one **prove**, rather than assume, that the evidence has not changed?

For CROs, the practical question is whether exported evidence such as eTMF extracts, EDC exports, or database-lock snapshots can be deterministically verified as unchanged at a later inspection timepoint, **often months or years after export**, when original personnel, systems, or logs may no longer be available and reconstructive investigation is costly or infeasible.

This audit trial evaluates whether **Proof-of-Unchanged**, a custody-boundary verification methodology, can function as a **system-independent, institution-agnostic verification primitive applicable to audit contexts** under real-world CRO governance conditions.

The trial evaluates **verifiability**, not clinical outcomes, system performance, or regulatory compliance.
No claim of regulatory classification, clearance, or endorsement is made or implied.
Track B is observational only and has no bearing on participation, outcomes, or reporting of Track A.

---

## 2. Trial Design Overview

### 2.1 Design Type

- International, CRO-executed audit trial  
- Fixed 10-week verification window within Q2 2026  
- Non-interventional; no modification to trial conduct  
- No randomization, no blinding, no treatment arms  

The trial assesses **post-export evidence verification only**.

### 2.2 Evaluation Tracks

**Track A: Cryptographic Verification (Primary)**  
Mandatory for all participants.

- Deterministic verification of:
  - evidence integrity (byte-level hash parity via dual-hash: SHA-256 and RIPEMD-160(SHA-256))
  - evidence-set membership (Evidence Set Fingerprint equivalence)
- Binary outcomes:
  - **PASS (Proof-of-Unchanged)**, or
  - **Divergence enumerated**
- Machine-deterministic outputs with human-verifiable audit artefacts (HVT-A)
- Verification operates across a four-tier reproducibility architecture (per-evidence, per-batch, per-log, per-session) as documented in C12 and the technical validation materials.

**Track B: Operational Comparison (Optional)**  
CRO-controlled and optional.

- Qualitative comparison with baseline SOPs (e.g., time, effort, review scope)
- Participation in Track B is entirely at the CRO's discretion. By default, no Track B data will be requested, collected, or referenced in any publication. This activity falls entirely under CRO governance. Where a CRO elects to voluntarily disclose Track B results for statistical analysis, prior written approval is required, and any disclosure must be CRO-agnostic and system-agnostic (anonymized).

### 2.3 What CROs Actually Do During the Trial

This audit trial is intentionally **use-case agnostic**.

Participating CROs are not asked to reproduce a predefined workflow, dataset, or protocol.
Instead, each CRO applies Proof-of-Unchanged to **their own audit reality**, under their own SOPs.

During the 10-week window, a CRO may choose to:

- Verify any post-export evidence they already manage (e.g. eTMF exports, EDC snapshots, safety datasets, audit packages).
- Apply verification at any custody boundary they consider operationally relevant (e.g. post-database lock, pre-archive, pre-inspection).
- Re-verify evidence after elapsed time, migration, packaging, or SOP-driven transformation.
- Observe whether verification yields:
  - Proof-of-Unchanged (PASS), or
  - Deterministic divergence enumeration that bounds review scope.

There is **no prescribed workflow**.
There is **no required dataset**.
There is **no expected outcome**.

The trial asks only one question:

> Under real CRO SOPs and governance constraints, can Proof-of-Unchanged be used to deterministically establish whether evidence has changed since export?

CROs may additionally:
- Compare the verification process against their baseline SOPs, **if they wish**.
- Analyse public reference material (Ordinal 15 / Mendeley datasets) **if they wish**.
- Perform no comparative analysis at all and treat the trial as a tooling evaluation.

All choices remain entirely under CRO governance.

---

## 3. What Is Being Verified

Verification applies to **exported audit artefacts**, not live systems.

Verification occurs:
- after export from source systems,
- after database lock,
- before long-term archival or submission.

The verification object is the **evidence state**, not:
- the clinical data itself,
- the originating platform,
- vendor-controlled logs.

The methodology detects change; it does not prevent, judge, or interpret it. Divergence outcomes are informational signals intended solely to direct proportional human effort under applicable SOPs.

---

## 4. System Characteristics (Regulator-Relevant)

- **Zero custody:**  
No raw data, filenames, directory paths, or study metadata leave the CRO environment.

Only the following **proof-only artifacts** are transmitted or retained by AuditLog.AI:
- cryptographic digests (`.hash`, `.2ha`) derived from evidence bytes,
- public anchoring receipts (Bitcoin TXID, block height),
- UTC timestamps associated with the anchoring event, and
- pseudonymous session identifiers (non-reversible meta-IDs) used solely to correlate verification events.

No personal identifiers, study identifiers, file names, directory structures, content metadata, or contextual attributes are transmitted, retained, or processed.

- **Hash-only disclosure:**  
  Verification relies exclusively on dual-hash cryptographic digests (SHA-256 and RIPEMD-160(SHA-256)).

- **Zero authority:**  
  No reliance on proprietary vendor attestations, permissioned validators, or smart contracts. Public time attestation uses Bitcoin mainnet (permissionless, independently verifiable via OP_RETURN).

- **Deterministic outcomes:**  
  Results are mathematically derived (PASS or divergence enumeration). 100% dual-hash parity at both the evidence and membership layers are required for Proof-of-Unchanged (PASS result).

- **Human governance preserved:**  
  All critical system actions, particularly the anchoring of data to a public ledger, require explicit operator confirmation under controlled institutional authentication. Human primacy is enforced through a layered authorization model which includes:  
  (i) Institutional authenticated account (enterprise identity; unique login and password); and  
  (ii) Unique user account (username + password and optional 2FA), where approval is bound to the specific record via record-linking fields that include the reviewer's unique user meta-ID, UTC timestamp, meaning of signature, and the SHA-256 digest of the approved material.

- **Offline verifiability:**  
  Verification can be repeated from retained exports without system participation. Independent auditors may recompute hashes using open-source tools without vendor access.

- **Public time attestation:**  
  Session level cryptographic commitments are blockchain anchored solely to establish existence at time. OpenTimestamps proofs are optionally implemented at the evidence level.

- **Fail-closed architecture:**  
  Runtime execution is governed by Compliance Management Enforcement (CME) rules, including a 300-second execution threshold. If process integrity constraints are violated, the system rejects the session rather than producing an unreliable result.

For detailed regulatory mapping of these characteristics, see C12 AuditLog.AI Global Compliance Matrix.

---

## 5. Verification Outcomes

For each audit session, the system produces:

- Binary Proof-of-Unchanged (PASS) **or**
- Deterministic divergence enumeration (informational)
- Human-verifiable audit artefacts (HVT-A)

**Interpretation rule (non-accusatory):**

- PASS confirms evidence is provably unchanged.
- Divergence does **not** imply error, misconduct, or non-compliance.
- Divergence does **not** imply control failure.
- Divergence exists solely to bound proportional human review toward the minimal delta set.

> PASS reduces reconstructive effort.  
> Divergence bounds reconstructive effort.

Verification establishes integrity facts; interpretation, materiality, and response remain exclusively human and institutional responsibilities.

---

## 6. Independent Verification Options

Participants may independently:

- Recompute cryptographic identifiers from their retained evidence exports using open-source tools (e.g., folder_dualhasher_v2.py, extract_hashes.py, or AuditLog.AI_PublicDualHashVerifier.exe).
- Verify equivalence or divergence against pre-anchored canonical states.
- Confirm public blockchain anchors via any Bitcoin explorer using the provided TXID and payload.
- Assess whether Proof-of-Unchanged holds under their own custody and governance constraints.

Verification remains possible **without continued system access**.

Public hash-only verification materials are provided via Ordinal 15 DOI: [10.5281/zenodo.18452216](https://doi.org/10.5281/zenodo.18452216) and associated repositories:
- Zero-custody export packets: Mendeley Data, doi: [10.17632/wjj674twb4.1](https://doi.org/10.17632/wjj674twb4.1)
- Analysis dataset: Mendeley Data, doi: [10.17632/fzw4pzkd83.1](https://doi.org/10.17632/fzw4pzkd83.1)

Ordinal 15 is provided as a public, worked example of Proof-of-Unchanged in a disclosed setting; it is not the object of the trial itself.

---

## 7. Eligibility

Participation is restricted to:

- Contract Research Organizations (CROs), and
- Accredited academic or research institutions

Participants must have custodial responsibility for regulated, inspectable, or compliance-relevant evidence.

Note: This trial protocol is scoped to clinical research institutions. Methodology evaluations for audit & assurance or technology governance contexts are described separately (see C17 Proof-of-Unchanged Global Application Matrix).

---

## 8. Participation Constraints

- Participation requires registration and is limited to a single 10-week window within Q2 2026. The 10-week window begins after institutional registration is complete, not from initial outreach.
- Induction is a single remote session (approximately 60-90 minutes), covering software installation, verification execution, and artefact review.
- No PHI / PII ingestion. Proof-only, hash-based zero-custody data flow.
- No clinical diagnosis or therapy support. Software does not inform medical decisions.
- No overwriting of audit history. Append-only verification with immutable cryptographic anchoring.
- Software access and induction are provided by Cardiovascular Diagnostic Audit & AI Pty Ltd (Melbourne, Australia).

---

## 9. Governance and Compliance Position

- The protocol originator does not access, retain, or process any participant evidence, filenames, or metadata. Only aggregate, non-attributable verification statistics (session count, session meta ID and timestamp) may be collected.
- This trial involves no clinical intervention, and no modification to trial conduct. Participating institutions may elect to notify their ethics or governance committees at their discretion.
- No interference with trial conduct.
- No regulatory submissions are made as part of this trial.
- Results may be reported **only in aggregate**, without attribution.
- No endorsements will be requested or published.

**Conflict of interest disclosure:**  
Cardiovascular Diagnostic Audit & AI Pty Ltd (ABN 19 638 019 431) is the developer of the software under evaluation. This relationship is disclosed to all participants prior to registration. The trial evaluates methodology verifiability, not commercial suitability.  
Participation does not constitute vendor onboarding, procurement evaluation, or commercial engagement, and creates no licensing, purchase, or endorsement obligation.

This trial evaluates **verifiability**, not regulatory acceptance or compliance status.

---

## 10. Post-Trial Disclosure

At the conclusion of the trial window, **only aggregate, non-attributable information that is available under the zero-custody model may be disclosed**.

By default, this is limited to system-observable facts, such as:

- number of registered participating organizations
- number of audit sessions executed
- timestamps

Any analysis beyond these system-level aggregates (including interpretation of divergence rates, false positives, or operational comparisons) is **possible only if a participating CRO voluntarily elects to disclose such information** under its own governance and with explicit written approval.

No participant-level evidence, results, or identifiers are accessible to the protocol originator without voluntary disclosure.

No endorsements will be requested or published.  
No individual institutional results will be disclosed.

---

## 11. Forward Path

Following completion of the audit trial, results may inform:

- refinement of Proof-of-Unchanged methodology,
- potential CRO and sponsor evaluation programs for subsequent studies,
- subsequent multi-site evaluations.

---

## 12. Regulatory and Assurance Framework References

This methodology is positioned under electronic records and audit documentation frameworks. Detailed clause-level mapping is provided in C12 AuditLog.AI Global Compliance Matrix.

Referenced frameworks include:

- **FDA 21 CFR Part 11** - electronic records and electronic signatures
- **EMA Annex 11** + GCP Guideline Integration (2023) - computerized systems and data integrity
- **TGA / PIC/S PE 009-17** - harmonized GMP computerized systems
- **PCAOB AS 1105 / AS 1215** (including AS 1105.10A - external electronic information reliability evaluation, effective for fiscal years beginning on or after December 15, 2025)
- **ISA 230 / ISA 500 / ISA 240 (Revised 2025)** - international audit documentation and evidence standards

These references reflect methodological alignment and evidence mapping, not regulatory acceptance or certification. No regulatory authority has reviewed, classified, or endorsed this methodology.

This methodology is **not** clinical decision support, is **not** a medical device, and does not provide patient-level treatment recommendations.

---

## 13. Public Verification References

> Format: **Block; Payload. Bitcoin TXID**

**Ordinal 15** - Proof-of-Unchanged Zero-Custody Audit Reproducibility Trial  
> 934659; ORDINAL15|7152ab0ffdd30982127306539db22725349d168f|d8a2d8e2. Bitcoin `006e274af867de728c28da77175892cb76821e82f05378033e95e024712912a7`

Telles F. Ordinal 15: Proof-of-Unchanged Zero-Custody Audit Reproducibility Trial. Zenodo; 2026.  
https://doi.org/10.5281/zenodo.18452216

*(For the complete methodology reference and anchor index, see C17 Proof-of-Unchanged Global Application Matrix.)*

---

## Contact

Dr. Fernando Telles  
Founder & Lead Architect  
AuditLog.AI  
Fernando.Telles@AuditLog.AI

---

*This protocol describes a methodology evaluation. It does not constitute regulatory advice, legal opinion, or a determination by any regulatory authority. Final classification and regulatory acceptance rest with the applicable authorities (FDA, EMA, TGA, PCAOB, or other competent body).*
