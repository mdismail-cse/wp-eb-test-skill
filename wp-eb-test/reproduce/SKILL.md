---
name: wp-eb-reproduce
description: >
  Generate a visual reproduction guide for failed QA test cases from an Essential Blocks QA report.
  Takes a qa-report.md (or any test report) as input, extracts all FAIL items, then produces a
  step-by-step reproduction guide with screenshots for each failure. Use this skill when the user
  mentions "reproduce", "repro steps", "reproduction guide", "how to reproduce", "reproduce failures",
  "reproduce report", or wants to create a bug reproduction document from a QA report.
---

# Essential Blocks -- Failure Reproduction Guide Generator

You take a QA report (from the `wp-eb-test` skill or any similar test report) and generate a
detailed visual reproduction guide for every failed test case. The goal is to give developers
a clear, screenshot-annotated document showing exactly how to trigger each failure.

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `report` | Yes | Path to the QA report file (e.g., `qa-report.md`) |
| `site_url` | Yes | The WordPress site URL to reproduce on |
| `output` | No | Output file path (defaults to `reproduce-report.md` in current directory) |

Example invocations:
- `/wp-eb-reproduce report=qa-report.md site_url=https://dev.local`
- `/wp-eb-reproduce report=./reports/qa-2024.md site_url=https://staging.site.com output=./repro.md`

## Workflow

### Step 1: Parse the QA report

Read the report file and extract all test cases with a **FAIL** result:

```bash
cat <report_path>
```

For each failed test case, extract:
- Test case number and description
- Component (Free / Pro / Controls)
- Method used (Code / Visual)
- Notes from the report

If no FAIL items are found, tell the user: "No failed test cases found in the report. Nothing to reproduce."

### Step 2: Read credentials

If reproduction requires wp-admin access, read credentials:

```bash
cat c.txt
```

### Step 3: Start the browser

1. Call `preview_start` to launch the Playwright browser
2. Store the `serverId`
3. Navigate to `site_url`, take `preview_screenshot` to confirm site is accessible
4. Log in to wp-admin if needed (using credentials from `c.txt` or ask user)

### Step 4: Reproduce each failure

For EACH failed test case, follow this process:

**4a: Plan the reproduction steps**

Based on the failure description from the report, figure out the exact steps to trigger the failure:
- Which page to visit (frontend or editor)
- Which block or setting to interact with
- What specific action triggers the failure
- What the expected vs actual result is

If unclear, ask the user: "The report says [test case] failed but I'm not sure how to reproduce it.
Can you give me more context?"

**4b: Execute and capture**

For each step in the reproduction:

1. Navigate to the relevant page
2. Take `preview_screenshot` BEFORE the action (the "starting state")
3. Perform the action (click, change setting, navigate, resize viewport, etc.)
4. Take `preview_screenshot` AFTER the action (showing the failure)
5. Use `preview_console_logs` with `level: "error"` to capture any JS errors
6. Use `preview_inspect` on the failing element to get computed styles, dimensions, text
7. Use `preview_network` with `filter: "failed"` if the failure involves API/network errors

Label each screenshot clearly:
- `[TC-#] Step N - Description (before/after)`

**4c: Document the failure**

For each test case, write:
- Numbered reproduction steps (what to click, where to navigate)
- What you expected to happen
- What actually happened (the bug)
- Screenshots showing the before/after states
- Console errors if any
- CSS/style details if it's a visual bug
- Browser/viewport info if responsive issue

### Step 5: Stop the browser

1. Call `preview_stop` with the `serverId`

### Step 6: Generate the reproduction report

Save to the output file (default `reproduce-report.md`):

```markdown
# Reproduction Guide: Essential Blocks Failures

**Date:** [today's date]
**Source report:** [report path]
**Site:** [site_url]
**Total failures:** [count]

---

## Failure #1: [Test case description]

**Component:** [Free/Pro/Controls]
**Original report note:** [note from QA report]

### Steps to reproduce

1. Go to [URL]
2. [Action step]
3. [Action step]
4. ...

### Expected result

[What should happen]

### Actual result

[What actually happens -- the bug]

### Screenshots

#### Before
[Screenshot reference or description of starting state]

#### After
[Screenshot reference or description showing the failure]

### Technical details

- **Console errors:** [errors if any, or "None"]
- **Failed network requests:** [requests if any, or "None"]
- **Element details:** [computed styles, dimensions if relevant]
- **Viewport:** [width x height if responsive issue]

### Severity

[Critical / Major / Minor / Cosmetic]

- **Critical**: Site crash, data loss, security issue
- **Major**: Feature broken, blocks unusable
- **Minor**: Feature works but with visual glitch or wrong behavior in edge case
- **Cosmetic**: Styling/alignment/spacing issue only

---

## Failure #2: [next failure...]

[repeat for each failure]

---

## Summary

| # | Test Case | Component | Severity | Reproducible |
|---|-----------|-----------|----------|--------------|
| 1 | [description] | Free/Pro/Controls | Critical/Major/Minor/Cosmetic | Yes/No/Intermittent |

## Environment

- **Site URL:** [url]
- **Browser:** Playwright (Chromium)
- **Viewport:** [default viewport used]
- **WordPress version:** [if visible]
- **EB Free version:** [if visible]
- **EB Pro version:** [if visible]
```

### Step 7: Print summary

After saving the report, print a quick summary:

```
Reproduction guide saved to [output_path]

[X] failures reproduced:
- #1 [description] → [severity] ✅ Reproduced
- #2 [description] → [severity] ❌ Could not reproduce
- #3 [description] → [severity] ⚠️ Intermittent
```

## Important Notes

- **Read-only.** This skill does NOT fix bugs. It only reproduces and documents them.
- If a failure can't be reproduced, mark it as "Could not reproduce" with notes on what was tried.
- If a failure is intermittent, note the conditions under which it appeared/didn't appear.
- Ask the user for help if you can't figure out how to reach the failing state.
- Always stop the browser server when done, even if reproduction fails partway through.
- Screenshots are the most important part -- capture before AND after states for every failure.
