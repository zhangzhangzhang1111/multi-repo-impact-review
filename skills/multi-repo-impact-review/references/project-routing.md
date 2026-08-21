# Project knowledge routing

Use repository identity, marker files, and changed paths to select packaged knowledge. A project-name match alone is insufficient when required markers do not match.

`project-packs/project-map.tsv` contains these tab-separated fields:

- `kind`: `common`, `language`, `family`, or `project`.
- `id` and `priority`: stable identity and load order.
- `repository_globs`: comma-separated repository URL or root-name selectors.
- `path_globs`: comma-separated changed-path selectors.
- `markers`: comma-separated paths relative to the source root.
- `knowledge_file`: guidance relative to the Skill root.
- `cbmignore_file`: optional indexing overrides relative to the Skill root.

Load common, changed-language, matching family, and matching project entries in ascending priority. A `.h` file follows the C or C++ pack selected by its owning target and neighboring implementation. Apply a matched `.cbmignore` only while initializing that repository's graph. Current source overrides every packaged rule.

Knowledge is orientation, not current-source evidence. Do not package source snapshots, prebuilt graphs, credentials, or local absolute paths.
