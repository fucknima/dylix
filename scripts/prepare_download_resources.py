"""Pin optional archives and optionally stage a static dylib.cn deployment tree."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for part in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(part)
    return h.hexdigest()

def prepare(stage=None):
    rows = []
    for identifier, title, path in [
        ('developer-tools', '开发工具', ROOT / 'Resources/iSH/developer-tools.tar'),
        ('reverse-tools', '逆向分析工具', ROOT / 'Resources/iSH/reverse-tools.tar'),
        ('sdk26', 'iOS 26.0 SDK', ROOT / 'build/embedded-SDK26.zip'),
    ]:
        sha = digest(path)
        filename = f'{identifier}-{sha[:16]}{path.suffix}'
        rows.append(dict(id=identifier, title=title, file=filename,
                         bytes=path.stat().st_size, sha256=sha,
                         url=f'https://dylib.cn/downloads/dylix/v1/{filename}'))
        if stage:
            target = Path(stage) / 'downloads/dylix/v1' / filename
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
    if stage:
        notices = Path(stage) / 'downloads/dylix/notices'
        shutil.copytree(ROOT / 'Resources/ThirdPartyNotices', notices, dirs_exist_ok=True)
        shutil.copytree(ROOT / 'Resources/iSH/GuestTools', notices / 'GuestTools', dirs_exist_ok=True)
        shutil.copy2(ROOT / 'Resources/iSH/developer-tools.json', notices / 'developer-tools.json')
        shutil.copy2(ROOT / 'Resources/iSH/reverse-tools.json', notices / 'reverse-tools.json')
    return rows

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / 'Resources/DownloadResources.json')
    args = parser.parse_args()
    args.output.write_text(json.dumps(prepare(args.stage), ensure_ascii=False, indent=2) + '\n')
    print(args.output)
