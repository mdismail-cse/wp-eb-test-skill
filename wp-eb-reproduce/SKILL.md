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

Takes a QA report and generates a detailed visual reproduction guide for every failed test case.
Output is a screenshot-annotated document showing exactly how to trigger each failure.

## Defaults

On startup, check for `defaults.json` in the plugin directory:

```bash
cat defaults.json 2>/dev/null
```

Values from `defaults.json` are used unless the user overrides them:
- `site_url`, `wp_user`, `wp_pass`, `screenshots`

## Arguments

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `report` | Yes | Path to the QA report file | -- |
| `site_url` | Yes* | WordPress site URL | from `defaults.json` |
| `output` | No | Output file path | `reproduce-report.md` |
| `screenshots` | No | `yes`/`no` -- skip screenshots | `yes` or defaults.json |

*Required unless set in `defaults.json`.

Examples:
- `/wp-eb-reproduce report=qa-report.md` (uses defaults for site_url)
- `/wp-eb-reproduce report=qa-report.md site_url=https://dev.local`
- `/wp-eb-reproduce report=./reports/qa.md output=./repro.md screenshots=no`

## Credentials

Same priority as main skill:
1. **Inline in command**: `user:X pass:Y`
2. **`defaults.json`**: `wp_user` + `wp_pass`
3. **Ask the user**: "What are the WP admin credentials?"

Never ask for credentials already provided.

## Preflight Checks

Before starting, verify:
- Browser MCP: try `preview_list`. If unavailable, ask: "No browser MCP available. Skip visual reproduction or set it up?"
- Report file exists and is readable

## Workflow

### Step 1: Parse the QA report

```bash
cat <report_path>
```

Extract all test cases with **FAIL** result:
- Test case number, description
- Component (Free / Pro / Controls)
- Method (Code / Visual)
- Notes from the report

If no FAIL items found: "No failed test cases found in the report. Nothing to reproduce."

### Step 2: Start browser

1. `preview_start`, store `serverId`
2. Navigate to `site_url`, confirm loaded
3. If unreachable, ask: "Is the dev server running?"
4. Log in to wp-admin using credentials from Credentials section

### Step 3: Reproduce each failure

For each failed test case:

**3a: Plan steps** -- Based on failure description, determine:
- Page to visit (frontend or editor)
- Block/setting to interact with
- Action that triggers the failure

If unclear, ask: "The report says [test case] failed but I'm not sure how to reproduce it. Can you give me more context?"

**3b: Execute and capture** -- For each step:
1. Navigate with `preview_eval`
2. If `screenshots=yes`: `preview_screenshot` BEFORE action
3. Perform action (click, change setting, resize, etc.)
4. If `screenshots=yes`: `preview_screenshot` AFTER action
5. `preview_console_logs` with `level: "error"` for JS errors
6. `preview_inspect` for CSS/element details if visual bug
7. `preview_network` with `filter: "failed"` for network errors

Label screenshots: `[TC-#] Step N - Description (before/after)`

**3c: Document** -- For each test case:
- Numbered reproduction steps
- Expected vs actual result
- Screenshots (before/after)
- Console errors, failed requests
- CSS/style details for visual bugs
- Viewport info for responsive bugs

### Step 4: Stop browser

`preview_stop` with `serverId`. Always clean up, even on failure.

### Step 5: Generate report

Read `references/reproduce-template.md` and fill it in. Save to the output path.

### Step 6: Print summary

```
Reproduction guide saved to [output_path]

[X] failures reproduced:
- #1 [description] → [severity] Reproduced
- #2 [description] → [severity] Could not reproduce
- #3 [description] → [severity] Intermittent
```

## Important Notes

- **Read-only.** Does NOT fix bugs. Only reproduces and documents them.
- If a failure can't be reproduced, mark "Could not reproduce" with notes on what was tried.
- For intermittent failures, note conditions when it appeared/didn't.
- Ask the user for help if you can't reach the failing state.
- Always stop the browser server, even if reproduction fails partway through.
- Screenshots capture before AND after states for every failure.
