from pathlib import Path
import sys, unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from signing_profiles import entitlements_for, signing_plan

def profile(app, prefix='PREFIX', team='TEAM'):
    return {'ApplicationIdentifierPrefix':[prefix],'TeamIdentifier':[team], 'Entitlements':{'application-identifier':prefix+'.'+app,'com.apple.developer.team-identifier':team,'keychain-access-groups':[prefix+'.*'],'com.apple.security.application-groups':['group.common']}}

class Signing(unittest.TestCase):
    def test_exact(self):
        self.assertEqual(entitlements_for(profile('com.test'),'com.test')['application-identifier'],'PREFIX.com.test')
    def test_fixed_profile_rejects_original(self):
        with self.assertRaisesRegex(ValueError,'不匹配'):entitlements_for(profile('app.panda1248.maroon8441'),'com.xuegao.theosmobilecompiler')
    def test_wildcard(self):
        self.assertEqual(entitlements_for(profile('com.*'),'com.test')['keychain-access-groups'],['PREFIX.com.test'])
    def test_prefix_not_team(self):
        self.assertEqual(entitlements_for(profile('com.test'),'com.test')['com.apple.developer.team-identifier'],'TEAM')
    def test_missing_prefix(self):
        with self.assertRaises(ValueError):entitlements_for({'Entitlements':{}},'test')
    def test_three_matching_profiles(self):
        self.assertEqual(len(signing_plan('com.test',*[profile(x) for x in ['com.test','com.test.share','com.test.activity']])),3)
    def test_same_profile_for_extensions_fails(self):
        with self.assertRaises(ValueError):signing_plan('com.test',*[profile('com.test')]*3)
    def test_no_common_group(self):
        p=profile('com.test.share');p['Entitlements']['com.apple.security.application-groups']=[]
        with self.assertRaisesRegex(ValueError,'App Group'):signing_plan('com.test',profile('com.test'),p,profile('com.test.activity'))
    def test_other_team(self):
        with self.assertRaisesRegex(ValueError,'团队'):signing_plan('com.test',profile('com.test'),profile('com.test.share',team='OTHER'),profile('com.test.activity'))
    def test_unknown_wildcard(self):
        p=profile('com.test');p['Entitlements']['other-service']='*'
        with self.assertRaisesRegex(ValueError,'通配'):entitlements_for(p,'com.test')

unittest.main()
