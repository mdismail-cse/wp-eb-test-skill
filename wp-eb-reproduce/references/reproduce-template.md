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
