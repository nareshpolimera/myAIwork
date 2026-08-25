# GitHub Copilot Instructions — Salesforce Metadata Code Review

These instructions configure the AI code review behavior for this
repository. This file is read in full and sent as-is to Claude by the
`mariomac/phoenix-plugin` GitHub Action (or any compatible AI review action
that reads `.github/copilot-instructions.md`). It applies when reviewing
changes under `force-app/main/default/` (or equivalent Salesforce package
directories).

> ⚠️ **Path matters.** This action reads rules from the exact path
> `.github/copilot-instructions.md` by default (configurable via the
> `rules-file` input in the workflow `.yml`). If a different file exists at
> that path, it will be used instead of this one — check for and remove any
> placeholder/example rules file before relying on this one.

> ℹ️ **Output format matters.** This action posts the review as a **single
> aggregated PR comment**, not separate native inline GitHub review comments.
> "Line by line" below means: *every violating line must be explicitly
> referenced by file name and line number inside that one comment* — not
> that separate comment threads will be created per line.

Full rule set: see [`SALESFORCE_CODE_REVIEW_GUIDELINES.md`](./SALESFORCE_CODE_REVIEW_GUIDELINES.md)
in the repo root. Treat that file as the source of truth; these instructions
tell Copilot *how* to apply it during review.

## Review Scope

Apply this review to any changed file matching:
- `**/*.cls`, `**/*.trigger` (Apex)
- `**/*.js`, `**/*.html`, `**/*.js-meta.xml` (Lightning Web Components)
- `**/*.object-meta.xml`, `**/*.field-meta.xml` (Custom objects/fields)
- `**/*.flow-meta.xml` (Flows)
- `**/*.permissionset-meta.xml`, `**/*.profile-meta.xml` (Permissions)
- `**/*Test.cls` (Apex test classes)

Skip generated/vendor metadata (e.g. `staticresources/`, `lwc/**/__tests__/`
snapshots) unless explicitly modified in the diff.

## Core Review Behavior

1. **Review line by line, but report in one comment.** For every changed
   line (or contiguous block) that violates a rule in
   `SALESFORCE_CODE_REVIEW_GUIDELINES.md`, include a dedicated entry in the
   review comment that names the **file path and exact line number(s)** —
   do not summarize violations only at the file or PR level. Group entries
   by file, ordered by line number within each file.
2. **Only report where a guideline is actually violated, or a real risk
   exists.** Do not report lines confirming compliance ("looks good here")
   — omission means no issue found. This keeps the comment readable.
3. **Cite the specific rule** being violated in every comment, using the same
   category names as the guidelines doc (e.g., "Bulkification & Governor
   Limits", "Security", "Error Handling & Reliability", "Testing").
4. **Classify severity** on every comment as one of:
   - 🔴 `Blocking` — must fix before merge (security, governor limits, broken/missing tests, SOQL injection, hardcoded credentials/IDs)
   - 🟡 `Suggestion` — non-blocking improvement (naming, magic strings, dead code, style)
   - 🔵 `Question` — needs author clarification, not a defect by itself
5. **Never rewrite business logic silently.** Point out the problem and
   suggest a fix, but do not assume intent beyond what the diff shows.

## Per-Line Entry Format

Within the single review comment, use this exact template for every
violating line or block, grouped under a heading for its file:

```
### `<file path>`

**Line <N>** — [<Severity Emoji> <Severity Label>] <Guideline Category>
<One-sentence description of what's wrong on this line/block.>

> Rule: "<short quote or paraphrase of the specific checklist item>"

Suggested fix: <concrete, minimal suggestion — code snippet if short>
```

Example (Apex, SOQL inside a loop):

```
### `force-app/main/default/classes/BadAccountHandler.cls`

**Line 16** — [🔴 Blocking] Bulkification & Governor Limits
This SOQL query executes once per iteration of the loop, risking the
101-query governor limit on bulk operations (e.g., a 200-record update).

> Rule: "No SOQL or DML statements inside for loops."

Suggested fix: Move the query outside the loop using a single
`SELECT ... WHERE Id IN :accountIds` and process results from a map.
```

## Apex-Specific Checks (comment on the exact offending line)

- SOQL/DML/callouts inside `for` loops → 🔴 Blocking, category "Bulkification & Governor Limits"
- Dynamic SOQL built by string concatenation of unescaped input → 🔴 Blocking, category "Security"
- Missing CRUD/FLS enforcement (`WITH SECURITY_ENFORCED`, `isAccessible()`, etc.) on user-context queries/DML → 🔴 Blocking, category "Security"
- No explicit `with sharing` / `without sharing` on a class → 🟡 Suggestion (🔴 if the class touches sensitive/financial fields), category "Security"
- Empty or overly broad `catch` blocks that swallow exceptions → 🔴 Blocking, category "Error Handling & Reliability"
- `System.debug` logging of sensitive data (PII, tokens, financial data) → 🔴 Blocking, category "Security"
- Hardcoded record type IDs, org URLs, or environment-specific values → 🔴 Blocking, category "General Principles"
- Commented-out dead code → 🟡 Suggestion, category "Style & Maintainability"
- Magic strings/numbers not extracted to constants/Custom Labels/Custom Metadata → 🟡 Suggestion, category "Style & Maintainability"
- New/changed public methods with no corresponding test method touching them → 🔴 Blocking, category "Testing"
- Test classes that only exercise the happy path (no negative/bulk 200+ record case) → 🟡 Suggestion (🔴 if there is *no* negative case at all), category "Testing"

## LWC-Specific Checks

- Imperative Apex call with no `.catch()` / error branch → 🔴 Blocking, category "LWC Review Checklist"
- Missing `aria-*` / label attributes on interactive elements → 🟡 Suggestion, category "LWC Review Checklist"
- `js-meta.xml` missing target scoping appropriate to the component's use → 🟡 Suggestion, category "LWC Review Checklist"

## Declarative Metadata Checks

- New custom field with no accompanying FLS/page layout change in the same PR → 🟡 Suggestion, category "Declarative Metadata Review Checklist"
- New field with empty/missing description or help text → 🟡 Suggestion, category "Declarative Metadata Review Checklist"
- Validation rule with a technical/unfriendly error message → 🟡 Suggestion, category "Declarative Metadata Review Checklist"
- Flow DML/callout element with no fault path connected → 🔴 Blocking, category "Declarative Metadata Review Checklist"
- Flow record-processing loop performing DML per iteration instead of using collection variables → 🔴 Blocking, category "Declarative Metadata Review Checklist"
- Permission set/profile granting `Modify All Data` / `View All Data` without justification in the PR description → 🔴 Blocking, category "Declarative Metadata Review Checklist"

## Summary Block (top of the same comment)

Before the per-file, per-line entries, open the comment with a summary block
using the format already defined in the guidelines doc:

1. **Summary** — one-line verdict: Approve / Changes Requested / Blocked.
2. **Blocking issues** — count and list of files containing 🔴 entries.
3. **Suggestions** — count of 🟡 entries.
4. **Questions** — count of 🔵 entries.

Never recommend Approve if any 🔴 Blocking entry exists anywhere in the diff.

## What Copilot Should NOT Do

- Do not invent guideline categories not present in `SALESFORCE_CODE_REVIEW_GUIDELINES.md`.
- Do not report on unchanged lines outside the PR diff.
- Do not review or comment on anything unrelated to Salesforce metadata (e.g., do not apply OpenTelemetry, generic observability, or unrelated instrumentation rules — those are out of scope for this repository).
- Do not recommend approval of deployment metadata changes (`destructiveChanges.xml`, permission set `Modify All Data`/`View All Data`) without noting that explicit human sign-off is required on the PR.