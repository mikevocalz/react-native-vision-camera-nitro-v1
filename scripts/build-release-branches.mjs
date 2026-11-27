#!/usr/bin/env node
// Stages each Nitro V1 VisionCamera package as a self-contained package and,
// with --push, commits it to its own `release/<package name>` branch so apps
// can install the Nitro V1 builds straight from GitHub:
//
//   "react-native-vision-camera": "github:mikevocalz/react-native-vision-camera-nitro-v1#release/react-native-vision-camera"
//   "react-native-vision-camera-resizer": "github:mikevocalz/react-native-vision-camera-nitro-v1#release/react-native-vision-camera-resizer"
//   "react-native-vision-camera-worklets": "github:mikevocalz/react-native-vision-camera-nitro-v1#release/react-native-vision-camera-worklets"
//
// Usage:
//   node scripts/build-release-branches.mjs [--out <dir>] [--push] [--remote origin] [--skip-build]
//
// What the staged package gets:
//   - a fresh build (`bun run build`: tsc into lib/ for every package) unless --skip-build
//   - the exact `npm pack` contents of each package, so its `files` list
//     decides what ships (lib/, src/, nitrogen/generated, apple/, cpp/,
//     android/, Package.swift, podspec, nitro.json)
//   - scripts, devDependencies and release-it config removed; pnpm runs
//     `prepare` for git dependencies, and there is nothing left to run
//   - `gitHead` and `nitroV1.sourceCommit` set to the source commit
//
// Adapted from mikevocalz/react-native-nitro-image-nitro-v1 scripts/build-release-branches.mjs.

import { execFileSync } from 'node:child_process'
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(fileURLToPath(new URL('..', import.meta.url)))
const REPO_SLUG = 'mikevocalz/react-native-vision-camera-nitro-v1'
const BRANCH_PREFIX = 'release/'
// Built and staged in dependency order: resizer and worklets type-check against the core's lib/.
const PACKAGES = [
  'packages/react-native-vision-camera',
  'packages/react-native-vision-camera-resizer',
  'packages/react-native-vision-camera-worklets',
]
const NITRO_PACKAGES = ['nitro-core', 'nitrogen', 'react-native-nitro-modules']

const args = process.argv.slice(2)
const flag = (name) => args.includes(name)
const option = (name, fallback) => {
  const i = args.indexOf(name)
  return i === -1 ? fallback : args[i + 1]
}

const push = flag('--push')
const skipBuild = flag('--skip-build')
const remote = option('--remote', 'origin')
const outDir = resolve(
  option('--out', mkdtempSync(join(tmpdir(), 'vision-camera-release-'))),
)

function run(cmd, cmdArgs, opts = {}) {
  // With inherited stdout, execFileSync returns null.
  const out = execFileSync(cmd, cmdArgs, {
    cwd: ROOT,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'inherit'],
    ...opts,
  })
  return (out ?? '').trim()
}
const git = (gitArgs, opts) => run('git', gitArgs, opts)
const readJson = (file) => JSON.parse(readFileSync(file, 'utf8'))
const writeJson = (file, value) =>
  writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`)

const sourceSha = git(['rev-parse', 'HEAD'])
const shortSha = sourceSha.slice(0, 7)

// A release commit says "from <sha>", so with --push the tracked files must be
// exactly that commit. The build regenerates nitrogen/generated, so check
// again after building: a diff there means the committed bindings are stale.
const assertClean = (when) => {
  if (push && git(['status', '--porcelain', '--untracked-files=no'])) {
    throw new Error(
      `Refusing to push release branches: tracked files differ from HEAD ${when}.\n` +
        git(['status', '--short', '--untracked-files=no']),
    )
  }
}
assertClean('before the build')

// ---------------------------------------------------------------------------
// 1. Build and check the Nitro pins.

if (!skipBuild) {
  for (const dir of PACKAGES) {
    run('bun', ['run', 'build'], {
      cwd: join(ROOT, dir),
      stdio: ['ignore', 'inherit', 'inherit'],
    })
  }
  assertClean('after the build (re-run nitrogen and commit the result)')
}

function assertNitroPins(manifest) {
  const pins = NITRO_PACKAGES.map((dep) => manifest.devDependencies?.[dep])
  if (pins.some((v) => !v) || new Set(pins).size !== 1) {
    throw new Error(
      `${manifest.name}: ${NITRO_PACKAGES.join(', ')} must be pinned to one identical version, got ${pins.join(', ')}`,
    )
  }
  return pins[0]
}

// ---------------------------------------------------------------------------
// 2. Pack and stage.

function packInto(dir, stageDir) {
  // Pack a copy with lifecycle scripts removed, so no npm version runs
  // `prepare` (npm 10 does so even with --ignore-scripts).
  const copy = mkdtempSync(join(tmpdir(), 'vision-camera-src-'))
  const skip = new Set(['node_modules', '.gradle', '.cxx', 'build', '.build'])
  cpSync(dir, copy, {
    recursive: true,
    filter: (src) => !skip.has(src.split('/').pop()),
  })
  const manifestFile = join(copy, 'package.json')
  const manifest = readJson(manifestFile)
  delete manifest.scripts
  writeJson(manifestFile, manifest)

  const scratch = mkdtempSync(join(tmpdir(), 'vision-camera-pack-'))
  const out = run(
    'npm',
    ['pack', '--ignore-scripts', '--json', '--pack-destination', scratch],
    { cwd: copy },
  )
  // npm 10 prints an array of reports; npm 11+ may print an object keyed by
  // package name.
  const report = JSON.parse(out)
  const [{ filename }] = Array.isArray(report) ? report : Object.values(report)
  run('tar', ['xzf', join(scratch, filename), '-C', scratch])
  rmSync(stageDir, { recursive: true, force: true })
  cpSync(join(scratch, 'package'), stageDir, { recursive: true })
  rmSync(scratch, { recursive: true, force: true })
  rmSync(copy, { recursive: true, force: true })
}

function rewriteManifest(stageDir, nitroVersion) {
  const file = join(stageDir, 'package.json')
  const m = readJson(file)
  delete m.scripts
  delete m.devDependencies
  delete m['release-it']
  delete m.publishConfig
  m.gitHead = sourceSha
  m.nitroV1 = { sourceCommit: sourceSha, nitroVersion }
  writeJson(file, m)
  return m
}

function assertContents(stageDir, m, cxxLibName) {
  // main/module/react-native are extensionless (`lib/index`); types is not.
  const resolved = [m.main, m.module, m['react-native'], m.types]
    .filter(Boolean)
    .map((entry) => (/\.(c|m)?(j|t)s$/.test(entry) ? entry : `${entry}.js`))
  const nativeFiles = [
    'nitro.json',
    'Package.swift',
    'android/build.gradle',
    'android/CMakeLists.txt',
    'nitrogen/generated/hybrid-classes.json',
    `nitrogen/generated/android/${cxxLibName}+autolinking.cmake`,
    `nitrogen/generated/android/${cxxLibName}+autolinking.gradle`,
  ]
  const missing = [...resolved, ...nativeFiles].filter(
    (e) => !existsSync(join(stageDir, e)),
  )
  if (!readdirSync(stageDir).some((f) => f.endsWith('.podspec'))) {
    missing.push('*.podspec')
  }
  // The specs `export * from '#nitro/X'`; every mapped .cjs must ship.
  const jsDir = join(stageDir, 'nitrogen/generated/shared/javascript')
  if (
    !existsSync(jsDir) ||
    !readdirSync(jsDir).some((f) => f.endsWith('.cjs'))
  ) {
    missing.push('nitrogen/generated/shared/javascript/*.cjs')
  }
  const sources = ['apple', 'cpp'].filter((d) => existsSync(join(stageDir, d)))
  if (!sources.length) missing.push('apple/ or cpp/')
  if (missing.length) {
    throw new Error(
      `${m.name}: missing from the packed output: ${missing.join(', ')}`,
    )
  }
}

// Each branch is named after the full package name, e.g. release/react-native-vision-camera.
const shortName = (pkgName) => pkgName
mkdirSync(outDir, { recursive: true })
const staged = []

for (const dir of PACKAGES) {
  const pkgDir = join(ROOT, dir)
  const source = readJson(join(pkgDir, 'package.json'))
  const nitroVersion = assertNitroPins(source)
  const stageDir = join(outDir, shortName(source.name))
  packInto(pkgDir, stageDir)
  const m = rewriteManifest(stageDir, nitroVersion)
  const { android } = readJson(join(pkgDir, 'nitro.json'))
  assertContents(stageDir, m, android.cxxLibName)
  staged.push({ name: m.name, version: m.version, stageDir })
}

// ---------------------------------------------------------------------------
// 3. Commit each staged directory on top of its release branch.
//
// History stays linear: every release commit's parent is the previous tip of
// the same branch, so a consumer can pin any commit SHA and it stays
// reachable. A package whose contents did not change gets no new commit.

const remoteTips = new Map()
try {
  const listing = git(['ls-remote', '--heads', remote, `${BRANCH_PREFIX}*`])
  for (const line of listing.split('\n').filter(Boolean)) {
    const [sha, ref] = line.split('\t')
    if (!ref.startsWith(`refs/heads/${BRANCH_PREFIX}`)) continue
    remoteTips.set(ref.replace('refs/heads/', ''), sha)
  }
  if (remoteTips.size) {
    git([
      'fetch',
      '--quiet',
      '--no-tags',
      remote,
      ...[...remoteTips.keys()].map((b) => `refs/heads/${b}`),
    ])
  }
} catch (error) {
  if (push) throw error
  console.warn(
    `could not read ${remote}; comparing against empty branches (${error.message})`,
  )
  remoteTips.clear()
}

const results = []
for (const { name, version, stageDir } of staged) {
  const branch = BRANCH_PREFIX + shortName(name)
  const index = join(mkdtempSync(join(tmpdir(), 'vision-camera-index-')), 'index')
  const env = { ...process.env, GIT_INDEX_FILE: index }
  git(['--work-tree', stageDir, 'add', '--all', '--force', '.'], { env })
  const tree = git(['write-tree'], { env })

  const parent = remoteTips.get(branch) ?? ''
  const parentTree = parent ? git(['rev-parse', `${parent}^{tree}`]) : ''
  if (tree === parentTree) {
    results.push({ branch, name, version, status: 'unchanged', commit: parent })
    continue
  }

  const message = `release ${name}@${version} from ${sourceSha}`
  if (!push) {
    results.push({ branch, name, version, status: 'would commit', tree })
    continue
  }
  const commit = git([
    'commit-tree',
    tree,
    ...(parent ? ['-p', parent] : []),
    '-m',
    message,
  ])
  // Plain push: fast-forward only. If someone rewrote the branch, fail loudly.
  git(['push', '--quiet', remote, `${commit}:refs/heads/${branch}`])
  const tag = `${name}@${version}+${shortSha}`
  if (git(['ls-remote', '--tags', remote, `refs/tags/${tag}`])) {
    console.warn(`tag ${tag} already exists on ${remote}; leaving it`)
    results.push({ branch, name, version, status: 'pushed', commit })
    continue
  }
  // Annotated tag built with mktag and pushed directly, so no local tag ref
  // is created.
  const tagObject = git(['mktag'], {
    input:
      `object ${commit}\ntype commit\ntag ${tag}\n` +
      `tagger ${git(['var', 'GIT_COMMITTER_IDENT'])}\n\n${message}\n`,
    stdio: ['pipe', 'pipe', 'inherit'],
  })
  git(['push', '--quiet', remote, `${tagObject}:refs/tags/${tag}`])
  results.push({ branch, name, version, status: 'pushed', commit, tag })
}

console.log(`source ${sourceSha}`)
console.log(`staged in ${outDir}`)
for (const r of results) {
  console.log(
    [
      r.branch.padEnd(36),
      `${r.name}@${r.version}`.padEnd(40),
      r.status,
      r.commit ?? '',
      r.tag ?? '',
    ]
      .join(' ')
      .trimEnd(),
  )
  console.log(`  install: "${r.name}": "github:${REPO_SLUG}#${r.branch}"`)
}
console.log(
  `\n${staged.length} package(s) staged${push ? '' : ' (dry run, nothing pushed)'}`,
)
