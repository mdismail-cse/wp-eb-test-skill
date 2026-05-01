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
  "screenshots": "no"
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
| `screenshots` | No | `yes` / `no` -- take image screenshots (opt-in) | `no` |
| `-c` / `cloudinary` | No | Upload screenshots to Cloudinary and share URLs | `no` |
| `visual` | No | `yes` / `no` -- run visual browser tests. **Default YES** | `yes` |
| `test_areas` | No | `editor`, `fse`, `frontend`, or `all` | `all` or defaults.json |
| `analysis` | No | `normal` or `deep` -- deep traces dependency chains, consults wp-eb-dev | `normal` or defaults.json |

*Required unless set in `defaults.json`.

Examples:
- `/wp-eb-test` (all defaults: visual ON, screenshots OFF, diff vs main/master)
- `/wp-eb-test focus="slider"` (defaults + focus)
- `/wp-eb-test visual=no` (SKIP visual tests, code-only)
- `/wp-eb-test screenshots=yes` (visual tests + local screenshots)
- `/wp-eb-test screenshots=yes -c` (visual tests + Cloudinary screenshot URLs)
- `/wp-eb-test issue_url=https://projects.startise.com//fbs-80634`
- `/wp-eb-test scope=free build=no mode=investigate`
- `/wp-eb-test analysis=deep` (consults wp-eb-dev for deeper edge cases)

## Visual Testing vs Screenshots

**Visual testing is MANDATORY by default.** Always open the browser, navigate to pages, and run
test cases in the editor/FSE/frontend. Only skip visual tests if user sets `visual=no`.

**Screenshots (image captures) are separate and OFF by default.** Visual testing works without
screenshots by using `preview_snapshot` + `preview_inspect` + `preview_console_logs` which capture
HTML/CSS/console state as text.

Take screenshots ONLY when:
- User sets `screenshots=yes` in the command
- `defaults.json` has `"screenshots": "yes"` AND user didn't override with `screenshots=no`
- User explicitly says "take screenshot" during the session

**Cloudinary upload (when `-c` flag is present):**

When user adds `-c` along with `screenshots=yes`, upload each screenshot to Cloudinary
and use the returned URL in the report instead of a local path:

```bash
URL=$(bash "$SKILL_DIR/scripts/upload-cloudinary.sh" "<screenshot_path>" "wp-eb-test-<test_id>")
```

Requires `cloudinary.json` in plugin dir or `~/.cloudinary.json`:
```json
{
  "cloud_name": "your-cloud-name",
  "upload_preset": "your-unsigned-preset"
}
```
See `references/cloudinary-example.json`.

If upload fails, fall back to local path and note "Cloudinary upload failed" in the report.

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
- Browser MCP fallback chain (try in order, use first available):
  1. **Claude Preview MCP** -- `preview_list` (preferred)
  2. **Playwright MCP** -- `mcp__playwright__browser_snapshot` (fallback)
  3. **Claude in Chrome** -- `mcp__Claude_in_Chrome__navigate` (last resort)
  4. None available → ask: "No browser MCP available. Skip visual tests (`visual=no`) or set one up?"
- Git: `git -C <path> rev-parse --is-inside-work-tree`. If fails, ask for correct path.
- pnpm: `which pnpm`. If missing, ask: "Skip building or install pnpm?"

Note: Throughout this skill, `preview_*` calls refer to Claude Preview. If using Playwright,
substitute `mcp__playwright__browser_*` (e.g., `browser_navigate`, `browser_snapshot`,
`browser_take_screenshot`, `browser_console_messages`). If using Claude in Chrome,
substitute `mcp__Claude_in_Chrome__*` equivalents.

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

**ALWAYS diff against main/master.** This is the baseline. Never diff against a feature branch
or commit unless the user explicitly sets `branch=...`. The goal: what did THIS branch change
compared to the stable release line.

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

**Test cases MUST come from the actual code diff in Phase 1. Not from generic QA templates.**

Process:
1. Take the diff summary from Phase 1 (list of changed files, hunks, functions)
2. For EACH changed file/function, ask: "What does THIS specific change do? What can break?"
3. Write test cases that directly target those changes
4. THEN layer applicable categories (editor/frontend/edge/security/etc.) on top

The categories below are **filters**, not sources. A test case exists because the code changed --
the category just tells you what angle to check it from.

**Example of right vs wrong:**

Diff shows: `src/blocks/slider/edit.js` — added `autoplay` attribute to slider.

- ❌ Wrong (generic): "Test that slider works in editor"
- ✅ Right (from diff): "TC1: Slider `autoplay` attribute defaults to false. Editor control toggles it. Value persists after save."
- ✅ Right (from diff): "TC2: When `autoplay=true`, slider advances automatically. When false, stays still."
- ✅ Right (from diff): "TC3: `autoplay` works with existing `speed` and `transition` attributes — no conflict."

Skip entire categories if nothing in the diff touches them. A CSS-only change doesn't need
security tests. A PHP backend change may not need responsive tests.

Be precise, not exhaustive. Read the code to know exact values and states.

**When `analysis=deep`, consult the `wp-eb-dev` skill for deeper insights:**

Before finalizing the checklist, invoke the `wp-eb-dev` skill to get senior-dev-level analysis:
- "Given these code changes [summary], what EB-specific chain effects or future risks should I test?"
- "What non-obvious edge cases does this change introduce based on EB's architecture?"
- "Which hooks/filters/blocks in EB free and pro depend on the changed code?"

Use wp-eb-dev's findings to add targeted test cases covering:
- **Chain effects**: Code paths that trigger when the changed code executes
- **Deprecated flows**: Old APIs that might still be in use
- **Release alignment**: Free/pro/controls version compatibility
- **Hook consumers**: Which plugins/themes subscribe to affected hooks
- **Cross-repo impact**: How the change ripples through free ↔ pro ↔ controls
- **Migration paths**: Old block attribute formats still in user content

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

**User perspective tests** (ALWAYS include at least 3-5):

Think like a real end user, not a developer. Ask: how will a content creator, site admin, or
visitor actually encounter this change?

- **Content creator (admin/editor)**: A blogger building a page with this block -- can they
  configure it without reading docs? Is the control labeling clear?
- **Page visitor**: Does the block load fast? Does it work on slow connections? Does clicking/
  hovering feel responsive? Any unexpected UI shifts?
- **Mobile user**: Does the block feel natural with thumb navigation? Are touch targets large
  enough? Does text wrap correctly?
- **Accessibility user**: Can a keyboard-only user tab through? Does a screen reader announce
  changes correctly? Sufficient color contrast?
- **Returning user**: If they had this block configured before the change, does it still look
  and work the same? Or does something unexpected happen?
- **Non-tech user setting up the plugin**: Does it work out of the box with no configuration?
- **Power user**: Can they customize deeply? Do advanced settings behave as expected?

Format: `[#] [Free/Pro/Controls] Description → Expected result`
Keep to **10-25 items**.

### Phase 4: Code Analysis Verdict

**Skip if `mode=investigate`.**

For each test, classify:
- **PASS (code)** -- Code clearly handles this correctly. Still verify in Phase 5 IF the test
  involves UI/runtime behavior (most tests do). Skip Phase 5 only for pure code-logic tests
  (e.g., "uses sanitize_text_field" -- visible from code, no UI to check).
- **NEEDS VISUAL** -- Cannot confirm from code alone. MUST run in Phase 5.
- **CONCERN** -- Code might be wrong. Explain why. MUST verify in Phase 5.

Default: when in doubt, mark **NEEDS VISUAL**. Visual confirmation > code-only assumption.

Check: sanitization, nonces, capabilities, escaping, prepared queries, block validation.

### Phase 5: Visual Verification

**ALWAYS run this phase unless `visual=no`.** Visual testing is mandatory.

If `visual=no`: skip Phase 5 entirely, mark all NEEDS VISUAL items as "SKIPPED (user opted out)".

Test items marked "NEEDS VISUAL" (or all items in investigate mode).

**5a: Start browser**
1. `preview_start`, store `serverId`
2. Navigate to site URL, confirm loaded
3. If unreachable, ask: "Is the dev server running?"

**5b: Test (follow this order)**

Run tests in this EXACT order per page being tested:

1. **Editor first** -- Open Gutenberg post editor (`/wp-admin/post-new.php` or existing post)
   - Insert/locate the block, test all changed controls and attributes
   - Verify no console errors
2. **Save** -- Click Update/Publish. Verify save succeeds with no validation errors
3. **Frontend after save** -- Visit the saved page on the frontend
   - Verify rendered output matches editor preview
   - Test interactive JS, CSS, hover/click behaviors
4. **FSE (if `test_areas` includes `fse`)** -- Open `/wp-admin/site-editor.php`
   - Test block in template, template parts, patterns
   - Verify global styles don't conflict

This ordering catches save/serialization bugs (block validation errors, attribute drift) AND
rendering bugs in one pass. Skip steps if `test_areas` excludes them.

Log in to wp-admin using credentials (from Credentials section).
When you need a specific page/block, ask at that moment: "Which page has [block]?"

For each test:
1. Navigate with `preview_eval`
2. `preview_inspect` for CSS, `preview_snapshot` for text/structure (primary verification)
3. `preview_console_logs` for JS errors
4. **ONLY if `screenshots=yes`**: `preview_screenshot`, then upload to Cloudinary if `-c` flag set
5. Record: **PASS (visual)**, **FAIL (visual)**, or **BLOCKED**

On errors: check console, network logs. Screenshot the error state ONLY if `screenshots=yes`.
Record as FAIL with details from snapshot/inspect/console output.

**5c: Stop browser**
`preview_stop` with `serverId`. Always clean up, even on failure.

### Phase 6: Generate Report

Read `references/report-template.md` and fill it in. Save to `qa-report.md`.
Print the verdict line immediately.

**Report style: caveman.** Few words. Short sentences. No fluff. Keep originality (all sections,
all info) but strip verbose prose. Example:

- ❌ "The block renders correctly in the editor with no console errors and all settings persist."
- ✅ "Block render editor. No errors. Settings persist."

- ❌ "This test case verifies that the block still functions correctly after deactivating the pro plugin."
- ✅ "Pro off. Block still work."

Keep file paths, error messages, and technical details full. Only prose gets trimmed.

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
