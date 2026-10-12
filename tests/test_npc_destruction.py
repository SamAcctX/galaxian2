"""Relocated compiler-layout fixtures without supplied archives or assets."""
import copy
import unittest
from types import SimpleNamespace
from gof2_content import npc_destruction as reader
from gof2_content.opening_npc_guidance import LAYOUTS as GUIDANCE


def variants():
    return [*reader.LAYOUTS.items(), ('x86_64', reader.MAC_ALTERNATE)]


def fixture(arch, shift=0, layouts=None, audio=None):
    layouts=reader.LAYOUTS[arch] if layouts is None else layouts
    rows=list(layouts.values())+list((audio or {}).values())
    low=min(row[0] for row in rows)-64
    high=max(row[0]+row[1] for row in rows)+64
    offset=128;origin=0x400000+shift;bias=4096
    data=bytearray(offset+high-low)
    for delta,size,raw in rows:data[offset+delta-low:offset+delta-low+size]=bytes.fromhex(raw)
    # Constants share the image mapping but belong to their named section.
    constants=[row[0] for key,row in layouts.items() if key in ['spin_constant','drift_multiplier','drift_base']] if arch=='x86_64' else []
    split=min(constants) if constants else high
    text={'segment':b'__TEXT','name':b'__text','address':origin,'offset':offset,'length':split-low}
    sections=[text]
    if constants:sections.append({'segment':b'__TEXT','name':b'__const','address':origin+split-low,'offset':offset+split-low,'length':high-split})
    m=SimpleNamespace(architecture=arch,slice_offset=bias,data=bytes(data),text=text,sections=sections)
    _,relative,size,_=GUIDANCE[arch]['selection']
    actors={'npc_initialization':{'guidance':{'actor_kind':8,'provenance':{'selection':{'offset':bias+offset+relative-low,'bytes':size}}},'construction':{'verified':True}}}
    return m,actors,offset,low


class DestructionTests(unittest.TestCase):
    def test_both_relocated_layouts(self):
        for arch,layouts in variants():
            for shift in [0,0x800000]:
                m,actors,*_=fixture(arch,shift,layouts)
                result=reader.extract_npc_destruction(m,actors)
                self.assertEqual({k:v for k,v in result.items() if k!='provenance'},reader.VALUES)
                self.assertEqual(len(result['provenance']),len(layouts))
                result['model_ids'].clear()
                self.assertEqual(reader.VALUES['model_ids'],[16821,16820])

    def test_changed_layouts_and_truncation(self):
        for arch,layouts in variants():
            m,actors,offset,low=fixture(arch,layouts=layouts)
            for key,(delta,_,_) in layouts.items():
                bad=copy.copy(m);raw=bytearray(m.data);raw[offset+delta-low]^=255;bad.data=bytes(raw)
                self.assertFalse(reader.extract_npc_destruction(bad,actors),(arch,key))
            bad=copy.copy(m);bad.data=m.data[:offset+10]
            self.assertFalse(reader.extract_npc_destruction(bad,actors))

    def test_missing_or_moved_anchor(self):
        for arch,layouts in variants():
            m,actors,*_=fixture(arch,layouts=layouts)
            for change in ['kind','selection','construction']:
                bad=copy.deepcopy(actors);npc=bad['npc_initialization']
                if change=='kind':npc['guidance']['actor_kind']=9
                elif change=='selection':npc['guidance']['provenance']['selection']['offset']+=2
                else:npc['construction']={}
                self.assertFalse(reader.extract_npc_destruction(m,bad))

    def test_audio_owners_and_changed_spans(self):
        for arch,layouts in variants():
            audio=reader.MAC_AUDIO_ALTERNATE if layouts is reader.MAC_ALTERNATE else reader.AUDIO_LAYOUTS[arch]
            m,actors,offset,low=fixture(arch,layouts=layouts,audio=audio)
            actors['npc_initialization']['destruction']=reader.extract_npc_destruction(m,actors)
            self.assertTrue(actors['npc_initialization']['destruction'])
            result=reader.extract_npc_destruction_audio(m,actors)
            self.assertEqual({k:v for k,v in result.items() if k!='provenance'},
                             {'initial_source_id':20,'breakup_source_ids':[18,19],
                              'position':'pre_motion','instance':'cached_event'})
            for key,(delta,_,_) in audio.items():
                bad=copy.copy(m);raw=bytearray(m.data);raw[offset+delta-low]^=255;bad.data=bytes(raw)
                self.assertFalse(reader.extract_npc_destruction_audio(bad,actors),(arch,key))
            for change in ['destruction','selection']:
                bad=copy.deepcopy(actors)
                if change=='destruction':bad['npc_initialization']['destruction']={}
                else:bad['npc_initialization']['guidance']['provenance']['selection']['offset']+=2
                self.assertFalse(reader.extract_npc_destruction_audio(m,bad))

    def test_audio_does_not_mix_mac_layouts(self):
        for main,other in [(reader.AUDIO_LAYOUTS['x86_64'],reader.MAC_AUDIO_ALTERNATE),
                           (reader.MAC_AUDIO_ALTERNATE,reader.AUDIO_LAYOUTS['x86_64'])]:
            mixed=copy.deepcopy(main)
            mixed['breakup_entry']=other['breakup_entry']
            m,actors,*_=fixture('x86_64',audio=mixed)
            actors['npc_initialization']['destruction']=reader.extract_npc_destruction(m,actors)
            self.assertTrue(actors['npc_initialization']['destruction'])
            self.assertFalse(reader.extract_npc_destruction_audio(m,actors))


ANDROID_ACTORS = {'npc_initialization': {'guidance': {'actor_kind': 8, 'provenance': {}}, 'construction': {'cargo_count_bound': 3},
                                         'destruction': copy.deepcopy(reader.VALUES)}}


class AndroidNpcDestructionTests(unittest.TestCase):
    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        verify_android_proof(self, reader, lambda lib: reader.extract_npc_destruction(lib, ANDROID_ACTORS), values='VALUES')
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            self.assertTrue(reader.extract_npc_destruction(lib, ANDROID_ACTORS))
            npc = ANDROID_ACTORS['npc_initialization']
            for name, changed in {'other kind': {**npc, 'guidance': {'actor_kind': 9}}, 'no construction': {**npc, 'construction': {}},
                                  'no guidance': {'construction': npc['construction']}}.items():
                self.assertEqual(reader.extract_npc_destruction(lib, {'npc_initialization': changed}), {}, name)
            self.assertEqual(reader.extract_npc_destruction(lib, {}), {})

    def test_android_audio_proofs(self):
        from android_fixture import layout_library
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        for shift in (0, 0x1000):
            image, layout, _ = layout_library(reader.ANDROID_AUDIO, shift)
            with patch.object(reader, 'ANDROID_AUDIO', layout):
                result = reader.extract_npc_destruction_audio(AndroidLibrary(image), ANDROID_ACTORS)
                self.assertEqual({k: v for k, v in result.items() if k != 'provenance'},
                                 {'initial_source_id': 20, 'breakup_source_ids': [18, 19], 'position': 'pre_motion', 'instance': 'cached_event'})
                self.assertEqual({k: v['offset'] - v['anchor'] for k, v in result['provenance'].items()}, {k: v[1] for k, v in layout.items()})
                for key, span in result['provenance'].items():
                    for index in {0, span['bytes'] - 1}:
                        raw = bytearray(image)
                        raw[span['offset'] + index] ^= 0xff
                        self.assertEqual(reader.extract_npc_destruction_audio(AndroidLibrary(bytes(raw)), ANDROID_ACTORS), {}, (key, index))
                lib = AndroidLibrary(image)
                other = copy.deepcopy(ANDROID_ACTORS)
                other['npc_initialization']['destruction'].update(death_sound=21, breakup_sound_base=17, breakup_sound_bound=3)
                self.assertEqual(reader.extract_npc_destruction_audio(lib, other)['breakup_source_ids'], [17, 18, 19])
                for name, actors in {'no destruction': {'npc_initialization': {'destruction': {}}}, 'no npc': {}}.items():
                    self.assertEqual(reader.extract_npc_destruction_audio(lib, actors), {}, name)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'npc_destruction_definitions.gd', values='VALUES')
        assert_native_android(self, reader, 'npc_destruction_definitions.gd', values='VALUES', layout='ANDROID_AUDIO')
