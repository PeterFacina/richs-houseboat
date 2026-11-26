import { once } from 'node:events';
import { createStudio } from '../game_prompt_studio/server.mjs';
import { createOllama } from '../game_prompt_studio/lib/model.mjs';
import { liveKnowledge } from './source-knowledge.mjs';
import { studioClient } from './studio.mjs';
import { repository } from './workflow.mjs';
import { candidateBrief, candidateRetrieval, deterministicRetriever, originalRetrieval, retrievalConfig, verificationGuidance } from './production-retrieval.mjs';
import { checkExport } from '../game_prompt_studio/lib/model.mjs';

export function requireGenerationReview(inbox, note, issue) {
  const previous = inbox.read(issue.number).captures.filter(row => row.input.report === note);
  if (previous.some(row => row.input.exportPassed === false)) {
    const error = new Error('Guard review required: this report already has a rejected capture. Correct and explicitly revise the report before retrying.');
    error.code = 'GUARD_REVIEW_REQUIRED';
    throw error;
  }
}

export async function workerGeneration({
  storage, model, knowledge, github, inbox, fetchOllama = fetch, retrieval = retrievalConfig(), log = console,
}) {
  const options = { port: 8765, ollamaPort: 11434, model, context: 8192, keepAliveMinutes: 2,
    tier: 'detailed', privateOrigin: '', exclude: [] };
  let active;
  const retrieve = retrieval.mode === candidateRetrieval ? deterministicRetriever(knowledge) : undefined;
  const provider = createOllama(options.ollamaPort, (url, init) => {
    if (new URL(url).pathname === '/api/chat') active.request = JSON.parse(init.body);
    return fetchOllama(url, init);
  });
  const server = createStudio({ storage, options, provider, async prepareKnowledge(input) {
    if (input.note !== active?.note) throw new Error('Generation requires a queued report.');
    const [source, { tasks, githubContextComplete }] = await Promise.all([
      knowledge.refresh(), liveKnowledge(github, active.issue.number),
    ]);
    const requested = retrieval.forIssue(active.issue.number);
    const start = performance.now();
    let selection;
    try { selection = await knowledge.select(input.note, tasks); }
    catch { log.warn('Knowledge selector unavailable for ' + source.commit + '.'); }
    let preparedEvidence;
    if (requested === candidateRetrieval) {
      try { preparedEvidence = await retrieve(source.commit, input.note, active.issue.number, selection); }
      catch { log.warn('Issue #' + active.issue.number + ': deterministic retrieval fell back to original.'); }
    }
    const effective = preparedEvidence ? candidateRetrieval : originalRetrieval;
    const elapsedMs = Math.round(performance.now() - start);
    log.info(`Issue #${active.issue.number}: retrieval requested=${requested} effective=${effective} source=${source.commit} ms=${elapsedMs} stale=${source.stale}.`);
    const briefVersion = preparedEvidence ? candidateBrief : originalRetrieval;
    return { ...source, githubContextComplete: githubContextComplete && Boolean(selection), selection,
      retrievalFallback: !selection || requested !== effective, preparedEvidence,
      generationGuidance: preparedEvidence ? verificationGuidance : '',
      retrieval: { requested, effective, elapsedMs, briefVersion } };
  } });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const generateBrief = studioClient('http://127.0.0.1:' + server.address().port);
  return {
    async generate(note, issue, { authorizedRetry = false } = {}) {
      if (active) throw new Error('The worker is already processing a report.');
      // The existing capture store makes this hold survive polling and restarts.
      // A new main revision alone must never spend another generation attempt.
      if (!authorizedRetry) requireGenerationReview(inbox, note, issue);
      active = { note, issue };
      try {
        const { record, exportPassed } = await generateBrief(note, { details: true });
        const { request } = active;
        const input = request && JSON.parse(request.messages.find(message => message.role === 'user').content);
        if (input?.currentRequest.note !== note || !record.generation.knowledge?.commit || request.model !== model) {
          throw new Error('Could not match the model request to the report and indexed commit.');
        }
        const { knowledge, facts, ...metrics } = record.generation;
        const retrievedContext = input.untrustedRetrievedEvidence;
        const guardFindings = checkExport(record.prompt, record.evidence, facts);
        const captureId = inbox.capture(issue.number, { repository, issueUrl: issue.html_url, report: note,
          commit: knowledge.commit, knowledge, retrievedContext, model: request.model, modelDigest: metrics.modelDigest,
          contextBytes: Buffer.byteLength(JSON.stringify(retrievedContext)), request, metrics, exportPassed, guardFindings,
          ...(record.evidence.some(item => item.kind === 'verified-lesson') ? { exportEvidence: record.evidence } : {}),
        }, record.prompt.trim());
        if (!exportPassed) {
          const error = new Error('Studio blocked export. The private capture is available for human review. Findings: ' + guardFindings.join('; '));
          error.code = 'GUARD_REVIEW_REQUIRED';
          throw error;
        }
        return { brief: record.prompt.trim(), captureId };
      } finally {
        active = null;
      }
    },
    async close() {
      const closed = once(server, 'close');
      server.close();
      server.closeAllConnections();
      await closed;
    },
  };
}
