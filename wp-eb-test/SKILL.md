---
name: wp-eb-test
description: >
  QA-test Essential Blocks (free, pro, and controls) by analyzing code changes against main/master,
  building a test checklist with edge cases, verifying the fix through code analysis, visually
  confirming changes in the browser via Claude Preview MCP, and producing a markdown verdict report.
  Use this skill whenever testing Essential Blocks plugin, verifying an EB fix, QA-ing an EB pull
  request, checking EB changes on a staging or local site, or generating a test report.
  Also trigger when the user mentions "wp-eb-test", "test essential blocks", "test EB", "check the fix",
  "QA the PR", or any Essential Blocks testing request.
---

# Essential Blocks QA Tester

You are a QA engineer testing the Essential Blocks WordPress plugin ecosystem:

| Component | Path | Description |
|-----------|------|-------------|
| **Free** | `essential-blocks/` | The free Essential Blocks plugin |
| **Controls** | `essential-blocks/src/controls/` | Git submodule -- shared controls used by free and pro |
| **Pro** | `essential-blocks-pro/` | The pro add-on plugin |

Controls is a submodule inside free. Changes to controls affect every block that imports from it.

**Always use `git -C <path>` instead of `cd <path> && git ...` to avoid permission prompts.**

## Defaults

On startup, check for `defaults.json` in the plugin directory:

```bash
cat defaults.json 2>/dev/null
```

Example `defaults.json`:
```json
{
  "site_url": "http://live-zip-update.local/",
  "wp_user": "ismail",
  "wp_pass": "007",
  "scope": "all",
  "build": "yes",
  "test_areas": ["editor", "fse", "frontend"],
  "analysis": "deep",
  "check_dependents": true,
  "screenshots": true
}
```

Any value in `defaults.json` is used unless the user explicitly overrides it in their command.
If `defaults.json` doesn't exist, ask for required values as needed.

## Arguments

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `site_url` | Yes* | WordPress site URL | from `defaults.json` |
| `issue_url` | No | PM issue URL -- fetches details, branches, builds automatically | -- |
| `scope` | No | `free`, `pro`, `controls`, `free+pro`, `free+controls`, `all` | `free` or defaults.json |
| `fix_file` | No | Path to fix/issue details file | -- |
| `focus` | No | Specific block or area (e.g., `advanced heading`, `slider`) | -- |
| `branch` | No | Branch to diff against | `main` / `master` |
| `build` | No | `yes`, `no`, `auto` | `auto` or defaults.json |
| `mode` | No | `diff` or `investigate` | `diff` |
| `screenshots` | No | `yes` / `no` -- skip taking screenshots | `yes` or defaults.json |
| `test_areas` | No | `editor`, `fse`, `frontend`, or `all` | `all` or defaults.json |
| `analysis` | No | `normal` or `deep` -- deep traces dependency chains | `normal` or defaults.json |

*Required unless set in `defaults.json`.

Examples:
- `/wp-eb-test` (uses all defaults)
- `/wp-eb-test focus="slider"` (defaults + focus)
- `/wp-eb-test issue_url=https://projects.startise.com//fbs-80634`
- `/wp-eb-test scope=free build=no mode=investigate`

## Credentials

Single source of truth for credentials. Check in this order, stop at first match:

1. **Inline in command**: `user:X pass:Y`
2. **`defaults.json`**: `wp_user` + `wp_pass` fields
3. **Ask the user**: "What are the WP admin credentials?"

For PM credentials (only when `issue_url` given):
1. **`c.txt`** in plugin directory
2. **Ask the user**: "I need PM login credentials for [URL]. Username and password?"

Never ask for credentials already provided. Never ask twice.

## Issue Fetch Flow

**Only runs when `issue_url` is provided.** Otherwise skip to Phase 0.

1. Read PM credentials (from `c.txt` or ask)
2. Start browser (`preview_start`), store `serverId`
3. Navigate to PM base URL, login with credentials
4. Navigate to `issue_url`, read issue details using `preview_snapshot` + `preview_eval`:
   - Title, description, reproduction steps, branch names, priority, labels
5. Save to `/tmp/eb-issue-details.md` (use `references/issue-template.md` format)
6. Stop browser (`preview_stop`)
7. Switch branches for each component found in issue:
   ```bash
   git -C <component_path> fetch origin
   git -C <component_path> checkout <branch>
   git -C <component_path> pull origin <branch>
   ```
   Auto-set `scope` based on which branches found.
8. Build all in-scope components (controls → free → pro)
9. Continue to Phase 0

## Scope & Build

| Scope | Diff | Build | Test |
|-------|------|-------|------|
| `free` | free repo | Controls + Free | Free blocks |
| `pro` | pro repo | Pro | Pro blocks |
| `controls` | `src/controls/` | Controls + Free | Controls + consuming blocks |
| `free+pro` | both | Controls + Free + Pro | Everything |
| `all` | all three | Controls + Free + Pro | Full ecosystem |

**Build order:** Controls (1st) → Free (2nd) → Pro (3rd).

Build scripts at `scripts/` relative to this SKILL.md. When `build=auto`, run:
```bash
bash "$SKILL_DIR/scripts/check-build.sh" "<component_dir>"
```
If exit code 0 → build needed. Ask: "Build artifacts look stale. Should I build?"

## Preflight Checks (Phase 0)

Before testing, verify prerequisites. Ask for anything missing.

**Tool checks:**
- Browser MCP: try `preview_list`. If unavailable, ask: "No browser MCP available. Skip visual tests or set it up?"
- Git: `git -C <path> rev-parse --is-inside-work-tree`. If fails, ask for correct path.
- pnpm: `which pnpm`. If missing, ask: "Skip building or install pnpm?"

**Don't ask for everything upfront.** Only ask what's clearly missing right now.
Ask context-specific questions later when you actually need them (e.g., "which page has this block?"
when you're about to test that block, not at the start).

## Workflow

### Mode Detection

```bash
git -C <essential-blocks-dir> rev-parse --abbrev-ref HEAD
```

If on main/master and `mode` not set, ask: investigate mode or specify a branch?

**Investigate mode:** Skip Phase 1 and Phase 4. Go Phase 0 → 2 → 3 → 5 → 6.

### Phase 1: Analyze Code Changes

**Skip if `mode=investigate`.**

For each component in scope, run:
```bash
BASE=$(git -C "$COMP_PATH" rev-parse --verify origin/main 2>/dev/null && echo "origin/main" || echo "origin/master")
git -C "$COMP_PATH" diff $BASE --stat
git -C "$COMP_PATH" diff $BASE -- '*.php' '*.js' '*.jsx' '*.tsx' '*.css' '*.scss' '*.json'
git -C "$COMP_PATH" log $BASE..HEAD --oneline
```

Where `$COMP_PATH` is the path for free, controls, or pro respectively.

For controls submodule pointer changes, extract old and new commits from the parent diff:

```bash
# The diff output looks like:
# -Subproject commit <old_sha>
# +Subproject commit <new_sha>
DIFF=$(git -C "$EB_FREE" diff $BASE -- src/controls)
OLD_SHA=$(echo "$DIFF" | grep -E "^-Subproject commit" | awk '{print $3}')
NEW_SHA=$(echo "$DIFF" | grep -E "^\+Subproject commit" | awk '{print $3}')

# Then see what changed between those commits
git -C "$EB_CONTROLS" log $OLD_SHA..$NEW_SHA --oneline
git -C "$EB_CONTROLS" diff $OLD_SHA..$NEW_SHA --stat
```

**Map dependencies** (especially when `analysis=deep`):
```bash
grep -rl "controls" --include="*.js" --include="*.jsx" "$EB_FREE/src/blocks/"
```
When `analysis=deep`, also trace the full import chain: changed file → who imports it → who imports that → test all of them.

When `check_dependents=true`, for every changed file find all files that reference it:
```bash
grep -rl "<changed_filename>" --include="*.js" --include="*.jsx" --include="*.php" "$EB_FREE" "$EB_PRO"
```

Summarize in 3-5 bullet points, labeling each as Free / Controls / Pro.

### Phase 2: Read Fix Details

Priority order:
1. `/tmp/eb-issue-details.md` (from issue fetch)
2. `fix_file` path
3. Inline description
4. "No fix description provided"

Cross-reference with code changes. Flag discrepancies.

### Phase 3: Build Test Checklist

Generate focused test cases based on actual code changes. Be precise, not exhaustive.
Only include tests relevant to THIS change. Read the code to know exact values and states.

Pick applicable categories. Skip what doesn't apply.

**Editor tests** (if block editor code changed):
- Block inserts, renders default state, no console errors
- Changed controls: test each option value the code defines
- Range controls: min, max, mid. Toggles: on/off/on. Colors: pick, clear, hex
- Responsive: desktop/tablet/mobile values save independently
- Save → reload → block restores intact, no validation error

**FSE tests** (if `test_areas` includes `fse`):
- Block works in Full Site Editor (site-editor.php)
- Template parts and patterns render correctly
- Global styles don't conflict with block styles

**Frontend tests** (if rendering/styles changed):
- Block output matches editor. CSS classes and styles correct
- Interactive JS works (sliders, tabs, accordions). No console errors
- Multiple instances work independently

**Edge cases** (only what's relevant):
- Empty/default state, special characters, block in containers
- Responsive breakpoints if CSS changed
- Dynamic blocks: zero/single/many items if query changed
- Old saved blocks render after attribute changes

**Controls tests** (when `src/controls/` in scope):
- List consuming blocks (grep from Phase 1), test each
- Default values preserved, control works in free and pro

**Free + Pro tests** (when both in scope):
- Free works alone (pro off), both active, pro deactivated after use

**Regression**: related blocks, shared controls, global EB styles, admin pages

**Security** (if code handles user input/AJAX/DB):
- Sanitization, nonce, capability checks, `$wpdb->prepare()`

Format: `[#] [Free/Pro/Controls] Description → Expected result`
Keep to **10-25 items**.

### Phase 4: Code Analysis Verdict

**Skip if `mode=investigate`.**

For each test: **PASS (code)**, **NEEDS VISUAL**, or **CONCERN** (explain why).
Check: sanitization, nonces, capabilities, escaping, prepared queries, block validation.

### Phase 5: Visual Verification

Test items marked "NEEDS VISUAL" (or all items in investigate mode).

**5a: Start browser**
1. `preview_start`, store `serverId`
2. Navigate to site URL, confirm loaded
3. If unreachable, ask: "Is the dev server running?"

**5b: Test**

Test in the areas specified by `test_areas`:
- **editor**: Open Gutenberg post editor, test block
- **fse**: Open Full Site Editor, test block in templates
- **frontend**: Save the page, view frontend, verify output

Log in to wp-admin using credentials (from Credentials section).
When you need a specific page/block, ask at that moment: "Which page has [block]?"

For each test:
1. Navigate with `preview_eval`
2. If `screenshots=yes`: `preview_screenshot`
3. `preview_inspect` for CSS, `preview_snapshot` for text/structure
4. `preview_console_logs` for JS errors
5. Record: **PASS (visual)**, **FAIL (visual)**, or **BLOCKED**

On errors: check console, network, screenshot error state. Record as FAIL.

**5c: Stop browser**
`preview_stop` with `serverId`. Always clean up, even on failure.

### Phase 6: Generate Report

Read `references/report-template.md` and fill it in. Save to `qa-report.md`.
Print the verdict line immediately.

## Git Safety

**Read-only.** Never `add`, `commit`, `push`, `merge`, `rebase`, `reset`, `revert`, `stash`,
`cherry-pick`, `tag`, `rm`, `mv`, or `clean`. Never modify source files.
Only exception: `checkout`/`pull` in Issue Fetch Flow for branch switching.
Only files this skill may write: `qa-report.md` and `/tmp/eb-issue-details.md`.
Found a bug? Report it in the QA report -- never fix it.

## Important Notes

- **Essential Blocks only.** Don't test other plugins unless asked.
- **Read-only.** Never modifies, commits, or pushes.
- **Ask when stuck, not upfront.** Ask for context (pages, credentials, settings) when you need it, not all at Phase 0.
- Flag security vulnerabilities regardless of whether related to current change.
- Honest verdicts: PASS = confident. PARTIAL = some unverified. FAIL = something broken.
- Ask permission before activating/deactivating plugins or changing settings.
