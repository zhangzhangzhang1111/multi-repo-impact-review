# Impact JSON artifact design

## Goal

Every completed impact review produces a standalone JSON file alongside its Markdown report. Its root is the decoded `rawReportContent` object, not a Kafka event or a JSON-encoded string.

## Output contract

- Write `impact-report.json` next to the Markdown report, outside every reviewed source tree.
- Keep exactly these top-level fields: `summary`, `changed_modules`, `changed_symbols`, `direct_impacts`, `indirect_impacts`, `impact_chains`, `risk_level`, `risks`, `test_suggestions`, `api_changes`.
- `summary` is a string; `risk_level` is `low`, `medium`, or `high`; the remaining fields are arrays. An empty array means no verified item, not a claim that the area was fully tested.
- The template uses empty arrays. The supplied example does not define element shapes for arrays that were empty, so validation checks their top-level array type without inventing an item schema.
- Do not add Kafka envelope fields such as `packUser`, `jiraInfo`, `status`, `aiAssessmentType`, or `rawReportContent`.

## Production and validation

Add a JSON template in the installable skill and link it from `SKILL.md`. Produce Markdown and JSON from the same verified evidence so their summary, impact paths, risks, and risk level agree. Preserve uncertainty and avoid filling an array with unverified candidates merely to avoid emptiness.

Add a contract test that parses the template, checks the field set and top-level types, and rejects Kafka envelope fields. Keep the existing Markdown template and CodeGraph workflow unchanged. Validate the generated JSON by parsing it before delivery and include both artifact paths in the final response.

## Scope

No Kafka publishing, transport schema, API integration, or analysis of the sample project's actual commit is part of this change.
