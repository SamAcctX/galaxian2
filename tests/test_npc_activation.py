"""Relocated activation vtables and independent cue/constructor link failures."""
import copy
import struct
import unittest
from gof2_content import npc_activation as reader
from gof2_content.npc_initialization import extract_npc_initialization
from test_npc_initialization import fixture as initialization_fixture
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def fixture(mac, shift=0):
    m,f,_=initialization_fixture(mac,shift)
    initial=extract_npc_initialization(m,f,m.text['address']+5800)
    assert initial
    origin=m.text['address']; data=bytearray(m.data)
    data.extend(bytes(2000))
    cue=6000; table_init=4700+(0x51 if mac else 0x62); method=6400; vtable=9000
    def block(at,spec,values):
        body,fields=expand(spec)
        for key,(p,n) in fields.items():
            raw=values.get(key,bytes(n));assert len(raw)==n
            body[p:p+n]=raw
        data[256+at:256+at+len(body)]=body
        return fields
    spec=reader.MAC_PAN2.replace('50c30000',' {spatial:4} ') if mac else reader.ARM_PAN2
    block(cue,spec,{'spatial':struct.pack('<i',43210)} if mac else {'word_5a':arm_wide(43210,10)})
    if mac:
        block(table_init,reader.MAC_TABLE,{'table':struct.pack('<i',vtable-table_init-7)})
    else:
        delta=vtable-table_init-24
        block(table_init,reader.ARM_TABLE,{'low':arm_wide(delta&65535,1),'high':arm_wide(delta>>16,1,True)})
    spec=reader.MAC_ACTIVATE if mac else reader.ARM_ACTIVATE
    _,fields=expand(spec);p,n=fields['setter']
    block(method,spec,{'setter':struct.pack('<i',5900-method-p-n) if mac else branch(origin+method+p,origin+5900)})
    slot=vtable+(24 if mac else 12)
    struct.pack_into('<Q' if mac else '<I',data,256+slot,origin+method+(0 if mac else 1))
    m.sections.append({'name':b'__const','segment':b'__DATA','address':origin+vtable,'offset':256+vtable,'length':100})
    m.data=bytes(data)
    actors={'actors':[{'actor_id':i} for i in range(3)],'npc_initialization':initial}
    camera={'pan':{'engagement_after_event_finished':7},'provenance':{'pan2':{'offset':m.slice_offset+256+cue,'bytes':189 if mac else 190}}}
    return m,actors,camera


class NPCActivation(unittest.TestCase):
    def test_relocation_and_changed_spatial_range(self):
        for mac in [True,False]:
            for shift in [0,0x500000]:
                m,a,c=fixture(mac,shift)
                r=reader.extract_npc_activation(m,a,c)
                self.assertTrue(r,(mac,shift))
                self.assertEqual(r['spatial_half_extent'],43210)
                self.assertEqual(r['actor_ids'],[0,1,2])
                self.assertEqual((r['after_event_finished'],r['phase'],r['active'],r['actor_mode']),(7,3,True,1))

    def test_broken_provenance_and_links(self):
        for mac in [True,False]:
            m,a,c=fixture(mac)
            result=reader.extract_npc_activation(m,a,c)
            self.assertTrue(result)
            for key,span in result['provenance'].items():
                damaged=copy.copy(m);data=bytearray(m.data)
                data[span['offset']-m.slice_offset]^=255
                damaged.data=bytes(data)
                self.assertFalse(reader.extract_npc_activation(damaged,a,c),(mac,key))
            for key in ['activity_setter','actor_wrapper']:
                bad=copy.deepcopy(a);bad['npc_initialization']['provenance'][key]['offset']+=2
                self.assertFalse(reader.extract_npc_activation(m,bad,c))
            truncated=copy.copy(m);truncated.data=m.data[:256+9014]
            self.assertFalse(reader.extract_npc_activation(truncated,a,c))

    def test_source_context_is_required(self):
        for mac in [True,False]:
            m,a,c=fixture(mac)
            for bad in ['population','active','event','empty','section','thumb']:
                mm=copy.deepcopy(m);aa=copy.deepcopy(a);cc=copy.deepcopy(c)
                if bad=='population':aa['actors'][2]['actor_id']=1
                if bad=='active':aa['npc_initialization']['initial_active']=True
                if bad=='event':cc['pan']['engagement_after_event_finished']=6
                if bad=='empty':aa['npc_initialization']={}
                if bad=='section':mm.sections[-1]['segment']=b'__TEXT'
                if bad=='thumb':
                    if mac:continue
                    data=bytearray(mm.data);data[256+9012]&=254;mm.data=bytes(data)
                self.assertFalse(reader.extract_npc_activation(mm,aa,cc),(mac,bad))

if __name__=='__main__':unittest.main()


ANDROID_ACTORS = {'actors': [{'actor_id': i} for i in range(3)], 'npc_initialization': {'initial_active': False}}
ANDROID_CAMERA = {'pan': {'engagement_after_event_finished': 5}}


def android_extract(actors=ANDROID_ACTORS, camera=ANDROID_CAMERA, event='0x14', slot='0x10', spatial='0x1234', loop=12, vtable=None, **changes):
    """Synthetic Android cue, constructor and vtable: message 5, slot 4, spatial 0x1234."""
    from android_text_fixture import fill, text_library
    from gof2_content.npc_initialization import ANDROID_ACTIVITY
    cue = fill(reader.ANDROID_CUE, blank='#end', event=event, slot=slot, spatial=spatial, loop='#loop').strip().splitlines()
    functions = {
        '_ZN11LevelScript7processEi': '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', *cue[:loop], 'loop:', *cue[loop:], 'end:', 'bx lr']),
        '_ZN13PlayerFighterC1EiiP6PlayerP10AEGeometryfffb': changes.pop('fighter', '\n'.join([
            'push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', 'mov r6, r0', fill(reader.ANDROID_TABLE, blank='&_ZTV13PlayerFighter'), 'bx lr'])),
        '_ZN13PlayerFighter5awakeEv': fill(reader.ANDROID_ACTIVATE, setter='_ZN6Player9setActiveEb'),
        '_ZN6Player9setActiveEb': ANDROID_ACTIVITY}
    functions.update(changes)
    table = vtable or [0, 0, 'f0', 'f1', 'f2', 'f3', '_ZN13PlayerFighter5awakeEv']
    lib, addresses = text_library({k: v for k, v in functions.items() if v is not None},
                                  {'_ZTV13PlayerFighter': table, '_ZTV8KIPlayer': [0, 0, 'f0', 'f1', 'f2', 'f3', '_ZN13PlayerFighter5awakeEv']})
    return reader.extract_npc_activation(lib, actors, camera), lib, addresses


class AndroidNPCActivation(unittest.TestCase):
    def test_named_cue_vtable_and_spans(self):
        from gof2_content.android_shapes import objects
        result, lib, addresses = android_extract()
        self.assertEqual({k: v for k, v in result.items() if k != 'provenance'},
                         {'after_event_finished': 5, 'phase': 3, 'actor_ids': [0, 1, 2], 'active': True, 'actor_mode': 1, 'spatial_half_extent': 0x1234})
        p = result['provenance']
        self.assertEqual((p['cue']['offset'] - addresses['_ZN11LevelScript7processEi'], p['cue']['bytes']), (4, 98))
        self.assertEqual((p['table_initializer']['offset'] - addresses['_ZN13PlayerFighterC1EiiP6PlayerP10AEGeometryfffb'], p['table_initializer']['bytes']), (6, 24))
        self.assertEqual((p['activation']['offset'], p['activity_setter']['offset']), (addresses['_ZN13PlayerFighter5awakeEv'], addresses['_ZN6Player9setActiveEb']))
        rel = lib.elf_sections['.rel.dyn']
        # The vtable's slot 4 entry (word 6) and the GOT word; each relocation entry starts with the word's address.
        slot = int.from_bytes(lib.data[p['virtual_activation']['offset']:p['virtual_activation']['offset'] + 4], 'little')
        self.assertEqual(slot, objects(lib)['_ZTV13PlayerFighter'] + 24)
        for key in ('virtual_activation', 'table_reference'):
            self.assertTrue(rel['offset'] <= p[key]['offset'] < rel['offset'] + rel['length'] and p[key]['bytes'] == 8, key)

    def test_each_broken_rule_is_unsupported(self):
        from android_text_fixture import fill
        table = fill(reader.ANDROID_TABLE, blank='&_ZTV13PlayerFighter')
        fighter = lambda *parts: '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', *parts, 'bx lr'])
        cases = {
            'no initialization': dict(actors={'actors': ANDROID_ACTORS['actors'], 'npc_initialization': {}}),
            'active actors': dict(actors={'actors': ANDROID_ACTORS['actors'], 'npc_initialization': {'initial_active': True}}),
            'other actors': dict(actors={'actors': ANDROID_ACTORS['actors'][:2], 'npc_initialization': {'initial_active': False}}),
            'no camera': dict(camera={}),
            'other message': dict(camera={'pan': {'engagement_after_event_finished': 6}}),
            'zero spatial': dict(spatial='0'),
            'loop elsewhere': dict(loop=11),
            'no cue': {'_ZN11LevelScript7processEi': 'bx lr'},
            'no table': dict(fighter=fighter('mov r6, r0')),
            'this changed': dict(fighter=fighter('movs r0, #0', 'mov r6, r0', table)),
            'other table': dict(fighter=fighter('mov r6, r0', table.replace('&_ZTV13PlayerFighter', '&_ZTV8KIPlayer'))),
            'slot not relocated': dict(vtable=[0, 0, 'f0', 'f1', 'f2', 'f3', 0]),
            'activation shape': {'_ZN13PlayerFighter5awakeEv': fill(reader.ANDROID_ACTIVATE, setter='_ZN6Player9setActiveEb').replace('movs r5, #1', 'movs r5, #5')},
            'setter shape': {'_ZN6Player9setActiveEb': 'strb.w r1, [r0, #0xc1]\nbx lr'},
        }
        for name, changes in cases.items():
            with self.subTest(name):
                self.assertEqual(android_extract(**changes)[0], {})
