"""Both bounded layouts, relocated and disconnected from their dependencies."""
import copy
import unittest
from types import SimpleNamespace
from gof2_content import npc_death_accounting as reader
from gof2_content.opening_npc_guidance import LAYOUTS as GUIDANCE


def variants():
    return [*reader.LAYOUTS.items(), ('x86_64', reader.MAC_ALTERNATE)]


def fixture(arch, shift=0, layouts=None):
    layouts=reader.LAYOUTS[arch] if layouts is None else layouts
    low=min(r[0] for r in layouts.values())-64
    high=max(r[0]+r[1] for r in layouts.values())+64
    offset=128;bias=4096
    data=bytearray(offset+high-low)
    for delta,size,raw in layouts.values():data[offset+delta-low:offset+delta-low+size]=bytes.fromhex(raw)
    text={'segment':b'__TEXT','name':b'__text','address':0x400000+shift,'offset':offset,'length':high-low}
    mach=SimpleNamespace(architecture=arch,slice_offset=bias,data=bytes(data),text=text,sections=[text])
    origin=bias+offset-low
    _,relative,size,_=GUIDANCE[arch]['selection']
    npc={'guidance':{'provenance':{'selection':{'offset':origin+relative,'bytes':size}}},
         'destruction':{'verified':True},'hostility':{'verified':True},'primary_weapon':{'verified':True},
         'provenance':{'stats_entry':{'offset':origin+layouts['initial_attribution'][0]-(0x2f9 if arch=='x86_64' else 0x20c)}}}
    actors={'npc_initialization':npc,'actors':[{'actor_kind':8} for _ in range(3)]}
    weapons={'ordinary_hit_policy':{'provenance':{'normal_hit':{'offset':origin+layouts['hit_argument'][0]}}}}
    return mach,actors,weapons,offset,low


class DeathAccountingTests(unittest.TestCase):
    def test_relocated_profiles(self):
        for arch,layouts in variants():
            for shift in [0,0x900000]:
                mach,actors,weapons,*_=fixture(arch,shift,layouts)
                result=reader.extract_npc_death_accounting(mach,actors,weapons)
                self.assertEqual({k:v for k,v in result.items() if k!='provenance'},reader.VALUES)
                self.assertEqual(len(result['provenance']),len(layouts))
                self.assertFalse(any('pattern' in r or 'code' in r for r in result['provenance'].values()))

    def test_each_changed_span_and_truncation(self):
        for arch,layouts in variants():
            mach,actors,weapons,offset,low=fixture(arch,layouts=layouts)
            for key,(delta,_,_) in layouts.items():
                bad=copy.copy(mach);raw=bytearray(mach.data);raw[offset+delta-low]^=255;bad.data=bytes(raw)
                self.assertFalse(reader.extract_npc_death_accounting(bad,actors,weapons),(arch,key))
            bad=copy.copy(mach);bad.data=mach.data[:offset+10]
            self.assertFalse(reader.extract_npc_death_accounting(bad,actors,weapons))

    def test_dependency_identity(self):
        for arch,layouts in variants():
            mach,actors,weapons,*_=fixture(arch,layouts=layouts)
            for key in ['destruction','hostility','primary_weapon','guidance','provenance']:
                bad=copy.deepcopy(actors);bad['npc_initialization'][key]={}
                self.assertFalse(reader.extract_npc_death_accounting(mach,bad,weapons))
            for path in ['stats','selection','kind','hit']:
                bad=copy.deepcopy(actors);gun=copy.deepcopy(weapons)
                if path=='stats':bad['npc_initialization']['provenance']['stats_entry']['offset']+=2
                elif path=='selection':bad['npc_initialization']['guidance']['provenance']['selection']['offset']+=2
                elif path=='kind':bad['actors'][1]['actor_kind']=9
                else:gun['ordinary_hit_policy']['provenance']['normal_hit']['offset']+=2
                self.assertFalse(reader.extract_npc_death_accounting(mach,bad,gun))


ANDROID_NPC = {'destruction': {'a': 1}, 'hostility': {'a': 1}, 'primary_weapon': {'a': 1}, 'guidance': {'a': 1}}
ANDROID_ACTORS = {'npc_initialization': ANDROID_NPC, 'actors': [{'actor_kind': 8}] * 3}
ANDROID_WEAPONS = {'ordinary_hit_policy': {'a': 1}}


class AndroidDeathAccounting(unittest.TestCase):
    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        verify_android_proof(self, reader, lambda lib: reader.extract_npc_death_accounting(lib, ANDROID_ACTORS, ANDROID_WEAPONS), values='VALUES')
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            self.assertTrue(reader.extract_npc_death_accounting(lib, ANDROID_ACTORS, ANDROID_WEAPONS))
            cases = {key: ({**ANDROID_ACTORS, 'npc_initialization': {**ANDROID_NPC, key: {}}}, ANDROID_WEAPONS)
                     for key in ('destruction', 'hostility', 'primary_weapon', 'guidance')}
            cases.update({'other kind': ({**ANDROID_ACTORS, 'actors': [{'actor_kind': 8}, {'actor_kind': 9}, {'actor_kind': 8}]}, ANDROID_WEAPONS),
                          'no hit policy': (ANDROID_ACTORS, {'ordinary_hit_policy': {}}), 'no weapons': (ANDROID_ACTORS, {}), 'no actors': ({}, ANDROID_WEAPONS)})
            for name, (actors, weapons) in cases.items():
                self.assertEqual(reader.extract_npc_death_accounting(lib, actors, weapons), {}, name)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'npc_death_accounting_definitions.gd', values='VALUES')
