import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

import fine_tune


class TrainingAuthorizationTest(unittest.TestCase):
    def test_scheduled_tick_only_reports_eligible_examples(self):
        with TemporaryDirectory(prefix='houseboat-training-gate-') as folder:
            home = Path(folder)
            holdout = home / 'holdout.json'
            holdout.touch()
            examples = [{'issue': issue} for issue in range(1, 25)]
            with patch.object(fine_tune, 'run_tool', return_value=json.dumps(examples)) as tool, \
                 patch.object(fine_tune, 'read_holdout', return_value=([], set())), \
                 patch.object(fine_tune, 'train_adapter') as train:
                fine_tune.tick({'node': 'node', 'holdout': holdout, 'minExamples': 24}, home, False)
                tool.assert_called_once()
                train.assert_not_called()
            report = fine_tune.read_json(home / 'training-status.json')
            self.assertEqual(report['phase'], 'awaiting-training-authorization')
            self.assertEqual(report['examples'], 24)
