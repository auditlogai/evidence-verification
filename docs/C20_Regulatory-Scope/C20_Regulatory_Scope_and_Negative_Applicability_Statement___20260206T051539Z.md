# C20: Regulatory Scope and Negative Applicability Statement
## Proof-of-Unchanged Methodology (Electronic Records & Audit Infrastructure)

**Audience:** CRO Quality Assurance, Regulatory Affairs, Inspection Readiness, Independent Evaluators  
**Applies to:** Proof-of-Unchanged methodology; AuditLog.AI execution evidence; QMS Auditor outputs  
**Scope Type:** Methodology positioning and negative regulatory applicability  
**Anchoring Software:** AuditLog.AI 
**Auditing Software:** QMS Auditor
**Version:** v5  
**Mode:** Zero-Custody | Hash-Only | Human-Verified | Machine-Deterministic | Time-Anchored  
**Protocol Originator:** Dr. Fernando Telles  
**Date:** 06 February 2026  
**AI_used:** true  
**LLM_used:** LLM1<>LLM4  
**Human_verified:** true (HV_FT)  
**Classification:** Public methodology-level positioning (non-authoritative; non-binding)  
**Primary references:**  
- C12 AuditLog.AI Global Compliance Matrix (Ordinal 12; DOI: 10.5281/zenodo.17462383)  
- C17 Proof-of-Unchanged Global Application Matrix (Ordinal 16; DOI: 10.5281/zenodo.18501507)

> **One-sentence summary:** This document clarifies the regulatory scope boundaries of the Proof-of-Unchanged methodology as documented in publicly anchored materials and explicitly identifies frameworks to which it does not apply.

---

## Purpose of this page

This page clarifies the **regulatory scope boundaries** of the AuditLog.AI Proof-of-Unchanged methodology, as documented in publicly available, cryptographically anchored materials.

It is intended to help CRO QA and Regulatory Affairs teams:
- understand **what regulatory frameworks this methodology is positioned under**,
- understand **what it is explicitly not**, and
- avoid misclassification (e.g., as clinical decision support or medical device software).

This page does **not** assert regulatory approval, clearance, or endorsement.  
Formal regulator engagement (e.g., FDA Q-Submission, EMA Scientific Advice, TGA Excluded Software Determination) is planned but has **not yet occurred**. No regulatory authority has reviewed, classified, or endorsed this methodology.

---

## High-level positioning (methodology, not approval)

Based on the published evidence and mappings in **C12: AuditLog.AI Global Compliance Matrix**, the Proof-of-Unchanged methodology is positioned as:

> **Audit-trail and electronic-records verification infrastructure**, operating at custody boundaries, under electronic records, data integrity, and audit documentation frameworks.

This positioning reflects **how the methodology is designed and documented**, not a determination by any regulatory authority.

---
## What this methodology does (intended use)

As documented in **C17: Proof-of-Unchanged (Global Application Matrix)**, the intended use of the methodology is to:

- Verify whether **exported digital evidence has remained byte-unchanged** since a prior, verifiable checkpoint.
- Operates **post-export, pre-archive**, or at other custody boundaries.
- Uses **hash-only, zero-custody verification** with optional decentralized time attestation and public anchoring.
- Produces **deterministic outcomes**:
  - **PASS (proof-of-unchanged)**, or
  - **divergence enumeration** (informational deltas to bound human review).

The methodology **detects change**; it does not prevent, judge, or interpret it.

---

## What this methodology does **not** do (negative scope)

Based on its documented design and published evidence, the Proof-of-Unchanged methodology:

- **Does not provide clinical recommendations** regarding diagnosis, treatment, prevention, or patient care.
- **Does not analyze patient-specific medical information** for clinical decision-making.
- **Does not generate compliance determinations**, audit opinions, or regulatory judgments.
- **Does not infer intent, misconduct, or error** when divergence is detected.
- **Does not operate inside source systems** (EDC, eTMF, CTMS, LIMS, cloud platforms).
- **Does not require system integration** or modification of operational workflows.
- **Does not perform real-time monitoring or control**.

Divergence outcomes are **informational signals**, intended solely to **direct proportional human effort** under applicable SOPs.

---

## Relationship to FDA Clinical Decision Support (CDS) Guidance (January 2026)

The FDA's updated **Clinical Decision Support Software Guidance** (revised final, January 6, 2026; superseded January 29, 2026) clarifies when software functions fall within, or outside, medical-device regulation under section 520(o)(1)(E) of the FD&C Act.

As documented and positioned in C12 and C17:
- The Proof-of-Unchanged methodology **does not meet the definitional criteria for CDS** under section 520(o)(1)(E) of the FD&C Act, because it:
  - is not intended to provide recommendations to healthcare professionals regarding diagnosis, treatment, or prevention (Criterion 3),
  - does not analyze patient-specific medical information for the purpose of clinical decision-making, and
  - does not generate outputs intended to be relied upon for clinical diagnosis or treatment decisions regarding individual patients (Criterion 4).

Accordingly, the CDS guidance is referenced here **only to clarify non-applicability**, not as a governing framework.

No claim is made that FDA has reviewed or classified AuditLog.AI under this guidance.

---

## Regulatory frameworks referenced in C12 (documented mapping)

The following frameworks are referenced **as mapping contexts** in **C12: AuditLog.AI Global Compliance Matrix**, based on how the methodology’s execution evidence aligns with documented requirements:

- **FDA 21 CFR Part 11** — electronic records and electronic signatures
- **EMA Annex 11** + GCP Guideline Integration (2023) — computerized systems and data integrity
- **TGA / PIC/S PE 009-17** — harmonized GMP computerized systems
- **PCAOB AS 1105 / AS 1215**, including **AS 1105.10A** — audit evidence and external electronic information reliability evaluation (effective for fiscal years beginning on or after December 15, 2025)
- **ISA 230 / ISA 500 / ISA 240 (Revised 2025)** — international audit documentation and evidence standards

These references reflect **methodological alignment and evidence mapping**, not regulatory acceptance or certification.

---

## Intended regulatory role (for CROs)

For CRO Quality and Regulatory Affairs teams, the Proof-of-Unchanged methodology is intended to function as:

- a **post-export verification layer** applied at custody boundaries (as defined in C17 §3–4),
- a **supplement to existing SOPs**, not a replacement for validation, quality systems, or regulatory judgment,
- a deterministic method to **prove evidence has not changed** between defined checkpoints, and
- a method to **bound inspection and audit effort** to the minimal delta set when change has occurred.

It does **not** replace validation, quality systems, inspection readiness programs, or regulatory judgment.

---

## Source documents

The regulatory positioning described on this page is derived exclusively from publicly available, cryptographically anchored materials:

- **C12: AuditLog.AI Global Compliance Matrix** (Ordinal 12; DOI: 10.5281/zenodo.17462383) 
- **C17: Proof-of-Unchanged: Global Application Matrix** (Ordinal 16; DOI 10.5281/zenodo.18501507)
- **AuditLog.AI Runtime Execution and Validation Dossier** (Ordinal 11; DOI: 10.5281/zenodo.17460850) 
- **Ordinal 15: Proof-of-Unchanged Zero-Custody Audit Reproducibility Trial** (Ordinal 15; DOI: 10.5281/zenodo.18452216)

Public anchoring and verification details are described on the **Proof-of-Unchanged** page.

---

## Summary

Proof-of-Unchanged is a **custody-boundary verification methodology** designed to answer one narrow, deterministic question:

> **Has this evidence changed since the last verified checkpoint?**

It operates within electronic records and audit documentation contexts, as documented in C12, and is **not positioned as clinical decision support or medical-device software**.

All interpretations remain subject to CRO governance, SOPs, and future regulator interaction.

---

*This page describes the regulatory scope positioning of the Proof-of-Unchanged methodology as documented in publicly anchored materials. It does not constitute regulatory advice, legal opinion, or a determination by any regulatory authority. Final classification and regulatory acceptance rest with the applicable authorities (FDA, EMA, TGA, PCAOB, or other competent body).*
