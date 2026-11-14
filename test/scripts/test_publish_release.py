"""Exercise release publication without contacting GitHub."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / '.github/scripts/publish_release.sh'


class PublishReleaseTest(unittest.TestCase):
    def run_publish(self, tag, stable):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / 'calls'
            gh = root / 'gh'
            gh.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
with open(os.environ['GH_CALLS'], 'a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\\n')
if sys.argv[1:3] == ['release', 'view']:
    if sys.argv[-1] == 'isDraft':
        print('{"isDraft":true}')
    else:
        print('{"assets":[{"name":"update.json","size":2}]}')
''')
            gh.chmod(0o755)
            assets = root / 'assets'
            assets.mkdir()
            (assets / 'update.json').write_text('{}')
            notes = root / 'notes.md'
            notes.write_text('Release notes')
            result = subprocess.run(['bash', str(SCRIPT)], capture_output=True, text=True, env={
                **os.environ, 'PATH': f'{root}:{os.environ["PATH"]}',
                'GH_TOKEN': 'test', 'GITHUB_REPOSITORY': 'owner/repo',
                'RELEASE_TAG': tag, 'IS_STABLE': stable,
                'RELEASE_NOTES_FILE': str(notes), 'RELEASE_ASSET_DIR': str(assets),
                'GH_CALLS': str(log),
            })
            return result, log.read_text() if log.exists() else ''

    def test_stable_latest(self):
        result, calls = self.run_publish('v0.6.0', 'true')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"--prerelease=false", "--latest"', calls)

    def test_preview_never_latest(self):
        result, calls = self.run_publish('v0.6.0-pre.1', 'false')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"--prerelease", "--latest=false"', calls)

    def test_bad_channel_rejected_before_github(self):
        for tag, stable in [('v0.6.0-pre.1', 'true'), ('v0.6.0', 'false'),
                            ('v0.6.0-beta.1', 'false'), ('v0.6.0-pre.01', 'false')]:
            with self.subTest(tag=tag, stable=stable):
                result, calls = self.run_publish(tag, stable)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(calls, '')


if __name__ == '__main__':
    unittest.main()
