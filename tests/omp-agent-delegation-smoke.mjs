// Focus: native OMP preset/project selection, nested completion and handoff,
// allowlist refusal and the unchanged depth-two cap. Only fixture task/read
// calls are generated; this tests routing, not a security sandbox or model judgment.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';

const name = 'omp-agent-delegation-smoke';
const omp = Bun.which('omp');
if (!omp) {
  assert.notEqual(process.env.OMP_REQUIRE_DELEGATION, '1', 'required installed OMP client (omp) not on PATH');
  console.log(`${name}: unavailable (omp not on PATH); nested delegation not exercised`);
  process.exit(0);
}

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), `${name}.`)));
const home = path.join(root, 'home');
const foreign = path.join(root, 'foreign');
const project = path.join(root, 'project');
const candidate = path.join(root, 'candidate');
const agentDir = path.join(home, '.omp', 'agent');
const children = new Set();
const fixtureErrors = [];
const auxiliaryRequests = { routingHints: 0, taskLabels: 0 };
const blockedDiscovery = new Set();
// Native 18.12.6 startup discovery; the proxy denies these destinations, never forwards them.
const discoveryDestinations = new Set([
  'catalog.stencil.so:443', 'coding-intl.dashscope.aliyuncs.com:443', 'hyper.charm.land:443',
  'api.commandcode.ai:443', 'api.kilo.ai:443', 'api.venice.ai:443', 'zenmux.ai:443',
]);
let active;
let server;
let env;

function inside(file) {
  assert.ok(path.isAbsolute(file), `not an absolute fixture path: ${file}`);
  // RPC can report a future session file; its parent must already resolve inside the fixture.
  const canonical = fs.lstatSync(file, { throwIfNoEntry: false })
    ? fs.realpathSync(file)
    : path.join(fs.realpathSync(path.dirname(file)), path.basename(file));
  const relative = path.relative(root, canonical);
  assert.ok(relative && relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative),
    `native artifact escaped disposable root: ${file}`);
}

function metadata(text) {
  const match = text.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/);
  assert.ok(match, 'agent has no YAML frontmatter');
  return Bun.YAML.parse(match[1]);
}

function client(args, cwd) {
  const child = spawn(omp, args, { cwd, env, stdio: ['pipe', 'pipe', 'pipe'] });
  children.add(child);
  child.once('close', () => children.delete(child));
  return child;
}

async function command(args, cwd = foreign) {
  const child = client(args, cwd);
  let stdout = '';
  let stderr = '';
  child.stdout.on('data', (chunk) => { stdout += chunk; });
  child.stderr.on('data', (chunk) => { stderr += chunk; });
  const timer = setTimeout(() => child.kill('SIGKILL'), 30_000);
  try {
    const status = await new Promise((resolve, reject) => {
      child.once('error', reject);
      child.once('close', (code, signal) => resolve({ code, signal }));
      child.stdin.end();
    });
    assert.equal(status.code, 0, `omp ${args.join(' ')}: ${status.signal ?? status.code}\n${stderr}`);
    return stdout;
  } finally {
    clearTimeout(timer);
    if (child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
  }
}

function text(content) {
  if (typeof content === 'string') return content;
  return (content ?? []).filter((part) => part.type === 'text').map((part) => part.text).join('\n');
}

function toolText(messages, id) {
  return messages.filter((message) => message.role === 'tool' && message.tool_call_id === id)
    .map((message) => text(message.content)).join('\n');
}

function nonce(content) {
  return content.match(/DELEGATION_NONCE_[a-f0-9]{32}/)?.[0];
}

function tool(name, id, args) {
  assert.ok(name === 'task' || name === 'read', `unsafe fixture tool: ${name}`);
  return { tool: { index: 0, id, type: 'function', function: { name, arguments: JSON.stringify(args) } } };
}

function assignment(stage, extra = '') {
  return `SMOKE_STAGE=${stage}\nDisposable native delegation fixture only. ${extra}`;
}

function answer(body) {
  assert.equal(body.model, 'fixture', 'native request selected a non-fixture model');
  assert.equal(body.stream, true, 'fixture expects the public streaming chat-completions protocol');
  assert.ok(Array.isArray(body.messages), 'provider request has no messages');
  const messages = body.messages;
  const user = messages.filter((message) => message.role === 'user').map((message) => text(message.content)).join('\n');
  const system = messages.filter((message) => message.role === 'system' || message.role === 'developer')
    .map((message) => text(message.content)).join('\n');
  // Native routing-hint compression and UI labels are side requests, not agent turns.
  if (!body.tools?.length) {
    if (messages.length === 1 && messages[0].role === 'user'
      && user.startsWith('Compress into one routing hint of at most 12 words:')
      && /\n\nSkill: [^\n]+\nDescription: .+/.test(user)) {
      auxiliaryRequests.routingHints++;
      return { text: 'Use the named skill when explicitly requested' };
    }
    if (messages.length === 2 && messages[0].role === 'system' && messages[1].role === 'user'
      && system.startsWith('# Task\nLabel the delegated work in the next user message:')) {
      auxiliaryRequests.taskLabels++;
      return { text: '<title>Exercise native delegation fixture</title>' };
    }
    assert.fail(`unknown tool-less native request: roles=${messages.map((message) => message.role).join(',')}; ${system.slice(0, 100) || user.slice(0, 100)}`);
  }
  assert.ok(active, 'unexpected agent request outside a fixture session');
  const stage = [...user.matchAll(/SMOKE_STAGE=(root|workflow|helper|forbidden|depth-three)\b/g)].at(-1)?.[1];
  assert.ok(stage, 'native request lost the fixture assignment');
  active.requests.push(stage);
  if (stage === 'forbidden' || stage === 'depth-three') {
    assert.fail(`native started a forbidden ${stage} session`);
  }
  if (stage === 'root') {
    const delivered = toolText(messages, 'call_route');
    if (!delivered) {
      return tool('task', 'call_route', {
        agent: active.route,
        task: assignment('workflow', `Use only the supplied absolute fixture paths under ${root}.`),
        solutionSpace: 'One fixed native delegation fixture; no implementation or provider operations.',
      });
    }
    const received = nonce(delivered);
    return { text: received && delivered.includes(`WORKFLOW_RESULT:${received}`)
      ? `ROOT_RESULT:${received}` : 'ROOT_NATIVE_FAILURE' };
  }
  if (stage === 'workflow') {
    const delivered = toolText(messages, 'call_default');
    if (!delivered) {
      // Intentionally omit agent: execution, not a schema default, must select task/scout.
      return tool('task', 'call_default', {
        task: assignment('helper', `Read only this absolute fixture file: ${active.input}`),
        solutionSpace: 'Read one fixture value and return it; no writes or live-system authority.',
      });
    }
    const received = nonce(delivered);
    // Let a pre-change declaration settle normally, then fail on its native tool result below.
    if (!received || !delivered.includes(`HELPER_RESULT:${received}`)) return { text: 'WORKFLOW_NATIVE_FAILURE' };
    if (active.route === 'change-builder' && !toolText(messages, 'call_forbidden')) {
      return tool('task', 'call_forbidden', {
        agent: 'change-reviewer-final',
        task: assignment('forbidden'),
        solutionSpace: 'Forbidden-route refusal probe; the reviewer must never start.',
      });
    }
    return { text: `WORKFLOW_RESULT:${received}` };
  }
  const read = toolText(messages, 'call_read');
  if (!read) return tool('read', 'call_read', { path: active.input });
  const received = nonce(read);
  assert.ok(received, 'native read did not deliver the fixture value');
  if (active.route === 'change-builder' && !toolText(messages, 'call_depth')) {
    // Even an unadvertised tool call must be refused: the bundled task policy is wildcard.
    return tool('task', 'call_depth', {
      agent: 'scout',
      task: assignment('depth-three'),
      solutionSpace: 'Depth-cap refusal probe; a third child level must never start.',
    });
  }
  return { text: `HELPER_RESULT:${received}` };
}

function stream(reply) {
  const delta = reply.tool ? { role: 'assistant', tool_calls: [reply.tool] } : { role: 'assistant', content: reply.text };
  const chunk = (delta, finish_reason) => `data: ${JSON.stringify({
    id: 'delegation-smoke', object: 'chat.completion.chunk', created: 1, model: 'fixture',
    choices: [{ index: 0, delta, finish_reason }],
  })}\n\n`;
  return new Response(chunk(delta, null) + chunk({}, reply.tool ? 'tool_calls' : 'stop') + 'data: [DONE]\n\n', {
    headers: { 'Content-Type': 'text/event-stream' },
  });
}

async function exercise(selection, route, cwd) {
  const artifacts = path.join(root, 'artifacts', `${selection}-${route}`);
  fs.mkdirSync(artifacts, { recursive: true });
  const input = path.join(artifacts, 'input.txt');
  const value = `DELEGATION_NONCE_${randomBytes(16).toString('hex')}`;
  fs.writeFileSync(input, `${value}\n`);
  active = { selection, route, input, requests: [] };
  const child = client([
    '--mode', 'rpc', '--model', 'delegation-smoke/fixture', '--session-dir', artifacts,
    '--no-title', '--no-lsp', '--no-pty', '--no-extensions', '--no-rules', '--tools', 'task,read',
    '--max-time', '45s',
  ], cwd);
  const frames = [];
  const waiting = new Set();
  let failure;
  let stderr = '';
  let sequence = 0;
  function fail(error) {
    failure ??= error;
    for (const waiter of waiting) waiter.reject(failure);
    waiting.clear();
  }
  const closed = new Promise((resolve) => child.once('close', resolve));
  child.once('error', fail);
  child.once('close', (code, signal) => fail(new Error(`native RPC closed (${signal ?? code})\n${stderr}`)));
  child.stderr.on('data', (chunk) => { stderr += chunk; });
  const lines = createInterface({ input: child.stdout });
  lines.on('line', (line) => {
    try {
      const frame = JSON.parse(line);
      frames.push(frame);
      for (const waiter of waiting) {
        if (waiter.predicate(frame)) {
          waiting.delete(waiter);
          waiter.resolve(frame);
        }
      }
    } catch (error) { fail(error); }
  });
  const timer = setTimeout(() => {
    fail(new Error(`${selection}/${route}: native RPC timed out\n${stderr}`));
    child.kill('SIGKILL');
  }, 60_000);
  function until(predicate) {
    const found = frames.find(predicate);
    if (found) return Promise.resolve(found);
    if (failure) return Promise.reject(failure);
    return new Promise((resolve, reject) => waiting.add({ predicate, resolve, reject }));
  }
  async function rpc(type, fields = {}) {
    const id = `request-${++sequence}`;
    child.stdin.write(`${JSON.stringify({ id, type, ...fields })}\n`);
    const response = await until((frame) => frame.type === 'response' && frame.id === id);
    assert.equal(response.success, true, `${type}: ${response.error}`);
    return { id, data: response.data };
  }
  try {
    const { data: state } = await rpc('get_state');
    assert.equal(state.messageCount, 0, 'fixture started with inherited conversation state');
    assert.equal(state.model.provider, 'delegation-smoke');
    assert.equal(state.model.baseUrl, `${server.url.origin}/v1`);
    inside(state.sessionFile);
    await rpc('set_subagent_subscription', { level: 'events' });
    const prompt = await rpc('prompt', { message: assignment('root') });
    const done = await until((frame) => frame.type === 'prompt_result' && frame.id === prompt.id);
    assert.equal(done.status, 'completed', `${selection}/${route}: ${JSON.stringify(done.error)}\n${fixtureErrors.join('\n')}\n${stderr}`);
    await until((frame) => frame.type === 'session_settled');
    assert.deepEqual(fixtureErrors, [], 'loopback fixture rejected an unexpected request');

    const events = frames.flatMap((frame) => frame.type === 'subagent_event' ? [frame.payload.event] : [frame]);
    function result(id) {
      const end = events.find((event) => event.type === 'tool_execution_end' && event.toolCallId === id);
      if (end) return { ...end.result, isError: end.isError ?? end.result.isError };
      const message = events.find((event) => event.type === 'message_end'
        && event.message.role === 'toolResult' && event.message.toolCallId === id)?.message;
      assert.ok(message, `${selection}/${route}: no native tool result for ${id}`);
      return message;
    }
    const defaultResult = result('call_default');
    assert.notEqual(defaultResult.isError, true,
      `${selection}/${route}: depth-one default helper refused: ${text(defaultResult.content)}`);
    const helper = route === 'change-builder' ? 'task' : 'scout';
    for (const [id, agent, output] of [
      ['call_default', helper, `HELPER_RESULT:${value}`],
      ['call_route', route, `WORKFLOW_RESULT:${value}`],
    ]) {
      const native = result(id);
      assert.notEqual(native.isError, true, `${id}: ${text(native.content)}`);
      assert.equal(native.details?.results?.length, 1, `${id}: no single native completion`);
      const completed = native.details.results[0];
      assert.equal(completed.agent, agent, `${id}: incorrect effective default/route`);
      assert.equal(completed.exitCode, 0, `${id}: child did not complete`);
      assert.ok(!completed.error && !completed.aborted, `${id}: child was failed or aborted`);
      assert.ok(completed.requests > 0, `${id}: no native child model turn`);
      assert.ok(completed.output.includes(output), `${id}: native completion lost the read-derived result`);
    }
    assert.ok(text(result('call_read').content).includes(value), 'no native fixture read execution');
    assert.notEqual(result('call_read').isError, true);
    if (route === 'change-builder') {
      const denied = result('call_forbidden');
      assert.equal(denied.isError, true, 'builder directly launched the mandatory reviewer');
      assert.deepEqual(denied.details?.results, [], 'forbidden reviewer reached execution');
      assert.equal(result('call_depth').isError, true, 'depth-two wildcard task spawned again');
    }
    const lifecycle = frames.filter((frame) => frame.type === 'subagent_lifecycle').map((frame) => frame.payload);
    const starts = lifecycle.filter((entry) => entry.status === 'started');
    assert.deepEqual(starts.map((entry) => [entry.agent, entry.parentToolCallId]),
      [[route, 'call_route'], [helper, 'call_default']], 'unexpected native session, nesting or forbidden spawn');
    for (const start of starts) {
      assert.ok(lifecycle.some((entry) => entry.id === start.id && entry.status === 'completed'),
        `no native completion event for ${start.agent}`);
      assert.equal(start.agentSource, start.agent === route
        ? selection === 'project-override' ? 'project' : 'user' : 'bundled');
      inside(start.sessionFile);
      const { data: transcript } = await rpc('get_subagent_messages', { sessionFile: start.sessionFile });
      const init = transcript.entries.findLast((entry) => entry.type === 'session_init');
      assert.equal(init?.agent, start.agent, 'native transcript has no matching session initialization');
      if (start.agent === route) {
        const prompt = Array.isArray(init.systemPrompt) ? init.systemPrompt.join('\n') : init.systemPrompt;
        assert.ok(prompt.includes(`OMP_DELEGATION_SMOKE_SOURCE=${selection}:${route}`),
          `${selection}: native session initialized from the wrong ${route} definition`);
      }
      if (start.agent === 'task') assert.equal(init.spawns, '', 'depth-two task retained spawning permission');
    }
    const rootFinal = frames.filter((frame) => frame.type === 'message_end' && frame.message.role === 'assistant')
      .some((frame) => text(frame.message.content).includes(`ROOT_RESULT:${value}`));
    assert.ok(rootFinal, 'root never received the completed workflow result');
    assert.ok(active.requests.includes('helper'), 'no helper reached the installed client provider');
    console.log(JSON.stringify({ proof: 'native-nested-delegation', selection, route, defaultHelper: helper,
      completed: starts.map((entry) => entry.agent), readResultDeliveredToRoot: true,
      ...(route === 'change-builder' ? { directReviewerRefused: true, depthTwoSpawnRefused: true } : {}) }));
  } finally {
    clearTimeout(timer);
    lines.close();
    if (child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
    await closed;
    active = undefined;
  }
}

try {
  for (const directory of [agentDir, foreign, project, path.join(root, 'tmp')]) fs.mkdirSync(directory, { recursive: true });
  server = Bun.serve({
    hostname: '127.0.0.1', port: 0,
    async fetch(request) {
      try {
        if (request.method === 'CONNECT') {
          assert.ok(discoveryDestinations.has(request.url), `unknown proxy destination blocked: ${request.url}`);
          if (!blockedDiscovery.has(request.url)) {
            console.log(JSON.stringify({ proof: 'blocked-discovery-egress', destination: request.url, status: 403 }));
          }
          blockedDiscovery.add(request.url);
          return new Response('Native fixture denies discovery egress', { status: 403 });
        }
        // Unsolicited local GETs receive no provider data and count as no execution evidence.
        if (request.method === 'GET'
          && (request.url === `${server.url.origin}/` || request.url === `http://localhost:${server.port}/`)) {
          return new Response(null, { status: 404 });
        }
        assert.equal(new URL(request.url).origin, server.url.origin, 'external provider/discovery request blocked');
        assert.equal(new URL(request.url).pathname, '/v1/chat/completions', 'unexpected fixture endpoint');
        assert.equal(request.method, 'POST');
        assert.equal(request.headers.get('authorization'), 'Bearer delegation-smoke-not-a-secret');
        return stream(answer(await request.json()));
      } catch (error) {
        fixtureErrors.push(error.message);
        return Response.json({ error: { message: error.message, type: 'fixture_error' } }, { status: 400 });
      }
    },
  });
  // No ambient credentials, profile, config, extension or real checkout enters the client.
  // The model allowlist and disabled fallback prevent external-provider selection;
  // the loopback proxy additionally rejects ambient public discovery requests.
  env = {
    PATH: process.env.PATH ?? '', HOME: home, TMPDIR: path.join(root, 'tmp'), OMP_SKIP_SETUP: '1',
    XDG_CONFIG_HOME: path.join(home, '.config'), XDG_CACHE_HOME: path.join(home, '.cache'),
    XDG_DATA_HOME: path.join(home, '.local', 'share'), XDG_STATE_HOME: path.join(home, '.local', 'state'),
    PI_PROXY: server.url.origin, PI_PY: '0', PI_JS: '0', PI_AUTO_QA: '0', OTEL_SDK_DISABLED: 'true',
    AWS_EC2_METADATA_DISABLED: 'true', GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null',
  };
  fs.writeFileSync(path.join(agentDir, 'models.yml'), JSON.stringify({ providers: {
    'delegation-smoke': {
      baseUrl: `${server.url.origin}/v1`, apiKey: 'delegation-smoke-not-a-secret', api: 'openai-completions',
      models: [{ id: 'fixture', reasoning: false, supportsTools: true, contextWindow: 1_000_000, maxTokens: 2048,
        compat: { supportsDeveloperRole: false, supportsUsageInStreaming: false, maxTokensField: 'max_tokens' } }],
    },
  } }));
  fs.writeFileSync(path.join(agentDir, 'config.yml'), JSON.stringify({
    enabledModels: ['delegation-smoke/fixture'],
    modelRoles: Object.fromEntries(['default', 'task', 'smol', 'slow', 'plan'].map((role) => [role, 'delegation-smoke/fixture'])),
    retry: { enabled: false, maxRetries: 0, modelFallback: false },
    async: { enabled: false }, task: { batch: false, structured: false, speculativeLaunch: false },
    tools: { xdev: false }, telemetry: { otlpExportEnabled: false },
  }));
  const version = (await command(['--version'])).trim();
  const depth = JSON.parse(await command(['config', 'get', 'task.maxRecursionDepth', '--json']));
  assert.equal(depth.value, 2, 'native default recursion depth changed; do not override it in this smoke');
  // Unpack outside discovery roots to inspect the actual installed wildcard definition, never override it.
  const bundled = path.join(root, 'bundled-reference');
  await command(['agents', 'unpack', '--dir', bundled, '--json']);
  assert.equal(metadata(fs.readFileSync(path.join(bundled, 'task.md'), 'utf8')).spawns, '*');
  fs.cpSync(repo, candidate, {
    recursive: true,
    filter(source) {
      const parts = path.relative(repo, source).split(path.sep);
      return !parts.some((part) => ['.git', 'node_modules', '.omp', '.claude'].includes(part) || part.startsWith('.env'))
        && !fs.lstatSync(source).isSymbolicLink();
    },
  });
  for (const route of ['change-builder', 'change-reviewer-final']) {
    const file = path.join(candidate, 'agents', `${route}.md`);
    fs.appendFileSync(file, `\nOMP_DELEGATION_SMOKE_SOURCE=installed-preset:${route}\n`);
    const directory = path.join(project, '.omp', 'agents');
    fs.mkdirSync(directory, { recursive: true });
    fs.writeFileSync(path.join(directory, `${route}.md`),
      fs.readFileSync(path.join(repo, '.omp', 'agents', `${route}.md`), 'utf8')
      + `\nOMP_DELEGATION_SMOKE_SOURCE=project-override:${route}\n`);
  }
  await command(['plugin', 'marketplace', 'add', candidate]);
  await command(['plugin', 'install', 'skills@skills']);
  const plugins = JSON.parse(await command(['plugin', 'list', '--json']));
  const installs = plugins.marketplace.filter((plugin) => plugin.id === 'skills@skills')
    .flatMap((plugin) => plugin.entries.map((entry) => entry.installPath));
  assert.equal(installs.length, 1, 'native marketplace did not install one candidate');
  inside(installs[0]);
  console.log(`${name}: client ${version} at ${omp}; disposable native marketplace; recursion default ${depth.value}`);
  for (const [selection, cwd] of [['installed-preset', foreign], ['project-override', project]]) {
    for (const route of ['change-builder', 'change-reviewer-final']) await exercise(selection, route, cwd);
  }
  assert.deepEqual(fixtureErrors, [], 'loopback fixture rejected an unexpected background request');
  console.log(JSON.stringify({ proof: 'fixture-boundaries', auxiliaryRequests, blockedDiscovery: [...blockedDiscovery].sort() }));
  console.log(`${name}: PASS (native helper completion/read-derived handoff, defaults, refusal and depth cap; no live workflow operations)`);
} finally {
  for (const child of children) child.kill('SIGKILL');
  await Promise.all([...children].map((child) => new Promise((resolve) => child.once('close', resolve))));
  server?.stop(true);
  fs.rmSync(root, { recursive: true, force: true });
}
