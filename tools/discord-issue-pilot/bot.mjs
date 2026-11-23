import { createServer } from 'node:http';
import { DatabaseSync } from 'node:sqlite';
import { ApplicationCommandType, ButtonBuilder, ButtonStyle, Client, Events, GatewayIntentBits,
  MessageFlags, ActionRowBuilder } from 'discord.js';
import { codexLink, repository, pullStatus, findGpuBrief } from './workflow.mjs';
import { studioClient } from './studio.mjs';

const { DISCORD_TOKEN, DISCORD_GUILD_ID, DISCORD_CHANNEL_ID, GITHUB_TOKEN,
  LAUNCH_URL, DISCORD_ROLE_ID } = process.env;
if (![DISCORD_TOKEN, DISCORD_GUILD_ID, DISCORD_CHANNEL_ID, GITHUB_TOKEN, LAUNCH_URL].every(Boolean)) {
  throw new Error('Missing required settings. See README.md.');
}
const launch = new URL(LAUNCH_URL);
if (launch.protocol !== 'https:' || launch.pathname !== '/' || launch.search || launch.hash
    || launch.username || launch.password) {
  throw new Error('LAUNCH_URL must be a private HTTPS origin.');
}
const generateBrief = process.env.STUDIO_URL ? studioClient(process.env.STUDIO_URL) : null;
const queueBrief = process.env.QUEUE_STUDIO_BRIEF === '1';
if (queueBrief && generateBrief) throw new Error('Choose QUEUE_STUDIO_BRIEF or STUDIO_URL.');

const db = new DatabaseSync('pilot.sqlite');
db.exec('PRAGMA journal_mode = WAL');
db.exec([
  'CREATE TABLE IF NOT EXISTS reports (',
  'source TEXT PRIMARY KEY, issue INTEGER UNIQUE, reply TEXT, claimant TEXT, created TEXT NOT NULL)',
].join(' '));
db.exec('CREATE TABLE IF NOT EXISTS gpu_briefs (source TEXT PRIMARY KEY, url TEXT)');
const find = db.prepare('SELECT reports.*, gpu_briefs.url, gpu_briefs.source IS NOT NULL AS queued'
  + ' FROM reports LEFT JOIN gpu_briefs USING (source) WHERE reports.source = ?');
const pending = db.prepare('SELECT reports.*, gpu_briefs.url FROM reports JOIN gpu_briefs USING (source)'
  + ' WHERE reply IS NOT NULL AND claimant IS NULL');
const tracked = db.prepare('SELECT * FROM reports WHERE reply IS NOT NULL AND claimant IS NOT NULL');
const claim = db.prepare('UPDATE reports SET claimant = ? WHERE source = ? AND claimant IS NULL');
const client = new Client({ intents: [GatewayIntentBits.Guilds], allowedMentions: { parse: [] } });
const issueUrl = number => 'https://github.com/' + repository + '/issues/' + number;

async function github(path, method = 'GET', body) {
  const response = await fetch('https://api.github.com/repos/' + repository + path, {
    method,
    headers: { Authorization: 'Bearer ' + GITHUB_TOKEN, Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) throw new Error('GitHub ' + method + ' ' + path + ' returned ' + response.status);
  return response.json();
}

function card(report, status) {
  const waiting = report.queued && !report.url;
  const claimStatus = report.claimant ? '**In progress** · <@' + report.claimant + '>' : '**Ready to claim**';
  const button = new ButtonBuilder().setCustomId('claim:' + report.source)
    .setLabel(report.claimant ? 'Open in Codex' : 'Claim & Open in Codex')
    .setStyle(ButtonStyle.Primary);
  return {
    content: '**Rich’s Houseboat workflow pilot** · [Issue #' + report.issue + ']('
      + issueUrl(report.issue) + ')\n' + (waiting ? '**Waiting for GPU brief**' : (status ?? claimStatus))
      + (report.url ? '\n[Game Prompt Studio brief](' + report.url + ')' : '')
      + '\nCodex will read the issue, follow the team workflow, and open a linked draft PR.',
    components: waiting ? [] : [new ActionRowBuilder().addComponents(button)],
  };
}

async function submit(message) {
  const source = message.id;
  // Generate before reserving an issue so a failed export or busy model can be retried.
  const brief = generateBrief && !find.get(source) ? await generateBrief(message.content) : null;
  const reservation = db.prepare('INSERT OR IGNORE INTO reports (source, created) VALUES (?, ?)')
    .run(source, new Date().toISOString());
  let report = find.get(source);
  if (!report.issue) {
    const marker = '<!-- discord-pilot:' + source + ' -->';
    let issue;
    if (reservation.changes) {
      issue = await github('/issues', 'POST', {
        title: 'Workflow pilot: ' + message.content.trim().split('\n')[0].slice(0, 150),
        body: '## Goal\n\nRun a notes-only workflow pilot.\n\n'
          + '## Original report\n\n' + message.content + '\n\n'
          + 'Discord report: ' + message.url + '\n\n'
          + '## Done when\n\nThe requested notes change is in a linked draft PR, ready for human review.\n\n'
          + (brief ? '## Game Prompt Studio brief\n\n' + brief + '\n\n' : '')
          + (queueBrief ? '<!-- houseboat-gpu-pending:v1 -->\n' : '')
          + marker,
      });
    } else {
      for (let page = 1; !issue; page++) {
        const since = new Date(Date.parse(report.created) - 60_000).toISOString();
        const issues = await github('/issues?state=all&per_page=100&page=' + page
          + '&since=' + encodeURIComponent(since));
        issue = issues.find(item => !item.pull_request && item.body?.includes(marker));
        if (issues.length < 100) break;
      }
      if (!issue) throw new Error('Unconfirmed issue creation. See recovery steps in README.md.');
    }
    db.exec('BEGIN IMMEDIATE');
    try {
      db.prepare('UPDATE reports SET issue = ? WHERE source = ?').run(issue.number, source);
      if (issue.body?.trimEnd().endsWith('<!-- houseboat-gpu-pending:v1 -->\n' + marker)) {
        db.prepare('INSERT OR IGNORE INTO gpu_briefs (source) VALUES (?)').run(source);
      }
      db.exec('COMMIT');
    } catch (error) {
      db.exec('ROLLBACK');
      throw error;
    }
    report = find.get(source);
  }
  if (!report.reply) {
    const reply = await message.channel.send({ ...card(report), nonce: source, enforceNonce: true,
      reply: { messageReference: source, failIfNotExists: false } });
    db.prepare('UPDATE reports SET reply = ? WHERE source = ?').run(reply.id, source);
  }
  return issueUrl(report.issue);
}

const submissions = new Map();
client.on(Events.InteractionCreate, async interaction => {
  if (!interaction.isMessageContextMenuCommand() && !interaction.isButton()) return;
  if (interaction.isButton() && !interaction.customId.startsWith('claim:')) return;
  if (interaction.isMessageContextMenuCommand() && interaction.commandName !== 'Create pilot issue') return;
  if (interaction.guildId !== DISCORD_GUILD_ID || interaction.channelId !== DISCORD_CHANNEL_ID) {
    await interaction.reply({ content: 'Use this action in #issues.', flags: MessageFlags.Ephemeral });
    return;
  }
  const memberRoles = interaction.member?.roles;
  if (DISCORD_ROLE_ID && !(Array.isArray(memberRoles)
    ? memberRoles.includes(DISCORD_ROLE_ID) : memberRoles?.cache.has(DISCORD_ROLE_ID))) {
    await interaction.reply({ content: 'This action is for the pilot team.', flags: MessageFlags.Ephemeral });
    return;
  }
  try {
    await interaction.deferReply({ flags: MessageFlags.Ephemeral });
    if (interaction.isMessageContextMenuCommand()) {
      const message = interaction.targetMessage;
      if (!message.content?.trim() || message.author.bot) {
        await interaction.editReply('Choose a teammate’s text report for the notes-only pilot.');
        return;
      }
      if (!submissions.has(message.id)) {
        submissions.set(message.id, submit(message).finally(() => submissions.delete(message.id)));
      }
      await interaction.editReply('Pilot issue: ' + await submissions.get(message.id));
      return;
    }
    const source = interaction.customId.slice(6);
    const report = find.get(source);
    if (!report || report.reply !== interaction.message.id) {
      await interaction.editReply('This pilot report is unavailable.');
      return;
    }
    if (report.queued && !report.url) {
      await interaction.editReply('The GPU brief is still pending.');
      return;
    }
    const changed = claim.run(interaction.user.id, source).changes;
    const current = find.get(source);
    if (current.claimant !== interaction.user.id) {
      await interaction.editReply('Already claimed by <@' + current.claimant + '>.');
      return;
    }
    const button = new ButtonBuilder().setStyle(ButtonStyle.Link).setLabel('Open launcher')
      .setURL(new URL('/open/' + current.issue, launch).href);
    await interaction.editReply({ content: 'Open the launcher, then select Open in Codex.',
      components: [new ActionRowBuilder().addComponents(button)] });
    if (changed) {
      await interaction.message.edit(card(current)).catch(error => console.error(error.message));
      await refresh();
    }
  } catch (error) {
    console.error(error.message);
    if (interaction.deferred) {
      const reply = error.message.startsWith('Studio ') ? error.message
        : 'The pilot could not complete that action. Ask the bot operator to check the log.';
      await interaction.editReply(reply)
        .catch(() => {});
    }
  }
});

let refreshing = false;
async function refresh() {
  if (refreshing) return;
  refreshing = true;
  try {
    const reports = tracked.all();
    const waiting = pending.all();
    if (!reports.length && !waiting.length) return;
    const channel = await client.channels.fetch(DISCORD_CHANNEL_ID);
    for (const report of waiting) {
      try {
        if (!report.url) {
          let brief;
          for (let page = 1; !brief; page++) {
            const comments = await github('/issues/' + report.issue + '/comments?per_page=100&page=' + page);
            brief = findGpuBrief(comments);
            if (comments.length < 100) break;
          }
          if (!brief) continue;
          db.prepare('UPDATE gpu_briefs SET url = ? WHERE source = ?').run(brief.html_url, report.source);
        }
        const message = await channel.messages.fetch(report.reply);
        const update = card(find.get(report.source));
        if (message.content !== update.content) await message.edit(update);
      } catch (error) {
        console.error('GPU brief status update failed for issue ' + report.issue + ': ' + error.message);
      }
    }
    if (!reports.length) return;
    const oldest = reports.map(report => report.created).sort()[0];
    const pulls = [];
    for (let page = 1; ; page++) {
      const batch = await github('/pulls?state=all&sort=updated&direction=desc&per_page=100&page=' + page);
      pulls.push(...batch);
      if (batch.length < 100 || Date.parse(batch.at(-1).updated_at) < Date.parse(oldest) - 60_000) break;
    }
    for (const report of reports) {
      try {
        const message = await channel.messages.fetch(report.reply);
        const update = card(find.get(report.source), pullStatus(pulls, report.issue));
        if (message.content !== update.content) await message.edit(update);
      } catch (error) {
        console.error('Discord status update failed for issue ' + report.issue + ': ' + error.message);
      }
    }
  } catch (error) {
    console.error('Status refresh failed: ' + error.message);
  } finally {
    refreshing = false;
  }
}

const server = createServer((request, response) => {
  const match = /^\/open\/(\d+)$/.exec(request.url);
  const report = match && db.prepare('SELECT issue, url FROM reports LEFT JOIN gpu_briefs USING (source)'
    + ' WHERE issue = ? AND claimant IS NOT NULL')
    .get(Number(match[1]));
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('Content-Type', 'text/html; charset=utf-8');
  if (request.method !== 'GET' || !report) {
    response.writeHead(404).end('Report unavailable');
    return;
  }
  const href = codexLink(issueUrl(report.issue), report.url).replaceAll('&', '&amp;');
  response.end('<!doctype html><meta charset="utf-8"><title>Rich’s Houseboat</title>'
    + '<h1>Rich’s Houseboat</h1><p><a href="' + href + '">Open in Codex</a></p>');
});

client.once(Events.ClientReady, async ready => {
  try {
    const guild = await ready.guilds.fetch(DISCORD_GUILD_ID);
    await guild.commands.create({ name: 'Create pilot issue', type: ApplicationCommandType.Message });
    server.listen(Number(process.env.LAUNCH_PORT ?? 8766), '127.0.0.1');
    console.log('Discord issue pilot is ready.');
    await refresh();
    setInterval(refresh, 60_000).unref();
  } catch (error) {
    console.error('Pilot startup failed: ' + error.message);
    client.destroy();
    process.exitCode = 1;
  }
});
await client.login(DISCORD_TOKEN);
