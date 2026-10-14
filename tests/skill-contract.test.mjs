import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const repo = path.resolve(import.meta.dirname, '..');
const skill = path.join(repo, 'skills', 'multi-repo-impact-review');
const read = (p) => fs.readFileSync(p, 'utf8');

test('project introductions are installed with the skill and remain discoverable', () => {
  const routing = path.join(skill, 'references', 'project-routing.md');
  const map = path.join(skill, 'project-packs', 'project-map.tsv');
  assert.ok(fs.existsSync(routing));
  assert.ok(fs.existsSync(map));
  assert.match(read(path.join(skill, 'SKILL.md')), /references\/project-routing\.md/);
  const rows = read(map).trim().split(/\r?\n/).map((line) => line.split('\t'));
  assert.equal(rows[0].at(-1), 'knowledge_file');
  for (const row of rows.slice(1)) {
    const knowledge = row.at(-1);
    assert.ok(fs.existsSync(path.join(skill, knowledge)), knowledge);
  }
  for (const id of ['scriptswtlua', 'mobiwtlua']) {
    const file = path.join(skill, 'project-packs', 'projects', id, 'knowledge', `${id.toUpperCase()}_PROJECT_KNOWLEDGE.md`);
    assert.ok(fs.existsSync(file), file);
  }
});

test('skill is CodeGraph-only and initializes indexes when needed', () => {
  const text = read(path.join(skill, 'SKILL.md'));
  for (const required of [
    'codegraph_status',
    'codegraph init -i',
    'codegraph_context',
    'codegraph_impact',
    'codegraph_trace',
    'codegraph_explore',
  ]) assert.match(text, new RegExp(required.replace(/[.*+?^$\{\}()|[\]\\]/g, '\\$&')));
  assert.doesNotMatch(text, /codebase-memory|launch-engine|graph\.db\.zst|trace_path|detect_changes/i);
});

test('legacy bundled-engine artifacts are absent', () => {
  for (const rel of ['runtime', 'vendor', 'project-packs', 'MANIFEST.json', 'SBOM.json', 'scripts']) {
    assert.equal(fs.existsSync(path.join(repo, rel)), false, rel);
  }
  assert.equal(fs.existsSync(path.join(skill, 'scripts', 'run-review.sh')), false, 'legacy review runner');
});

test('all relative Markdown links from SKILL.md resolve', () => {
  const text = read(path.join(skill, 'SKILL.md'));
  const links = [...text.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)].map((m) => m[1]);
  assert.ok(links.length > 0);
  for (const rel of links) assert.ok(fs.existsSync(path.join(skill, rel)), rel);
});

test('report template has an independent technical appendix', () => {
  assert.match(read(path.join(skill, 'assets', 'report-template.md')), /^## 4\. 技术证据与限制$/m);
});

test('JSON template matches the decoded rawReportContent contract', () => {
  const template = JSON.parse(read(path.join(skill, 'assets', 'impact-report.template.json')));
  const schema = JSON.parse(read(path.join(skill, 'assets', 'impact-report.schema.json')));
  const keys = ['summary', 'changed_modules', 'changed_symbols', 'direct_impacts', 'indirect_impacts', 'impact_chains', 'risk_level', 'risks', 'test_suggestions', 'api_changes'];
  assert.deepEqual(Object.keys(template).sort(), [...keys].sort());
  assert.deepEqual([...schema.required].sort(), [...keys].sort());
  assert.deepEqual(Object.keys(schema.properties).sort(), [...keys].sort());
  assert.equal(schema.additionalProperties, false);
  assert.deepEqual(schema.properties.risk_level.enum, ['low', 'medium', 'high']);
  assert.equal(schema.properties.summary.type, 'string');
  assert.equal(template.risk_level, '');
  for (const key of keys.filter((key) => !['summary', 'risk_level'].includes(key))) {
    assert.ok(Array.isArray(template[key]), key);
    assert.equal(schema.properties[key].type, 'array');
  }
  assert.match(read(path.join(skill, 'SKILL.md')), /impact-report\.template\.json/);
  assert.match(read(path.join(skill, 'SKILL.md')), /impact-report\.schema\.json/);
  assert.match(read(path.join(skill, 'SKILL.md')), /validate-impact-json\.py/);
});

test('skill instructions and design are readable in Chinese', () => {
  for (const rel of [
    'SKILL.md',
    'references/task-input.md',
    'references/project-routing.md',
    'references/graph-verification.md',
    'references/cpp-lua-bindings.md',
    'project-packs/common/review.md',
    'project-packs/families/embedded-lua-services.md',
    'project-packs/projects/scriptswtlua/knowledge/project.md',
  ]) {
    const han = read(path.join(skill, rel)).match(/\p{Script=Han}/gu) ?? [];
    assert.ok(han.length >= 30, rel);
  }
  const design = read(path.join(repo, 'docs', 'superpowers', 'specs', '2026-10-14-impact-json-artifact-design.md'));
  assert.ok((design.match(/\p{Script=Han}/gu) ?? []).length >= 30);
});

test('validator accepts a filled rawReportContent object and rejects malformed reports', () => {
  const validator = path.join(skill, 'scripts', 'validate-impact-json.py');
  const template = JSON.parse(read(path.join(skill, 'assets', 'impact-report.template.json')));
  const valid = { ...template, summary: 'two services add sync component', risk_level: 'medium' };
  const run = (value) => spawnSync('python', [validator, '-'], { input: typeof value === 'string' ? value : JSON.stringify(value), encoding: 'utf8' });
  assert.equal(run(valid).status, 0);
  for (const invalid of [
    template,
    { ...valid, risk_level: 'critical' },
    { ...valid, packUser: 'someone' },
    { ...valid, api_changes: undefined },
    { ...valid, impact_chains: 'not an array' },
    JSON.stringify(valid).replace('"risks":[]', '"risks":[NaN]'),
    JSON.stringify(valid).replace('"summary":"two services add sync component"', '"summary":"first","summary":"second"'),
    '{broken json',
  ]) assert.notEqual(run(invalid).status, 0);
});
