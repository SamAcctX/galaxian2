"""Relocated synthetic route declarations and source links, without game assets."""
import copy
import struct
import unittest
from gof2_content import npc_routes as reader
from test_opening_npc_guidance import fixture as base_fixture
from test_font_selection import expand
from test_ship_models import branch


def fixture(mac,shift=0):
    m,a,old,_,offset=base_fixture(mac,shift);data=bytearray(m.data);arch=m.architecture
    origin=m.text['address'];positions={};fields={}
    bases={'constructor':4000,'update':20000,'wrapper':10000,'route':11000,'loop':12000,'copy':13000,'advance_wrapper':14000,'advance':15000}
    def write(at,raw):data[offset+at:offset+at+len(raw)]=raw
    patterns={k:v[3] for k,v in reader.LAYOUTS[arch].items()}
    patterns['selection']=reader.GUIDANCE_LAYOUTS[arch]['selection'][3]
    for key,pattern in patterns.items():
        if key=='selection':at=old['selection']
        else:base,delta,_,_=reader.LAYOUTS[arch][key];at=bases[base]+delta
        positions[key]=at;raw,fields[key]=expand(pattern);write(at,raw)
    destinations={}
    for n,group in enumerate(reader.SAME_TARGETS[arch].values()):
        for field in group:destinations[field]=40000+8*n
    destinations['selection.'+('call_33' if mac else 'call_3c')]=destinations[reader.SAME_TARGETS[arch]['random'][0]]
    for base,(key,field) in reader.LINKS[arch].items():
        name=key+'.'+field;destinations[name]=bases[base]
        for group in reader.SAME_TARGETS[arch].values():
            if name in group:
                for linked in group:destinations[linked]=bases[base]
    for name,destination in destinations.items():
        key,field=name.split('.');at=positions[key];p,n=fields[key][field]
        write(at+p,struct.pack('<i',destination-at-p-n) if mac else branch(origin+at+p,origin+destination))
    literals={}
    for name,value in reader.LITERALS[arch].items():
        key,field=name.split('.');at=positions[key];p,n=fields[key][field]
        target=(50000 if mac else 15600)+(0 if value>0 else 4)
        if mac:raw=struct.pack('<i',target-at-p-n)
        else:
            # The two ARM loads use S0 and S4 respectively.
            reg=0 if value>0 else 4;delta=target-((at+p+4)&~3)
            assert 0<=delta<=1020 and delta%4==0
            raw=struct.pack('<HH',0xed9f,((reg//2)<<12)|0xa00|delta//4)
        write(at+p,raw);write(target,struct.pack('<f',value));literals[name]=target
    initial=a['npc_initialization'];initial['holding']={'available':True}
    initial['guidance']={'provenance':{'selection':{'offset':m.slice_offset+offset+positions['selection'],'bytes':len(expand(patterns['selection'])[0])}}}
    m.data=bytes(data)
    return m,a,positions,literals,fields,offset


class RouteTests(unittest.TestCase):
    def test_both_independent_relocated_layouts(self):
        for mac in [False,True]:
            for shift in [0,0x600000]:
                m,a,*_=fixture(mac,shift);result=reader.extract_npc_routes(m,a)
                self.assertTrue(result,(mac,shift))
                self.assertEqual({k:v for k,v in result.items() if k!='provenance'},reader.VALUES)
                self.assertEqual(len(result['provenance']),17 if mac else 18)

    def test_fixed_declarations_links_and_literals_reject_changes(self):
        for mac in [False,True]:
            m,a,positions,literals,fields,offset=fixture(mac)
            for key,at in {**positions,**literals,'virtual_update':51000}.items():
                # copy_plain starts with a masked allocator argument only on neither architecture.
                changed=copy.copy(m);data=bytearray(m.data);data[offset+at]^=255;changed.data=bytes(data)
                self.assertFalse(reader.extract_npc_routes(changed,a),(mac,key))
            for field in reader.SAME_TARGETS[m.architecture]['random']:
                key,name=field.split('.');at=positions[key]+fields[key][name][0]
                data=bytearray(m.data);data[offset+at:offset+at+4]=struct.pack('<i',1234) if mac else branch(m.text['address']+at,m.text['address']+39000)
                changed=copy.copy(m);changed.data=bytes(data)
                self.assertFalse(reader.extract_npc_routes(changed,a),(mac,field))
            for key in ['flight','guidance','holding']:
                changed=copy.deepcopy(a);changed['npc_initialization'][key]={}
                self.assertFalse(reader.extract_npc_routes(m,changed))
            changed=copy.deepcopy(a);changed['actors'][1]['hull_catalogue_id']=2
            self.assertFalse(reader.extract_npc_routes(m,changed))

    def test_bounds_sections_and_ambiguity(self):
        for mac in [False,True]:
            m,a,*_=fixture(mac)
            changed=copy.copy(m);changed.data=m.data[:51257]
            self.assertFalse(reader.extract_npc_routes(changed,a))
            changed=copy.deepcopy(m);changed.sections.append(copy.copy(m.text))
            self.assertFalse(reader.extract_npc_routes(changed,a))
            changed=copy.deepcopy(m);changed.sections[-1]['segment']=b'__TEXT'
            self.assertFalse(reader.extract_npc_routes(changed,a))
            changed=copy.copy(m);changed.architecture='unknown'
            self.assertFalse(reader.extract_npc_routes(changed,a))


ANDROID_ACTORS = {'actors': [{'actor_kind': 8, 'hull_catalogue_id': h} for h in (2, 23, 2)],
                  'npc_initialization': {'holding': {'actor_mode': 5}, 'flight': {'pi': 3.14}, 'guidance': {'actor_kind': 8}}}


class AndroidNpcRoutes(unittest.TestCase):
    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        verify_android_proof(self, reader, lambda lib: reader.extract_npc_routes(lib, ANDROID_ACTORS), values='VALUES')
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            self.assertTrue(reader.extract_npc_routes(lib, ANDROID_ACTORS))
            initial = ANDROID_ACTORS['npc_initialization']
            cases = {**{'no ' + key: {**ANDROID_ACTORS, 'npc_initialization': {k: v for k, v in initial.items() if k != key}}
                        for key in initial},
                     'other kinds': {**ANDROID_ACTORS, 'actors': [{'actor_kind': 9, 'hull_catalogue_id': h} for h in (2, 23, 2)]},
                     'other hulls': {**ANDROID_ACTORS, 'actors': [{'actor_kind': 8, 'hull_catalogue_id': 2} for _ in range(3)]},
                     'no initialization': {'actors': ANDROID_ACTORS['actors']}}
            for name, actors in cases.items():
                self.assertEqual(reader.extract_npc_routes(lib, actors), {}, name)

    def test_android_native_spans(self):
        # The game pins the route values through its own constants; the spans must match the importer's.
        import json, re
        from pathlib import Path
        source = (Path(__file__).resolve().parents[1] / 'game/src/content/npc_route_definitions.gd').read_text()
        found = re.findall(r'^const ANDROID_SPANS :?= (.+)$', source, re.M)
        self.assertEqual([json.loads(row) for row in found], [{k: [v[1], v[2]] for k, v in reader.ANDROID.items()}])


if __name__=='__main__':unittest.main()
