import gameRoutes from './game-routes.json' with { type: 'json' };

const sourceFilename = /(?<![\w.-])[\w-]+\.(?:gd|tscn|gdshader)\b/gi;
const legacyAssetDirectory = /(?<![\w./:-])(res:\/\/|godot-cove\/)?ottawa\//gi;
const currentAssetDirectory = /(?<![\w./:-])(?:res:\/\/|godot-cove\/)?deep_river\//i;
const routes = gameRoutes.routes.map(([pattern, paths, guidePath]) => ({ pattern: new RegExp(pattern, 'i'), paths, guidePath }));

export function resolveGameRoutes(note) {
  const lookup = note.replace(sourceFilename, name => gameRoutes.aliases[name.toLowerCase()] ?? name)
    .replace(legacyAssetDirectory, (_match, prefix = '') => prefix + 'deep_river/');
  const matched = routes.filter(route => route.pattern.test(lookup));
  const filenames = [...lookup.matchAll(sourceFilename)].map(match => match[0].toLowerCase());
  if (currentAssetDirectory.test(lookup)) {
    matched.push({ paths: ['deep_river_map.gd'], guidePath: 'docs/ARCHITECTURE.md' });
  }
  return { lookup, filenames, paths: matched.flatMap(route => route.paths), guides: matched.map(route => route.guidePath) };
}
