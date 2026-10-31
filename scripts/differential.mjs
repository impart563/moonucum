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

const logarithmicCases = [
  ['Np', '1'], ['B', '1'], ['bit_s', '1'], ['B[SPL]', 'Pa'],
  ['B[V]', 'V'], ['B[mV]', 'V'], ['B[uV]', 'V'], ['B[10.nV]', 'V'],
  ['B[W]', 'W'], ['B[kW]', 'W'], ['[pH]', 'mol/L'],
];
for (const [source, target] of logarithmicCases) {
  for (const value of [-10, 0, 1, 7.4, 20]) cases.push({ value, source, target });
  for (const value of [0.1, 1, 100]) cases.push({ value, source: target, target: source });
}
for (const [source, target] of [['dB[W]', 'W'], ['dB[V]', 'V'], ['dB[SPL]', 'Pa'], ['2.B', '1'], ['B/2', '1']]) {
  for (const value of [0, 1, 10, 30]) cases.push({ value, source, target });
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
    && Math.abs(a - b) <= (b === 0 ? 1e-10 : Math.max(Number.MIN_VALUE, Math.abs(b) * 1e-10));
}
function reviewedDifference(item, output, expected) {
  const constants = new Map([
    ['u', ['g', 1.6605390666e-24, 1.6605402e-24]],
    ['eV', ['m2.s-2.g', 1.602176634e-16, 1.60217733e-16]],
    ['[G]', ['m3.s-2.g-1', 6.67430e-14, 6.67259e-14]],
    ['[e]', ['C', 1.602176634e-19, 1.60217733e-19]],
    ['[h]', ['m2.s-1.g', 6.62607015e-31, 6.6260755e-31]],
    ['[k]', ['m2.s-2.g.K-1', 1.380649e-20, 1.380658e-20]],
    ['[m_e]', ['g', 9.1093837139e-28, 9.1093897e-28]],
    ['[m_p]', ['g', 1.67262192595e-24, 1.6726231e-24]],
  ]);
  const constant = constants.get(item.source);
  if (constant && item.target === constant[0] && output.ok && expected.status === 'succeeded'
      && close(output.value, item.value * constant[1]) && close(expected.toVal, item.value * constant[2])) {
    return 'UCUM 2.2 table 5 updated constant; the pinned NLM catalog retains an older value';
  }
  if (output.ok && expected.status === 'failed' && expected.code === 'incommensurable') {
    if (item.source === '[pH]' && item.target === 'mol/L' && close(output.value, 10 ** -item.value)) {
      return 'UCUM §45: concentration in mol/L = 10^(-pH); NLM rejects commensurability';
    }
    if (item.source === 'mol/L' && item.target === '[pH]' && close(output.value, -Math.log10(item.value))) {
      return 'UCUM §45: pH = -log10(concentration in mol/L); NLM rejects commensurability';
    }
  }
  if (item.source === 'B/2' && item.target === '1' && output.ok
      && expected.status === 'failed' && expected.code === 'unknown-unit'
      && close(output.value, 10 ** (item.value / 2))) {
    return 'UCUM §22: dimensionless scalar scaling of a special unit; NLM rejects B/2';
  }
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
  relative_tolerance: 1e-10, absolute_tolerance_at_zero: 1e-10,
  cases: results.length, matched: results.filter(item => item.classification === 'matched').length,
  reviewed_standard_differences: differences.length,
  failures, differences, results,
};
const output = new URL('../validation/differential-results.json', import.meta.url);
mkdirSync(new URL('../validation/', import.meta.url), { recursive: true });
writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ cases: report.cases, matched: report.matched, reviewed_standard_differences: differences.length, unexpected_differences: failures.length, failures }, null, 2));
if (failures.length) process.exitCode = 1;
