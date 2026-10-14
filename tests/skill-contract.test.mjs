import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

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
  assert.equal(fs.existsSync(path.join(skill, 'scripts')), false, 'skill scripts');
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
