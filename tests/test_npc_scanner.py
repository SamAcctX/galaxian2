import copy
import unittest
from declaration_fixture import literal_fixture
from gof2_content import npc_scanner as reader


def variants():
    return [*reader.LAYOUTS.items(), ('x86_64', reader.MAC_ALTERNATE)]


def fixture(arch, shift=0, rows=None):
    rows=reader.LAYOUTS[arch] if rows is None else rows
    mach,origin,offset,low=literal_fixture(arch,rows,shift,[k for k in rows if k.endswith('_constant')])
    staging={'player_aim':{'present':True},'provenance':{'initial':{'offset':origin,'bytes':366 if arch=='x86_64' else 320}}}
    actors={'npc_initialization':{k:{'present':True} for k in ['hull','hostility','construction']}}
    return mach,staging,actors,offset,low


class NpcScannerTests(unittest.TestCase):
    def test_profiles_relocation_and_data_only_output(self):
        for arch,rows in variants():
            for shift in [0,0x700000]:
                m,s,a,*_=fixture(arch,shift,rows);data=reader.extract_npc_scanner(m,s,a)
                self.assertEqual({k:v for k,v in data.items() if k!='provenance'},reader.VALUES[arch])
                for key,span in data['provenance'].items():
                    self.assertEqual(set(span),{'offset','bytes'})
                    self.assertEqual(span['offset'],s['provenance']['initial']['offset']+rows[key][0])

    def test_every_changed_span_and_truncation(self):
        for arch,rows in variants():
            m,s,a,offset,low=fixture(arch,rows=rows)
            for key,(delta,_,_) in rows.items():
                bad=copy.copy(m);raw=bytearray(m.data);raw[offset+delta-low]^=255;bad.data=bytes(raw)
                self.assertFalse(reader.extract_npc_scanner(bad,s,a),key)
            m.data=m.data[:offset+16]
            self.assertFalse(reader.extract_npc_scanner(m,s,a))

    def test_parent_capabilities_and_section_boundaries(self):
        for arch,rows in variants():
            for key in ['hull','hostility','construction','aim','origin','size','section','arch']:
                m,s,a,*_=fixture(arch,rows=rows)
                if key in ['hull','hostility','construction']:a['npc_initialization'][key]={}
                elif key=='aim':s['player_aim']={}
                elif key=='origin':s['provenance']['initial']['offset']+=2
                elif key=='size':s['provenance']['initial']['bytes']+=1
                elif key=='section':m.sections[0]['segment']=b'__DATA'
                else:m.architecture='unsupported'
                self.assertFalse(reader.extract_npc_scanner(m,s,a),key)


ANDROID_PARENTS = ({'player_aim': {'aim': 1}}, {'npc_initialization': {'hull': {'rank': 0}, 'hostility': {'actor_kind': 8}, 'construction': {'cargo_count_bound': 3}}})


class AndroidNpcScannerTests(unittest.TestCase):
    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        verify_android_proof(self, reader, lambda lib: reader.extract_npc_scanner(lib, *ANDROID_PARENTS))
        self.assertEqual({k: v for k, v in reader.ANDROID_VALUES.items() if reader.VALUES['x86_64'][k] != v},
                         {'architecture': 'android-armv7', 'window_divisor': 16})
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            self.assertTrue(reader.extract_npc_scanner(lib, *ANDROID_PARENTS))
            # The result is a deep copy: changing its lists leaves the module's values intact.
            before = copy.deepcopy(reader.ANDROID_VALUES)
            for value in reader.extract_npc_scanner(lib, *ANDROID_PARENTS).values():
                if isinstance(value, list):
                    value.append(None)
                    for item in value:
                        if isinstance(item, list): item.append(None)
            self.assertEqual(reader.ANDROID_VALUES, before)
            staging, actors = ANDROID_PARENTS
            npc = actors['npc_initialization']
            for key in ('hull', 'hostility', 'construction'):
                self.assertEqual(reader.extract_npc_scanner(lib, staging, {'npc_initialization': {**npc, key: {}}}), {}, key)
            self.assertEqual(reader.extract_npc_scanner(lib, {'player_aim': {}}, actors), {})
            self.assertEqual(reader.extract_npc_scanner(lib, staging, {}), {})

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'npc_scanner_definitions.gd')
