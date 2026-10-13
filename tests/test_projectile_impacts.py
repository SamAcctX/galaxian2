import copy
import unittest
from declaration_fixture import literal_fixture
from gof2_content import projectile_impacts as reader


def variants():
    return [*reader.LAYOUTS.items(), ('x86_64', reader.MAC_ALTERNATE)]


def fixture(arch, shift=0, rows=None):
    rows=reader.LAYOUTS[arch] if rows is None else rows
    constants=['model_2','model_19']
    mach,origin,offset,low=literal_fixture(arch,rows,shift,constants)
    staging={'provenance':{'initial':{'offset':origin}},'projectile_visuals':{'verified':True}}
    actors={'npc_initialization':{'primary_weapon':{'item_id':19}}}
    return mach,staging,actors,{'ordinary_hit_policy':{'verified':True},'player_hit_policy':{'verified':True}},offset,low


class ProjectileImpactTests(unittest.TestCase):
    def test_profiles_relocation_and_data_only_output(self):
        for arch,rows in variants():
            for shift in [0,0x700000]:
                args=fixture(arch,shift,rows);data=reader.extract_projectile_impacts(*args[:4])
                self.assertEqual({k:v for k,v in data.items() if k!='provenance'},reader.VALUES)
                for key,span in data['provenance'].items():
                    self.assertEqual(set(span),{'offset','bytes'})
                    self.assertEqual(span['offset'],args[1]['provenance']['initial']['offset']+rows[key][0])

    def test_every_changed_span_and_truncation(self):
        for arch,rows in variants():
            m,s,a,o,offset,low=fixture(arch,rows=rows)
            for key,(delta,_,_) in rows.items():
                bad=copy.copy(m);raw=bytearray(m.data);raw[offset+delta-low]^=255;bad.data=bytes(raw)
                self.assertFalse(reader.extract_projectile_impacts(bad,s,a,o),key)
            m.data=m.data[:offset+16]
            self.assertFalse(reader.extract_projectile_impacts(m,s,a,o))

    def test_scope_and_section_boundaries(self):
        for arch,rows in variants():
            for key in ['player','npc','ordinary','player_hit','origin','section','arch']:
                m,s,a,o,*_=fixture(arch,rows=rows)
                if key=='player':s['projectile_visuals']={}
                elif key=='npc':a['npc_initialization']['primary_weapon']['item_id']=18
                elif key=='ordinary':o['ordinary_hit_policy']={}
                elif key=='player_hit':o['player_hit_policy']={}
                elif key=='origin':s['provenance']['initial']['offset']+=2
                elif key=='section':m.sections[1]['segment']=b'__DATA'
                else:m.architecture='unsupported'
                self.assertFalse(reader.extract_projectile_impacts(m,s,a,o),key)


class AndroidProjectileImpacts(unittest.TestCase):
    PARENTS = ({'projectile_visuals': {'present': True}}, {'npc_initialization': {'primary_weapon': {'item_id': 19}}},
               {'ordinary_hit_policy': {'present': True}, 'player_hit_policy': {'present': True}})

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        from unittest.mock import patch
        verify_android_proof(self, reader, lambda lib: reader.extract_projectile_impacts(lib, *self.PARENTS))
        self.assertEqual(reader.ANDROID_VALUES, reader.VALUES)
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            result = reader.extract_projectile_impacts(lib, *self.PARENTS)
            result['model_ids'].append(0)
            self.assertEqual(reader.ANDROID_VALUES['model_ids'], [14600, 14605])
            staging, actors, weapons = self.PARENTS
            for parents in (({}, actors, weapons), (staging, {'npc_initialization': {'primary_weapon': {'item_id': 21}}}, weapons),
                            (staging, {}, weapons), (staging, actors, {**weapons, 'ordinary_hit_policy': {}}),
                            (staging, actors, {**weapons, 'player_hit_policy': {}}), (staging, actors, {})):
                self.assertEqual(reader.extract_projectile_impacts(lib, *parents), {}, parents)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'projectile_impact_definitions.gd')
