"""Provisioning preflight. Reads public profile metadata; never imports keys."""
import copy
import fnmatch
import plistlib
import subprocess


def load_profile(path):
    result = subprocess.run(['security', 'cms', '-D', '-i', str(path)], capture_output=True, check=True)
    return plistlib.loads(result.stdout)


def entitlements_for(profile, bundle_id):
    rights = copy.deepcopy(profile.get('Entitlements', {}))
    allowed = rights.get('application-identifier', '')
    prefixes = profile.get('ApplicationIdentifierPrefix', [])
    prefix = next((p for p in prefixes if allowed.startswith(p + '.')), None)
    if not prefix:
        raise ValueError('描述文件缺少有效的 ApplicationIdentifierPrefix/application-identifier')
    actual = prefix + '.' + bundle_id
    # Apple provisioning identifiers allow an exact ID or a trailing wildcard.
    matches = allowed == actual or (allowed.endswith('.*') and '*' not in allowed[:-1] and actual.startswith(allowed[:-1]))
    if not matches:
        raise ValueError(f'Bundle ID {bundle_id} 与描述文件 {allowed} 不匹配；请更换描述文件或显式设置 --bundle-id。不要只伪造 application-identifier。')
    rights['application-identifier'] = actual
    if 'keychain-access-groups' in rights:
        rights['keychain-access-groups'] = [actual if '*' in group and fnmatch.fnmatchcase(actual, group) else group for group in rights['keychain-access-groups']]
    # Do not guess expansions of other service-specific wildcard entitlements.
    def has_wildcard(v):
        return ('*' in v) if isinstance(v, str) else any(has_wildcard(x) for x in (v.values() if isinstance(v, dict) else v)) if isinstance(v, (dict, list)) else False
    if has_wildcard(rights):
        raise ValueError('描述文件包含无法安全展开的服务通配权限，请使用明确 App ID 的描述文件。')
    return rights


def signing_plan(bundle_id, main, share, activity):
    profiles = [main, share, activity]
    ids = [bundle_id, bundle_id + '.share', bundle_id + '.activity']
    rights = [entitlements_for(p, b) for p, b in zip(profiles, ids)]
    teams = [p.get('TeamIdentifier', []) for p in profiles]
    if not teams[0] or any(t != teams[0] for t in teams[1:]):
        raise ValueError('主应用与扩展必须属于同一签名团队。')
    common = set(rights[0].get('com.apple.security.application-groups', [])) & set(rights[1].get('com.apple.security.application-groups', []))
    if not common:
        raise ValueError('主应用和分享扩展的描述文件没有共同 App Group，无法传递分享文件。')
    return rights
