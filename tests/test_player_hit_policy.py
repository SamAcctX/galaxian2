"""Synthetic source data and relocation checks for player damage scaling."""
import copy
import struct
import unittest
from types import SimpleNamespace
from gof2_content.player_hit_policy import extract_player_hit_policy
from gof2_content.ordinary_hit_policy import MAC_ROUTE, ARM_ROUTE
from test_font_selection import expand


def fixture(mac, shift=0):
    origin=0x300000+shift;offset=256;bias=4096;at=1000 if mac else 1002
    raw,fields=expand(MAC_ROUTE if mac else ARM_ROUTE);data=bytearray(5256)
    if mac:
        for index,field in enumerate(['constant_32','constant_86','constant_8e']):
            p,n=fields[field];raw[p:p+n]=struct.pack('<i',4000+index*4-at-p-n)
        data[offset+4000:offset+4012]=struct.pack('<3f',0.2,3.0,0.25)
    else:
        data[offset+at-0x344:offset+at-0x344+12]=bytes.fromhex('80ef188f85ef10af9fede7ca')
    data[offset+at:offset+at+len(raw)]=raw
    text={'name':b'__text','segment':b'__TEXT','address':origin,'offset':offset,'length':3500}
    const={'name':b'__const','segment':b'__TEXT','address':origin+4000,'offset':offset+4000,'length':1000}
    m=SimpleNamespace(data=bytes(data),architecture='x86_64' if mac else 'armv7',slice_offset=bias,text=text,sections=[text,const])
    weapon={'ordinary_hit_policy':{'provenance':{'damage_route':{'offset':bias+offset+at,'bytes':len(raw)}}}}
    return m,weapon,at,fields


class PlayerHitPolicyTests(unittest.TestCase):
    def test_relocated_source_scalars(self):
        for mac in [False,True]:
            for shift in [0,0xa00000]:
                m,w,_,_=fixture(mac,shift);result=extract_player_hit_policy(m,w)
                self.assertTrue(result,(mac,shift))
                self.assertEqual(result['nonhostile_scale'],struct.unpack('<f',struct.pack('<f',0.2))[0])
                self.assertEqual(result['special_flight_multipliers'],[3,0.25])
                self.assertTrue(result['nonhostile_precedes_special'])
                self.assertEqual(len(result['provenance']),4 if mac else 2)

    def test_reject_broken_branches_scalars_and_live_registers(self):
        for mac in [False,True]:
            m,w,at,fields=fixture(mac)
            locations=[at+8,4000,4004,4008] if mac else [at+8,at+98,at-0x344,at-0x340,at-0x33c]
            if mac:locations.extend(at+fields[key][0] for key in ['constant_32','constant_86','constant_8e'])
            for site in locations:
                changed=copy.copy(m);data=bytearray(m.data);data[256+site]^=1;changed.data=bytes(data)
                self.assertEqual(extract_player_hit_policy(changed,w),{},(mac,site))
            changed=copy.copy(m);changed.data=m.data[:256+at+50]
            self.assertEqual(extract_player_hit_policy(changed,w),{})
            moved=copy.deepcopy(w);moved['ordinary_hit_policy']['provenance']['damage_route']['offset']+=2
            self.assertEqual(extract_player_hit_policy(m,moved),{})
            self.assertEqual(extract_player_hit_policy(m,{}),{})


@unittest.skipUnless(__import__('importlib').util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidPlayerHitPolicy(unittest.TestCase):
    def test_route_registers_give_multipliers(self):
        from test_weapon_parameters import android_guns, android_weapon_chain
        lib, at, weapon = android_guns()
        weapon = android_weapon_chain(lib, weapon)
        result = weapon['player_hit_policy']
        self.assertEqual({k: v for k, v in result.items() if k != 'provenance'},
                         {'nonhostile_scale': 0.20000000298023224, 'special_flight_multipliers': [3.0, 0.25],
                          'rounding': 'binary32_then_truncate', 'nonhostile_precedes_special': True})
        p = result['provenance']
        self.assertEqual(p['damage_route'], weapon['ordinary_hit_policy']['provenance']['damage_route'])
        self.assertEqual({k: (p[k]['offset'] - at['collision'], p[k]['bytes']) for k in ('special_first', 'special_second', 'nonhostile_load')},
                         {'special_first': (12, 4), 'special_second': (16, 4), 'nonhostile_load': (20, 4)})
        self.assertEqual(struct.unpack_from('<f', lib.data, p['nonhostile']['offset'])[0], result['nonhostile_scale'])

    def test_each_broken_rule_is_unsupported(self):
        from test_weapon_parameters import android_guns, android_weapon_chain
        cases = {'second write': dict(edits=[('collision', 'vpop', 'vmov.f32 s16, #1.000000e+00\nvpop')]),
                 'double register write': dict(edits=[('collision', 'vpop', 'vldr d9, [fp, #8]\nvpop')]),
                 'set after the route': dict(edits=[('collision', 'vmov.f32 s16, #3.000000e+00\n', ''), ('collision', 'vpop', 'vmov.f32 s16, #3.000000e+00\nvpop')]),
                 'loaded elsewhere': dict(edits=[('collision', 'vldr s24, =0x3e4ccccd', 'vldr s24, [fp, #8]')]),
                 'other docked scale': dict(edits=[('collision', 'vmov.f32 s18, #2.500000e-01', 'vmov.f32 s18, #5.000000e-01')]),
                 'other first scale': dict(edits=[('collision', 'vmov.f32 s16, #3.000000e+00', 'vmov.f32 s16, #2.000000e+00')]),
                 'other hostile scale': dict(edits=[('collision', '=0x3e4ccccd', '=0x3e800000')])}
        for name, options in cases.items():
            with self.subTest(name):
                lib, _, weapon = android_guns(**options)
                self.assertEqual(android_weapon_chain(lib, weapon)['player_hit_policy'], {})
        lib, _, weapon = android_guns()
        weapon = android_weapon_chain(lib, weapon)
        self.assertEqual(extract_player_hit_policy(lib, {**weapon, 'ordinary_hit_policy': {}}), {})
        moved = copy.deepcopy(weapon)
        moved['ordinary_hit_policy']['provenance']['damage_route']['offset'] += 2
        self.assertEqual(extract_player_hit_policy(lib, moved), {})
