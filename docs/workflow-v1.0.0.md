# The tiered workflow

How we build with Claude Code in every project, from a request to production.

| Item | Value |
|---|---|
| Version | 1.0.0 |
| Owner | Aman Nabi |
| Status | In use from the first pilot; the change procedure it supports is a draft until approved |

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-10-22 | First version. |

## Why

Two problems, and what fixes them:

- **Small fixes took hours.** Every change went through the same heavy process. DORA's research names "the same process for every change regardless of risk" as a pitfall. Anthropic's own advice is that a quick fix should not go through planning and sub-agent hand-offs.
- **Changes passed locally and failed on stage on the first try.** Tests written in the same session as the code pass by construction. Local checks never see real domains, cookies, data or a production build. The fix is tests written from the requirements, plus automatic checks against stage after every deploy.

## 1. Tiers

Claude names the tier and the reason before any work. The person who asked can raise it; it is never lowered.

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

1. **Request.** The person says what's needed.
2. **Tier.** `/tiered-workflow:tier`.
3. **Grill.** Claude asks questions in rounds, each with its recommended answer: 0 to 3 for small, about 5 to 8 for normal, as many as needed for high. Claude looks facts up itself; only decisions go to the person.
4. **Plan.** A short plan from the answers, including the test cases. For small, the one sentence is the plan. For high, add a design note.
5. **Plan check** (normal, high). The contrarian agent looks for flaws and unclear steps, graded, one round. Findings that change the product go to the person; missing test cases go into the plan.
6. **Tests first.** A separate agent writes acceptance tests from the plan only, never from the code, and they are shown failing. Small changes get one regression test, written in the same session before the fix.
7. **Build.** Small and most normal work: one session. Big or multi-repo work: one edit agent per repo; the main session runs every check. Build in vertical slices: one failing test, the least code, repeat.
8. **Gate.** When Claude ends a turn, the Stop hook runs lint, typecheck, the related tests and the comment check.
   - **Scope:** only the files that changed since the person's prompt, never the person's own work in progress.
   - **Trust:** a repo's commands run only after the person trusts its gate config (`/tiered-workflow:gate-trust`).
   - **Failures:** a failure keeps Claude working, up to 3 times per prompt. If Claude stops with checks still failing, the person is told.
   - **CI:** runs the full suite on push.
9. **Prove the tests are real.** Break the code on purpose; each test must go red. High tier adds mutation testing where set up.
10. **Review.** First Claude re-reads every comment it added (section 5). Then two fresh, read-only reviewers read the diff, one for standards (including the comments) and one for the spec (including a hollow-test check). Graded, one round: fix critical and should-fix.
11. **First look.** A headed local walkthrough saves screenshots of every changed screen into the PR. The person rules on wording and placement there, before stage.
12. **Docs.** Living docs are updated in the same change, following the organisation's document rule. The changelog comes from commits.
13. **Stage.** The deploy script runs the smoke suite against stage. If it fails, the deploy rolls back and the person is told what broke. If it passes, the person walks it.
14. **Production.** The person's go or no-go, then read-only smoke checks on production. The release record is generated.
15. **Learn.** A bug that escaped to stage becomes a smoke check. A mistake corrected twice becomes a hook or a rule.

## 3. What each tier keeps

| Step | Small | Normal | High |
|---|---|---|---|
| Grill | 0 to 3 questions | 5 to 8 | As needed |
| Plan | One sentence | Short plan | Plan and design note |
| Plan check | No | Yes | Yes |
| Tests first | 1 regression test, this session | Acceptance tests, separate agent | Acceptance and contract tests, separate agent |
| Build | This session | This session or one agent | Agent per repo when big |
| Gate and CI | Yes | Yes | Yes |
| Tests proven real | Red before green | Break check | Break check and mutation testing |
| Review | Yes | Yes | Yes |
| Screenshots | If a screen changed | Yes | Yes |
| Stage smoke and walk | Yes | Yes | Yes |
| DPIA check | No | No | When personal-data handling changes |

## 4. Automated tests

| Layer | When it runs | Written by | What it catches |
|---|---|---|---|
| Lint, typecheck | Stop hook, CI | Set up once | Type errors, broken conventions |
| Secret scan | CI | Set up once | Leaked keys |
| Unit and integration | Related tests in the hook, full suite in CI | The test-writer agent, before the code | Logic bugs, regressions |
| Contract tests between services | CI on both sides | Set up once per feed | Producer data the reader doesn't expect |
| Local browser tests (headed) | Before the PR | The test-writer agent, per changed journey | Broken screens; reload, back button, double submit, prefetch |
| Stage smoke suite | After every deploy, then on a schedule | Set up once per project, grows | Anything only stage shows: domains, cookies, env, data, a dead service |

Rules that keep the tests honest:
- **Expected values are literals** from the requirement, never recomputed the way the code does it.
- **Mock only system boundaries:** external APIs, email, payments, time, randomness.
- **A test that never went red is deleted or rewritten.**
- **A skipped test counts as failed.**
- **Every page with a one-time action gets a reload test.**
- **Every GET is checked to change nothing**, because frameworks prefetch links.
- **Time-based rules run on a controllable clock**, on the server as well as in the browser.
- **Feed fixtures come from the producer's real builder**, or are recorded from real responses, never written by hand.
- **Every test run has a cap and a timeout.**

The stage smoke suite covers, at minimum:
- the sign-in round trip for each product;
- a reload of a one-time link;
- one key screen per product;
- each feed's shape against real stage data;
- every service's health.

Its test account secret lives in the server environment or pipeline secrets, never in the repo. It runs headless because it runs from the deploy script; that is the only headless browser run in the workflow.

## 5. Code comments

Claude Code users report the same complaints about AI-written comments:
- comments that restate the line below;
- "what the code used to do" history and dated change notes;
- notes addressed to the user;
- 10 to 20 line blocks on short functions;
- the plan pasted into the code;
- TODOs left behind.

Rules in CLAUDE.md alone fade over a long session. What holds is a check with a failing state. So the workflow has three layers:

1. **Rules**, worded as what to do (`templates/claude-md-rules.md`):
   - comment only a why the code cannot show: a business rule, an outside constraint, a ticket or decision reference, a non-obvious workaround;
   - describe the code as it is now; history goes in the commit message;
   - write for a reader who never saw the session or the plan;
   - one or two lines per comment; link to the design doc instead of copying it;
   - a TODO carries a ticket ID;
   - one good and one bad example sit next to the rules.
2. **The comment check** in the Stop gate (`scripts/comment-check.sh`). It reads only the comment lines added in the change and flags:
   - history and session talk;
   - dated change notes;
   - TODOs without a ticket;
   - divider comments, which a project can allow;
   - blocks longer than 8 lines, a limit the project can change.

   It leaves out phrases that are also ordinary domain words, such as "no longer".
3. **The comment pass and the review.** Before review Claude re-reads its comments, and the Standards reviewer checks each added comment.

Context an agent needs lives in docs, decision records and CLAUDE.md, not in code comments. That answers the point that comments help the model on a big codebase.

## 6. Shared and per project

- **Shared, in this plugin:** the workflow, the skills, the agents, the Stop gate and the change procedure. One copy, versioned, installed in every project and every Claude Code login.
- **Per project:**
  - `.claude/workflow-profile.md`: protected areas, commands, stage, docs;
  - `.claude/workflow-gate.conf`: the gate commands;
  - a short CLAUDE.md;
  - the project's smoke suite.
- **CLAUDE.md stays short.** A rule the model keeps breaking becomes a hook, because a hook runs every time and CLAUDE.md is advice.

## 7. Records

Each change leaves:
- the tier line;
- the plan;
- the test output;
- the CI run;
- the review report;
- the screenshots;
- the deploy and smoke log;
- the approval.

The change procedure says which records are kept, for how long, and which need a person.

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
- Matt Pocock, github.com/mattpocock/skills; aaddrick, github.com/aaddrick/contrarian.
