# International Audit Trial
## Proof-of-Unchanged Post-Export Evidence Verification

**Anchoring Software:** AuditLog.AI  
**Auditing Software:** QMSv5 Auditor  
**Mode:** Zero-Custody | Human-Verified | Machine-Deterministic  
**Version:** v5  
**Trial Window:** CRO-selected 10-week window within Q2 2026 (non-extendable)  
**Scope:** Post-export, pre-archive verification of audit evidence  
**Audience:** Contract Research Organizations (CROs) and eligible research institutions  

**Protocol Originator:** Dr. Fernando Telles  
**Date:** 07 February 2026  
**Status:** Public audit-trial protocol  
**Classification:** Methodology evaluation (non-clinical, non-interventional)  

**Linked Canonicals:**  
C12: AuditLog.AI Global Compliance Matrix  
C17: Proof-of-Unchanged Global Application Matrix  
Ordinal 15: Proof-of-Unchanged Zero-Custody Audit Reproducibility Trial  

---

## 1. Purpose of the Audit Trial

Regulatory inspections routinely rely on evidence that has been exported from operational systems and subsequently retained, transformed, or re-used.  

A recurring inspection question is:

> After evidence is exported and analyses are completed, how can one **prove**, rather than assume, that the evidence has not changed?

This audit trial evaluates whether **Proof-of-Unchanged**, a custody-boundary verification methodology, can function as a **system-independent, institution-agnostic audit primitive** under real-world CRO governance conditions.

The trial evaluates **verifiability**, not clinical outcomes, system performance, or regulatory compliance.

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
  - evidence integrity (byte-level hash parity)
  - evidence-set membership (Evidence Set Fingerprint equivalence)
- Binary outcomes:
  - **PASS (Proof-of-Unchanged)**, or
  - **Divergence enumerated**
- Machine-deterministic outputs with human-verifiable audit artefacts (HVT-A)

**Track B: Operational Comparison (Optional)**  
CRO-controlled and optional.

- Qualitative comparison with baseline SOPs (time, effort, review scope)
- No requirement to report Track B results

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

---

## 4. System Characteristics (Regulator-Relevant)

- **Zero custody:**  
  No raw data, filenames, directory paths, or metadata leave the CRO environment.

- **Hash-only disclosure:**  
  Verification relies exclusively on cryptographic digests.

- **Zero authority:**  
  No reliance on vendor attestations, validators, or smart contracts.

- **Deterministic outcomes:**  
  Results are mathematically derived (PASS or divergence enumeration).

- **Human governance preserved:**  
  No AI interpretation, scoring, or judgement.

- **Offline verifiability:**  
  Verification can be repeated from retained exports without system participation.

- **Public time attestation:**  
  Cryptographic commitments are anchored solely to establish existence at time.

---

## 5. Verification Outcomes

For each audit session, the system produces:

- Binary Proof-of-Unchanged (PASS) **or**
- Deterministic divergence enumeration (informational)
- Human-verifiable audit artefacts (HVT-A)

**Interpretation rule:**

- PASS confirms evidence is provably unchanged.
- Divergence does **not** imply error, misconduct, or non-compliance.
- Divergence exists solely to bound proportional human review.

> PASS reduces reconstructive effort.  
> Divergence bounds reconstructive effort.

---

## 6. Independent Verification Options

Participants may independently:

- Recompute cryptographic identifiers from their retained evidence exports.
- Verify equivalence or divergence against pre-anchored canonical states.
- Assess whether Proof-of-Unchanged holds under their own custody and governance constraints.

Verification remains possible **without continued system access**.

Public hash-only verification materials are provided via Ordinal 15 and associated repositories.

---

## 7. Eligibility

Participation is restricted to:

- Contract Research Organizations (CROs), and
- Accredited academic or research institutions

Participants must have custodial responsibility for regulated, inspectable, or compliance-relevant evidence.

---

## 8. Participation Constraints

- Participation requires registration.
- Trial access is limited to a single 10-week window within Q2 2026.
- No PHI / PII ingestion.
- No clinical diagnosis or therapy support.
- No overwriting of audit history (append-only verification).
- Software access and induction are provided by Cardiovascular Diagnostic Audit & AI Pty Ltd (Australia).

---

## 9. Governance and Compliance Position

- No participant data accessed by the protocol originator.
- No ethics approval required.
- No interference with trial conduct.
- No regulatory submissions are made as part of this trial.
- Results may be reported **only in aggregate**, without attribution.

This trial evaluates **verifiability**, not regulatory acceptance or compliance status.

---

## 10. Post-Trial Disclosure

At the conclusion of the trial window, aggregate facts may be disclosed, including:

- number of participating organizations,
- number of audit sessions executed,
- number of artefacts verified,
- presence or absence of false positives.

No endorsements will be requested or published.

---

## 11. Forward Path

Following completion of the audit trial, results may inform:

- refinement of Proof-of-Unchanged methodology,
- CRO and sponsor design-partner programs for future studies,
- subsequent multi-site evaluations.

---

## Contact

Dr. Fernando Telles  
Founder & Lead Architect  
AuditLog.AI  
📧 Fernando.Telles@AuditLog.AI
