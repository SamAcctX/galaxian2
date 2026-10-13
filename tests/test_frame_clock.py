"""Synthetic scene caps and linked millisecond suppliers, never executed."""
import importlib.util
import struct
from types import SimpleNamespace
import unittest
from test_ship_models import branch
from gof2_content.frame_clock import extract_frame_clock


def fixture(mac, relocation=0):
    base = (0x100002000 if mac else 0x2000) + relocation
    code = bytearray(2048)
    if mac:
        clamp = bytearray.fromhex('498b7d10e8000000003d780000007f12498b7d10e8000000004889c131c085c97822498b7d10e8000000004889c1b87800000081f9780000007f09498b7d10e80000000041894548')
        calls = (4, 20, 38, 63)
        helper = bytes.fromhex('554889e548897df8488b7df8488b87c0000000482b87c80000005dc3')
        for at in calls: struct.pack_into('<i', clamp, at + 1, 1200 - 300 - at - 5)
    else:
        clamp = bytearray.fromhex('782c08dcdbf808004ff0ff31b49100000000002810dbdbf808004ff0ff34b49400000000782801dd782006e0dbf80800b4940000000000e0002000ee900b')
        calls = (14, 32, 50)
        helper = bytes.fromhex('82b00190c16e026f436f806fc91a62eb000000900846009902b07047')
        for at in calls: clamp[at:at + 4] = branch(base + 300 + at, base + 1200)
    code[300:300 + len(clamp)] = clamp
    code[1200:1200 + len(helper)] = helper
    text = dict(offset=256, address=base, length=len(code), segment=b'__TEXT', name=b'__text')
    return SimpleNamespace(data=bytes(256) + code, text=text, sections=[text],
                           architecture='x86_64' if mac else 'armv7', slice_offset=4096)


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class FrameClockTests(unittest.TestCase):
    def test_both_relocated_clocks_and_alternate_cap(self):
        for mac in (True, False):
            for relocation in (0, 0x3400):
                m = fixture(mac, relocation)
                result = extract_frame_clock(m, {'supported': True})
                self.assertEqual(result['max_frame_milliseconds'], 120)
                self.assertEqual(result['time_unit'], 'milliseconds')
                self.assertEqual(result['provenance'], [{'offset': 4096 + 256 + 300, 'bytes': 72 if mac else 62},
                                                        {'offset': 4096 + 256 + 1200, 'bytes': 28}])
                self.assertEqual(extract_frame_clock(m, {}), {})

    def test_disagreement_bad_calls_and_invalid_suppliers(self):
        for mac in (True, False):
            for case in ('disagree', 'zero', 'call', 'helper', 'extent', 'duplicate'):
                m = fixture(mac); data = bytearray(m.data)
                if case == 'disagree': data[256 + 300 + (10 if mac else 0)] = 119
                elif case == 'zero':
                    for at in ((10, 47, 53) if mac else (0, 36, 40)):
                        data[256 + 300 + at] = 0
                elif case == 'call': data[256 + 300 + (5 if mac else 14)] ^= 1
                elif case == 'helper': data[256 + 1200] ^= 1
                elif case == 'extent': m.sections[0]['length'] = 1210
                elif case == 'duplicate':
                    count = 72 if mac else 62
                    data[256 + 1600:256 + 1600 + count] = data[256 + 300:256 + 300 + count]
                m.data = bytes(data)
                self.assertEqual(extract_frame_clock(m, {'supported': True}), {}, (mac, case))


def android(caps=(120, 120, 120), calls=('clock',) * 4, clock_field=0x70, copies=1, omit=None):
    """MGame::OnUpdate's frame cap and ApplicationManager::GetElapsedTimeMillis in the Android shape."""
    from android_fixture import TEXT, Thumb, library, stub
    from gof2_content.android_library import AndroidLibrary
    from gof2_content.frame_clock import ANDROID_ELAPSED, ANDROID_UPDATE
    from test_steering import asrs, assemble, b_to, cmp_imm, ldr_w, ldrd, sbc_w, str_pre, subs_w, vmov_scalar
    update, clock = TEXT + 0x100, TEXT + 0x400

    def emit(asm, L):
        asm.push()
        for copy in range(copies):
            targets = iter([clock if c == 'clock' or copy else stub('puts') for c in calls])
            def label(name): return f'{name}{copy}'
            def to(name): return L.get(label(name), asm.here() + 4)
            ldr_w(asm, 0, 11, 8).call(next(targets))
            b_to(cmp_imm(asm, 0, caps[0]), to('clamp'), 'gt')
            ldr_w(asm, 0, 11, 8).call(next(targets))
            b_to(cmp_imm(asm, 0, 0), to('zero'), 'lt').label(label('clamp'))
            ldr_w(asm, 0, 11, 8).call(next(targets))
            b_to(cmp_imm(asm, 0, caps[1]), to('fresh'), 'le').movs(0, caps[2])
            b_to(asm, to('store')).label(label('fresh'))
            ldr_w(asm, 0, 11, 8).call(next(targets))
            b_to(asm, to('store')).label(label('zero')).movs(0, 0).label(label('store'))
            vmov_scalar(asrs(vmov_scalar(asm, 16, 0, 0), 1, 0, 31), 16, 1, 1)
            vmov_scalar(vmov_scalar(asm, 17, 0, 0), 17, 1, 1).mov(1, 11)
            str_pre(asm, 0, 1, 0x40)
        asm.pop()
    functions = [(ANDROID_UPDATE, assemble(update, emit).finish(), update)]
    asm = Thumb(clock)
    ldrd(ldrd(asm, 12, 2, 0, clock_field), 3, 1, 0, 0x78)
    functions.append((ANDROID_ELAPSED, sbc_w(subs_w(asm, 0, 12, 3), 1, 2, 1).ret().finish(), clock))
    return AndroidLibrary(library([f for f in functions if f[0] != omit], {}))


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidFrameClockTests(unittest.TestCase):
    def test_named_cap_and_clock(self):
        from android_fixture import TEXT
        result = extract_frame_clock(android(), {'supported': True})
        self.assertEqual(result, {'max_frame_milliseconds': 120, 'time_unit': 'milliseconds',
                                  'provenance': [{'offset': TEXT + 0x102, 'bytes': 76}, {'offset': TEXT + 0x400, 'bytes': 18}]})
        self.assertEqual(extract_frame_clock(android(), {}), {})

    def test_each_broken_declaration_is_unsupported(self):
        from gof2_content.frame_clock import ANDROID_ELAPSED, ANDROID_UPDATE
        cases = {'disagree': dict(caps=(120, 119, 120)), 'clamp value': dict(caps=(120, 120, 119)), 'zero': dict(caps=(0, 0, 0)),
                 'first call': dict(calls=('puts', 'clock', 'clock', 'clock')), 'second call': dict(calls=('clock', 'puts', 'clock', 'clock')),
                 'third call': dict(calls=('clock', 'clock', 'puts', 'clock')), 'fourth call': dict(calls=('clock', 'clock', 'clock', 'puts')),
                 'clock field': dict(clock_field=0x68), 'duplicate': dict(copies=2), 'no update': dict(omit=ANDROID_UPDATE),
                 'no clock': dict(omit=ANDROID_ELAPSED)}
        for name, options in cases.items():
            self.assertEqual(extract_frame_clock(android(**options), {'supported': True}), {}, name)
