# Code Review Rules


# Salesforce Metadata Code Review Guidelines

This document defines the standards and checklist used when reviewing Salesforce metadata changes (Apex, Lightning Web Components, and declarative metadata) in this repository. Use it as a reference during manual PR reviews, or as an instruction set for an automated reviewer (e.g., a GitHub Action or AI agent).

# Scope

Applies to changes under force-app/main/default/ (or equivalent package directories), including:

Apex classes and triggers (.cls, .trigger)
Lightning Web Components (.js, .html, .css, .js-meta.xml)
Custom objects, fields, validation rules (.object-meta.xml, .field-meta.xml)
Flows and Process Builder definitions (.flow-meta.xml)
Permission sets, profiles, roles (.permissionset-meta.xml, .profile-meta.xml)
Custom metadata types, labels, static resources
General Principles
Every change should be minimal, scoped to the stated purpose, and reversible.
Prefer declarative solutions (Flow, validation rules) over Apex when performance and maintainability allow it — but not at the cost of testability.
No hardcoded IDs, org-specific URLs, or environment-specific values in code.
All metadata should deploy cleanly via sf project deploy with no manual post-deploy steps unless explicitly documented.
Apex Review Checklist

Bulkification & Governor Limits

 No SOQL or DML statements inside for loops.
 No callouts inside loops.
 Collections (Map, Set, List) used to batch record processing.
 Trigger logic delegates to a handler class; triggers contain no business logic.

Security

 SOQL queries use WITH SECURITY_ENFORCED or explicit CRUD/FLS checks (Schema.sObjectType...isAccessible(), etc.) where user-context matters.
 No SOQL injection — all dynamic query fragments use bind variables or String.escapeSingleQuotes().
 Sharing model is explicit (with sharing / without sharing) and justified.
 No sensitive data (tokens, credentials) logged via System.debug.

Error Handling & Reliability

 DML operations use Database.insert/update(records, false) with result checking where partial success is acceptable, or are wrapped in try/catch with meaningful logging when atomicity is required.
 Custom exceptions extend Exception and carry actionable messages.
 Callouts have timeout handling and are wrapped in try/catch.

Testing

 New/changed classes have ≥75% coverage (org requirement), with meaningful assertions — not just execution coverage.
 Test data is created in-test (@testSetup or factory methods), not dependent on org data.
 Positive, negative, and bulk (200+ records) test cases included.
 Test.startTest() / Test.stopTest() used around async/governor-limit-sensitive code.

Style & Maintainability

 Class/method names follow existing naming conventions (e.g., XxxService, XxxTriggerHandler, XxxController).
 No commented-out dead code.
 Magic numbers/strings extracted to constants or Custom Metadata/Labels.
Lightning Web Component Review Checklist
 @wire adapters used instead of imperative Apex calls where possible.
 Imperative Apex calls handle both success and error paths.
 No direct DOM manipulation outside of renderedCallback guards.
 Accessibility: labels, aria-* attributes, and keyboard navigation considered.
 js-meta.xml correctly scopes targets (App Builder, Flow, record page, etc.).
 No sensitive logic or secrets exposed client-side.
Declarative Metadata Review Checklist

Custom Fields / Objects

 Field-level security and page layout assignments included in the same PR.
 Help text and description populated for new fields.
 Naming follows org convention (e.g., __c suffix, PascalCase labels).

Validation Rules

 Error message is user-friendly and states the fix, not just the condition.
 Rule does not conflict with existing automation (Flows/triggers) causing save errors on legitimate updates.

Flows

 No recursive triggering risk (Flow calling itself via DML on same object).
 Fault paths defined for all DML/callout elements.
 Flow is bulkified (uses collection variables, not per-record loops with DML).

Permission Sets / Profiles

 Principle of least privilege — only required object/field/tab access granted.
 No Modify All Data / View All Data unless explicitly justified in PR description.
Deployment & CI Checks
 sf project deploy validate passes against target org.
 No destructive changes (destructiveChanges.xml) without explicit sign-off.
 Package.xml (if used) updated to include new components.
PR Review Response Format

When reviewing, structure feedback as:

Summary — one-line assessment (approve / changes requested / blocked).
Blocking issues — must be fixed before merge (security, governor limits, broken tests).
Suggestions — non-blocking style/maintainability improvements.
Questions — anything needing clarification from the author.

Cite the specific file and line number for every issue raised.