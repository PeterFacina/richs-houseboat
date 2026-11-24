import { readFileSync } from 'node:fs';
import { openTrainingInbox } from './training-inbox.mjs';

const [action, issueNumber, file] = process.argv.slice(2);
const issue = Number(issueNumber);
if (!Number.isSafeInteger(issue) || issue < 1
    || !((action === 'show' && !file) || (action === 'record' && file))) {
  throw new Error('Usage: node training-review.mjs show ISSUE | record ISSUE REVIEW.json');
}
const inbox = openTrainingInbox();
try {
  if (action === 'show') {
    console.log(JSON.stringify(inbox.read(issue), null, 2));
  } else {
    const input = JSON.parse(readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
    const { status, prUrl, summary, reviewer, captureId, target } = input;
    if (!/^https:\/\/github\.com\/PeterFacina\/richs-houseboat\/pull\/[1-9]\d*(?:#[-\w]+)?$/.test(prUrl ?? '')) {
      throw new Error('Supply the link to the Houseboat PR or its feedback comment.');
    }
    inbox.addReview(issue, { status, prUrl, summary, reviewer, captureId, target });
    console.log('Recorded ' + status + ' for issue #' + issue);
  }
} finally {
  inbox.close();
}
