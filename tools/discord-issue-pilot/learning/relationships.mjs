const codeOnly = text => text.replace(/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|#[^\n]*/g, ' ');
const gdPath = resource => 'godot-cove/' + resource.replace(/^res:\/\//, '');

export const symbolKey = item => `${item.path}:${item.name}`;

export function enrichRelationships(index, snapshot) {
  const functions = index.entries.filter(item => item.symbolKind === 'func');
  const symbols = new Map(functions.map(item => [symbolKey(item), item]));
  const owners = new Map();
  let typedCalls = 0, rpcCalls = 0, stateLinks = 0, graphifyLinks = 0;
  const join = (from, to, kind) => {
    if (!from || !to || from === to || from.links.get(to.id) === kind) return false;
    if (from.links.has(to.id) && !from.links.get(to.id).includes('hint') && kind.includes('hint')) return false;
    from.links.set(to.id, kind);
    const old = to.links.get(from.id);
    if (!old || old.includes('hint')) to.links.set(from.id, `reverse ${kind}`);
    return true;
  };

  for (const [path, file] of index.files) {
    if (!path.endsWith('.gd')) continue;
    const source = file.lines.join('\n');
    const aliases = new Map([...source.matchAll(/^const\s+(\w+)\s*:?=\s*preload\(["'](res:\/\/[^"']+\.gd)["']\)/gm)]
      .map(match => [match[1], gdPath(match[2])]));
    const fields = new Map();
    for (const [, field, type, constructed] of codeOnly(source).matchAll(/^var\s+(\w+)(?:\s*:\s*(\w+)|\s*:?=\s*(\w+)\.new\()/gm)) {
      const owner = aliases.get(type ?? constructed);
      if (owner) fields.set(field, owner);
    }
    for (const [name, owner] of aliases) fields.set(name, owner);
    owners.set(path, { aliases, fields });
  }

  const state = new Map();
  for (const fn of functions) {
    const fields = new Map(owners.get(fn.path)?.fields);
    const aliases = owners.get(fn.path)?.aliases;
    const raw = fn.lines.join('\n');
    const text = codeOnly(raw);
    for (const [, name, type] of text.matchAll(/\b(?:var\s+)?(\w+)\s*:\s*(\w+)\b/g)) {
      const owner = aliases?.get(type);
      if (owner) fields.set(name, owner);
    }
    for (const [, receiver, name] of text.matchAll(/\b(\w+(?:\.\w+)*)\.(\w+)\s*\(/g)) {
      const [head, ...tail] = receiver.split('.');
      let path = head === 'self' ? fn.path : fields.get(head);
      for (const step of tail) path = owners.get(path)?.fields.get(step);
      if (path && join(fn, symbols.get(`${path}:${name}`), 'typed call')) typedCalls++;
    }
    for (const [, receiver, name] of text.matchAll(/\b(?:(\w+)\.)?(\w+)\.(?:rpc|rpc_id|call_deferred)\s*\(/g)) {
      const path = !receiver || receiver === 'self' ? fn.path : fields.get(receiver);
      if (path && join(fn, symbols.get(`${path}:${name}`), 'resolved dispatch')) rpcCalls++;
    }
    // Match a field within an indexed file; a shared spelling is only a navigation hint.
    for (const [, name, assignment] of text.matchAll(/\b\w+\.(\w{4,})\s*(=(?!=))?/g)) {
      const key = `${fn.path}:${name}`;
      if (!state.has(key)) state.set(key, { writers: new Set(), readers: new Set() });
      state.get(key)[assignment ? 'writers' : 'readers'].add(fn);
    }
  }
  for (const { writers, readers } of state.values()) {
    if (!writers.size || readers.size > 8 || writers.size > 4) continue;
    for (const from of writers) for (const to of readers) if (join(from, to, 'shared field hint')) stateLinks++;
  }

  if (snapshot) {
    const trusted = new Map();
    for (const node of snapshot.nodes ?? []) {
      const path = gdPath(node.source_file ?? '');
      const file = index.files.get(path);
      if (!file || file.hash !== snapshot.hashes?.[node.source_file]) continue;
      const fn = symbols.get(`${path}:${String(node.label).replace(/\(\)$/, '')}`);
      const line = Number(/^L(\d+)/.exec(node.source_location ?? '')?.[1]);
      if (fn && line === fn.line) trusted.set(node.id, fn);
    }
    for (const edge of snapshot.links ?? []) {
      const from = trusted.get(edge.source), to = trusted.get(edge.target);
      if (edge.confidence !== 'EXTRACTED' || !/^calls?$/.test(edge.relation) || !from || !to || from.links.has(to.id)) continue;
      if (join(from, to, 'Graphify call')) graphifyLinks++;
    }
  }
  return { typedCalls, rpcCalls, stateLinks, graphifyLinks };
}
