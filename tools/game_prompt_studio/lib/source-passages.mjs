const hud = /\b(?:hud|fps|on-screen (?:display|indicators?))\b/i;
const performance = /\b(?:fps|performance|graphics|presets?|resolutions?|viewport)\b/i;
const clock = /\b(?:clock|calendar|date|time display)\b/i;
const location = /\b(?:location|region|place)(?:\s+names?)?\s+(?:labels?|indicators?)\b|\b(?:location|region|place) names?\b/i;
const objective = /\b(?:objectives?|action hints?|prompts?)\b/i;
const helm = /\b(?:helm|steer\w*|at the wheel)\b/i;
const multiplayer = /\b(?:multiplayer|host|guest|captain|authority|ownership|transfer|replicat\w*)\b/i;

// Each entry identifies a behavior and a source function that owns it. The
// current manifest supplies the line number and the SQLite index supplies the text.
const hudPaths = [
  [performance, 'cove.gd', 'build_hud', ['fps.set_anchors', 'fps.offset_left', 'fps.offset_right']],
  [performance, 'fishing.gd', 'update_hud', ['fps.text', 'graphics.description']],
  [/\b(?:fps|f3|toggle\w*)\b/i, 'cove.gd', '_unhandled_input', ['KEY_F3', 'fps.visible']],
  [clock, 'shannon_job.gd', 'setup', ['game.hud.add_child(calendar)', 'calendar.set_anchors', 'calendar.offset_top']],
  [location, 'river_regions.gd', 'setup', ['region_label =', 'region_label.set_anchors', 'region_label.offset_top']],
  [objective, 'fishing.gd', 'update_hud', ['campaign.action_hint()', 'instruction.text = action']],
];
const helmPaths = [
  [null, 'fishing.gd', '_physics_process', ['near_wheel()', 'campaign.helm()']],
  [null, 'river_campaign.gd', 'request', ['crew.order.rpc_id', 'perform(crew.my_id()']],
  [null, 'river_campaign.gd', 'use_helm', ['helm_anchor()', 'captain = peer', 'set_meta("captain"']],
  [null, 'houseboat.gd', 'helm_anchor', ['skiff else HELM']],
  [null, 'river_crew.gd', 'steer', ['is_finite', 'get_meta("captain"', 'command_received.emit']],
  [null, 'fishing.gd', 'update_helm_throttle', ['vessel.hold_throttle']],
  [null, 'river_campaign.gd', 'step_boat', ['tick_client_ship', 'remote_age', 'remote_throttle', 'remote_rudder']],
];

export function bestFunctionWindow(db, manifest, path, name, scoreWindow) {
  const symbols = manifest.files[path]?.symbols ?? [];
  const index = symbols.findIndex(symbol => symbol.kind === 'func' && symbol.name === name);
  if (index === -1) return null;
  const start = symbols[index].line;
  const end = symbols[index + 1]?.line ?? Number.MAX_SAFE_INTEGER;
  const chunks = db.prepare('SELECT line,excerpt FROM chunks WHERE path=? AND line>=? AND line<? ORDER BY line')
    .all(path, start - 27, end);
  const lines = new Map();
  for (const chunk of chunks) {
    chunk.excerpt.split('\n').forEach((text, offset) => {
      const line = chunk.line + offset;
      if (line >= start && line < end && text.length > (lines.get(line)?.length ?? -1)) lines.set(line, text);
    });
  }

  let best;
  for (const [line, first] of lines) {
    if (!first.trim()) continue;
    const excerpt = [];
    let length = 0;
    for (let next = line; next < line + 12 && lines.has(next); next++) {
      const text = lines.get(next);
      if (length + text.length + 1 > 590) break;
      excerpt.push(text);
      length += text.length + 1;
    }
    const passage = excerpt.join('\n').trimEnd();
    const match = scoreWindow(passage);
    const score = match + 0.1 * Number(line === start);
    if (match > 0 && (!best || score > best.score)) {
      best = { path, line, excerpt: passage, title: name, score };
    }
  }
  return best;
}

export function routedSourcePassages(db, manifest, note) {
  if (!manifest) return null;
  const hudReport = hud.test(note);
  if (!hudReport && !(helm.test(note) && multiplayer.test(note))) return null;
  const paths = hudReport ? hudPaths : helmPaths;
  const passages = paths.flatMap(([intent, file, name, cues]) => {
    if (intent && !intent.test(note)) return [];
    const passage = bestFunctionWindow(db, manifest, 'godot-cove/' + file, name,
      text => cues.filter(cue => text.includes(cue)).length * 10);
    return passage ? [passage] : [];
  });
  if (!passages.length) return null;
  const guides = hudReport ? ['docs/systems/HUD-UI.md'] : ['docs/systems/BOAT-WATER.md', 'docs/systems/MULTIPLAYER.md'];
  return { passages, guides };
}
