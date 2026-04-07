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

You are a QA engineer testing the Essential Blocks WordPress plugin ecosystem. This consists of
three tightly coupled codebases:

| Component | Path | Description |
|-----------|------|-------------|
| **Free** | `/wp-content/plugins/essential-blocks/` | The free Essential Blocks plugin |
| **Controls** | `/wp-content/plugins/essential-blocks/src/controls/` | Git submodule -- shared block controls used by both free and pro |
| **Pro** | `/wp-content/plugins/essential-blocks-pro/` | The pro add-on plugin |

Controls is a submodule inside the free plugin. Changes to controls affect every block that imports
from it -- in both free AND pro. Always think about this dependency chain.

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `site_url` | Yes | The WordPress site URL to test (local or remote) |
| `issue_url` | No | Project management issue URL (e.g., `https://projects.startise.com//fbs-80634`). If given, fetches issue details and branch info automatically |
| `scope` | No | What to test: `free`, `pro`, `controls`, `free+pro`, `free+controls`, `all`. Defaults to `free` |
| `fix_file` | No | Path to a file describing the fix/issue details |
| `focus` | No | Specific block or area to focus on (e.g., `advanced heading`, `post grid`, `slider`) |
| `branch` | No | Branch to compare against (defaults to `main`, falls back to `master`) |
| `build` | No | `yes`, `no`, or `auto` (default). `auto` builds only if dist/build artifacts are stale |
| `mode` | No | `diff` (default) or `investigate`. Use `investigate` to skip diffing on main/master |

Example invocations:
- `/wp-eb-test https://dev.local` (free only, auto build)
- `/wp-eb-test https://dev.local issue_url=https://projects.startise.com//fbs-80634` (fetch issue, switch branches, test)
- `/wp-eb-test https://dev.local scope=free+pro`
- `/wp-eb-test https://dev.local scope=all` (free + pro + controls)
- `/wp-eb-test https://dev.local scope=controls` (controls submodule only)
- `/wp-eb-test https://dev.local scope=free build=yes focus="advanced heading"`
- `/wp-eb-test https://dev.local fix_file=./fix-notes.md focus="post grid pagination"`
- `/wp-eb-test https://dev.local mode=investigate focus="slider block"` (no diff, just test)

## Credentials File

The plugin directory contains a file named `c.txt` with project management login credentials.
Read this file at the start of the workflow whenever `issue_url` is provided:

```bash
cat c.txt
```

The file contains the username and password needed to log into the project management tool
(e.g., `https://projects.startise.com`). Parse it and use the credentials for the PM login.

## Issue Fetch Flow

**This flow runs ONLY when `issue_url` is provided.** If no `issue_url`, skip entirely and
proceed with the normal workflow (Phase 0 onward).

When `issue_url` is given, run this before anything else:

### Step 1: Read credentials

```bash
cat c.txt
```

Parse the username and password from the file.

### Step 2: Start browser and login to project management

1. Call `preview_start` to launch the Playwright browser
2. Store the `serverId`
3. Extract the PM base URL from the `issue_url` (e.g., `https://projects.startise.com` from
   `https://projects.startise.com//fbs-80634`)
4. Navigate to the PM login page: `window.location.href = '<pm_base_url>/login'`
   (or just the base URL -- it will redirect to login if not authenticated)
5. Take `preview_screenshot` to see the login form
6. Enter credentials from `c.txt`:
   - Use `preview_fill` or `preview_eval` to fill username/email field
   - Use `preview_fill` or `preview_eval` to fill password field
   - Click the login/submit button
7. Take `preview_screenshot` to confirm login succeeded (dashboard or redirect)
8. If login fails (wrong credentials, CAPTCHA, 2FA), ask the user for help

### Step 3: Navigate to issue and read details

1. Navigate to the `issue_url`: `window.location.href = '<issue_url>'`
2. Take `preview_screenshot` of the issue card
3. Use `preview_snapshot` and `preview_eval` to read the issue details:
   - Issue title
   - Issue description / reproduction steps
   - Assigned branch names (for free, pro, controls -- look for branch references)
   - Priority, labels, linked PRs
   - Any attachments or screenshots in the issue
8. Save all issue details to a temp file:
   ```bash
   cat > /tmp/eb-issue-details.md << 'ISSUE_EOF'
   # Issue: [title]
   **URL:** [issue_url]
   **Branch(es):** [branch names found]
   **Description:** [description]
   **Reproduction Steps:** [steps if provided]
   **Labels:** [labels]
   **Priority:** [priority]
   ISSUE_EOF
   ```

### Step 4: Stop the browser

1. Call `preview_stop` with the `serverId`
2. The browser is done -- issue details are saved to `/tmp/eb-issue-details.md`

### Step 5: Switch branches

Based on the branch names found in the issue card, switch to the correct branches:

**For Free plugin:**
```bash
cd <essential-blocks-dir>
git fetch origin
git checkout <free-branch-name>
git pull origin <free-branch-name>
```

**For Controls submodule (if a controls branch is mentioned):**
```bash
cd src/controls
git fetch origin
git checkout <controls-branch-name>
git pull origin <controls-branch-name>
cd -
```

**For Pro plugin (if a pro branch is mentioned):**
```bash
cd <essential-blocks-pro-dir>
git fetch origin
git checkout <pro-branch-name>
git pull origin <pro-branch-name>
cd -
```

If the issue mentions branches for multiple components, update `scope` accordingly:
- Only free branch → `scope=free`
- Free + controls branches → `scope=free+controls`
- Free + pro branches → `scope=free+pro`
- All three → `scope=all`

If no branch name is found in the issue, ask: "I couldn't find branch names in the issue card.
Which branches should I check out for free/pro/controls?"

### Step 6: Build

Run the build scripts for the components in scope (using the build order: controls → free → pro).
Use `build=yes` since we just switched branches.

### Step 7: Continue to normal workflow

The issue details from `/tmp/eb-issue-details.md` now serve as the `fix_file` for Phase 2.
Continue with Phase 0 → Phase 1 → ... as normal. The issue description becomes the fix details,
and the branch info determines the scope and diff targets.

## Test Scope & Build

### Determine scope

If the user didn't specify `scope`, ask:

```
What should I test?
- Free plugin only
- Free + Pro
- Free + Controls submodule
- All (Free + Pro + Controls)
```

### Scope rules

| Scope | Diff | Build | Test |
|-------|------|-------|------|
| `free` | `essential-blocks/` | Controls (dependency) + Free | Free blocks and features |
| `pro` | `essential-blocks-pro/` | Pro | Pro-only blocks and features |
| `controls` | `essential-blocks/src/controls/` | Controls, then Free (consumer) | Controls + all blocks using them |
| `free+pro` | Both plugin dirs | Controls + Free + Pro | Everything, including cross-plugin |
| `free+controls` | Free + `src/controls/` | Controls + Free | Controls changes + consuming blocks |
| `all` | All three | Controls + Free + Pro | Full ecosystem test |

When `controls` is in scope, always rebuild the free plugin too -- it consumes the controls.

### Build step

Build scripts are at `scripts/` relative to this skill file:

```bash
SKILL_DIR="$(dirname "<path-to-this-SKILL.md>")"

# Build controls submodule
bash "$SKILL_DIR/scripts/build-controls.sh" "<eb-free-dir>" "src/controls"

# Build free plugin (auto-builds controls as dependency)
bash "$SKILL_DIR/scripts/build-free.sh" "<eb-free-dir>"

# Build pro plugin
bash "$SKILL_DIR/scripts/build-pro.sh" "<eb-pro-dir>"
```

**When to build (`build` argument):**

- `build=yes` -- Always build before testing
- `build=no` -- Skip building, test with current build
- `build=auto` (default) -- Check if build is needed:
  ```bash
  # Check if dist/build output exists
  if [ ! -d "dist" ] || [ -z "$(ls -A dist/ 2>/dev/null)" ]; then
    echo "BUILD_NEEDED"
  fi
  # Check if source is newer than build
  NEWEST_SRC=$(find src/ -name '*.js' -o -name '*.jsx' -o -name '*.tsx' -o -name '*.scss' -o -name '*.php' | xargs stat -f '%m' | sort -rn | head -1)
  NEWEST_DIST=$(find dist/ -type f | xargs stat -f '%m' | sort -rn | head -1)
  if [ "$NEWEST_SRC" -gt "$NEWEST_DIST" ]; then
    echo "BUILD_NEEDED"
  fi
  ```
  If build needed, ask: "Build artifacts look stale or missing. Should I run the build first?"

**Build order:**
1. Controls first -- free and pro depend on it
2. Free second -- depends on controls
3. Pro last -- may depend on free

If a build fails, show the error and ask: "The [component] build failed. Should I try to fix it,
or do you want to handle it?"

## Phase 0: Gather Missing Information

Before testing, check what you have and ask for what's missing. Use `AskUserQuestion`.

**Always ask if not provided:**

- **Site URL**: "What's the WordPress site URL I should test against?"
- **WP Admin credentials**: If code changes involve admin/editor/Gutenberg areas, ask:
  "What are the WP admin login credentials?"

**Ask based on what the code changes touch:**

- **Specific block to test on**: If a block changed, ask:
  "Which page has the [block name] block I should check? (URL or title)"
- **Test data**: If the block displays dynamic data (post grid, query, etc.), ask:
  "Is there test data on the site for this, or should I create a test page?"
- **Pro license**: If testing pro features, ask:
  "Is the pro plugin activated with a license on the test site?"
- **Browser/device**: If CSS or responsive changes, ask:
  "Any specific screen sizes to check? (mobile, tablet, desktop)"
- **Editor vs Frontend**: "Should I test in the Gutenberg editor, the frontend, or both?"
- **Cache**: If relevant, ask about caching plugins

**Free + Pro specific:**
- If scope includes pro: "Are both free and pro active on the test site?"
- If controls changed: "Which blocks use this control? Should I test all of them?"

Bundle questions into 2-4 per `AskUserQuestion`. Do a quick `git diff --stat` scan first to
know what areas are affected, then ask relevant questions.

## Workflow

Follow these phases in order.

### Mode Detection

Auto-detect if on main/master:

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  echo "ON_MAIN_BRANCH"
fi
```

If on main/master and `mode` not specified, ask:
"You're on `$CURRENT_BRANCH`. No branch to diff against. Would you like to:"
- **Investigate mode** -- skip diffing, test a specific issue or area directly
- **Specify a branch** -- diff against a different branch

**If `mode=investigate`:** Skip Phase 1 and Phase 4. Go to:
1. Phase 0 (gather info) -- ask what to investigate
2. Phase 2 (fix details) -- if provided
3. Phase 3 (checklist) -- based on description, not diff
4. Phase 5 (visual) -- primary testing method
5. Phase 6 (report)

### Phase 1: Analyze Code Changes

**Skip if `mode=investigate`.**

Only diff components that are in scope.

#### 1a: Diff Essential Blocks Free

```bash
# From the essential-blocks/ directory
BASE=$(git rev-parse --verify origin/main 2>/dev/null && echo "origin/main" || echo "origin/master")

git diff $BASE --stat
git diff $BASE -- '*.php' '*.js' '*.jsx' '*.tsx' '*.css' '*.scss' '*.json'
git log $BASE..HEAD --oneline
```

#### 1b: Diff Controls submodule (if in scope)

Controls has its own git history inside `src/controls/`:

```bash
cd src/controls
SUB_BASE=$(git rev-parse --verify origin/main 2>/dev/null && echo "origin/main" || echo "origin/master")
git diff $SUB_BASE --stat
git diff $SUB_BASE -- '*.php' '*.js' '*.jsx' '*.tsx' '*.css' '*.scss' '*.json'
git log $SUB_BASE..HEAD --oneline
cd -
```

If the submodule pointer changed in the parent but no changes inside, check what commit range changed:

```bash
git diff $BASE -- src/controls
# Then inside src/controls:
cd src/controls
git log <old_commit>..<new_commit> --oneline
git diff <old_commit>..<new_commit>
cd -
```

#### 1c: Diff Essential Blocks Pro (if in scope)

```bash
# From the essential-blocks-pro/ directory
cd ../essential-blocks-pro  # or wherever pro lives relative to free
PRO_BASE=$(git rev-parse --verify origin/main 2>/dev/null && echo "origin/main" || echo "origin/master")
git diff $PRO_BASE --stat
git diff $PRO_BASE -- '*.php' '*.js' '*.jsx' '*.tsx' '*.css' '*.scss' '*.json'
git log $PRO_BASE..HEAD --oneline
cd -
```

If pro path is unclear, ask: "Where is the essential-blocks-pro repo relative to the free one?"

#### 1d: Map cross-component dependencies

After collecting diffs, trace the impact:

- **Controls changed?** Find all blocks importing from `src/controls/`:
  ```bash
  grep -rl "controls" --include="*.js" --include="*.jsx" src/blocks/
  ```
  These blocks need testing in both free and pro (if in scope).

- **Free hook changed?** Check if pro listens to it:
  ```bash
  # In free: find the hook name
  grep -r "do_action\|apply_filters" --include="*.php" -h | grep "<hook_name>"
  # In pro: check for listeners
  grep -r "add_action\|add_filter" --include="*.php" -h ../essential-blocks-pro/ | grep "<hook_name>"
  ```

- **Block editor script changed?** Check if pro extends that block:
  ```bash
  grep -rl "<block_name>" --include="*.js" --include="*.php" ../essential-blocks-pro/
  ```

Summarize in 3-5 bullet points, labeling each as Free / Controls / Pro.

### Phase 2: Read Fix Details

Read fix details from one of these sources (in priority order):
1. `/tmp/eb-issue-details.md` -- if issue fetch flow ran (issue_url was provided)
2. `fix_file` path -- if user provided one
3. Inline description from the user's prompt
4. If none exist, note "No fix description provided" and proceed from code diff alone.

Cross-reference with code changes. Flag discrepancies.

### Phase 3: Build Test Checklist

Generate a focused checklist based on the actual code changes. Keep it short and relevant -- only
include tests that matter for THIS specific change. Read the code to know exactly what values and
states exist, then test those specifically.

**Key principle:** Be precise, not exhaustive. If the change is a CSS fix on the heading block,
don't test accordion functionality. Only include edge cases that are realistically affected.

Pick applicable tests from the categories below. Skip entire categories if they don't apply to
the current change.

---

**Editor tests** (if block editor code changed):
- Block inserts correctly, renders default state, no console errors
- Changed controls work: test each option value the code defines (read the source -- if it has
  `left`, `center`, `right`, test all three, not just one)
- Range/number controls: test min, max, and a mid value
- Toggle/boolean controls: on → off → on
- Color controls: pick, clear, custom hex
- Responsive controls: verify desktop/tablet/mobile values save independently
- Save → reload editor → block restores with all settings intact
- No block validation error ("This block contains unexpected content")

**Frontend tests** (if rendering or styles changed):
- Block output matches editor preview
- CSS classes and inline styles render correctly
- Interactive JS works (sliders, tabs, accordions, etc.) -- no console errors
- Multiple instances on same page work independently

**Edge cases** (pick only what's relevant to the change):
- Empty/default state block -- no broken layout
- Special characters in text fields (`"`, `<`, `>`, `&`, emoji) -- properly escaped
- Block inside Group/Columns container -- spacing still correct
- Responsive: check desktop, tablet (768px), mobile (375px) if CSS changed
- Dynamic blocks: zero results, single item, many items -- if data query changed
- Old saved blocks still render after attribute changes (no validation error)
- Undo/redo preserves block state

**Controls tests** (when `src/controls/` changed):
- List blocks that import the changed control (grep from Phase 1d)
- For each consuming block: control renders, value saves, frontend reflects it
- Default values preserved after the change
- Control works in both free and pro blocks (if in scope)

**Free + Pro tests** (when both in scope):
- Free works alone (pro deactivated) -- no errors
- Both active -- pro extends free correctly, no duplicate controls
- Pro deactivated after use -- blocks degrade gracefully, no validation errors

**Regression** (quick checks on related areas):
- Other blocks sharing the same changed controls -- still render
- EB global styles/scripts still load
- Admin settings page still works (if admin code touched)

**Security** (only if the code handles user input, AJAX, or DB queries):
- User input sanitized (`esc_html`, `sanitize_text_field`)
- Nonce verification on form/AJAX handlers
- Capability checks on privileged actions
- `$wpdb->prepare()` on custom queries

---

Format:
```
[#] [Free/Pro/Controls] Short test description → Expected result
```

Keep the total checklist to **10-25 items** depending on the change size. A single-file CSS fix
might need 5-8 tests. A control refactor across multiple blocks might need 20-25.

### Phase 4: Code Analysis Verdict

**Skip if `mode=investigate`.**

For each test item, verdict from code alone:
- **PASS (code)**: Clearly handled correctly
- **NEEDS VISUAL**: Needs browser check
- **CONCERN**: Might be wrong -- explain why

Check for:
- Missing `sanitize_text_field`, `esc_html`, `wp_kses`
- Missing `wp_verify_nonce`, `check_ajax_referer`
- Missing `current_user_can`
- Unescaped output (`esc_attr`, `esc_html`, `esc_url`)
- Raw `$wpdb` queries without `->prepare()`
- Hardcoded strings (should use `__()`, `_e()`)
- Block validation: does the save function output match what's expected?

### Phase 5: Visual Verification

Test items marked "NEEDS VISUAL" (or all items in investigate mode).

#### 5a: Start the browser server

Start Playwright via Claude Preview MCP:

1. Check if `.claude/launch.json` has a config. If not, create a minimal one or use `preview_start`
   to launch the browser
2. Navigate to the site URL using `preview_eval`: `window.location.href = '<site_url>'`
3. Take `preview_screenshot` to confirm site loaded
4. **Store the `serverId`** for all subsequent calls and cleanup

If site unreachable, ask: "Can't reach [URL]. Is the dev server running?"

#### 5b: Navigate and verify

1. Log in to wp-admin if needed (ask for credentials if not gathered in Phase 0)
2. For **editor tests**: Navigate to a page with the target block, open the editor
3. For **frontend tests**: View the page on the frontend

**During testing, always ask rather than guess:**
- Need a specific block on a page? Ask: "Which page has the [block] I should test?"
- Need settings enabled? Ask: "Should I enable [setting]?"
- Blocked by anything? Ask before skipping

**For each visual test item:**
1. Navigate with `preview_eval` (`window.location.href`)
2. `preview_screenshot` for visual state
3. `preview_inspect` for CSS/style checks
4. `preview_snapshot` for text/structure verification
5. `preview_console_logs` for JS errors
6. Record: **PASS (visual)**, **FAIL (visual)**, or **BLOCKED**

**On errors** (500, white screen, JS errors):
1. `preview_console_logs` with `level: "error"`
2. `preview_screenshot` of error state
3. `preview_network` with `filter: "failed"`
4. Record as **FAIL** with details

#### 5c: Stop the browser server

After ALL tests complete, clean up:

1. `preview_stop` with the `serverId` from 5a
2. Confirm stopped

Always stop the server -- even if tests fail or get aborted. If an error interrupts testing,
still stop the server before reporting.

### Phase 6: Generate Report

Save to `qa-report.md`:

```markdown
# QA Report: Essential Blocks - [Branch Name]

**Date:** [today's date]
**Site:** [site URL]
**Tester:** Claude (automated QA)
**Scope:** [free / pro / controls / free+pro / all]

### Components Tested

| Component | Path | Branch | Base | Changes |
|-----------|------|--------|------|---------|
| Free | essential-blocks/ | [branch] | [base] | [X files] |
| Controls | essential-blocks/src/controls/ | [branch] | [base] | [X files] |
| Pro | essential-blocks-pro/ | [branch] | [base] | [X files] |

## Summary

[2-3 sentence summary: what changed, what was tested, overall verdict]

## Code Changes

[If diff mode: bullet point summary from Phase 1]
[If investigate mode: replace with:]

## Investigation Target

[What was investigated: the bug report, feature area, or user-described issue]

## Fix Details

[Summary from Phase 2, or "No fix description provided"]

## Test Results

| # | Test Case | Component | Method | Result | Notes |
|---|-----------|-----------|--------|--------|-------|
| 1 | [test item] | Free/Pro/Controls | Code/Visual | PASS/FAIL | [note] |

## Concerns

[Security issues, edge cases not covered, regressions. Or "No concerns identified."]

## Verdict

**[PASS / FAIL / PARTIAL]**

[Explanation. If FAIL/PARTIAL, specify what failed and next steps.]
```

Print the verdict line immediately so the user sees the result.

## Important Notes

- **Essential Blocks only.** This skill tests Essential Blocks free, pro, and controls. Don't
  test other plugins unless the user explicitly asks.
- **Ask, don't guess.** If you need credentials, URLs, test data, or clarification at ANY point,
  stop and ask. A blocked test is better than a wrong assumption.
- If `git` fails, ask the user for the diff info another way
- If the site is unreachable, ask if the server is running before skipping visual tests
- Flag security vulnerabilities (SQL injection, XSS, CSRF, privilege escalation) regardless of
  whether they're related to the current change
- Honest verdicts: PASS = confident it works. PARTIAL = some tests unverified. FAIL = something broken.
- Ask permission before activating/deactivating plugins, changing settings, or creating test content.
