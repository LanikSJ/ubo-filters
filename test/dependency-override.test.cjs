const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { createRequire } = require('node:module');
const path = require('node:path');
const { test } = require('node:test');

const repoRoot = path.resolve(__dirname, '..');
const packageJson = JSON.parse(readFileSync(path.join(repoRoot, 'package.json'), 'utf8'));
const lockfile = JSON.parse(readFileSync(path.join(repoRoot, 'package-lock.json'), 'utf8'));
const zodEntries = Object.entries(lockfile.packages).filter(
  ([location]) => location.endsWith('/node_modules/zod') || location === 'node_modules/zod',
);

const globEntries = Object.entries(lockfile.packages).filter(
  ([location]) => location.endsWith('/node_modules/glob') || location === 'node_modules/glob',
);

const jsYamlEntries = Object.entries(lockfile.packages).filter(
  ([location]) => location.endsWith('/node_modules/js-yaml') || location === 'node_modules/js-yaml',
);

const minimatchEntries = Object.entries(lockfile.packages).filter(
  ([location]) => location.endsWith('/node_modules/minimatch') || location === 'node_modules/minimatch',
);

function resolveZodConsumer() {
  const scriptletsRequire = createRequire(require.resolve('@adguard/scriptlets/package.json'));
  const filename = scriptletsRequire.resolve('@adguard/agtree');
  return { filename, consumerRequire: createRequire(filename) };
}

function loadZodConsumer() {
  const { filename, consumerRequire } = resolveZodConsumer();
  assert.equal(
    consumerRequire('zod/package.json').version,
    packageJson.overrides.zod,
    'Run npm ci to install the PR dependencies',
  );
  return consumerRequire(filename);
}

test('Zod is pinned to the PR version', () => {
  assert.equal(packageJson.overrides.zod, '4.6.6');
});

test('Zod lockfile entry matches override and tarball', () => {
  const lockedZod = lockfile.packages['node_modules/zod'];
  assert.ok(lockedZod);
  assert.equal(lockedZod.version, packageJson.overrides.zod);
  assert.equal(lockedZod.resolved, `https://registry.npmjs.org/zod/-/zod-${packageJson.overrides.zod}.tgz`);
});

test('no nested Zod lockfile retains older version', () => {
  assert.ok(zodEntries.length > 0);
  for (const [location, entry] of zodEntries) {
    assert.equal(entry.version, packageJson.overrides.zod);
    assert.equal(
      entry.resolved,
      `https://registry.npmjs.org/zod/-/zod-${entry.version}.tgz`,
      `${location} must resolve the overridden tarball`,
    );
  }
});

test('AGTree consumer resolves overridden Zod', () => {
  const { consumerRequire } = resolveZodConsumer();
  assert.equal(consumerRequire('zod/package.json').version, packageJson.overrides.zod);
});

test('AGTree initializes Zod schemas', () => {
  const { RuleParser } = loadZodConsumer();
  assert.equal(typeof RuleParser.parse, 'function');
  assert.equal(typeof RuleParser.generate, 'function');
});

for (const [name, rule, category] of [
  ['network rule with a negated domain', '||example.com^$domain=example.org|~sub.example.org', 'Network'],
  ['network exception', '@@||example.com^$script', 'Network'],
  ['cosmetic rule with multiple domains', 'example.com,~example.org##.newsletter', 'Cosmetic'],
  ['cosmetic exception', 'example.com#@#.newsletter', 'Cosmetic'],
  ['uBlock scriptlet', 'example.com##+js(aopr, googletag)', 'Cosmetic'],
]) {
  test(`preserves ${name}`, () => {
    const { RuleParser } = loadZodConsumer();
    const parsed = RuleParser.parse(rule);
    assert.equal(parsed.category, category);
    assert.equal(RuleParser.generate(parsed), rule);
  });
}

test('rejects unterminated scriptlet in strict mode', () => {
  const { RuleParser, AdblockSyntaxError } = loadZodConsumer();
  assert.throws(() => RuleParser.parse('example.com##+js(aopr, googletag', { tolerant: false }), AdblockSyntaxError);
});

test('tolerant parsing preserves invalid scriptlet', () => {
  const { RuleParser } = loadZodConsumer();
  const rule = 'example.com##+js(aopr, googletag';
  const parsed = RuleParser.parse(rule, { tolerant: true });
  assert.equal(parsed.category, 'Invalid');
  assert.equal(parsed.error.name, 'AdblockSyntaxError');
  assert.ok(parsed.error.message.length > 0);
  assert.equal(RuleParser.generate(parsed), rule);
});

// Glob override tests (14.0.2) - resolved via AGTree consumer identified as from dead-domains-linter
test('glob is pinned to override version', () => {
  assert.equal(packageJson.overrides.glob, '14.0.2');
});

test('glob lockfile entry matches override', () => {
  const lockedGlob = lockfile.packages['node_modules/glob'];
  assert.ok(lockedGlob);
  assert.equal(lockedGlob.version, packageJson.overrides.glob);
  assert.equal(lockedGlob.resolved, `https://registry.npmjs.org/glob/-/glob-${packageJson.overrides.glob}.tgz`);
});

test('no nested glob lockfile retains older version', () => {
  assert.ok(globEntries.length > 0);
  for (const [location, entry] of globEntries) {
    assert.equal(entry.version, packageJson.overrides.glob);
  }
});

test('AGTree consumer resolves overridden glob', () => {
  const { consumerRequire } = resolveZodConsumer();
  assert.equal(consumerRequire('glob/package.json').version, packageJson.overrides.glob);
});

// js-yaml override tests (4.3.2) - identified as resolved via AGTree consumer
test('js-yaml is pinned to override version', () => {
  assert.equal(packageJson.overrides['js-yaml'], '4.3.2');
});

test('js-yaml lockfile entry matches override', () => {
  const lockedJsYaml = lockfile.packages['node_modules/js-yaml'];
  assert.ok(lockedJsYaml);
  assert.equal(lockedJsYaml.version, packageJson.overrides['js-yaml']);
  assert.equal(
    lockedJsYaml.resolved,
    `https://registry.npmjs.org/js-yaml/-/js-yaml-${packageJson.overrides['js-yaml']}.tgz`,
  );
});

test('no nested js-yaml lockfile retains older version', () => {
  assert.ok(jsYamlEntries.length > 0);
  for (const [location, entry] of jsYamlEntries) {
    assert.equal(entry.version, packageJson.overrides['js-yaml']);
  }
});

test('AGTree consumer resolves overridden js-yaml', () => {
  const { consumerRequire } = resolveZodConsumer();
  assert.equal(consumerRequire('js-yaml/package.json').version, packageJson.overrides['js-yaml']);
});

// minimatch override tests (11.0.1) - identified as resolved from glob consumer
test('minimatch is pinned to override version', () => {
  assert.equal(packageJson.overrides['minimatch'], '11.0.1');
});

test('minimatch lockfile entry matches override', () => {
  const lockedMinimatch = lockfile.packages['node_modules/minimatch'];
  assert.ok(lockedMinimatch);
  assert.equal(lockedMinimatch.version, packageJson.overrides['minimatch']);
  assert.equal(
    lockedMinimatch.resolved,
    `https://registry.npmjs.org/minimatch/-/minimatch-${packageJson.overrides['minimatch']}.tgz`,
  );
});

test('no nested minimatch lockfile retains older version', () => {
  assert.ok(minimatchEntries.length > 0);
  for (const [location, entry] of minimatchEntries) {
    assert.equal(entry.version, packageJson.overrides['minimatch']);
  }
});

test('AGTree consumer resolves overridden minimatch', () => {
  const { consumerRequire } = resolveZodConsumer();
  assert.equal(consumerRequire('minimatch/package.json').version, packageJson.overrides['minimatch']);
});
