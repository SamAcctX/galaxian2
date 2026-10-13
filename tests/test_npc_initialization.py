"""Relocated NPC factory fixtures with changed declarations and damaged links."""
import copy
import struct
import unittest
from types import SimpleNamespace
from gof2_content import npc_initialization as reader
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch
from test_surface_material import arm_modified

# Bounded constructor layouts, without original executable/content fixtures.
STATIC = {True: [('stats', 0, '554889e54157415641554154534883ec284589ce'),
        ('stats', 170, '897344899380000000'),
        ('stats', 236, 'c7437000000000c643620048c783980000000000000048c7839000000000000000'),
        ('stats', 269, 'c683cb00000001'),
        ('stats', 773, 'c683c800000001'),
        ('stats', 797, 'c683ca00000001'),
        ('stats', 859, 'c6436d00'),
        ('base', 385, 'c6435800'),
        ('base', 427, 'c683c000000001'),
        ('base', 542, 'c6435c00')],
 False: [('stats', 0, 'f0b503af2de9000dadf1400424f00f04a54604f9ed8204f9efc298b0'),
         ('stats', 110, '3164b267'),
         ('stats', 66, '0024'),
         ('stats', 36, 'c0ef5000'),
         ('stats', 140, '06f18800f4670125c6f88040f46686f85e4040f98f0a304686f8c350'),
         ('stats',
          524,
          '002001214ff0ff35c6f8d00086f8701004acc6f80c1186f8440086f8450086f8680086f8c01086f8c100c6f8b40086f8c210c6f8d40086f85d0086f85c0086f8e00086f8ec0086f8ed00706786f8540086f8550086f86900'),
         ('base',
          290,
          '00204ff0ff32c0f22401c6f82480f064794486f86e0086f8210086f8710086f8380086f8390086f83a0086f83e0086f83f0086f840007264012286f88820'),
         ('base', 422, '02990120002281f8f1004ff0ff3081f82020c1f8e42081f83c20')]}


def fixture(mac, shift=0):
    origin=0x100000+shift; offset=256; slice_offset=4096
    positions={'factory':1000,'selector':2400,'stats_wrapper':2700,'stats':3000,
               'actor_wrapper':4400,'actor':4700,'base':5000,'value':7000,'deactivate':5800,'setter':5900}
    data=bytearray(8500)
    def write(at,raw): data[offset+at:offset+at+len(raw)]=raw
    write(positions['factory'],bytes.fromhex('554889e5' if mac else 'f0b503af'))
    for parent,delta,raw in STATIC[mac]:write(positions[parent]+delta,bytes.fromhex(raw))
    write(positions['value'],struct.pack('<f',2.5))
    contexts={}
    def block(key,at,spec,targets=None,values=None):
        body,fields=expand(spec);targets=targets or {};values=values or {}
        for name,(p,n) in fields.items():
            if name in values:raw=values[name]
            elif mac:
                dest=positions[targets[name]] if name in targets else 7400
                raw=struct.pack('<i',dest-at-p-n-(1 if key=='selector' and name=='value' else 0))
            elif name=='allocate':raw=branch(origin+at+p,origin+7500)
            elif name in targets:raw=branch(origin+at+p,origin+positions[targets[name]])
            elif name=='settings_low':raw=arm_wide(300,0)
            elif name=='settings_high':raw=arm_wide(0,0,top=True)
            else:raise AssertionError((key,name))
            assert len(raw)==n,(key,name,n,len(raw))
            body[p:p+n]=raw
        write(at,body);contexts[key]=(at,body,fields)
    block('selection',positions['factory']+(0x203 if mac else 0x23e),reader.MAC_SELECTION if mac else reader.ARM_SELECTION,
          {'selector':'selector','stats':'stats_wrapper'},
          {'ordinary':struct.pack('<i',912) if mac else arm_modified(912,1),
           'special':struct.pack('<i',777) if mac else arm_wide(777,1)})
    block('selector',positions['selector'],reader.MAC_SELECTOR if mac else reader.ARM_SELECTOR,
          {'value':'value'},{} if mac else {'value':bytes.fromhex('80ef141f')})
    block('stats_wrapper',positions['stats_wrapper'],'554889e55de9 {constructor:4}' if mac else '90b501af82b00446b868d7f80c908de801022046 {constructor:4} 204602b090bd',{'constructor':'stats'})
    block('ship_call',positions['factory']+(0x324 if mac else 0x2ca),reader.MAC_SHIP if mac else reader.ARM_SHIP,{'actor':'actor_wrapper'})
    block('actor_wrapper',positions['actor_wrapper'],reader.MAC_ACTOR_WRAPPER if mac else reader.ARM_ACTOR_WRAPPER,{'constructor':'actor'})
    block('base_call',positions['actor']+(0x43 if mac else 0x42),reader.MAC_BASE_CALL if mac else reader.ARM_BASE_CALL,{'base':'base'})
    block('opening_deactivation',positions['deactivate'],'554889e553504889fbc783bc00000005000000488b7b0831f6e8 {setter:4}' if mac else '90b504460520c4f884000021606801af {setter:4} 012084f8ad0090bd',{'setter':'setter'})
    write(positions['setter'],bytes.fromhex('554889e54088b7c80000005dc3' if mac else '80f8c0107047'))
    text={'name':b'__text','segment':b'__TEXT','address':origin,'offset':offset,'length':6800}
    const={'name':b'__const','segment':b'__TEXT','address':origin+6800,'offset':offset+6800,'length':1000}
    mach=SimpleNamespace(data=bytes(data),text=text,sections=[text,const],slice_offset=slice_offset,architecture='x86_64' if mac else 'armv7')
    return mach,origin+positions['factory'],contexts


class NPCInitialization(unittest.TestCase):
    def test_relocated_and_changed_parameters(self):
        for mac in [True,False]:
            for shift in [0,0x400000]:
                m,f,_=fixture(mac,shift)
                result=reader.extract_npc_initialization(m,f,m.text['address']+5800)
                self.assertTrue(result,(mac,shift))
                self.assertEqual(result['ordinary_half_extent'],912)
                self.assertEqual(result['special_half_extent'],777)
                self.assertEqual(result['special_difficulty'],2.5)
                self.assertEqual((result['initial_armor'],result['initial_shield']),(0,0.0))
                self.assertTrue(result['initial_firing_allowed'] and not result['initial_active'] and result['initial_damage_allowed'])
                self.assertFalse(result['is_player'] or result['initial_point_geometry'] or result['initial_special_impact_state'])

    def test_every_proof_extent_required(self):
        for mac in [True,False]:
            m,f,_=fixture(mac)
            result=reader.extract_npc_initialization(m,f,m.text['address']+5800)
            self.assertTrue(result)
            for key,span in result['provenance'].items():
                changed=copy.copy(m);data=bytearray(m.data)
                if key=='difficulty_value':data[span['offset']-m.slice_offset:span['offset']-m.slice_offset+4]=struct.pack('<f',float('nan'))
                else:data[span['offset']-m.slice_offset]^=0xff
                changed.data=bytes(data)
                self.assertFalse(reader.extract_npc_initialization(changed,f,m.text['address']+5800),(mac,key))

    def test_broken_links_and_ranges(self):
        for mac in [True,False]:
            for key,field in [('selection','stats'),('selection','selector'),('stats_wrapper','constructor'),('ship_call','actor'),('actor_wrapper','constructor'),('base_call','base'),('opening_deactivation','setter')]:
                m,f,blocks=fixture(mac);at,body,fields=blocks[key];p,n=fields[field]
                data=bytearray(m.data);data[256+at+p:256+at+p+n]=struct.pack('<i',6000-at-p-4) if mac else branch(m.text['address']+at+p,m.text['address']+6000)
                m.data=bytes(data)
                self.assertFalse(reader.extract_npc_initialization(m,f,m.text['address']+5800),(mac,key))
            m,f,_=fixture(mac)
            self.assertFalse(reader.extract_npc_initialization(m,f+2,m.text['address']+5800))
            m.data=m.data[:256+3600]
            self.assertFalse(reader.extract_npc_initialization(m,f,m.text['address']+5800))

if __name__=='__main__':unittest.main()


ANDROID_NAMES = dict(selector='_ZN6Status12hardCoreModeEv', stats='_ZN6PlayerC1Eiiiii', actor='_ZN13PlayerFighterC1EiiP6PlayerP10AEGeometryfffb',
                     base='_ZN8KIPlayerC2EiiP6PlayerP10AEGeometryfffb', setter='_ZN6Player9setActiveEb')


def android_functions(ordinary='0x390', special='0x309', value='2.500000e+00', fighter='#fighter', **changes):
    """Synthetic Android factory chain: half extents 912/777, hard-core value 2.5."""
    from android_text_fixture import fill
    names = dict(ANDROID_NAMES, **changes.pop('names', {}))
    selection = fill(reader.ANDROID_SELECTION, ordinary=ordinary, special=special, fighter=fighter, **names)
    functions = {
        '_ZN5Level10createShipEiiiP8Waypointbb': '\n'.join([
            'push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', changes.pop('selection', selection), 'bx lr',
            'fighter:', fill(reader.ANDROID_FIGHTER, **names), 'elsewhere:', 'bx lr']),
        '_ZN6Status12hardCoreModeEv': fill(reader.ANDROID_SELECTOR, value=value),
        '_ZN6PlayerC1Eiiiii': changes.pop('stats', '\n'.join([
            'push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', 'add r7, sp, #0xc', fill(reader.ANDROID_STATS),
            'call _ZN6Player16updateDamageRateEv', fill(reader.ANDROID_FLAGS), 'bx lr'])),
        '_ZN13PlayerFighterC1EiiP6PlayerP10AEGeometryfffb': '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', fill(reader.ANDROID_BASE_CALL, **names), 'bx lr']),
        '_ZN8KIPlayerC2EiiP6PlayerP10AEGeometryfffb': changes.pop('base', '\n'.join([
            'push.w {r4, r5, r6, r7, r8, sb, sl, lr}', 'mov r5, r0', fill(reader.ANDROID_ACTOR_FLAGS),
            'call _ZN11AbyssEngine6StringC1EPKcb', fill(reader.ANDROID_POINT), 'bx lr'])),
        '_ZN8KIPlayer10setToSleepEv': fill(reader.ANDROID_DEACTIVATION, **names),
        '_ZN6Player9setActiveEb': reader.ANDROID_ACTIVITY}
    functions.update(changes)
    return {k: v for k, v in functions.items() if v is not None}


def android_extract(**changes):
    from android_text_fixture import text_library
    lib, addresses = text_library(android_functions(**changes))
    return reader.extract_npc_initialization(lib, '_ZN5Level10createShipEiiiP8Waypointbb', '_ZN8KIPlayer10setToSleepEv'), addresses


class AndroidNPCInitialization(unittest.TestCase):
    def test_named_chain_gives_extents_flags_and_spans(self):
        result, addresses = android_extract()
        self.assertEqual((result['ordinary_half_extent'], result['special_half_extent'], result['special_difficulty']), (912, 777, 2.5))
        self.assertEqual({k: v for k, v in result.items() if k not in ('ordinary_half_extent', 'special_half_extent', 'special_difficulty', 'provenance')},
                         {'initial_armor': 0, 'initial_shield': 0.0, 'initial_firing_allowed': True, 'initial_active': False,
                          'initial_damage_allowed': True, 'is_player': False, 'initial_special_impact_state': False,
                          'initial_collision_enabled': True, 'initial_point_geometry': False})
        found = {k: (v['offset'] - addresses[name], v['bytes']) for k, v, name in [
            (k, v, n) for k, v in result['provenance'].items() for n in [{
                'selection': '_ZN5Level10createShipEiiiP8Waypointbb', 'fighter_call': '_ZN5Level10createShipEiiiP8Waypointbb',
                'selector': '_ZN6Status12hardCoreModeEv', 'stats_stores': '_ZN6PlayerC1Eiiiii', 'flags': '_ZN6PlayerC1Eiiiii',
                'base_call': '_ZN13PlayerFighterC1EiiP6PlayerP10AEGeometryfffb', 'actor_flags': '_ZN8KIPlayerC2EiiP6PlayerP10AEGeometryfffb',
                'point_geometry': '_ZN8KIPlayerC2EiiP6PlayerP10AEGeometryfffb', 'opening_deactivation': '_ZN8KIPlayer10setToSleepEv',
                'activity_setter': '_ZN6Player9setActiveEb'}[k]]]}
        self.assertEqual(found, {'selection': (4, 112), 'fighter_call': (118, 72), 'selector': (0, 30), 'stats_stores': (6, 154),
                                 'flags': (164, 84), 'base_call': (4, 28), 'actor_flags': (6, 58), 'point_geometry': (68, 24),
                                 'opening_deactivation': (0, 28), 'activity_setter': (0, 6)})

    def test_each_broken_rule_is_unsupported(self):
        from android_text_fixture import fill
        stats = lambda *parts: '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', *parts, 'bx lr'])
        base = lambda *parts: '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, lr}', *parts, 'bx lr'])
        S, F, A, P = (fill(t) for t in (reader.ANDROID_STATS, reader.ANDROID_FLAGS, reader.ANDROID_ACTOR_FLAGS, reader.ANDROID_POINT))
        selection = fill(reader.ANDROID_SELECTION, ordinary='0x390', special='0x309', fighter='#fighter', **ANDROID_NAMES)
        cases = {
            'two selections': dict(selection=selection + '\n' + selection),
            'fighter elsewhere': dict(fighter='#elsewhere'),
            'selector shape': {'_ZN6Status12hardCoreModeEv': fill(reader.ANDROID_SELECTOR, value='2.500000e+00').replace('it eq\nmoveq', 'it ne\nmovne')},
            'no stores': dict(stats=stats(F)),
            'flags first': dict(stats=stats(F, S)),
            'stores twice': dict(stats=stats(S, F, S)),
            'this changed first': dict(stats=stats('movs r0, #0', S, F)),
            'this lost': dict(stats=stats(S, 'movs r4, #0', F)),
            'no base call': {'_ZN13PlayerFighterC1EiiP6PlayerP10AEGeometryfffb': 'bx lr'},
            'no actor flags': dict(base=base('mov r5, r0', P)),
            'point first': dict(base=base('mov r5, r0', P, A)),
            'base this from r1': dict(base=base('mov r5, r1', A, P)),
            'base r0 changed': dict(base=base('movs r0, #0', 'mov r5, r0', A, P)),
            'base this lost': dict(base=base('mov r5, r0', A, 'movs r5, #0', P)),
            'deactivation shape': {'_ZN8KIPlayer10setToSleepEv': fill(reader.ANDROID_DEACTIVATION, **ANDROID_NAMES).replace('movs r0, #5', 'movs r0, #6')},
            'activity shape': {'_ZN6Player9setActiveEb': 'strb.w r1, [r0, #0xc1]\nbx lr'},
            'zero extent': dict(ordinary='0'),
            'huge extent': dict(ordinary='0x1000000'),
            'zero special extent': dict(special='0'),
            'negative value': dict(value='-2.500000e+00'),
            'large value': dict(value='1.600000e+01'),
        }
        for name, changes in cases.items():
            with self.subTest(name):
                self.assertEqual(android_extract(**changes)[0], {})
