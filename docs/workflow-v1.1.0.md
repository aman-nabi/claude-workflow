# The tiered workflow

How we build with Claude Code in every project, from a request to production.

| Item | Value |
|---|---|
| Version | 1.1.0 |
| Owner | Aman Nabi |
| Status | In use; the change procedure it supports is a draft until approved |

| Version | Date | Change |
|---|---|---|
| 1.1.0 | 2026-10-22 | The flow runs in four stages with the build in parallel: a tier per fix, one grill round, a plan written once and locked, the user's list check, agent worktrees, tests red on old code and green on new, locked tests, one review per repo, a walkthrough table with evidence, stage times. No code comments by default. Plugin 1.2.0. |
| 1.0.0 | 2026-10-22 | First version. |

## Why

Three problems, and what fixes them:

- **Small fixes took hours.** Every change went through the same heavy process. DORA's research names "the same process for every change regardless of risk" as a pitfall. Anthropic's own advice is that a quick fix should not go through planning and sub-agent hand-offs.
- **Changes passed locally and failed on stage on the first try.** Tests written in the same session as the code pass by construction. Local checks never see real domains, cookies, data or a production build. The fix is tests written from the requirements, plus automatic checks against stage after every deploy.
- **The careful steps were repeated, not done once.** On 22 Oct 2026 a batch of six fixes took 6.5 hours, and the coding was about 30 minutes. The rest was:
  - questions asked one at a time, with a new plan version per answer;
  - briefs that sent agents searching (the docs agent ran 80 minutes; the agent briefed with exact files and helpers took 6.5);
  - six reviewers;
  - full suites after every round;
  - one long session that compacted and lost detail.

  The sources in the last section agree on the fix: plan once and lock it, brief tightly, build in parallel, check once at the end, and turn repeated mistakes into checks.

## 1. Tiers

Claude names the tier and the reason for each fix before any work. The person who asked can raise it; it is never lowered.

| Tier | Entry |
|---|---|
| Small | The whole change fits in one sentence. It touches no protected area, stays in one repo, is easy to revert, and adds no new screen or flow. |
| Normal | Everything that is not small or high. |
| High | It touches a protected area, spans more than one repo, or changes stored data. |

The protected areas are listed per project in `.claude/workflow-profile.md`. By default:
- sign-in and sessions;
- money;
- personal data;
- stored data (schema, migrations);
- infrastructure and CI;
- logging and audit.

Size never lowers a tier: a one-line change to sign-in is high. A production outage takes the emergency path in the change procedure.

## 2. The flow

Normal and high (`/tiered-workflow:feature`) run in four stages. Each stage's start and end time goes in the plan, so the next run shows what is still slow. A long session hands over to a fresh one at a stage boundary; the plan carries everything across.

**Stage A: agree (the person and Claude).**
1. **Tier** each fix.
2. **Grill, one round.** Claude looks facts up itself, then puts every question of the batch in one message, each with its recommended answer. A second round only for a question an answer opened.
3. **Plan, written once,** from `templates/plan-template.md`. Per fix:
   - the tier;
   - what the user should see, in plain sentences;
   - what should happen behind the scenes;
   - the names both sides build to;
   - the exact files touched.
4. **The person reads the lists.** Gaps are cheapest to catch here.
5. **Plan check,** high only and one round, skipped when every decision is settled. The contrarian agent looks for flaws, unclear steps and missing test cases.
6. **The plan is locked.** Every brief is copied from it.

**Stage B: build in parallel.** Each agent gets its own worktree (`scripts/agent-worktree.sh`), so agents cannot see each other's work and the Stop gate never checks a half-finished edit. At the same time:
- the **test writer** (high) works from the plan's lists and names only;
- **one builder per repo**, or the main session when the work fits it;
- the **docs writer**, from the plan's docs list;
- the **walkthrough writer**, from the "user should see" list.

For normal tier, the builder may write its regression test with the fix; the review is the independent check.

**Stage C: check once.**
1. **Red on the old code:** the test worktree is collected first and its tests must fail. They are then locked; the test-lock hook refuses edits to them until the person lifts it.
2. **Green on the new code:** the builders' worktrees are collected and the tests must pass. A failing locked test means the code is fixed to the plan, or the person is asked.
3. **Prove the tests are real:** break the code on purpose; each test must go red. High tier adds mutation testing where set up.
4. **One review:** one fresh, read-only reviewer per repo covers standards (including every comment) and the spec (including a hollow-test check). Graded, one round: fix critical and should-fix; the rest goes on a follow-up list.
5. **Full suite once,** in the background or by CI on push, against the baseline.
6. **Walkthrough:** headed, in a real browser, from the "user should see" list. The result is a table: one row per line, pass or fail, with its screenshot or output.

**Stage D: close out.** The hand-off says what the stage smoke suite checks and what to walk by hand. Then five minutes on what cost time: a mistake seen twice becomes a hook or a check; stale notes and version copies are removed.

**Then:**
- **Stage:** the deploy script runs the smoke suite against stage. If it fails, the deploy rolls back and the person is told what broke. If it passes, the person walks it.
- **Production:** the person's go or no-go, then read-only smoke checks on production. The release record is generated.

Small (`/tiered-workflow:fix`): tier, up to 3 questions, the one sentence as the plan, one regression test written before the fix in the same session, the fix, the gate, one review, a screenshot if a screen changed, docs.

**The gate runs through every stage.** When Claude ends a turn, the Stop hook runs lint, typecheck, the related tests and the comment check.
- **Scope:** only the files that changed since the person's prompt, never the person's own work in progress.
- **Trust:** a repo's commands run only after the person trusts its gate config (`/tiered-workflow:gate-trust`).
- **Failures:** a failure keeps Claude working, up to 3 times per prompt. If Claude stops with checks still failing, the person is told.

**The time this aims for:**
- a high batch like the one above in about an hour;
- a normal fix in about 25 minutes;
- a small fix in 10 to 15.

## 3. What each tier keeps

| Step | Small | Normal | High |
|---|---|---|---|
| Grill | 0 to 3 questions | One round | One round, a second only if an answer opens a question |
| Plan | One sentence | Plan from the template | Plan and design note |
| The person reads the lists | No | Yes | Yes |
| Plan check | No | No | Yes, unless every decision is settled |
| Tests first | 1 regression test, this session | Regression tests with the fix, by the builder | Acceptance tests by a separate agent, red on old code, locked |
| Build | This session | This session or one agent per repo | Agents in parallel, own worktrees |
| Gate and CI | Yes | Yes | Yes |
| Tests proven real | Red before green | Break check | Break check and mutation testing |
| Review | One reviewer | One reviewer per repo | One reviewer per repo |
| Walkthrough with evidence | Screenshot if a screen changed | Yes | Yes |
| Stage smoke and walk | Yes | Yes | Yes |
| DPIA check | No | No | When personal-data handling changes |

## 4. Automated tests

| Layer | When it runs | Written by | What it catches |
|---|---|---|---|
| Lint, typecheck | Stop hook, CI | Set up once | Type errors, broken conventions |
| Secret scan | CI | Set up once | Leaked keys |
| Unit and integration | Related tests in the hook, full suite once per change and in CI | The test writer, from the plan's lists, before the code is collected | Logic bugs, regressions |
| Contract tests between services | CI on both sides | Set up once per feed | Producer data the reader doesn't expect |
| Local browser tests (headed) | Stage C | The walkthrough writer, from the "user should see" list | Broken screens; reload, back button, double submit, prefetch |
| Stage smoke suite | After every deploy, then on a schedule | Set up once per project, grows | Anything only stage shows: domains, cookies, env, data, a dead service |

Rules that keep the tests honest:
- **The test writer never sees the code being written.** It works in its own worktree from the plan's lists.
- **Red on the old code, green on the new.**
- **Locked once red.** The test-lock hook refuses edits; only the person lifts the lock, for one turn. Edits through the shell are outside the hook, so the rule still forbids them.
- **Expected values are literals** from the requirement, never recomputed the way the code does it.
- **Mock only system boundaries:** external APIs, email, payments, time, randomness.
- **A test that never went red is deleted or rewritten.**
- **A skipped test counts as failed.**
- **Every page with a one-time action gets a reload test.**
- **Every GET is checked to change nothing**, because frameworks prefetch links.
- **Time-based rules run on a controllable clock**, on the server as well as in the browser.
- **Feed fixtures come from the producer's real builder**, or are recorded from real responses, never written by hand.
- **Every test run has a cap and a timeout.**
- **A walkthrough line passes only with its evidence** attached: a screenshot or real output.

The stage smoke suite covers, at minimum:
- the sign-in round trip for each product;
- a reload of a one-time link;
- one key screen per product;
- each feed's shape against real stage data;
- every service's health.

Its test account secret lives in the server environment or pipeline secrets, never in the repo. It runs headless because it runs from the deploy script; that is the only headless browser run in the workflow.

## 5. Code comments

**No comments by default.** A comment is kept only for a why the code cannot show (a business rule, an outside constraint, a ticket or decision reference, a non-obvious workaround), in one or two lines, describing the code as it is now. For example: `// Memberfied pairs by invoice first, so the same order is used here (F2 D2.9).`

Claude Code users report the same complaints about AI-written comments:
- comments that restate the line below;
- "what the code used to do" history and dated change notes;
- notes addressed to the user;
- 10 to 20 line blocks on short functions;
- the plan pasted into the code;
- TODOs left behind.

Rules in CLAUDE.md alone fade over a long session. What holds is a check with a failing state. So the workflow has three layers:

1. **Rules**, in `templates/claude-md-rules.md` and in every agent brief.
2. **The comment check** in the Stop gate (`scripts/comment-check.sh`). It reads only the comment lines added in the change and flags:
   - history and session talk;
   - dated change notes;
   - TODOs without a ticket;
   - divider comments, which a project can allow;
   - a block longer than 2 lines;
   - a file that gains more than 6 comment lines in one turn.

   The project can change both limits. The check leaves out phrases that are also ordinary domain words, such as "no longer".
3. **The review.** The reviewer checks each added comment and asks whether it would be missed if deleted.

Existing comments are left alone unless that code is changed anyway. Context an agent needs lives in docs, decision records and CLAUDE.md, not in code comments.

## 6. Shared and per project

- **Shared, in this plugin:**
  - the workflow, the skills, the agents and the change procedure;
  - the Stop gate, the test lock and the agent-worktree script;
  - the plan template.

  One copy, versioned, installed in every project and every Claude Code login.
- **Per project:**
  - `.claude/workflow-profile.md`: protected areas, commands, walkthrough helpers, model and effort per role, stage, docs;
  - `.claude/workflow-gate.conf`: the gate commands;
  - a short CLAUDE.md;
  - the project's smoke suite.
- **CLAUDE.md stays short.** A rule the model keeps breaking becomes a hook, because a hook runs every time and CLAUDE.md is advice.

## 7. Records

Each change leaves:
- the tier line per fix;
- the plan, with its stage times and follow-up list;
- the test output, red on old code and green on new, and the locked list;
- the CI run;
- the review report;
- the walkthrough table and its screenshots;
- the deploy and smoke log;
- the approval.

The change procedure says which records are kept, for how long, and which need a person.

**Standards fit:**
- independent review and change records support SOC 2 CC8.1;
- test-first with recorded evidence, and design steps scaled to risk, support ISO 9001 8.3.4 and 8.5.1;
- removing stale notes and version copies supports ISO 9001 7.5.3.

The flow changes in 1.1.0 remove repeats only. Every review, check and record stays.

## Sources

- Anthropic, Claude Code best practices and hooks reference, code.claude.com/docs.
- Anthropic, how the Claude Code team tiers review by risk (blog, 15 Oct 2026).
- DORA, change approval and the 2024 and 2025 reports, dora.dev.
- Reddit threads read in full on 22 Oct 2026:
  - "My Claude Code setup: it runs like a small engineering team with guardrails";
  - "You're shipping bugs if you're not using adversarial reviews with claude code";
  - "Do you feel that claude code unit tests are useless?";
  - "A Stop hook that makes Claude Code run the tests before it says done";
  - "Matt Pocock's Claude Code habits";
  - "8 Claude workflow tips from daily use";
  - "3 small Claude Code habits from other people's setups";
  - "I went from exhausting Claude Code's weekly limits in 2 days".
- Reddit threads on AI comment noise, read in full on 22 Oct 2026: r/ClaudeCode 1vl44qq, 1vplwi0, 1wfjrgi. The votes were low, but the threads agree with each other.
- Added for 1.1.0, read in full on 22 Oct 2026 through the Arctic Shift archive of r/ClaudeCode:
  - "TDD workflows with Claude Code - what's actually working after months of iteration" (1qd64xx);
  - "Those doing TDD... Are you really?" (1q9vkvh);
  - "My workflow as product and process owner" (1ww2ss4);
  - "A humble guide to the multi-agent workflows I use every day" (1vphazv);
  - "My Claude Code workflow after months of daily use" (1vmey7d);
  - "How to do testing validation with agents?" (1wrv8tb);
  - "Anybody here uses Claude code for QA automation testing" (1xa704b);
  - "Questions on new tests using Claude Code and Playwright" (r/Playwright 1wve448).
- Repos read on 22 Oct 2026: llopresto87/Cypress (tiers, a contained lane for small changes, test waves ahead of the build); kunchenguid/firstmate and kunchenguid/no-mistakes (one check pass on the final commit, the full suite in CI, only intent decisions to the person).
- Matt Pocock, github.com/mattpocock/skills; aaddrick, github.com/aaddrick/contrarian.
