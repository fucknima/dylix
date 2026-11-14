"""Exercise migrations using neutral text, never the shipped prompt catalog."""
from pathlib import Path
import argparse
import json
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--legacy-root', type=Path, help='Optional build166 source for a real legacy-reader check')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
sdk = Path('/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk')
if not sdk.exists():
    sdk = Path(subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip())
old_id = '11111111-1111-4111-8111-111111111111'
new_id = '22222222-2222-4222-8222-222222222222'
row = dict(id=old_id, name='Neutral legacy example', body='Use concise language.\n🙂',
           mode='append', isBuiltin=True, builtinKey='fixture.legacy', updatedAt=0)
new_row = dict(row, id=new_id, name='Neutral new example', builtinKey='fixture.new')
catalog = dict(catalogVersion=2, retiredBuiltinKeys=['fixture.legacy'],
               personas=[new_row], tailBody='', prefixTemplate='')
checks = 0

def check(condition, label):
    global checks
    assert condition, label
    checks += 1
    print('PASS', label, flush=True)

with tempfile.TemporaryDirectory(prefix='dylix-storage-regression-') as tmp:
    tmp = Path(tmp)
    helper = root / 'tests/PersonaStorageFixture.m'

    def compile_reader(source, target):
        # Resolve the fixture header against the selected source, not this checkout.
        main = tmp / (target.name + '.m')
        main.write_text(helper.read_text().replace('../App/AI/Persona/TFAIPersona.h',
                                                   str(source / 'App/AI/Persona/TFAIPersona.h')))
        subprocess.run(['xcrun', 'clang', '-isysroot', str(sdk), '-fobjc-arc', '-fblocks',
                        '-Wno-nullability-completeness', str(main),
                        str(source / 'App/AI/Persona/TFAIPersona.m'),
                        '-framework', 'Foundation', '-o', str(target)], check=True)

    binary = tmp / 'current'
    compile_reader(root, binary)
    catalog_path = tmp / 'catalog.json'
    catalog_path.write_text(json.dumps(catalog))

    def run(path, cat=catalog_path, exe=binary):
        return json.loads(subprocess.check_output([str(exe), str(path), str(cat)], timeout=20))

    for name, entry, version, enabled in [
        ('legacy-selected', row, 2, True),
        ('edited-selected', dict(row, updatedAt=123, body='User edited text.'), 2, True),
        ('custom-selected', dict(row, isBuiltin=False), 2, True),
        ('disabled', row, 2, False),
        ('existing-version3', row, 3, True),
    ]:
        folder = tmp / name
        folder.mkdir()
        path = folder / 'personas.json'
        state = dict(schemaVersion=version, enabled=enabled, personas=[entry], activeID=old_id,
                     hiddenBuiltins=[], tailEnabled=True)
        original = json.dumps(state, ensure_ascii=False).encode()
        path.write_bytes(original)
        result = run(path)
        check(not result['error'], name + ': migration readable')
        check(result['activeID'] == old_id and result['enabled'] == enabled,
              name + ': selection and switch preserved')
        check(result['rows'][old_id]['body'] == entry['body'], name + ': original text preserved')
        check(result['tailEnabled'] and new_id in result['rows'], name + ': additive catalog preserves options')
        backups = list((folder / 'MigrationBackups').glob('*.json'))
        check(len(backups) == 1 and backups[0].read_bytes() == original,
              name + ': byte-exact original snapshot')
        check(backups[0].stat().st_mode & 0o777 == 0o600, name + ': private snapshot permissions')
        written = path.read_bytes()
        check(json.loads(written)['schemaVersion'] == 3, name + ': v3 additive envelope')
        check(run(path) == result and path.read_bytes() == written and
              len(list((folder / 'MigrationBackups').glob('*.json'))) == 1,
              name + ': reopening does not rewrite or create duplicate snapshots')

    folder = tmp / 'backup-failure'
    folder.mkdir()
    path = folder / 'personas.json'
    original = json.dumps(dict(schemaVersion=2, enabled=True, personas=[row], activeID=old_id)).encode()
    path.write_bytes(original)
    (folder / 'MigrationBackups').write_text('blocked')
    result = run(path)
    check(bool(result['error']) and path.read_bytes() == original,
          'backup failure leaves original file untouched')

    folder = tmp / 'hidden-new-item'
    folder.mkdir()
    path = folder / 'personas.json'
    path.write_text(json.dumps(dict(schemaVersion=2, enabled=False, personas=[row],
                                   activeID=old_id, hiddenBuiltins=[new_id], tailEnabled=False)))
    result = run(path)
    check(new_id not in result['rows'] and result['hiddenBuiltins'] == [new_id],
          'explicitly deleted catalog entry stays hidden')

    if args.legacy_root:
        legacy = tmp / 'legacy'
        compile_reader(args.legacy_root.resolve(), legacy)
        old_catalog = tmp / 'old-catalog.json'
        old_catalog.write_text(json.dumps(dict(catalogVersion=1, personas=[row], tailBody='', prefixTemplate='')))
        result = run(tmp / 'legacy-selected/personas.json', old_catalog, legacy)
        check(not result['error'] and result['activeID'] == old_id and result['enabled'],
              'actual build166 reader retains selection and enabled state')
        check(result['rows'][old_id]['body'] == row['body'] and new_id in result['rows'],
              'actual build166 reader retains old and new text records')

print(f'TOTAL {checks} neutral storage checks passed')
