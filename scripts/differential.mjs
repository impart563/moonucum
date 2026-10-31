// The reference implementation is test-only. MoonUCUM never invokes it at runtime.
import { createRequire } from 'node:module';
import { spawnSync } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
const require = createRequire(import.meta.url);
const { UcumLhcUtils } = require('@lhncbc/ucum-lhc');
const reference = UcumLhcUtils.getInstance();
const root = fileURLToPath(new URL('../', import.meta.url));

function moon(args) {
  const process = spawnSync('moon', ['run', '--target', 'js', 'cmd/ucum', '--', ...args], {
    cwd: root, encoding: 'utf8', timeout: 120000, maxBuffer: 16 * 1024 * 1024,
  });
  if (process.status !== 0) throw new Error(process.stderr || String(process.error));
  return process.stdout.trim().split(/\r?\n/).map(line => JSON.parse(line));
}

const catalog = moon(['catalog'])[0];
const cases = [];
for (const entry of catalog.units) {
  if (!entry.normalization.ok) continue;
  for (const value of [1, 123.45]) {
    cases.push({ value, source: entry.code, target: entry.normalization.basis });
  }
}
for (const [source, target] of [
  ['mg/dL', 'g/L'], ['ug/(kg.min)', 'mg/(kg.h)'], ['mm[Hg]', 'kPa'],
  ['Cel', '[degF]'], ['mCel', 'K'], ['[degRe]', 'K'], ['2.Cel', 'K'],
  ['km/h', 'm/s'], ['KiBy', 'By'], ['s/m.g', 'g.s/m'], ['s/m/g', 's/(m.g)'],
]) {
  for (const value of [-40, 0, 1, 12.5, 1000]) cases.push({ value, source, target });
}

const failures = [];
const differences = [];
const results = [];
// Each entry is independently pinned to the unchanged UCUM 2.2 catalog or §43.
// A reference mismatch is reviewed only if BOTH observed values match this policy.
const policies = new Map([
  ['mol', ['1', 6.02214076e23, 0, 'incommensurable', 'UCUM §28: mole is not a base dimension']],
  ['eq', ['1', 6.02214076e23, 0, 'incommensurable', 'UCUM table 18: eq = mol']],
  ['osm', ['1', 6.02214076e23, 0, 'incommensurable', 'UCUM table 18: osm = mol']],
  ['kat', ['s-1', 6.02214076e23, 0, 'incommensurable', 'UCUM table 4: kat = mol/s']],
  ['U', ['s-1', 6.02214076e23 / 60000000, 0, 'incommensurable', 'UCUM table 18: U = umol/min']],
  ['Bd', ['s-1', 1, 0, 'incommensurable', 'UCUM table 22: Bd = /s']],
  ['[diop]', ['m-1', 1, 0, 'incommensurable', 'UCUM table 18: [diop] = /m']],
  ['[mesh_i]', ['m-1', 1 / 0.0254, 0, 'incommensurable', 'UCUM table 21: [mesh_i] = /[in_i]']],
  ['[NTU]', ['1', 1, 0, 'unknown-unit', 'UCUM 2.2 table 21: newly defined code']],
  ['[FNU]', ['1', 1, 0, 'unknown-unit', 'UCUM 2.2 table 21: newly defined code']],
  ['[LPF]', ['1', 100, 0, 'lpf', 'UCUM table 18: [LPF] = 100']],
  ['[degRe]', ['K', 1.25, 273.15, 'reaumur', 'UCUM §43: K = 5/4 * (Re + 218.52)']],
]);
function close(a, b) {
  return Number.isFinite(a) && Number.isFinite(b)
    && Math.abs(a - b) <= Math.max(1e-10, Math.abs(b) * 1e-10);
}
function reviewedDifference(item, output, expected) {
  const policy = policies.get(item.source);
  if (!policy || item.target !== policy[0] || !output.ok
      || !close(output.value, item.value * policy[1] + policy[2])) return null;
  const mode = policy[3];
  const referenceMatches = mode === 'lpf'
    ? expected.status === 'succeeded' && close(expected.toVal, item.value)
    : mode === 'reaumur'
      ? expected.status === 'succeeded' && close(expected.toVal, (item.value + 273.15) * 1.25)
      : expected.status === 'failed' && expected.code === mode;
  return referenceMatches ? policy[4] : null;
}
for (let start = 0; start < cases.length; start += 48) {
  const batch = cases.slice(start, start + 48);
  const actual = moon(['batch', ...batch.map(item => JSON.stringify({ op: 'convert', ...item }))]);
  if (actual.length !== batch.length) throw new Error('Missing batch results');
  batch.forEach((item, index) => {
    const expected = reference.convertUnitTo(item.source, item.value, item.target);
    const output = actual[index];
    const target = expected.toVal;
    const matched = output.ok && expected.status === 'succeeded' && close(output.value, target);
    const reason = matched ? null : reviewedDifference(item, output, expected);
    const classification = matched ? 'matched' : reason ? 'reviewed_standard_difference' : 'unexpected_difference';
    const result = { ...item, expected: target ?? null, actual: output.value ?? null, classification, ...(reason ? { reason } : {}) };
    results.push(result);
    if (reason) differences.push(result);
    if (!matched && !reason) failures.push({ ...result, reference_status: expected.status, reference_code: expected.code, output });
  });
}
const report = {
  reference: '@lhncbc/ucum-lhc@8.0.1',
  command: 'npm ci && npm test',
  relative_tolerance: 1e-10, absolute_tolerance: 1e-10,
  cases: results.length, matched: results.filter(item => item.classification === 'matched').length,
  reviewed_standard_differences: differences.length,
  failures, differences, results,
};
const output = new URL('../validation/differential-results.json', import.meta.url);
mkdirSync(new URL('../validation/', import.meta.url), { recursive: true });
writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ cases: report.cases, matched: report.matched, reviewed_standard_differences: differences.length, unexpected_differences: failures.length, failures }, null, 2));
if (failures.length) process.exitCode = 1;
