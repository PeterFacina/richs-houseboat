const repository = 'https://github.com/PeterFacina/richs-houseboat';
const validNumber = number => Number.isSafeInteger(number) && number > 0;

export function lessonSection(evidence) {
  const item = evidence.find(entry => entry.kind === 'verified-lesson');
  if (!item || !/^S[1-9]\d*$/.test(item.id) || !validNumber(item.issue) || !validNumber(item.pull)) return null;
  const prose = [item.failed, item.succeeded, item.feedback, item.verification];
  if (!prose.every(text => typeof text === 'string' && text.length > 0 && text.length <= 240 &&
      !/[\p{Cc}\p{Cf}]/u.test(text))) return null;
  const sourceLine = `- Original records: ${repository}/issues/${item.issue} and ${repository}/pull/${item.pull}`;
  return { sourceLine, text: [
    'VERIFIED LESSON FROM A COMPLETED TASK',
    `- Use [${item.id}] as background for the current report.`,
    '- Previously failed approach: ' + item.failed,
    '- Merged solution: ' + item.succeeded,
    '- Review feedback: ' + item.feedback,
    '- Verification: ' + item.verification,
    sourceLine,
  ].join('\n') };
}
