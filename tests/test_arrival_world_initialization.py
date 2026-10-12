"""Relocated Mac rescue world declarations and rejection at each source boundary.

Further iOS validation is deferred by the project's current development priority.
"""
import copy
import unittest
from declaration_fixture import literal_fixture
from gof2_content import arrival_world_initialization as reader


def fixture(rows,shift=0):
    constants=[k for k,v in rows.items() if v[0]=='__const']
    mach,origin,offset,low=literal_fixture('x86_64',{k:v[1:] for k,v in rows.items()},shift,constants)
    arrival={'campaign_cursor':1,'actor_kind':3,'actor_hull_id':30,
             'provenance':{'actor':{'offset':origin,'bytes':315}}}
    actors={'npc_initialization':{'world_initialization':{'weapon_item_sequence':[0,19],'weapon_effect_capacity':4}},
            'player_initialization':{'flight_cache':{'quest_kind':11}}}
    return mach,arrival,actors,{'supported':True},{'supported':True},offset,low


class ArrivalWorldInitializationTests(unittest.TestCase):
    def test_relocation_and_declarative_output(self):
        for layout in [reader.LAYOUTS['x86_64'],reader.MAC_ALTERNATE]:
            for shift in [0,0x1200000]:
                m,a,n,c,e,*_=fixture(layout,shift)
                data=reader.extract_arrival_world_initialization(m,a,n,c,e)
                self.assertEqual({k:v for k,v in data.items() if k!='provenance'},reader.VALUES)
                for key,span in data['provenance'].items():
                    self.assertEqual(set(span),{'offset','bytes'})
                    self.assertEqual(span['offset'],a['provenance']['actor']['offset']+layout[key][1])
                data['weapon_item_sequence'].clear()
                self.assertEqual(reader.extract_arrival_world_initialization(m,a,n,c,e)['weapon_item_sequence'],[0,25])

    def test_altered_source_and_missing_sections(self):
        for layout in [reader.LAYOUTS['x86_64'],reader.MAC_ALTERNATE]:
            m,a,n,c,e,offset,low=fixture(layout)
            for key,(_,delta,size,_) in layout.items():
                for edge in [0,size-1]:
                    bad=copy.copy(m);raw=bytearray(m.data);raw[offset+delta-low+edge]^=128;bad.data=bytes(raw)
                    self.assertEqual(reader.extract_arrival_world_initialization(bad,a,n,c,e),{},(key,edge))
            m.sections=[s for s in m.sections if s['name']!=b'__const']
            self.assertEqual(reader.extract_arrival_world_initialization(m,a,n,c,e),{})

    def test_context_and_truncation(self):
        for layout in [reader.LAYOUTS['x86_64'],reader.MAC_ALTERNATE]:
            for name in ['cursor','hull','kind','origin','size','shared','quest','capacity','construction','environment','truncated','architecture']:
                m,a,n,c,e,*_=fixture(layout)
                if name in ['cursor','hull','kind']:a[{'cursor':'campaign_cursor','hull':'actor_hull_id','kind':'actor_kind'}[name]]=-1
                elif name=='origin':a['provenance']['actor']['offset']+=2
                elif name=='size':a['provenance']['actor']['bytes']+=1
                elif name=='shared':n['npc_initialization'].clear()
                elif name=='quest':n['player_initialization']['flight_cache']['quest_kind']=183
                elif name=='capacity':n['npc_initialization']['world_initialization']['weapon_effect_capacity']=5
                elif name=='construction':c.clear()
                elif name=='environment':e.clear()
                elif name=='truncated':m.data=m.data[:128]
                else:m.architecture='unsupported'
                self.assertEqual(reader.extract_arrival_world_initialization(m,a,n,c,e),{},name)


ANDROID_ARRIVAL = {'campaign_cursor': 1, 'actor_kind': 3, 'actor_hull_id': 30}
ANDROID_ACTORS = {'npc_initialization': {'world_initialization': {'weapon_item_sequence': [0, 19], 'weapon_effect_capacity': 4}},
                  'player_initialization': {'flight_cache': {'quest_kind': 11}}}


class AndroidArrivalWorldInitializationTests(unittest.TestCase):
    def extract(self, lib, arrival=ANDROID_ARRIVAL, actors=ANDROID_ACTORS, construction={'present': True}, environment={'present': True}):
        return reader.extract_arrival_world_initialization(lib, arrival, actors, construction, environment)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, reader, self.extract, values='VALUES')
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            data = self.extract(lib)
            data['weapon_item_sequence'][1] = 0
            self.assertEqual(reader.VALUES['weapon_item_sequence'], [0, 25])
            shared = ANDROID_ACTORS['npc_initialization']['world_initialization']
            def actors(shared=shared, cache={'quest_kind': 11}):
                return {'npc_initialization': {'world_initialization': shared}, 'player_initialization': {'flight_cache': cache}}
            for name, changes in {'other cursor': dict(arrival={**ANDROID_ARRIVAL, 'campaign_cursor': 2}),
                                  'other kind': dict(arrival={**ANDROID_ARRIVAL, 'actor_kind': 2}),
                                  'other hull': dict(arrival={**ANDROID_ARRIVAL, 'actor_hull_id': 31}),
                                  'no construction': dict(construction={}), 'no environment': dict(environment={}),
                                  'no shared world': dict(actors=actors(shared={})),
                                  'other quest': dict(actors=actors(cache={'quest_kind': 12})),
                                  'other items': dict(actors=actors(shared={**shared, 'weapon_item_sequence': [0, 25]})),
                                  'other capacity': dict(actors=actors(shared={**shared, 'weapon_effect_capacity': 3})),
                                  'no cache': dict(actors={'npc_initialization': {'world_initialization': shared}})}.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'arrival_world_initialization_definitions.gd', values='VALUES')
        # Gun::setIndex's table holds 14606 for item 25.
        self.assertEqual(int.from_bytes(bytes.fromhex(reader.ANDROID['effect_model_25'][3]), 'little'), reader.VALUES['weapon_effect_sequence'][1])
