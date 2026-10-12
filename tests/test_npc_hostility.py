"""Synthetic declaration relocation and rejected fresh-hostility source changes."""
import copy
import struct
import unittest
from gof2_content import npc_hostility as reader
from test_opening_npc_guidance import fixture as base_fixture
from test_font_selection import expand
from test_ship_models import branch


def fixture(mac,shift=0):
    m,actors,_,_,offset=base_fixture(mac,shift);data=bytearray(m.data)
    origin=m.text['address'];bases={'stats':32000,'base':35000,'fresh':38000,'update':20000}
    positions={};fields_by_block={}
    def extent(at,n):return {'offset':m.slice_offset+offset+at,'bytes':n}
    def write(at,raw):data[offset+at:offset+at+len(raw)]=raw
    for key,(base,delta,size,pattern) in reader.LAYOUTS[m.architecture].items():
        at=bases[base]+delta;positions[key]=at
        raw,fields=expand(pattern);fields_by_block[key]=fields
        if key=='overrides':
            for i,(name,(field,code)) in enumerate(reader.GETTERS[m.architecture].items()):
                target=40000+i*100;p,n=fields[field];positions[name]=target
                raw[p:p+n]=struct.pack('<i',target-at-p-n) if mac else branch(origin+at+p,origin+target)
                write(target,bytes.fromhex(code))
            if mac:
                for field in ['ref_0','ref_13']:
                    p,n=fields[field];raw[p:p+n]=struct.pack('<i',44000-at-p-n)
            else:
                for field,code in [('ref_0','46f6fc60'),('ref_8','c0f22100')]:
                    p,n=fields[field];raw[p:p+n]=bytes.fromhex(code)
        elif key=='base_flags' and not mac:
            p,n=fields['ref_6'];raw[p:p+n]=bytes.fromhex('c0f22401')
        write(at,raw)
    initial=actors['npc_initialization']
    initial['provenance'].update({'stats_entry':extent(bases['stats'],20 if mac else 28),
        'point_geometry':extent(bases['base']+(0x21e if mac else 0x1a6),4 if mac else 26)})
    initial['primary_weapon']['provenance']['fresh_level']=extent(bases['fresh'],11 if mac else 42)
    initial['guidance']={'provenance':{'virtual_update':copy.deepcopy(initial['flight']['provenance']['virtual_update'])}}
    initial['holding']={'available':True};initial['activation']={'available':True}
    m.data=bytes(data)
    return m,actors,positions,fields_by_block,offset


class HostilityTests(unittest.TestCase):
    def test_both_relocated_declarations(self):
        for mac in [False,True]:
            for shift in [0,0x600000]:
                m,a,_,_,_=fixture(mac,shift);result=reader.extract_npc_hostility(m,a)
                self.assertTrue(result,(mac,shift))
                self.assertEqual({k:v for k,v in result.items() if k!='provenance'},reader.VALUES)
                self.assertEqual(len(result['provenance']),8)

    def test_reject_changed_flags_branches_getters_and_anchors(self):
        for mac in [False,True]:
            m,a,positions,fields,offset=fixture(mac)
            for key,at in positions.items():
                changed=copy.copy(m);raw=bytearray(m.data);raw[offset+at]^=255;changed.data=bytes(raw)
                self.assertFalse(reader.extract_npc_hostility(changed,a),(mac,key))
            for key in ['flight','guidance','holding','activation','primary_weapon']:
                changed=copy.deepcopy(a);changed['npc_initialization'][key]={}
                self.assertFalse(reader.extract_npc_hostility(m,changed),(mac,key))
            for key in ['stats_entry','point_geometry']:
                changed=copy.deepcopy(a);changed['npc_initialization']['provenance'][key]['offset']+=2
                self.assertFalse(reader.extract_npc_hostility(m,changed),(mac,key))
            changed=copy.deepcopy(a);changed['actors'][1]['actor_kind']=9
            self.assertFalse(reader.extract_npc_hostility(m,changed))
            for field in (['ref_13','call_41','call_5e'] if mac else ['ref_8','call_48','call_64']):
                changed=copy.copy(m);raw=bytearray(m.data)
                raw[offset+positions['overrides']+fields['overrides'][field][0]]^=255;changed.data=bytes(raw)
                self.assertFalse(reader.extract_npc_hostility(changed,a),(mac,field))

    def test_reject_truncation_and_wrong_virtual_section(self):
        for mac in [False,True]:
            m,a,_,_,offset=fixture(mac)
            changed=copy.copy(m);changed.data=m.data[:offset+51002]
            self.assertFalse(reader.extract_npc_hostility(changed,a))
            changed=copy.deepcopy(m);changed.sections[-1]['segment']=b'__TEXT'
            self.assertFalse(reader.extract_npc_hostility(changed,a))


ANDROID_ACTORS = {'actors': [{'actor_id': i, 'actor_kind': 8, 'hull_catalogue_id': h} for i, h in enumerate((2, 23, 2))],
                  'npc_initialization': {'guidance': {'a': 1}, 'holding': {'a': 1}, 'activation': {'a': 1}}}


def android_extract(actors=ANDROID_ACTORS, kind='8', globals_=('&_ZN7Globals6statusE',) * 3, slot=13, **changes):
    """Synthetic Android constructors, Status::resetGame and PlayerFighter::update."""
    from android_text_fixture import fill, text_library
    from gof2_content.npc_initialization import ANDROID_ACTOR_FLAGS, ANDROID_FLAGS
    kind_block = fill(reader.ANDROID_KIND, blank='BLANK', kind=kind).replace('b BLANK', 'b #out').replace('=BLANK', '=' + globals_[0])
    overrides = fill(reader.ANDROID_OVERRIDES, blank='BLANK', special_getter='_ZN6Player11turnedEnemyEv', neutral_getter='_ZN6Player14isAlwaysFriendEv')
    overrides = overrides.replace('=BLANK', '=' + globals_[1], 1).replace('=BLANK', '=' + globals_[2])
    push = 'push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}'
    functions = {
        '_ZN13PlayerFighter6updateEi': changes.pop('update', '\n'.join([push, 'mov r4, r0', kind_block, overrides, 'out:', 'bx lr'])),
        '_ZN6PlayerC1Eiiiii': changes.pop('stats', '\n'.join([push, 'mov r4, r0', ANDROID_FLAGS, 'bx lr'])),
        '_ZN8KIPlayerC2EiiP6PlayerP10AEGeometryfffb': changes.pop('base', '\n'.join([push, 'mov r5, r0', fill(ANDROID_ACTOR_FLAGS), 'bx lr'])),
        '_ZN6Status9resetGameEv': changes.pop('fresh', '\n'.join([push, 'mov r8, r0', reader.ANDROID_FRESH, 'bx lr'])),
        '_ZN6Player11turnedEnemyEv': reader.ANDROID_GETTERS['special_getter'],
        '_ZN6Player14isAlwaysFriendEv': reader.ANDROID_GETTERS['neutral_getter']}
    functions.update(changes)
    table = [0, 0] + ['f%d' % i for i in range(14)]
    table[2 + slot] = '_ZN13PlayerFighter6updateEi'
    lib, addresses = text_library({k: v for k, v in functions.items() if v is not None},
                                  {'_ZTV13PlayerFighter': table, '_ZN7Globals6statusE': [0], '_ZN7Globals7optionsE': [0]})
    return reader.extract_npc_hostility(lib, actors), lib, addresses


class AndroidNPCHostility(unittest.TestCase):
    def test_named_blocks_give_values_and_spans(self):
        result, lib, addresses = android_extract()
        self.assertEqual({k: v for k, v in result.items() if k != 'provenance'}, reader.VALUES)
        p = result['provenance']
        found = {k: (p[k]['offset'] - addresses[name], p[k]['bytes']) for k, name in [
            ('stats_flags', '_ZN6PlayerC1Eiiiii'), ('base_flags', '_ZN8KIPlayerC2EiiP6PlayerP10AEGeometryfffb'),
            ('fresh_override', '_ZN6Status9resetGameEv'), ('kind', '_ZN13PlayerFighter6updateEi'), ('overrides', '_ZN13PlayerFighter6updateEi'),
            ('special_getter', '_ZN6Player11turnedEnemyEv'), ('neutral_getter', '_ZN6Player14isAlwaysFriendEv')]}
        self.assertEqual(found, {'stats_flags': (6, 84), 'base_flags': (6, 58), 'fresh_override': (6, 54), 'kind': (6, 72),
                                 'overrides': (78, 98), 'special_getter': (0, 6), 'neutral_getter': (0, 6)})
        rel = lib.elf_sections['.rel.dyn']
        self.assertTrue(rel['offset'] <= p['virtual_update']['offset'] < rel['offset'] + rel['length'] and p['virtual_update']['bytes'] == 8)

    def test_each_broken_rule_is_unsupported(self):
        from android_text_fixture import fill
        from gof2_content.npc_initialization import ANDROID_ACTOR_FLAGS, ANDROID_FLAGS
        initial = ANDROID_ACTORS['npc_initialization']
        push = 'push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}'
        cases = {
            **{'no ' + key: dict(actors=dict(ANDROID_ACTORS, npc_initialization=dict(initial, **{key: {}}))) for key in ('guidance', 'holding', 'activation')},
            'other actor ids': dict(actors=dict(ANDROID_ACTORS, actors=[dict(a, actor_id=a['actor_id'] + 1) for a in ANDROID_ACTORS['actors']])),
            'other kinds': dict(actors=dict(ANDROID_ACTORS, actors=[dict(a, actor_kind=7) for a in ANDROID_ACTORS['actors']])),
            'other hulls': dict(actors=dict(ANDROID_ACTORS, actors=[dict(a, hull_catalogue_id=2) for a in ANDROID_ACTORS['actors']])),
            'other slot': dict(slot=12),
            'no stats flags': dict(stats=push + '\nbx lr'),
            'no base flags': dict(base=push + '\nbx lr'),
            'no fresh override': dict(fresh=push + '\nbx lr'),
            'no update blocks': dict(update=push + '\nbx lr'),
            'other kind': dict(kind='6'),
            'stats this changed': dict(stats='\n'.join([push, 'movs r0, #0', 'mov r4, r0', ANDROID_FLAGS, 'bx lr'])),
            'base this lost': dict(base='\n'.join([push, 'mov r5, r0', 'movs r5, #0', fill(ANDROID_ACTOR_FLAGS), 'bx lr'])),
            'status this changed': dict(fresh='\n'.join([push, 'mov r8, r1', reader.ANDROID_FRESH, 'bx lr'])),
            **{'other global %d' % n: dict(globals_=tuple('&_ZN7Globals7optionsE' if i == n else '&_ZN7Globals6statusE' for i in range(3))) for n in range(3)},
            'special getter shape': {'_ZN6Player11turnedEnemyEv': 'ldrb.w r0, [r0, #0xe1]\nbx lr'},
            'neutral getter shape': {'_ZN6Player14isAlwaysFriendEv': 'ldrb.w r0, [r0, #0xec]\nbx lr'},
        }
        for name, changes in cases.items():
            with self.subTest(name):
                self.assertEqual(android_extract(**changes)[0], {})
