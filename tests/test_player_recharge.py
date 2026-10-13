"""Synthetic, relocated player recharge declarations without proprietary fixtures."""
import copy
import struct
import unittest
from types import SimpleNamespace
from gof2_content import player_recharge as reader
from test_font_selection import expand
from test_ship_models import branch


def fixture(mac,shift=0):
    origin=0x200000+shift;offset=256;bias=4096
    arch='x86_64' if mac else 'armv7';data=bytearray(61500)
    ctor=10000-(0x92e if mac else 0x51a)
    positions={'pulse':10000,'recharge':30000,'application_order':40000,'world_pass':44000,
        'assignment':45000,'equipment_zero':45200,'getter':47000,'hull_getter':47100,
        'adder':47200,'clock_zero':ctor+(0x302 if mac else 0x152),
        'blocked_zero':ctor+(0x298 if mac else 0x12a)}
    if not mac:positions.update(zero_vector=ctor+0x1c,zero_integer=ctor+0x2c,divisor_load=ctor+0x35e)
    fields={}
    def write(at,raw):data[offset+at:offset+at+len(raw)]=raw
    def extent(at,size):return {'offset':bias+offset+at,'bytes':size}
    targets={'pulse':{'call_c':50200,('call_4' if mac else 'call_6'):50400,'call_18':50400,('call_20' if mac else 'call_1e'):47000},
        'recharge':{'call_a':50400,('call_12' if mac else 'call_10'):47000,'call_1e':47100,('call_59' if mac else 'call_6a'):47200},
        'assignment':{('call_11' if mac else 'call_8'):50000},
        'application_order':{('call_5b' if mac else 'call_50'):30000-(0x234a if mac else 0x1d00),('call_7e' if mac else 'call_74'):44000}}
    divisor=60000 if mac else ((positions['divisor_load']+4)&~3)+0x2d8
    for key,(size,pattern) in reader.LAYOUTS[arch].items():
        at=positions[key];raw,masks=expand(pattern);fields[key]=masks
        for field,destination in targets.get(key,{}).items():
            p,n=masks[field];raw[p:p+n]=struct.pack('<i',destination-at-p-n) if mac else branch(origin+at+p,origin+destination)
        if key=='pulse' and mac:
            p,n=masks['ref_2c'];raw[p:p+n]=struct.pack('<i',divisor-at-p-n)
        if key=='divisor_load':raw[:]=bytes.fromhex('9fedb6aa')
        write(at,raw)
    write(divisor,struct.pack('<f',100.0));positions['divisor']=divisor
    text={'segment':b'__TEXT','name':b'__text','address':origin,'offset':offset,'length':59000}
    const={'segment':b'__TEXT','name':b'__const','address':origin+60000,'offset':offset+60000,'length':1000}
    m=SimpleNamespace(architecture=arch,data=bytes(data),slice_offset=bias,text=text,sections=[text,const])
    player={'provenance':{'shield_getter':extent(50200,9 if mac else 4),
        'shield_assignment':extent(45000-(26 if mac else 14),26 if mac else 14),
        'reset':extent(45200+(8 if mac else 0),8 if mac else 12)}}
    vehicle={'equipment_rule':'last_matching','provenance':{'property_getter':extent(50000,4)}}
    clock={'provenance':{'frame':extent(40000-(0x547 if mac else 0x2cc),31 if mac else 34)}}
    return m,{'player_initialization':player},vehicle,clock,positions,fields,offset


class RechargeTests(unittest.TestCase):
    def test_independent_relocated_layouts(self):
        for mac in [False,True]:
            for shift in [0,0x900000]:
                m,a,v,c,_,_,_=fixture(mac,shift);result=reader.extract_player_recharge(m,a,v,c)
                self.assertTrue(result,(mac,shift))
                self.assertEqual({k:x for k,x in result.items() if k!='provenance'},reader.VALUES)
                self.assertEqual(len(result['provenance']),12 if mac else 15)

    def test_reject_changed_blocks_and_cross_links(self):
        for mac in [False,True]:
            m,a,v,c,positions,fields,offset=fixture(mac)
            for key,at in positions.items():
                changed=copy.copy(m);raw=bytearray(m.data);raw[offset+at]^=255;changed.data=bytes(raw)
                self.assertFalse(reader.extract_player_recharge(changed,a,v,c),(mac,key))
            for block,field in [('pulse','call_c'),('assignment','call_11' if mac else 'call_8'),('recharge','call_12' if mac else 'call_10'),('application_order','call_5b' if mac else 'call_50'),('application_order','call_7e' if mac else 'call_74')]:
                changed=copy.copy(m);raw=bytearray(m.data);raw[offset+positions[block]+fields[block][field][0]]^=2;changed.data=bytes(raw)
                self.assertFalse(reader.extract_player_recharge(changed,a,v,c),(mac,block,field))
            changed=copy.deepcopy(c);changed['provenance']['frame']['offset']+=2
            self.assertFalse(reader.extract_player_recharge(m,a,v,changed))

    def test_reject_ambiguity_and_truncation(self):
        for mac in [False,True]:
            m,a,v,c,positions,_,offset=fixture(mac)
            raw=bytearray(m.data);size=reader.LAYOUTS[m.architecture]['pulse'][0]
            raw[offset+20000:offset+20000+size]=raw[offset+positions['pulse']:offset+positions['pulse']+size]
            changed=copy.copy(m);changed.data=bytes(raw)
            self.assertFalse(reader.extract_player_recharge(changed,a,v,c))
            changed=copy.copy(m);changed.data=m.data[:offset+47210]
            self.assertFalse(reader.extract_player_recharge(changed,a,v,c))
            self.assertFalse(reader.extract_player_recharge(m,{},v,c))


ANDROID_PARENTS = ({'player_initialization': {'half_extent': 1200}}, {'equipment_rule': 'last_matching'}, {'frame': 1})
EGO_UPDATE = '_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi'


def android_functions(**changes):
    """Synthetic Android recharge chain in the shapes the reader matches (divisor 100)."""
    from android_text_fixture import fill
    names = dict(getter='_ZN4Ship14getShieldRegenEv', hull_getter='_ZN6Player12getHitpointsEv', adder='_ZN6Player16regenerateShieldEf',
                 shield_getter='_ZN4Ship14getMaxShieldHPEv', update=EGO_UPDATE)
    names.update(changes.pop('names', {}))
    from gof2_content.player_initialization import ANDROID_RESET, ANDROID_SHIELD
    parts = dict(entry=fill(reader.ANDROID_ENTRY), clock=reader.ANDROID_CLOCK_ZERO, blocked=reader.ANDROID_BLOCKED_ZERO,
                 load=fill(reader.ANDROID_DIVISOR, divisor=changes.pop('divisor', '0x42c80000')), pulse=fill(reader.ANDROID_PULSE, **names))
    order = changes.pop('order', ['entry', 'clock', 'blocked', 'load', 'pulse'])
    functions = {
        '_ZN5MGame8OnUpdateEv': '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', fill(reader.ANDROID_ORDER, **names), 'bx lr']),
        EGO_UPDATE: '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', changes.pop('this', 'mov sb, r0'), fill(reader.ANDROID_RECHARGE, **names), 'bx lr']),
        '_ZN9PlayerEgoC1EP6Player': '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, lr}', 'vpush {d8}', *[parts.get(p, p) for p in order], 'bx lr']),
        '_ZN4Ship14getShieldRegenEv': reader.ANDROID_HELPERS['getter'],
        '_ZN6Player12getHitpointsEv': reader.ANDROID_HELPERS['hull_getter'],
        '_ZN6Player16regenerateShieldEf': fill(reader.ANDROID_HELPERS['adder'], changed='#_ZN6Player16updateDamageRateEv'),
        '_ZN4Ship14getMaxShieldHPEv': 'ldr r0, [r0, #0x1c]\nbx lr', '_ZN6Player16updateDamageRateEv': 'bx lr',
        '_ZN4Ship12refreshValueEv': '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', changes.pop('reset', fill(ANDROID_RESET)),
                                               changes.pop('shield', fill(ANDROID_SHIELD, next='#out')), 'out:', 'bx lr'])}
    functions.update(changes)
    return {k: v for k, v in functions.items() if v is not None}


def android_extract(parents=ANDROID_PARENTS, **changes):
    from android_text_fixture import text_library
    lib, addresses = text_library(android_functions(**changes))
    return reader.extract_player_recharge(lib, *parents), addresses


class AndroidRechargeTests(unittest.TestCase):
    def test_named_chain_gives_values_and_spans(self):
        from android_text_fixture import text_library
        lib, addresses = text_library(android_functions())
        result = reader.extract_player_recharge(lib, *ANDROID_PARENTS)
        self.assertEqual({k: v for k, v in result.items() if k != 'provenance'}, reader.VALUES)
        p = result['provenance']
        at = lambda key, name: (p[key]['offset'] - addresses[name], p[key]['bytes'])
        self.assertEqual([at('application_order', '_ZN5MGame8OnUpdateEv'), at('recharge', EGO_UPDATE)], [(4, 98), (6, 80)])
        ctor = '_ZN9PlayerEgoC1EP6Player'
        self.assertEqual([at(k, ctor) for k in ('entry', 'clock_zero', 'blocked_zero', 'divisor_load', 'pulse')], [(8, 28), (36, 8), (44, 4), (48, 4), (52, 54)])
        self.assertEqual(lib.data[p['divisor']['offset']:p['divisor']['offset'] + 4], bytes.fromhex('0000c842'))
        ship = '_ZN4Ship12refreshValueEv'
        # Attribute 19 follows the shield's attribute 18 (14 bytes in); the reset's last store clears it.
        self.assertEqual([at('assignment', ship), at('equipment_zero', ship)], [(4 + 44 + 14, 14), (4 + 40, 4)])
        for key, name in [('getter', '_ZN4Ship14getShieldRegenEv'), ('hull_getter', '_ZN6Player12getHitpointsEv'), ('adder', '_ZN6Player16regenerateShieldEf')]:
            self.assertEqual(p[key]['offset'], addresses[name], key)

    def test_each_broken_rule_is_unsupported(self):
        from android_text_fixture import fill
        from gof2_content.player_initialization import ANDROID_SHIELD
        cases = {
            'no player': dict(parents=({}, *ANDROID_PARENTS[1:])),
            'other equipment rule': dict(parents=(ANDROID_PARENTS[0], {'equipment_rule': 'first_matching'}, ANDROID_PARENTS[2])),
            'no clock parent': dict(parents=(*ANDROID_PARENTS[:2], {})),
            'no order': {'_ZN5MGame8OnUpdateEv': 'bx lr'},
            'no recharge': {EGO_UPDATE: 'bx lr'},
            **{'no ' + part: dict(order=[p for p in ['entry', 'clock', 'blocked', 'load', 'pulse'] if p != part]) for part in ('entry', 'clock', 'blocked', 'load', 'pulse')},
            'pulse getter': dict(order=['entry', 'clock', 'blocked', 'load', fill(reader.ANDROID_PULSE, shield_getter='_ZN4Ship14getMaxShieldHPEv', getter='_ZN6Player12getHitpointsEv')]),
            'ctor this lost': dict(order=['entry', 'clock', 'blocked', 'load', 'movs r4, #0', 'pulse']),
            'update this from r1': dict(this='mov sb, r1'),
            'zero lost': dict(order=['entry', 'movs r6, #1', 'clock', 'blocked', 'load', 'pulse']),
            'vector lost': dict(order=['entry', 'vld1.64 {d16, d17}, [r0:0x80]', 'clock', 'blocked', 'load', 'pulse']),
            'divisor after pulse': dict(order=['entry', 'clock', 'blocked', 'pulse', 'load']),
            'divisor replaced': dict(order=['entry', 'clock', 'blocked', 'load', 'vmov.f32 s16, #1.000000e+00', 'pulse']),
            'getter field': {'_ZN4Ship14getShieldRegenEv': 'ldr r0, [r0, #0x28]\nbx lr'},
            'hull getter field': {'_ZN6Player12getHitpointsEv': 'ldr r0, [r0, #0x7c]\nbx lr'},
            'adder shape': {'_ZN6Player16regenerateShieldEf': fill(reader.ANDROID_HELPERS['adder'], changed='#_ZN6Player16updateDamageRateEv').replace('it mi\nvmovmi', 'it gt\nvmovgt')},
            'shield getter field': {'_ZN4Ship14getMaxShieldHPEv': 'ldr r0, [r0, #0x20]\nbx lr'},
            'no reset': dict(reset='mov r4, r0'),
            'no attribute 19': dict(shield=fill(ANDROID_SHIELD, next='#out').replace('movs r1, #0x13', 'movs r1, #0x15')),
            'other divisor': dict(divisor='0x42c80001'),
        }
        for name, changes in cases.items():
            with self.subTest(name):
                self.assertEqual(android_extract(**changes)[0], {})
