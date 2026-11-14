"""Verify the public, pinned optional-resource URLs after static deployment."""
from pathlib import Path
import argparse
import hashlib
import json
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('--catalog', type=Path, default=Path(__file__).resolve().parents[1] / 'Resources/DownloadResources.json')
parser.add_argument('--full', action='store_true', help='Stream and verify every archive SHA-256, without saving files')
args = parser.parse_args()
failed = False
for entry in json.loads(args.catalog.read_text()):
    try:
        request = urllib.request.Request(entry['url'], method='GET' if args.full else 'HEAD', headers={'Accept-Encoding': 'identity'})
        with urllib.request.urlopen(request, timeout=60) as response:
            assert response.url == entry['url'], 'Unexpected redirect'
            assert response.status == 200, f'HTTP {response.status}'
            assert int(response.headers.get('Content-Length', -1)) == entry['bytes'], 'Size mismatch'
            if args.full:
                digest = hashlib.sha256()
                for chunk in iter(lambda: response.read(1024 * 1024), b''):
                    digest.update(chunk)
                assert digest.hexdigest() == entry['sha256'], 'SHA-256 mismatch'
        print('PASS', entry['id'])
    except Exception as error:
        failed = True
        print('FAIL', entry['id'], str(error))
raise SystemExit(1 if failed else 0)
