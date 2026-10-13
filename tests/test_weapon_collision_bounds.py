"""Relocated constructor defaults and linked ordinary collision selectors."""
import copy
import struct
import unittest
from gof2_content import weapon_collision_bounds as reader
from gof2_content.weapon_capacity import extract_weapon_capacity
from test_weapon_capacity import fixture as capacity_fixture
from test_font_selection import expand
from test_ship_models import branch


def fixture(mac, shift=0):
    m,w,f,_,_,_=capacity_fixture(mac,shift)
    w['projectile_capacity']=extract_weapon_capacity(m,w,f)
    assert w['projectile_capacity']
    base=m.text['address'];offset=m.text['offset'];raw=bytearray(m.data)
    constructor=4500;gate=6200;blocks={}
    def block(key,at,spec):
        body,fields=expand(spec)
        for name,(p,n) in fields.items():
            dest=constructor if name=='constructor' else 8000 if name!='call_3e' else 8200
            body[p:p+n]=struct.pack('<i',dest-at-p-n) if mac else branch(base+at+p,base+dest)
        raw[offset+at:offset+at+len(body)]=body
        blocks[key]=(at,body,fields)
    block('wrapper',3800,reader.MAC_WRAPPER if mac else reader.ARM_WRAPPER)
    block('constructor_entry',constructor,'554889e5' if mac else 'f0b503af')
    block('default',constructor+(0x349 if mac else 0x1e8),reader.MAC_DEFAULT if mac else reader.ARM_DEFAULT)
    block('selector',gate+(0x4d9 if mac else -0x26a),reader.MAC_SELECTOR if mac else reader.ARM_SELECTOR)
    w['ordinary_hit_policy']={'provenance':{'additional_gate':{'offset':m.slice_offset+offset+gate,'bytes':43 if mac else 30}}}
    m.data=bytes(raw)
    return m,w,blocks


class WeaponCollisionBounds(unittest.TestCase):
    def test_relocated_defaults(self):
        for mac in [True,False]:
            for shift in [0,0x500000]:
                m,w,_=fixture(mac,shift)
                self.assertEqual(reader.extract_weapon_collision_bounds(m,w).get('mode'),'target',(mac,shift))

    def test_every_proof_required(self):
        for mac in [True,False]:
            m,w,_=fixture(mac);result=reader.extract_weapon_collision_bounds(m,w)
            self.assertTrue(result)
            for key,span in result['provenance'].items():
                damaged=copy.copy(m);raw=bytearray(m.data)
                raw[span['offset']-m.slice_offset]^=255;damaged.data=bytes(raw)
                self.assertFalse(reader.extract_weapon_collision_bounds(damaged,w),(mac,key))

    def test_disconnected_and_truncated(self):
        for mac in [True,False]:
            for bad in ['capacity','policy','gate','constructor','truncated','architecture']:
                m,w,blocks=fixture(mac);raw=bytearray(m.data)
                if bad=='capacity':w['projectile_capacity']={}
                elif bad=='policy':w['ordinary_hit_policy']={}
                elif bad=='gate':w['ordinary_hit_policy']['provenance']['additional_gate']['offset']+=2
                elif bad=='constructor':
                    at,_,fields=blocks['wrapper'];p,n=fields['constructor']
                    raw[256+at+p:256+at+p+n]=struct.pack('<i',6000-at-p-n) if mac else branch(m.text['address']+at+p,m.text['address']+6000)
                elif bad=='truncated':raw=raw[:256+blocks['selector'][0]+2]
                else:m.architecture='unsupported'
                m.data=bytes(raw)
                self.assertFalse(reader.extract_weapon_collision_bounds(m,w),(mac,bad))

    def test_arm_preserved_zero_and_callees(self):
        for bad in ['zero','callee','flag_store']:
            m,w,blocks=fixture(False);raw=bytearray(m.data)
            at,body,fields=blocks['default']
            if bad=='zero':raw[256+at]=1
            elif bad=='flag_store':raw[256+at+len(body)-2]^=1
            else:
                p,n=fields['call_24'];raw[256+at+p:256+at+p+n]=branch(m.text['address']+at+p,m.text['address']+8200)
            m.data=bytes(raw)
            self.assertFalse(reader.extract_weapon_collision_bounds(m,w),bad)


@unittest.skipUnless(__import__('importlib').util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidCollisionBounds(unittest.TestCase):
    def test_cleared_flag_gives_target_bounds(self):
        from test_weapon_parameters import android_guns, android_weapon_chain
        lib, at, weapon = android_guns()
        weapon = android_weapon_chain(lib, weapon)
        result = weapon['collision_bounds']
        self.assertEqual(result['mode'], 'target')
        p = result['provenance']
        self.assertEqual(p['constructor_call'], weapon['projectile_capacity']['provenance']['constructor_call'])
        self.assertEqual({k: (p[k]['offset'] - at[f], p[k]['bytes']) for k, f in (('constructor_entry', 'constructor'), ('default_value', 'constructor'),
                                                                               ('default', 'constructor'), ('selector', 'collision'))},
                         {'constructor_entry': (0, 4), 'default_value': (8, 4), 'default': (16, 4), 'selector': (172, 20)})

    def test_each_broken_rule_is_unsupported(self):
        from test_weapon_parameters import android_guns, android_weapon_chain
        cases = {'other flag': dict(edits=[('constructor', 'strb.w sl, [r4, #0x6c]', 'strb.w sl, [r4, #0x68]')]),
                 'set flag': dict(edits=[('constructor', 'mov.w sl, #0', 'mov.w sl, #1')]),
                 'zero lost': dict(edits=[('constructor', 'str.w sl, [r4, #4]', 'mov sl, r1')]),
                 'never zeroed': dict(edits=[('constructor', 'mov.w sl, #0', 'nop')]),
                 'two stores': dict(edits=[('constructor', 'str.w sl, [r4, #4]', 'strb.w sl, [r4, #0x6c]')]),
                 'constructor this lost': dict(edits=[('constructor', 'mov r4, r0', 'mov r4, r1')]),
                 'collision this lost': dict(edits=[('collision', 'mov fp, r0', 'mov fp, r1')]),
                 'own bounds': dict(edits=[('collision', 'it ne\naddne.w r0, fp, #0x104', 'it eq\naddeq.w r0, fp, #0x104')])}
        lib, _, weapon = android_guns()
        weapon = android_weapon_chain(lib, weapon)
        # The parents stay valid: only the bounds rules break.
        for name, options in cases.items():
            with self.subTest(name):
                broken, _, _ = android_guns(**options)
                self.assertEqual(reader.extract_weapon_collision_bounds(broken, weapon), {})
        for key in ('projectile_capacity', 'ordinary_hit_policy'):
            self.assertEqual(reader.extract_weapon_collision_bounds(lib, {**weapon, key: {}}), {}, key)
