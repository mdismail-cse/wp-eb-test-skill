# wp-eb-test

A Claude Code skill for QA testing the [Essential Blocks](https://essential-blocks.com/) WordPress plugin ecosystem -- free, pro, and shared controls.

## What it does

This skill turns Claude into a QA engineer for Essential Blocks. Give it a site URL (and optionally an issue link), and it will:

1. **Fetch issue details** from your project management tool (if an issue URL is provided)
2. **Switch branches** based on the issue's branch references
3. **Build** the plugin(s) using bundled build scripts
4. **Diff code** against main/master to understand what changed
5. **Generate a test checklist** with relevant edge cases
6. **Analyze the code** for correctness, security issues, and potential regressions
7. **Open a browser** (via Playwright MCP) to visually verify the changes on the site
8. **Produce a markdown report** (`qa-report.md`) with a PASS / FAIL / PARTIAL verdict

## Components tested

| Component | Path | Description |
|-----------|------|-------------|
| **Free** | `essential-blocks/` | The free Essential Blocks plugin |
| **Controls** | `essential-blocks/src/controls/` | Git submodule -- shared block controls used by both free and pro |
| **Pro** | `essential-blocks-pro/` | The pro add-on plugin |

## Installation

### Option 1: Copy to Claude skills directory

```bash
cp -r wp-eb-test ~/.claude/skills/wp-eb-test
```

### Option 2: Clone this repo and symlink

```bash
git clone https://github.com/mdismail-cse/wp-eb-test-skill.git
ln -s "$(pwd)/wp-eb-test-skill/wp-eb-test" ~/.claude/skills/wp-eb-test
```

## Prerequisites

- [Claude Code](https://claude.ai/claude-code) CLI or desktop app
- [Claude Preview MCP](https://github.com/anthropics/claude-code) configured (for visual testing via Playwright)
- `git` and `pnpm` installed
- Essential Blocks repo(s) cloned locally

## Usage

Run from inside your Essential Blocks plugin directory:

```bash
# Basic -- test free plugin against main branch
/wp-eb-test https://dev.local

# With issue URL -- fetches issue, switches branches, builds, tests
/wp-eb-test https://dev.local issue_url=https://projects.startise.com//fbs-80634

# Test free + pro together
/wp-eb-test https://dev.local scope=free+pro

# Test everything (free + pro + controls)
/wp-eb-test https://dev.local scope=all

# Test only the controls submodule
/wp-eb-test https://dev.local scope=controls

# Force rebuild before testing
/wp-eb-test https://dev.local build=yes

# Focus on a specific block
/wp-eb-test https://dev.local focus="advanced heading"

# Investigate mode -- skip diffing, test a specific area on main branch
/wp-eb-test https://dev.local mode=investigate focus="post grid pagination"

# Provide a fix description file
/wp-eb-test https://dev.local fix_file=./fix-notes.md
```

## Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `site_url` | Yes | -- | WordPress site URL to test (local or remote) |
| `issue_url` | No | -- | PM issue URL. Fetches details, branches, and sets up the test automatically |
| `scope` | No | `free` | What to test: `free`, `pro`, `controls`, `free+pro`, `free+controls`, `all` |
| `fix_file` | No | -- | Path to a file with fix/issue details |
| `focus` | No | -- | Specific block or area to focus on |
| `branch` | No | `main` | Branch to diff against (falls back to `master`) |
| `build` | No | `auto` | `yes` (always build), `no` (skip), `auto` (build if stale) |
| `mode` | No | `diff` | `diff` (compare against base branch) or `investigate` (skip diff, test directly) |

## Workflow

```
issue_url provided?
  │
  ├─ YES ──→ Read c.txt credentials
  │          → Start browser → Login to PM → Read issue card
  │          → Save details to /tmp/eb-issue-details.md
  │          → Stop browser
  │          → Switch branches (free/pro/controls)
  │          → Build
  │          ↓
  ├─ NO ───→ (skip issue fetch)
  │          ↓
  ▼
Phase 0: Gather missing info (site URL, credentials, test pages)
  ↓
Phase 1: Analyze code changes (git diff against main/master)
  ↓
Phase 2: Read fix details (from issue, fix_file, or inline)
  ↓
Phase 3: Build test checklist (10-25 focused test cases)
  ↓
Phase 4: Code analysis verdict (PASS/NEEDS VISUAL/CONCERN per test)
  ↓
Phase 5: Visual verification
  ├─ Start Playwright browser
  ├─ Navigate, screenshot, inspect, check console
  └─ Stop browser
  ↓
Phase 6: Generate qa-report.md with verdict
```

**Investigate mode** (on main/master, no diff): Skips Phase 1 and 4, goes straight to testing.

## Scope and build order

The `scope` argument controls what gets diffed, built, and tested:

| Scope | Builds | Tests |
|-------|--------|-------|
| `free` | Controls (dependency) + Free | Free blocks only |
| `pro` | Pro | Pro-only features |
| `controls` | Controls + Free (consumer) | Controls + all consuming blocks |
| `free+pro` | Controls + Free + Pro | Everything including cross-plugin |
| `all` | Controls + Free + Pro | Full ecosystem |

Build order is always: **Controls** (1st) -> **Free** (2nd) -> **Pro** (3rd).

## Credentials file

When using `issue_url`, the skill reads `c.txt` from the plugin directory for PM login credentials. This file is gitignored and should contain your project management tool username and password.

## Report output

The skill generates `qa-report.md` in the current directory with:

- Components tested (repos, branches, file counts)
- Code change summary
- Fix details
- Test results table (test case, component, method, result, notes)
- Security concerns
- **Final verdict: PASS / FAIL / PARTIAL**

## Build scripts

Three build scripts are included in `wp-eb-test/scripts/`:

| Script | Purpose |
|--------|---------|
| `build-free.sh` | Builds controls (dependency) then the free plugin |
| `build-controls.sh` | Builds only the controls submodule |
| `build-pro.sh` | Builds the pro plugin |

All scripts use `pnpm` and accept the plugin directory as the first argument.

## Git safety

This skill is **read-only** for git repositories. It will never modify your code or push anything.

**Allowed:**
- `git diff`, `git log`, `git status`, `git branch`, `git rev-parse`, `git fetch`
- `git checkout` / `git pull` -- only when switching branches via issue fetch flow

**Blocked:**
- `git add`, `git commit`, `git push`, `git merge`, `git rebase`, `git reset`, `git revert`, `git stash`, `git cherry-pick`, `git tag`, `git rm`, `git mv`, `git clean`
- Editing, creating, or deleting any source file in the plugin repos

If the skill finds a bug, it reports it in `qa-report.md` -- it never attempts to fix it.

## License

MIT
