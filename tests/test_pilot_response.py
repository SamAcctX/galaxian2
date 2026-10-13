"""Synthetic pilot declarations; fixture bytes are inspected, never executed."""
import importlib.util
import struct
from types import SimpleNamespace
import unittest
from gof2_content.pilot_response import extract_pilot_response


def fixture(mac, relocation=0):
    base = (0x100002000 if mac else 0x2000) + relocation
    code = bytearray(2048)
    # Separate storage for every reference lets tests detect disagreement.
    values = [-630.0, 3.0, 16.0, 3.0, 16.0, -120.0, 120.0, -120.0, 120.0]
    constants = struct.pack('<9f', *values)
    address = base + (8192 if mac else 1100)
    def reference(at, index, register=4):
        target = address + index * 4
        if mac:
            return struct.pack('<i', target - base - at - 4)
        delta = target - ((base + at + 4) & ~3)
        assert delta % 4 == 0 and abs(delta) <= 1020
        return bytes([0x9f if delta >= 0 else 0x1f, 0xed, abs(delta) // 4, (register // 2 << 4) | 0xa])
    if mac:
        quantizer = bytes.fromhex('f30f100d') + reference(204, 0) + bytes.fromhex('f30f59c8f30f59cdf30f2cc14863c0f30f1183040300004869c88320088248c1e92001c889c1c1e91fc1f80501c8')
        for at, index in [(400, 1), (500, 3)]:
            ramp = bytes.fromhex('f30f1025') + reference(at + 4, index) + bytes.fromhex('f30f5c20f30f5925') + reference(at + 16, index + 1) + bytes.fromhex('f3410f2adef30f59ddf30f5edc')
            code[at:at + len(ramp)] = ramp
        for at, index in zip((600, 700, 800, 1200), range(5, 9)):
            neutral = bytes.fromhex('0f57c9f3410f2accf3410f598ea4010000f30f5e0d') + reference(at + 21, index) + bytes.fromhex('0f57d2f30f58c1')
            code[at:at + len(neutral)] = neutral
    else:
        quantizer = reference(200, 0) + bytes.fromhex('42f28301c8f20821b9ff811748ff120d40ff900d84ed961a84ed998abbff202712ee100a94ed9e2a51fb0000411101ebd070')
        ramp = reference(400, 1, 6) + bytes(4) + bytes.fromhex('45ec305b7844fbff2006') + bytes.fromhex('c3ef142f') + bytes.fromhex('006800f1180200ff900d417c002918bf00f1140292ed004a63ef044d04ffb23d80ee030a')
        code[400:400 + len(ramp)] = ramp
        for at, index in zip((600, 700, 800, 1200), range(5, 9)):
            neutral = bytes.fromhex('46ec306b9bed541afbff2006') + reference(at + 12, index) + bytes.fromhex('00ff911d81ee021a00ef010d')
            code[at:at + len(neutral)] = neutral
        code[1100:1136] = constants
    code[200:200 + len(quantizer)] = quantizer
    text = dict(offset=256, address=base, length=len(code), segment=b'__TEXT', name=b'__text')
    sections = [text]
    if mac:
        sections.append(dict(offset=2304, address=address, length=len(constants), segment=b'__TEXT', name=b'__literal4'))
    return SimpleNamespace(data=bytes(256) + code + (constants if mac else b''), text=text,
                           sections=sections, architecture='x86_64' if mac else 'armv7', slice_offset=4096)


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class PilotResponseTests(unittest.TestCase):
    def test_relocated_and_alternative_constants(self):
        for mac in (True, False):
            for relocation in (0, 0x3200):
                m = fixture(mac, relocation)
                result = extract_pilot_response(m, {'available': True})
                self.assertEqual(result['target_gain'], 630)
                self.assertEqual(result['target_divisor'], 63)
                self.assertEqual(result['ramp_bias'], 3)
                self.assertEqual(result['ramp_scale'], 16 if mac else 20)
                self.assertEqual(result['neutral_divisor'], 120)
                self.assertEqual(result['command_curve'], 'signed_square')
                sizes = ([54, 33, 33, 32, 32, 32, 32] + [4] * 9 if mac else [54, 58, 28, 28, 28, 28] + [4] * 7)
                self.assertEqual([p['bytes'] for p in result['provenance']], sizes)
                self.assertEqual(result['provenance'][0]['offset'], 4096 + 256 + 200)
                self.assertTrue(all(4096 <= p['offset'] < 4096 + len(m.data) for p in result['provenance']))
                self.assertEqual(extract_pilot_response(m, {}), {})

    def test_ambiguous_corrupt_and_disagreeing_data_is_unsupported(self):
        cases = ['duplicate', 'quantizer', 'ramp', 'neutral', 'nan', 'positive_gain', 'zero_bias', 'neutral_signs', 'neutral_mismatch', 'extent', 'target', 'load']
        for mac in (True, False):
            for corruption in cases + (['ramp_mismatch', 'scale_mismatch'] if mac else ['immediate']):
                m = fixture(mac); data = bytearray(m.data)
                constant = 2304 if mac else 1356
                if corruption == 'duplicate': data[256 + 1600:256 + 1654] = data[456:510]
                elif corruption == 'extent':
                    if mac: m.sections[-1]['length'] -= 1
                    else: m.data = m.data[:constant + 35]; data = bytearray(m.data)
                elif corruption == 'target': data[256 + 200 + (4 if mac else 2)] ^= 0x80
                elif corruption == 'load': data[256 + 200 + (0 if mac else 3)] ^= 0x10
                elif corruption == 'immediate': data[256 + 418:256 + 422] = bytes(4)
                elif corruption in ('quantizer', 'ramp', 'neutral'):
                    at = {'quantizer': 220, 'ramp': 424, 'neutral': 600}[corruption]
                    data[256 + at] ^= 1
                else:
                    changes = {'nan': [(0, float('nan'))], 'positive_gain': [(0, 630)], 'zero_bias': [(1, 0)],
                               'neutral_signs': [(5, 120), (7, 120)], 'neutral_mismatch': [(6, 121)],
                               'ramp_mismatch': [(3, 2)], 'scale_mismatch': [(4, 15)]}[corruption]
                    for index, value in changes: struct.pack_into('<f', data, constant + index * 4, value)
                m.data = bytes(data)
                self.assertEqual(extract_pilot_response(m, {'available': True}), {}, (mac, corruption))


def android(gains=(-500.0, 500.0, -500.0, 500.0), biases=(3.0,) * 4, scales=(16.0,) * 4, returns=(100.0, -100.0, 100.0, -100.0),
            ramps=('yaw', 'yaw', 'up', 'down'), magic=0x2083, copies=(1, 1, 1, 1), ramp_copies=(1, 1, 1, 1),
            outside=None, handling=0x154, omit=None):
    """PlayerEgo::right/left/up/down and update in the Android compiler's shape.

    `outside` = (direction index or 'update', pool word) points that load just before its function.
    """
    from android_fixture import TEXT, Thumb, library
    from gof2_content.android_library import AndroidLibrary
    from gof2_content.pilot_response import ANDROID_TURNS, ANDROID_UPDATE
    from test_steering import (add_imm, add_lsr, add_pc, asrs, cmp_imm, it_ne, ldrb, smmla, vcvt_s32, vdiv, vadd,
                               vldr_pc, vmov_from_core, vmov_imm, vmov_s, vneg, vsub)
    registers = [(4, 2, 0), (0, 2, 16), (2, 0, 16), (2, 0, 0)]  # quantizer q, handling, vneg source
    functions = []

    def target(owner, word, pool, address):
        return address - 4 if outside == (owner, word) else pool + 4 * word
    for index, symbol in enumerate(ANDROID_TURNS):
        address = TEXT + 0x200 * (index + 1)
        pool = address + 0x180
        q, h, negated = registers[index]
        asm = Thumb(address).push()
        for _ in range(copies[index]):
            vldr_pc(asm, q, target(index, 0, pool, address)).movw(1, magic).movt(1, 0x8208)
            if q != 4:
                vneg(asm, 4, negated)
            vcvt_s32(asm.vmul(q, 16, q).vmul(q, q, h), q, q).vmov_core(0, q)
            if q == 4:
                vneg(asm, 4, negated)
            add_lsr(asrs(smmla(asm, 0, 1, 0, 0), 1, 0, 5), 0, 1, 0, 31)
        for _ in range(ramp_copies[index]):
            asm.nop()
            if ramps[index] == 'yaw':
                vmov_imm(vldr_pc(asm, 6, target(index, 1, pool, address)), 12, scales[index])
                add_imm(add_pc(asm, 0).ldr(0, 0, 0), 2, 0, 0x18)
                add_imm(it_ne(cmp_imm(ldrb(asm, 1, 0, 0x11), 1, 0)), 2, 0, 0x14).vldr(10, 2, 0).vcvt(8, 8)
                vdiv(vsub(asm, 6, 6, 10).vmul(2, 8, 2).vmul(6, 6, 12), 2, 2, 6)
            else:
                if ramps[index] == 'up':
                    vmov_imm(vmov_imm(asm, 6, 1.25), 12, scales[index])
                else:
                    vldr_pc(vmov_imm(asm, 12, scales[index]), 6, pool + 8)
                ldrb(add_pc(asm, 0).ldr(0, 0, 0).vldr(10, 0, 0x18).vldr(8, 0, 0x14), 0, 0, 0x11).vmul(6, 10, 6)
                vmov_s(it_ne(cmp_imm(vmov_from_core(asm, 10, 5), 0, 0)), 6, 8)
                vldr_pc(asm, 8, target(index, 1, pool, address)).vcvt(10, 10)
                vdiv(vsub(asm, 6, 8, 6).vmul(0, 10, 0).vmul(6, 6, 12), 0, 0, 6)
        asm.pop()
        while asm.here() < pool:
            asm.nop()
        words = [gains[index], biases[index], 1.45]
        functions.append((symbol, asm.data(*(struct.unpack('<I', struct.pack('<f', v))[0] for v in words)).finish(), address))
    address = TEXT + 0xa00
    pool = address + 0x100
    asm = Thumb(address).push()
    for index in range(len(returns)):
        vmov_from_core(asm, 2, 8).vcvt(2, 2).vldr(4, 9, handling).vmul(2, 2, 4)
        vadd(vdiv(vldr_pc(asm, 4, target('update', index, pool, address)), 2, 2, 4), 0, 0, 2).nop()
    asm.pop()
    while asm.here() < pool:
        asm.nop()
    functions.append((ANDROID_UPDATE, asm.data(*(struct.unpack('<I', struct.pack('<f', v))[0] for v in returns)).finish(), address))
    return AndroidLibrary(library([f for f in functions if f[0] != omit], {}))


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidPilotResponseTests(unittest.TestCase):
    def test_named_directions_and_update_give_constants_and_spans(self):
        from android_fixture import TEXT
        result = extract_pilot_response(android(), {'available': True})
        self.assertEqual({k: v for k, v in result.items() if k != 'provenance'},
                         {'target_gain': 500.0, 'target_divisor': 63, 'ramp_bias': 3.0, 'ramp_scale': 16.0,
                          'neutral_divisor': 100.0, 'mode': 'elapsed', 'command_curve': 'signed_square'})
        # quantizers, ramps (right, left, up, down), the four neutral returns, then gains, biases and return divisors
        self.assertEqual([(p['offset'] - TEXT, p['bytes']) for p in result['provenance']],
                         [(0x202, 42), (0x402, 42), (0x602, 42), (0x802, 42), (0x22e, 50), (0x42e, 50), (0x62e, 62), (0x82e, 62),
                          (0xa02, 28), (0xa20, 28), (0xa3e, 28), (0xa5c, 28),
                          (0x380, 4), (0x580, 4), (0x780, 4), (0x980, 4), (0x384, 4), (0x584, 4), (0x784, 4), (0x984, 4),
                          (0xb00, 4), (0xb04, 4), (0xb08, 4), (0xb0c, 4)])
        self.assertEqual(extract_pilot_response(android(), {}), {})

    def test_each_broken_declaration_is_unsupported(self):
        from gof2_content.pilot_response import ANDROID_TURNS, ANDROID_UPDATE
        cases = {'magic': dict(magic=0x2084), 'two quantizers': dict(copies=(1, 2, 1, 1)), 'two ramps': dict(ramp_copies=(1, 1, 2, 1)),
                 'ramp shape': dict(ramps=('up', 'yaw', 'up', 'down')), 'gain outside': dict(outside=(1, 0)),
                 'bias outside': dict(outside=(2, 1)), 'return outside': dict(outside=('update', 3)),
                 'gain sign': dict(gains=(500.0, 500.0, -500.0, 500.0)), 'gain magnitude': dict(gains=(-500.0, 400.0, -500.0, 500.0)),
                 'bias differs': dict(biases=(3.0, 3.0, 2.5, 3.0)), 'scale differs': dict(scales=(16.0, 16.0, 16.0, 20.0)),
                 'three returns': dict(returns=(100.0, -100.0, 100.0)), 'five returns': dict(returns=(100.0, -100.0) * 2 + (100.0,)),
                 'return magnitude': dict(returns=(100.0, -100.0, 100.0, -90.0)), 'positive returns': dict(returns=(100.0,) * 4),
                 'negative returns': dict(returns=(-100.0,) * 4), 'gain range': dict(gains=(-2e6, 2e6, -2e6, 2e6)),
                 'bias range': dict(biases=(11.0,) * 4), 'bias sign': dict(biases=(-3.0,) * 4), 'scale sign': dict(scales=(-16.0,) * 4),
                 'return range': dict(returns=(2e4, -2e4, 2e4, -2e4)), 'handling field': dict(handling=0x150)}
        cases.update({name: dict(omit=name) for name in [*ANDROID_TURNS, ANDROID_UPDATE]})
        for name, options in cases.items():
            self.assertEqual(extract_pilot_response(android(**options), {'available': True}), {}, name)
