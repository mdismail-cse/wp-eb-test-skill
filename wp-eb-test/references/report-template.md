# QA Report: Essential Blocks — [Branch]

**Date:** [today]
**Site:** [url]
**Scope:** [free/pro/controls/all]
**Base:** main/master

## Tested

| Component | Branch | Base | Files Changed |
|-----------|--------|------|---------------|
| Free | [b] | main | [N] |
| Controls | [b] | main | [N] |
| Pro | [b] | main | [N] |

## Verdict

**[PASS / FAIL / PARTIAL]**

[One line. What work. What not work.]

**Coverage: [X] of [Y] tests confirmed by running. [Z] code-only (not executed).**
[If Z > 0, PASS cannot be claimed for those — they are PARTIAL at best.]

## Change Summary

- [file path] → [what change]
- [file path] → [what change]

## Fix Target

[From issue/fix_file. One line. What bug fix try solve.]

## Test Results

| # | Test | Where | How | Result |
|---|------|-------|-----|--------|
| 1 | [short desc] | Free/Pro/Controls | Code/Visual | PASS/FAIL |
| 2 | [short desc] | ... | ... | ... |

A PASS for anything a user sees or interacts with MUST have How=Visual. How=Code is allowed only
for pure non-runtime facts (e.g. sanitization present); never mark a runtime test PASS from code alone.

## Fail Detail

**#[N] [test name]**
- Expect: [short]
- Got: [short]
- Why bad: [short]

(Repeat per fail. Skip section if no fails.)

## User Check

| Perspective | Verdict | Note |
|-------------|---------|------|
| Content creator | PASS/FAIL | [one phrase] |
| Visitor | PASS/FAIL | [one phrase] |
| Mobile | PASS/FAIL | [one phrase] |
| A11y | PASS/FAIL | [one phrase] |

## Concerns

- [Security/regression/edge — one line each]
- Or: None.

## Next Steps

[If FAIL/PARTIAL: one bullet per action needed. Else: "Ship it."]
