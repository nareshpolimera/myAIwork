# GitHub Copilot Instructions — Salesforce Metadata Code Review

These instructions configure Copilot's code review behavior for this
repository. They apply to Copilot Chat, Copilot code review, and Copilot PR
summaries when reviewing changes under `force-app/main/default/` (or
equivalent Salesforce package directories).

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

1. **Review line by line.** For every changed line (or contiguous block) that
   violates a rule in `SALESFORCE_CODE_REVIEW_GUIDELINES.md`, leave an inline
   PR comment on that exact line — do not summarize violations only at the
   file or PR level. File/PR-level summary is additional, not a replacement.
2. **Only comment where a guideline is actually violated, or a real risk
   exists.** Do not leave comments confirming compliance ("looks good here")
   — silence on a line means no issue found. This keeps review noise low.
3. **Cite the specific rule** being violated in every comment, using the same
   category names as the guidelines doc (e.g., "Bulkification & Governor
   Limits", "Security", "Error Handling & Reliability", "Testing").
4. **Classify severity** on every comment as one of:
   - 🔴 `Blocking` — must fix before merge (security, governor limits, broken/missing tests, SOQL injection, hardcoded credentials/IDs)
   - 🟡 `Suggestion` — non-blocking improvement (naming, magic strings, dead code, style)
   - 🔵 `Question` — needs author clarification, not a defect by itself
5. **Never rewrite business logic silently.** Point out the problem and
   suggest a fix, but do not assume intent beyond what the diff shows.

## Inline Comment Format

Use this exact template for every line-level comment:

```
**[<Severity Emoji> <Severity Label>] <Guideline Category>**
<One-sentence description of what's wrong on this line/block.>

> Rule: "<short quote or paraphrase of the specific checklist item>"

Suggested fix: <concrete, minimal suggestion — code snippet if short>
```

Example (Apex, SOQL inside a loop):

```
**[🔴 Blocking] Bulkification & Governor Limits**
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

## PR-Level Summary (in addition to inline comments)

At the end of the review, post one summary comment using the format already
defined in the guidelines doc:

1. **Summary** — one-line verdict: Approve / Changes Requested / Blocked.
2. **Blocking issues** — count and list of files containing 🔴 comments.
3. **Suggestions** — count of 🟡 comments.
4. **Questions** — count of 🔵 comments.

Do not approve a PR with any open 🔴 Blocking inline comment.

## What Copilot Should NOT Do

- Do not invent guideline categories not present in `SALESFORCE_CODE_REVIEW_GUIDELINES.md`.
- Do not comment on unchanged lines outside the PR diff.
- Do not auto-resolve or dismiss its own prior comments without the author's fix being visible in a later commit.
- Do not approve deployment metadata changes (`destructiveChanges.xml`, permission set `Modify All Data`/`View All Data`) without an explicit human sign-off comment on the PR.