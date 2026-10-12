import copy
import unittest
from types import SimpleNamespace
from gof2_content import opening_player_flight as reader


def layouts():
    return [*reader.LAYOUTS.items(), ('x86_64', reader.MAC_ALTERNATE)]


def fixture(arch, shift=0, rows=None):
    rows=reader.LAYOUTS[arch] if rows is None else rows
    low=min(v[0] for v in rows.values())-32;high=max(v[0]+v[1] for v in rows.values())+32
    offset=128;bias=4096;data=bytearray(offset+high-low)
    for relative,size,raw in rows.values():data[offset+relative-low:offset+relative-low+size]=bytes.fromhex(raw)
    section={'segment':b'__TEXT','name':b'__text','address':0x400000+shift,'offset':offset,'length':high-low}
    mach=SimpleNamespace(architecture=arch,slice_offset=bias,data=bytes(data),text=section,sections=[section]);origin=bias+offset-low
    staging={'provenance':{'initial':{'offset':origin}},'player_motion':{'release_phase':4}}
    actors={'player_initialization':{'verified':True},'npc_initialization':{'initial_firing_allowed':True}}
    rotation={'provenance':[{'offset':origin+rows['rotation_anchor'][0]}]}
    response={'provenance':[{'offset':origin+rows['response_anchor'][0]}]}
    return mach,staging,actors,rotation,response,offset,low


class PlayerFlightTests(unittest.TestCase):
    def test_profiles_and_relocation(self):
        for arch,rows in layouts():
            for shift in [0,0x700000]:
                args=fixture(arch,shift,rows);data=reader.extract_opening_player_flight(*args[:5])
                self.assertEqual({k:v for k,v in data.items() if k!='provenance'},reader.VALUES)

    def test_every_changed_span_and_truncation(self):
        for arch,rows in layouts():
            m,s,a,r,p,o,low=fixture(arch,rows=rows)
            for key,(delta,_,_) in rows.items():
                bad=copy.copy(m);raw=bytearray(m.data);raw[o+delta-low]^=255;bad.data=bytes(raw)
                self.assertFalse(reader.extract_opening_player_flight(bad,s,a,r,p),key)
            m.data=m.data[:o+16]
            self.assertFalse(reader.extract_opening_player_flight(m,s,a,r,p))

    def test_dependency_disconnects(self):
        for arch,rows in layouts():
            for key in ['release','player','permission','rotation','response']:
                m,s,a,r,p,*_=fixture(arch,rows=rows)
                if key=='release':s['player_motion']['release_phase']=3
                elif key=='player':a['player_initialization']={}
                elif key=='permission':a['npc_initialization']['initial_firing_allowed']=False
                elif key=='rotation':r['provenance'][0]['offset']+=2
                else:p['provenance'][0]['offset']+=2
                self.assertFalse(reader.extract_opening_player_flight(m,s,a,r,p),key)


ANDROID_PARENTS = ({'player_motion': {'release_phase': 4}}, {'player_initialization': {'ship': 1}, 'npc_initialization': {'initial_firing_allowed': True}},
                   {'rotation_order': 'local_x_y'}, {'mode': 'elapsed'})


class AndroidPlayerFlight(unittest.TestCase):
    def test_android_proofs(self):
        from android_fixture import verify_android_proof
        verify_android_proof(self, reader, lambda lib: reader.extract_opening_player_flight(lib, *ANDROID_PARENTS))

    def test_android_parents(self):
        import copy
        from unittest.mock import patch
        from android_fixture import layout_library
        from gof2_content.android_library import AndroidLibrary
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            self.assertTrue(reader.extract_opening_player_flight(lib, *ANDROID_PARENTS))
            for index, path, value in [(0, ('player_motion', 'release_phase'), 5), (0, None, {}), (1, ('player_initialization',), {}),
                                       (1, ('npc_initialization', 'initial_firing_allowed'), False), (1, None, {}), (2, None, {}), (3, None, {})]:
                parents = copy.deepcopy(list(ANDROID_PARENTS))
                if path is None:
                    parents[index] = value
                else:
                    target = parents[index]
                    for key in path[:-1]:
                        target = target[key]
                    target[path[-1]] = value
                self.assertEqual(reader.extract_opening_player_flight(lib, *parents), {}, (index, path))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'opening_player_flight_definitions.gd')
