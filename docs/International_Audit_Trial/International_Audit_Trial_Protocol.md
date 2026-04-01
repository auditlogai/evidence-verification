# Independent External Evaluation of Post-Export Clinical Research Package Integrity

https://doi.org/10.17605/OSF.IO/WP73B

Date: 30 March 2026
Classification: Methodology evaluation (non-clinical, non-interventional)
Anchoring System: AuditLog.AI software
Auditing System: QMS Auditor software
Software Version: v5  
Mode: Zero-Custody | Human-Verified | Machine-Deterministic  
Activation Window: CRO/research institution selected start date must fall between 01 Apr 2026 and 30 Jun 2026.  
Evaluation Window: Each participating institution receives one non-extendable 10-week evaluation window, beginning on its registered activation date and ending 10 weeks after activation.
Scope: Post-export, pre-archive verification of clinical and/or regulatory evidence  
Audience: Contract Research Organizations (CROs) and eligible research institutions  
Disclosure Policy: Aggregate-only; no institutional attribution or endorsement  

Correspondence: 
Dr. Fernando Telles, BMedSc (Adv), MD(Dist) 
Methodology Lead for AuditLog.AI Research Initiative
Director, Cardiovascular Diagnostic Audit & AI
21 Shields Street, Flemington Victoria 3031, Australia
Email: Fernando.Telles@AuditLog.AI | Tel: +61 3 7302 0721

Linked public documents:
C12: AuditLog.AI Global Compliance Matrix (DOI: 10.5281/zenodo.17462382)  
C17: Proof-of-Unchanged Global Application Matrix (DOI: 10.5281/zenodo.18501507)  
Ordinal 15: Proof-of-Unchanged Zero-Custody Audit Reproducibility Trial (DOI: 10.5281/zenodo.18452216)  

---

## 1. The problem

Validated trial and registry systems generate high-fidelity records during data capture. After export, however, integrity is generally assumed rather than verified. There is currently no established, system-independent method to determine whether an exported clinical research package remains unchanged between export and later use, including pre-analysis curation, statistical analysis, manuscript preparation, archive, or submission.

---

## 2. Purpose of the Audit Trial (Research questions)

Regulatory inspections routinely rely on evidence that has been exported from validated systems and subsequently retained, transformed, or re-used.  

The critical inspection question is:
Can exported clinical research evidence be reproducibly verified as unchanged, or shown to have changed, without custody transfer of sensitive data?

Operational examples of validated system warranting post-export integrity assurance include:
- For CROs: eTMF extracts, EDC exports, or database-lock snapshots 
- For Research institutions: validated registries exports or clinical trial data at point of hand off cross-institutions for multi-site studies.

The practical question becomes whether exported evidence from these systems can be deterministically verified as unchanged at a later inspection timepoint, often months or years after export, when original personnel, systems, or logs may no longer be available and reconstructive investigation is costly or infeasible.

This audit trial evaluates whether Proof-of-Unchanged, a custody-boundary verification methodology, can function as a system-independent, institution-agnostic verification primitive applicable to audit contexts under independent, external governance conditions.

### Research question 1 (Feasibility): Can Proof-of-Unchanged be executed under real institutional governance using only post-export artefacts, with no custody transfer and no workflow modification?

### Research question 2 (Determinism): Do repeated verifications of the same retained export, within the same institution, yield identical cryptographic outputs and identical session outcomes?

### Research question 3 (Controlled-comparison accuracy): Under the minimum required external evaluation, do required control comparisons yield the expected outcomes: MATCH for unchanged copies and DIVERGENCE for controlled modifications?

### Research question 4 (immutable verifiability): Can a verifier confirm public anchoring receipts (TXID/block/payload) and recompute the relevant digests locally to verify parity without vendor access?

### Research question 5 (Independent verifiability): Can a third-party auditor reproduce results using hash-only export packets, without access to raw data, filenames, directory paths, or contextual metadata to recompute the relevant digests offsite and verify parity independently?

### Research question 6 (Operational utility, optional): When divergence occurs, can deterministic divergence enumeration bound proportional human review to the minimal delta set under existing SOPs?

---

## 3. Trial Design Overview

### Design Type

- Independent, external institution-executed methodology evaluation (audit evidence verification)  
- Non-clinical and non-interventional: no change to patient care, no change to trial conduct, and no transfer of participant data outside institutional controls  
- No clinical diagnosis or therapy support. Software does not inform medical decisions.
- No PHI / PII ingestion. Proof-only, hash-based zero-custody data flow.
- No randomization, no clinical treatment arms  
- Unit of participation: institutions (CROs / eligible research institutions); unit of analysis: verification sessions

### Verification Methodology

The method performs a paired comparison of two frozen, time-anchored evidence states (typically 1–10,000 files per state) and verifies:
•	Evidence integrity: whether individual file bytes are unchanged
•	Membership integrity: whether the grouping of files within a package are unchanged

Outputs are machine-deterministic audit artefacts (HVT-A) for human verification showing either:
•	MATCH: proof-of-unchanged
•	DIVERGENCE: altered / missing / extra items enumerated for review
These can be re-executed anytime with reproducible results. 

### Scope Boundary

The trial assesses post-export evidence verification only.
This establishes integrity facts only. PASS reduces reconstructive effort. Divergence bounds proportional human review toward the minimal delta set reducing reconstructive effort. 
It does not evaluate clinical meaning, statistical validity, compliance, intent, or root cause. No claim of regulatory classification, clearance, endorsement, or procurement suitability is made or implied.

### Eligibility

Participation is restricted to:
- Contract Research Organizations (CROs), and
- Accredited academic or research institutions

Participants must have custodial responsibility for clinical, regulated, inspectable, or compliance-relevant evidence.

### What independent institutions retain control over

Participating institutions retain control of:
•	data custody
•	governance and execution environment
•	choice of controls / challenges
•	interpretation of results
•	any decision to expand testing

Institutions may run unlimited internal tests and controls during the evaluation window

### Minimum External Evaluation Requirement (Track A, primary)

1.	Select one post-export research package 

2.	Locally freeze three evidence states using Anchoring System:
a) Reference state (immediately post-export)
b) Positive control (re-execution of locally frozen reference state / unchanged copy)
c) Integrity challenge (controlled modification)
The anchoring system freezes each state locally with complete provenance logs, and records a compact hash-only public timestamp commitment.

3.	Use Verification System to perform paired-comparisons of evidence states:
a)	Reference vs Positive control (expected MATCH)
b)	Reference vs Integrity challenge (expected MISSMATCH with divergence enumerated)
c)	Positive control vs Integrity challenge (expected MISSMATCH with divergence enumerated)

Minimum Disclosure Set (aggregate-only, no institutional attribution):

- number of institutions activated (count only)
- number of verification sessions executed
- number of anchors registered
- number of required control comparisons executed
- outcomes aggregated across all required control comparisons: True Positives / True Negatives / False Positives / False Negatives
- divergence class counts aggregated across all required control comparisons (missing, extra, altered, membership mismatch, log mismatch, session mismatch)

Optional Additional Disclosure:

- Human Verification Time (HVT-A): Software two can be utilized to register and timestamp START/END of human verification. From which summary statistics can be derived (seconds/file).
- qualitative notes on divergence sources and classes

Optional Extension (Track B)

Participation in Track B is optional and remains under CRO/research institution governance. Unlimited additional tests and controls may be introduced, with analyses extended to qualitative comparison against current standard operating protocols (time, effort, review scope, accuracy). 
By default, no Track B data will be requested, collected, pooled, or published. If an institution voluntarily elects to disclose Track B observations for aggregate reporting, prior written approval is required and all disclosures must remain institution-agnostic and system-agnostic.

---

## 4. System Characteristics and Definitions

•	Zero custody:  Software execution is performed locally. No raw data, filenames, directory paths, or study metadata leave the local environment.
Only the following proof-only artifacts are transmitted or retained by AuditLog.AI:
- cryptographic digest (SHA256 / RIPEMD160) of an evidence state’s provenance log, which is then anchored to Bitcoin mainnet via OP_RETURN.
- public anchoring receipts (Bitcoin TXID, block height),
- UTC timestamps associated with the anchoring event, and
- pseudonymous session identifiers (non-reversible meta-IDs) used solely to correlate verification events.

Session level cryptographic commitments are blockchain anchored solely to establish existence at time. OpenTimestamps proofs are optionally implemented at the evidence level.

No personal identifiers, study identifiers, file names, directory structures, content metadata, or contextual attributes are transmitted, retained, or processed.

•	Hash-only offline independent verifiability:  
 Verification relies exclusively on dual-hash cryptographic digests of evidence files (SHA-256 and RIPEMD-160(SHA-256)); not raw data itself. 
Verification can be repeated, locally from retained exports; or
Hash-only export packets can be generated locally by software two for independent, off-site verification without disclosure of sensitive data. 
Verification does not require ongoing system participation. Software two automates verification at scale, however independent auditors may recompute hashes using open-source tools without vendor access.

•	Human governance:  
 All critical system actions, particularly the anchoring of data to a public ledger, require explicit operator confirmation under controlled institutional authentication. Human primacy is enforced through a layered authorization model which includes:  
  (i) Institutional authenticated account (enterprise identity; unique login and password); and  
  (ii) Unique user account (username + password and optional 2FA), where approval is bound to the specific record via record-linking fields that include the reviewer's unique user meta-ID, UTC timestamp, meaning of signature, and the SHA-256 digest of the approved material.

•	Fail-closed architecture:  
Software runtime execution is governed by Compliance Management Enforcement (CME) rules, including a 300-second execution threshold. If process integrity constraints are violated, the system rejects the session rather than producing an unreliable result.

---

## 5. What is Provided to Independent Institutions

Registered institutions will receive unrestricted access to the anchoring and verification software for methodology evaluation, initial setup and ongoing support during trial conduction. 
Software access and induction are provided by Cardiovascular Diagnostic Audit & AI Pty Ltd (Melbourne, Australia).

---

## 6. Local Operational Requirements

1.	Software download and registration: Anchoring software has been designed in alignment with global regulatory standards FDA/EMA/TGA (C12: AuditLog.AI Global Compliance Matrix; https://doi.org/10.5281/zenodo.17462383). Therefore, institutional authentication registration is required for provenance logs (provenance logs remain local/not exported). 
2.	Operating computer (local): The methodology is designed to run on standard modern workstations. However, for larger datasets (5,000+ files per state) increased specifications/RAM improves hashing processing speed. Anchoring software copies and freezes evidence states locally for long term reproducibility (local data storage, frozen protections against accidental modification only). 
3.	Internet connection: required for blockchain timestamping. 
4.	Processing time: Anchoring an evidence state takes approximately 15 minutes; verification is typically near-instantaneous. Both depend on data size and operating computer specifications. 

---

## 7. Current status

A single-site study comprising five audit stages with increasing difficulty has been completed. In the current blinded, multi-operator proof-of-concept, 230,253 evidence files and 21,966 evidence-set fingerprints were deterministically verified, with 100% sensitivity, no false positives, and mean verification time of 0.076 seconds per file. Manuscript titled “Verification of post-export clinical trial evidence using a custody-boundary, system-independent model: a blinded, multi-operator, single-site proof-of-concept study” is under governance review prior to peer-review submission. Independent external replication is now the next priority.


---

## 8. Regulatory and Assurance Framework References

This methodology is positioned under electronic records and audit documentation frameworks. Detailed clause-level mapping is provided in C12 AuditLog.AI Global Compliance Matrix.

Referenced frameworks include:
- FDA 21 CFR Part 11 - electronic records and electronic signatures
- EMA Annex 11 + GCP Guideline Integration (2023) - computerized systems and data integrity
- TGA / PIC/S PE 009-17 - harmonized GMP computerized systems
- PCAOB AS 1105 / AS 1215 (including AS 1105.10A - external electronic information reliability evaluation, effective for fiscal years beginning on or after December 15, 2025)
- ISA 230 / ISA 500 / ISA 240 (Revised 2025) - international audit documentation and evidence standards

These references reflect methodological alignment and evidence mapping, not regulatory acceptance or certification. No regulatory authority has reviewed, classified, or endorsed this methodology.

This methodology is not clinical decision support, is not a medical device, and does not provide patient-level treatment recommendations.

Conflict of interest disclosure
  
Cardiovascular Diagnostic Audit & AI Pty Ltd (ABN 19 638 019 431) is the developer of the software under independent evaluation. This relationship is disclosed to all participants prior to registration. The trial evaluates methodology verifiability, not commercial suitability.  
Participation does not constitute vendor onboarding, procurement evaluation, or commercial engagement, and creates no licensing, purchase, or endorsement obligation.


*This protocol describes a methodology evaluation. It does not constitute regulatory advice, legal opinion, or a determination by any regulatory authority. Final classification and regulatory acceptance rest with the applicable authorities (FDA, EMA, TGA, PCAOB, or other competent body).*
