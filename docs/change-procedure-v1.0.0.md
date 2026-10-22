# Software change procedure

| Item | Value |
|---|---|
| Version | 1.0.0 |
| Status | DRAFT, waiting for approval. Not in force until approved. |
| Owner | Aman Nabi |
| Approver | Aman Nabi |
| Applies to | Every change to the software of any project that adopts tiered-workflow |
| Review | Every 12 months, and after any incident caused by a change |

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-10-22 | First draft. |

## 1. Purpose

Every change to our software is classified by risk, tested, reviewed, approved and recorded before it reaches production. Small, low-risk changes take a short path; risky changes take the full path. The records come mostly from the tools (pull requests, CI runs, deploy logs), not from hand-written documents.

## 2. Scope

**In scope:**
- application code;
- tests;
- database schema and migrations;
- infrastructure and deploy scripts;
- CI configuration;
- the Claude Code configuration that builds our code: CLAUDE.md files, skills, hooks, agent definitions and this plugin.

**Out of scope:** content changes made by users inside a product.

## 3. Roles

- **Requester:** asks for the change. Usually the product owner.
- **Author:** makes the change. This can be a person or Claude Code working for a person. The person who directs Claude Code is accountable for its work.
- **Approver:** decides that a change may go to production. An author never approves their own change. An AI agent's approval never counts as a human approval.
- **Independent reviewer:** a named second person who samples approved changes (section 7).

## 4. Change types

Classify every change with the `tier` skill. When unsure, pick the higher type. Size never lowers a type.

| Type | Entry criteria |
|---|---|
| Small (standard: the change type is pre-approved, so it needs no plan approval or plan check; production approval still applies) | The whole change fits in one sentence. It touches no protected area. It stays in one repo, is easy to revert, and adds no new screen or flow. |
| Normal | Not small and not high. |
| High | Touches a protected area: sign-in and sessions, money, personal data, stored data (schema, migrations), infrastructure and CI, logging and audit. Or it spans more than one repo. |
| Emergency | Production is down or data is at risk, and the normal path would take too long. |

Each project lists its protected areas, with real paths, in `.claude/workflow-profile.md`.

## 5. Required steps and records

| Step | Small | Normal | High | Record |
|---|---|---|---|---|
| Tier stated with the reason | Yes | Yes | Yes | PR description or `Tier:` commit line |
| Requirements clarified (grill) | 0 to 3 questions | Yes | Yes | Plan file or PR description |
| Plan with test cases | One sentence | Yes | Yes, plus design note | Plan file |
| Plan check (contrarian), one round | No | Yes | Yes | Line in the plan file |
| Tests written before the code, shown failing | 1 regression test | Yes | Yes | Test output in the PR or session record |
| Automatic gate: lint, typecheck, related tests | Yes | Yes | Yes | Hook result; CI run |
| Full test suite in CI | Yes | Yes | Yes | CI run linked to the commit |
| Tests proven able to fail | Red before green | Break check | Break check, mutation testing where set up | Session record |
| Independent code review, one graded round | Yes | Yes | Yes | Review report in the PR |
| Screenshots of changed screens | If a screen changed | Yes | Yes | PR |
| Living docs updated | If behaviour changed | Yes | Yes | Same change |
| Stage smoke suite passes after deploy | Yes | Yes | Yes | Deploy log |
| Owner walk on stage | Yes | Yes | Yes | PR comment or ticket |
| DPIA check | No | No | When personal-data handling changes | DPIA record |
| Production approval | Owner | Owner | Owner, plus a second person where one is available | PR approval or release record |

## 6. Emergency changes

Fix first, with the smallest change that restores service. Then:
- record the change and the reason within one business day;
- run the full steps for its type afterwards;
- get the owner's approval after the fact.

Every emergency change is reviewed at the next independent sampling.

## 7. Separation of duties

A solo owner approving changes written by Claude Code counts as one person. Until a second person approves each change, these compensating controls apply:

- Branch protection: the main branch takes changes only through a pull request with CI passing.
- CI runs the full test suite. A skipped test counts as failed.
- Every change gets an independent AI review whose report is kept.
- A named independent reviewer samples approved small and normal changes every month, and every high and emergency change. They record the result.

## 8. Testing

- Tests come from the requirements, not from the code.
- Expected values are known literals.
- The project's own code is not mocked.
- Every bug that escapes to stage becomes a smoke check.
- Test data on stage is seeded or anonymised. Real personal data is never copied to stage unmasked.

## 9. Environments

Development, stage and production are separate. Production credentials are not used in development or stage. The stage smoke suite runs against stage only; on production it runs read-only checks.

## 10. Records and retention

The records in section 5 are kept for `[retention period, to be set]`, and at least for the full audit period:
- pull requests;
- CI runs;
- review reports;
- plan files;
- deploy logs;
- approvals.

Session transcripts are supporting evidence only.

## 11. Standards mapping

| Requirement | Where this procedure meets it |
|---|---|
| ISO/IEC 27001:2022 A.8.32 Change management | Sections 4 to 7 |
| ISO/IEC 27001:2022 A.8.25 Secure development life cycle | Sections 4, 5 |
| ISO/IEC 27001:2022 A.8.29 Security testing in development and acceptance | Sections 5, 8 |
| ISO/IEC 27001:2022 A.8.31 Separation of development, test and production | Section 9 |
| ISO/IEC 27001:2022 A.8.33 Test information | Section 8 |
| SOC 2 CC8.1 Change management | Sections 4 to 7, 10 |
| ISO 9001:2015 7.5 Documented information | Section 10; docs follow the organisation's document rule |
| ISO 9001:2015 8.3.6 Design and development changes, 8.5.6 Control of changes | Sections 4, 5, 10 |
| PDPA and DPTM: data protection by design, DPIA | Section 5 (DPIA check), section 8 |

The clause mapping comes from consultancy guidance, not from the standards' primary text. Confirm it with the certification body or audit firm before relying on it.

## 12. Records generated automatically, and decisions that need a person

**Generated automatically, no approval needed:**
- the tier label;
- CI and test reports;
- review reports;
- the changelog from commits;
- deploy logs;
- smoke suite results;
- a traceability matrix built from ticket IDs in commits and test names.

**Need a person:**
- approval of this procedure and of each project's protected areas;
- production approval;
- risk acceptance;
- the DPIA decision;
- emergency sign-off after the fact;
- the monthly independent sampling.

## 13. Open items before approval

1. Name the independent reviewer.
2. Set the retention period.
3. Ask the organisation admin whether git history may replace a new versioned file per edit for documents kept in git.
4. Confirm the clause mapping with the auditor.
