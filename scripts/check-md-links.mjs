#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const REPO_ROOT = findRepoRoot();
const CONFIG = loadConfig(REPO_ROOT);
const files = inputFiles();
const anchorCache = new Map();
const diagnostics = [];

for (const file of files) {
  checkMarkdownFile(file);
}

if (diagnostics.length > 0) {
  for (const diagnostic of diagnostics) {
    console.error(diagnostic);
  }
  process.exit(1);
}

console.log(`md-links: checked ${files.length} Markdown files; external network ${CONFIG.externalLinks.network}`);

function findRepoRoot() {
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return process.cwd();
  }
}

function loadConfig(root) {
  const configPath = path.join(root, '.md-link-check.json');
  const defaults = {
    externalLinks: {
      network: 'disabled',
      allowedSchemes: ['http:', 'https:', 'mailto:'],
      allowedHosts: [],
    },
  };

  const config = fs.existsSync(configPath)
    ? JSON.parse(fs.readFileSync(configPath, 'utf8'))
    : defaults;

  config.externalLinks = { ...defaults.externalLinks, ...config.externalLinks };
  if (config.externalLinks.network !== 'disabled') {
    throw new Error('.md-link-check.json must keep externalLinks.network set to "disabled"; live network checks are out of scope');
  }
  return config;
}

function inputFiles() {
  const args = process.argv.slice(2);
  if (args.length > 0) {
    return args.map((input) => ({
      input,
      absolute: path.resolve(input),
      display: path.isAbsolute(input) ? input : normalizePath(input),
    }));
  }

  const tracked = execFileSync('git', ['ls-files', '*.md'], {
    cwd: REPO_ROOT,
    encoding: 'utf8',
  })
    .split('\n')
    .filter(Boolean);

  return tracked.map((input) => ({
    input,
    absolute: path.join(REPO_ROOT, input),
    display: normalizePath(input),
  }));
}

function checkMarkdownFile(file) {
  const content = fs.readFileSync(file.absolute, 'utf8');
  const lines = content.split(/\r?\n/);
  let inFence = false;

  for (let index = 0; index < lines.length; index += 1) {
    const lineNumber = index + 1;
    const line = lines[index];
    if (isFence(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      continue;
    }

    const inlineLinks = findInlineMarkdownLinks(line);
    const linkSpans = [];
    for (const link of inlineLinks) {
      linkSpans.push([link.start, link.end]);
      checkDestination({ file, lineNumber, destination: link.destination });
    }

    for (const bareUrl of findBareUrls(line, linkSpans)) {
      checkDestination({ file, lineNumber, destination: bareUrl.url });
    }
  }
}

function isFence(line) {
  return /^\s{0,3}(`{3,}|~{3,})/.test(line);
}

function findInlineMarkdownLinks(line) {
  const links = [];
  let offset = 0;

  while (offset < line.length) {
    const bang = line[offset] === '!' && line[offset + 1] === '[';
    const labelStart = bang ? offset + 1 : offset;
    if (line[labelStart] !== '[') {
      offset += 1;
      continue;
    }

    const labelEnd = findClosing(line, labelStart, '[', ']');
    if (labelEnd === -1 || line[labelEnd + 1] !== '(') {
      offset += 1;
      continue;
    }

    const destinationStart = labelEnd + 2;
    const destinationEnd = findClosing(line, labelEnd + 1, '(', ')');
    if (destinationEnd === -1) {
      offset += 1;
      continue;
    }

    const destination = parseMarkdownDestination(line.slice(destinationStart, destinationEnd));
    if (destination) {
      links.push({ start: offset, end: destinationEnd + 1, destination });
    }
    offset = destinationEnd + 1;
  }

  return links;
}

function findClosing(line, start, opener, closer) {
  let escaped = false;
  let depth = 0;
  for (let i = start; i < line.length; i += 1) {
    const char = line[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char === '\\') {
      escaped = true;
      continue;
    }
    if (char === opener) {
      depth += 1;
      continue;
    }
    if (char === closer) {
      depth -= 1;
      if (depth === 0) {
        return i;
      }
    }
  }
  return -1;
}

function parseMarkdownDestination(raw) {
  const trimmed = raw.trim();
  if (!trimmed) {
    return '';
  }
  if (trimmed.startsWith('<')) {
    const end = trimmed.indexOf('>');
    return end === -1 ? trimmed.slice(1) : trimmed.slice(1, end);
  }
  const match = trimmed.match(/^\S+/);
  return match ? match[0] : '';
}

function findBareUrls(line, occupiedSpans) {
  const bareUrlPattern = /https?:\/\/[^\s<>)\]]+/g;
  const urls = [];
  for (const match of line.matchAll(bareUrlPattern)) {
    const start = match.index ?? 0;
    const end = start + match[0].length;
    if (occupiedSpans.some(([spanStart, spanEnd]) => start >= spanStart && end <= spanEnd)) {
      continue;
    }
    urls.push({ start, end, url: trimTrailingPunctuation(match[0]) });
  }
  return urls;
}

function trimTrailingPunctuation(url) {
  return url.replace(/[.,;:!?]+$/u, '');
}

function checkDestination({ file, lineNumber, destination }) {
  if (!destination || destination.startsWith('{')) {
    return;
  }

  if (isExternalDestination(destination)) {
    checkExternalDestination({ file, lineNumber, destination });
    return;
  }

  const { target, fragment } = splitLocalDestination(destination);
  const targetPath = target ? resolveLocalTarget(file.absolute, target) : file.absolute;

  if (target && !fs.existsSync(targetPath)) {
    addDiagnostic(file, lineNumber, `target file does not exist: ${target}`);
    return;
  }

  if (fragment && isMarkdownFile(targetPath) && !anchorExists(targetPath, fragment)) {
    const targetLabel = target || path.basename(file.absolute);
    addDiagnostic(file, lineNumber, `anchor "${decodeFragment(fragment)}" not found in ${targetLabel}`);
  }
}

function isExternalDestination(destination) {
  return /^[a-z][a-z0-9+.-]*:/iu.test(destination) || destination.startsWith('//');
}

function checkExternalDestination({ file, lineNumber, destination }) {
  let url;
  try {
    url = destination.startsWith('//') ? new URL(`https:${destination}`) : new URL(destination);
  } catch {
    addDiagnostic(file, lineNumber, `external URL is invalid: ${destination}`);
    return;
  }

  if (!CONFIG.externalLinks.allowedSchemes.includes(url.protocol)) {
    addDiagnostic(file, lineNumber, `external URL scheme "${url.protocol}" is not allowlisted`);
    return;
  }

  if ((url.protocol === 'http:' || url.protocol === 'https:') && !hostAllowed(url.hostname)) {
    addDiagnostic(file, lineNumber, `external URL host "${url.hostname}" is not allowlisted`);
  }
}

function hostAllowed(hostname) {
  return CONFIG.externalLinks.allowedHosts.some((allowedHost) => {
    if (allowedHost.startsWith('*.')) {
      const suffix = allowedHost.slice(1);
      return hostname.endsWith(suffix);
    }
    return hostname === allowedHost;
  });
}

function splitLocalDestination(destination) {
  const hashIndex = destination.indexOf('#');
  const beforeHash = hashIndex === -1 ? destination : destination.slice(0, hashIndex);
  const fragment = hashIndex === -1 ? '' : destination.slice(hashIndex + 1);
  const queryIndex = beforeHash.indexOf('?');
  const target = queryIndex === -1 ? beforeHash : beforeHash.slice(0, queryIndex);
  return { target: decodeLocalPath(target), fragment };
}

function decodeLocalPath(target) {
  try {
    return decodeURI(target);
  } catch {
    return target;
  }
}

function resolveLocalTarget(sourceFile, target) {
  if (path.isAbsolute(target)) {
    return path.join(REPO_ROOT, target);
  }
  return path.resolve(path.dirname(sourceFile), target);
}

function isMarkdownFile(filePath) {
  return /\.(md|markdown)$/iu.test(filePath);
}

function anchorExists(filePath, fragment) {
  const normalizedFragment = decodeFragment(fragment);
  if (!normalizedFragment) {
    return true;
  }
  if (/^L\d+(?:-L\d+)?$/u.test(normalizedFragment)) {
    return lineAnchorExists(filePath, normalizedFragment);
  }
  return anchorsFor(filePath).has(normalizedFragment.toLowerCase());
}

function lineAnchorExists(filePath, fragment) {
  const lineCount = fs.readFileSync(filePath, 'utf8').split(/\r?\n/).length;
  const [start, end] = fragment
    .slice(1)
    .split('-L')
    .map((value) => Number.parseInt(value, 10));
  return start >= 1 && start <= lineCount && (!end || (end >= start && end <= lineCount));
}

function anchorsFor(filePath) {
  if (anchorCache.has(filePath)) {
    return anchorCache.get(filePath);
  }

  const anchors = new Set();
  const slugCounts = new Map();
  const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/);
  let inFence = false;

  for (const line of lines) {
    if (isFence(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      continue;
    }

    for (const explicitId of explicitAnchorIds(line)) {
      anchors.add(explicitId.toLowerCase());
    }

    const heading = line.match(/^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$/u);
    if (!heading) {
      continue;
    }
    const baseSlug = slugifyHeading(heading[1]);
    if (!baseSlug) {
      continue;
    }
    const priorCount = slugCounts.get(baseSlug) ?? 0;
    slugCounts.set(baseSlug, priorCount + 1);
    anchors.add(priorCount === 0 ? baseSlug : `${baseSlug}-${priorCount}`);
  }

  anchorCache.set(filePath, anchors);
  return anchors;
}

function explicitAnchorIds(line) {
  const ids = [];
  const idPattern = /\b(?:id|name)=["']([^"']+)["']/giu;
  for (const match of line.matchAll(idPattern)) {
    ids.push(match[1]);
  }
  return ids;
}

function slugifyHeading(text) {
  return text
    .replace(/`([^`]+)`/gu, '$1')
    .replace(/!??\[([^\]]*)\]\([^)]*\)/gu, '$1')
    .replace(/<[^>]+>/gu, '')
    .trim()
    .toLowerCase()
    .replace(/[^\p{Letter}\p{Number}\s_-]/gu, '')
    .replace(/[\s_]+/gu, '-')
    .replace(/-+/gu, '-')
    .replace(/^-|-$/gu, '');
}

function decodeFragment(fragment) {
  try {
    return decodeURIComponent(fragment);
  } catch {
    return fragment;
  }
}

function addDiagnostic(file, lineNumber, message) {
  diagnostics.push(`${file.display}:${lineNumber}: ${message}`);
}

function normalizePath(input) {
  return input.split(path.sep).join('/');
}
