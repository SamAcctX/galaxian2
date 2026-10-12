"""Holding-mode recognition, linked predicates and relocation without originals."""
import copy
import struct
import unittest
from gof2_content import npc_holding as reader
from test_opening_npc_guidance import fixture as base_fixture
from test_font_selection import expand
from test_ship_models import branch


def fixture(mac,shift=0,alternate=False):
    m,actors,_,_,offset=base_fixture(mac,shift);data=bytearray(m.data)
    origin=m.text['address'];positions={};bases={'constructor':4000,'update':20000,'world':30000,'activation':36000}
    def extent(at,n):return {'offset':m.slice_offset+offset+at,'bytes':n}
    def write(at,raw):data[offset+at:offset+at+len(raw)]=raw
    def linked(at,pattern,field,destination):
        raw,fields=expand(pattern);p,n=fields[field]
        raw[p:p+n]=struct.pack('<i',destination-at-p-n) if mac else branch(origin+at+p,origin+destination)
        write(at,raw)
    for key,(base,delta,_,pattern) in reader.LAYOUTS[m.architecture].items():
        if mac and alternate and key=='activation':pattern=reader.MAC_ACTIVATION_ALTERNATE
        at=bases[base]+delta;positions[key]=at
        if key=='range':linked(at,pattern,'getter',35500)
        else:write(at,expand(pattern)[0])
    pattern=('554889e553504889fbc783bc00000005000000488b7b0831f6e8 {setter:4}' if mac else
             '90b504460520c4f884000021606801af {setter:4} 012084f8ad0090bd')
    linked(3500,pattern,'setter',35000);positions['deactivation']=3500
    opening_size=413 if mac else 356
    positions['player_suppression']=43000+opening_size-(19 if mac else 22)
    write(positions['player_suppression'],bytes.fromhex('498b8768010000488b00c6406201' if mac else '1498012100684466d5f8f000006880f85e10'))
    actors['provenance']={'declaration':extent(43000,opening_size)}
    initial=actors['npc_initialization'];initial.update({'guidance':{'available':True},'activation':{'provenance':{'activation':extent(36000,33 if mac else 20)}},'initial_active':False})
    initial['provenance'].update({'opening_deactivation':extent(3500,30 if mac else 28),'activity_setter':extent(35000,13 if mac else 6)})
    projection={'provenance':{'predicate':extent(35500,26 if mac else 10)}}
    m.data=bytes(data)
    return m,actors,projection,positions,offset


class HoldingTests(unittest.TestCase):
    def test_both_relocated_layouts(self):
        for mac,alternate in [(False,False),(True,False),(True,True)]:
            for shift in [0,0x600000]:
                m,a,p,_,_=fixture(mac,shift,alternate);result=reader.extract_npc_holding(m,a,p)
                self.assertTrue(result,(mac,shift))
                self.assertEqual({k:v for k,v in result.items() if k!='provenance'},reader.VALUES)
                self.assertEqual(len(result['provenance']),8)

    def test_corruption_and_missing_dependencies(self):
        for mac,alternate in [(False,False),(True,False),(True,True)]:
            m,a,p,positions,offset=fixture(mac,alternate=alternate)
            for key,at in positions.items():
                altered=copy.copy(m);data=bytearray(m.data);data[offset+at]^=255;altered.data=bytes(data)
                self.assertFalse(reader.extract_npc_holding(altered,a,p),(mac,key))
            for key in ['flight','guidance','activation']:
                changed=copy.deepcopy(a);changed['npc_initialization'][key]={}
                self.assertFalse(reader.extract_npc_holding(m,changed,p),(mac,key))
            for key in ['actor_kind','hull_catalogue_id']:
                changed=copy.deepcopy(a);changed['actors'][1][key]=99
                self.assertFalse(reader.extract_npc_holding(m,changed,p))
            changed=copy.deepcopy(p);changed['provenance']['predicate']['offset']+=4
            self.assertFalse(reader.extract_npc_holding(m,a,changed))
            changed=copy.deepcopy(a);changed['npc_initialization']['provenance']['activity_setter']['offset']+=4
            self.assertFalse(reader.extract_npc_holding(m,changed,p))

    def test_unique_section_bounded_evidence(self):
        for mac in [False,True]:
            m,a,p,positions,offset=fixture(mac)
            changed=copy.copy(m);data=bytearray(m.data);n=reader.LAYOUTS[m.architecture]['world_order'][2]
            at=positions['world_order'];data[offset+31000:offset+31000+n]=data[offset+at:offset+at+n];changed.data=bytes(data)
            self.assertFalse(reader.extract_npc_holding(changed,a,p))
            changed=copy.deepcopy(m);changed.sections[-1]['segment']=b'__TEXT'
            self.assertFalse(reader.extract_npc_holding(changed,a,p))
            changed=copy.copy(m);changed.data=m.data[:offset+51002]
            self.assertFalse(reader.extract_npc_holding(changed,a,p))
            changed=copy.copy(m);changed.architecture='unknown'
            self.assertFalse(reader.extract_npc_holding(changed,a,p))


if __name__=='__main__':unittest.main()


ANDROID_ACTORS = {'actors': [{'actor_id': i, 'actor_kind': 8, 'hull_catalogue_id': h} for i, h in enumerate((2, 23, 2))],
                  'npc_initialization': {'guidance': {'a': 1}, 'activation': {'a': 1}, 'flight': {'a': 1}, 'initial_active': False}}


def android_extract(actors=ANDROID_ACTORS, projection={'near': 20.0}, near='0xc350', slots=(3, 13), status='&_ZN7Globals6statusE', **changes):
    """Synthetic Android PlayerFighter, Level::render, setToSleep and opening declaration."""
    from android_text_fixture import fill, text_library
    from gof2_content.npc_initialization import ANDROID_ACTIVITY, ANDROID_DEACTIVATION
    from test_opening_actors import android_level
    push = 'push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}'
    functions = android_level()
    functions.update({
        '_ZN13PlayerFighterC1EiiP6PlayerP10AEGeometryfffb': changes.pop('fighter', '\n'.join([
            push, reader.ANDROID_TIMERS, 'call _ZN5RouteC1EPii', fill(reader.ANDROID_RANGE, blank=status, near=near), 'bx lr'])),
        '_ZN13PlayerFighter6updateEi': changes.pop('update', '\n'.join([push, 'mov r4, r0', 'mov r8, r1', reader.ANDROID_CLOCK, 'bx lr'])),
        '_ZN13PlayerFighter5awakeEv': changes.pop('awake', fill(reader.ANDROID_ACTIVATION, blank='#_ZN10AEGeometry10setVisibleEb')),
        '_ZN10AEGeometry10setVisibleEb': 'bx lr',
        '_ZN5Level6renderEi': changes.pop('render', '\n'.join(['push {r4, r5, r6, r7, lr}', 'mov r4, r0', 'mov r5, r1', fill(reader.ANDROID_WORLD), 'bx lr'])),
        '_ZN8KIPlayer10setToSleepEv': fill(ANDROID_DEACTIVATION, setter='_ZN6Player9setActiveEb'),
        '_ZN6Player9setActiveEb': ANDROID_ACTIVITY})
    functions.update(changes)
    table = [0] * 16  # unrelocated slots read as absent
    for slot, name in zip(slots, ('_ZN13PlayerFighter5awakeEv', '_ZN13PlayerFighter6updateEi')):
        table[2 + slot] = name
    lib, addresses = text_library({k: v for k, v in functions.items() if v is not None},
                                  {'_ZTV13PlayerFighter': table, '_ZN7Globals6statusE': [0], '_ZN7Globals7optionsE': [0]})
    return reader.extract_npc_holding(lib, actors, projection), lib, addresses


class AndroidNPCHolding(unittest.TestCase):
    def test_named_blocks_give_values_and_spans(self):
        result, lib, addresses = android_extract()
        self.assertEqual({k: v for k, v in result.items() if k != 'provenance'}, reader.VALUES)
        p = result['provenance']
        found = {k: (p[k]['offset'] - addresses[name], p[k]['bytes']) for k, name in [
            ('timers', '_ZN13PlayerFighterC1EiiP6PlayerP10AEGeometryfffb'), ('range', '_ZN13PlayerFighterC1EiiP6PlayerP10AEGeometryfffb'),
            ('clock_step', '_ZN13PlayerFighter6updateEi'), ('activation', '_ZN13PlayerFighter5awakeEv'), ('world_order', '_ZN5Level6renderEi'),
            ('deactivation', '_ZN8KIPlayer10setToSleepEv'), ('player_suppression', '_ZN5Level21createCampaignMissionEv')]}
        # The suppression store closes the opening declaration (case 0 at 58, 262 bytes) before its exit branch.
        self.assertEqual(found, {'timers': (4, 100), 'range': (108, 32), 'clock_step': (8, 26), 'activation': (0, 48),
                                 'world_order': (6, 58), 'deactivation': (0, 28), 'player_suppression': (58 + 262 - 12, 10)})
        rel = lib.elf_sections['.rel.dyn']
        self.assertTrue(rel['offset'] <= p['virtual_update']['offset'] < rel['offset'] + rel['length'] and p['virtual_update']['bytes'] == 8)

    def test_each_broken_rule_is_unsupported(self):
        from android_text_fixture import fill
        from gof2_content.npc_initialization import ANDROID_DEACTIVATION
        initial = ANDROID_ACTORS['npc_initialization']
        render = lambda *parts: '\n'.join(['push {r4, r5, r6, r7, lr}', *parts, fill(reader.ANDROID_WORLD), 'bx lr'])
        cases = {
            **{'no ' + key: dict(actors=dict(ANDROID_ACTORS, npc_initialization=dict(initial, **{key: {}}))) for key in ('guidance', 'activation', 'flight')},
            'active actors': dict(actors=dict(ANDROID_ACTORS, npc_initialization=dict(initial, initial_active=True))),
            'unknown activity': dict(actors=dict(ANDROID_ACTORS, npc_initialization={k: v for k, v in initial.items() if k != 'initial_active'})),
            'other kinds': dict(actors=dict(ANDROID_ACTORS, actors=[dict(a, actor_kind=7) for a in ANDROID_ACTORS['actors']])),
            'other hulls': dict(actors=dict(ANDROID_ACTORS, actors=[dict(a, hull_catalogue_id=2) for a in ANDROID_ACTORS['actors']])),
            'no projection': dict(projection={}),
            'no update slot': dict(slots=(3, 12)),
            'no activation slot': dict(slots=(4, 13)),
            'no timers': dict(fighter='push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}\n' + fill(reader.ANDROID_RANGE, blank='&_ZN7Globals6statusE', near='0xc350') + '\nbx lr'),
            'no range': dict(fighter='push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}\n' + reader.ANDROID_TIMERS + '\nbx lr'),
            'other range': dict(near='0xc351'),
            'other range global': dict(status='&_ZN7Globals7optionsE'),
            'no clock': dict(update='bx lr'),
            'activation shape': dict(awake=fill(reader.ANDROID_ACTIVATION, blank='#_ZN10AEGeometry10setVisibleEb').replace('movs r5, #1', 'movs r5, #2')),
            'no world order': dict(render='bx lr'),
            'render this changed': dict(render=render('movs r0, #0', 'mov r4, r0', 'mov r5, r1')),
            'render elapsed changed': dict(render=render('mov r4, r0', 'movs r1, #0', 'mov r5, r1')),
            'deactivation shape': {'_ZN8KIPlayer10setToSleepEv': fill(ANDROID_DEACTIVATION, setter='_ZN6Player9setActiveEb').replace('movs r0, #5', 'movs r0, #4')},
            'setter shape': {'_ZN6Player9setActiveEb': 'strb.w r1, [r0, #0xc1]\nbx lr'},
            'no opening': {'_ZN5Level21createCampaignMissionEv': 'bx lr'},
        }
        for name, changes in cases.items():
            with self.subTest(name):
                self.assertEqual(android_extract(**changes)[0], {})
