"""Relocated synthetic declarations: speed, consumer and forward-axis identity."""
import importlib.util
import struct
from types import SimpleNamespace
import unittest
from test_ship_models import branch
from gof2_content.cruise import extract_cruise


def fixture(mac, relocation=0, speed=3.5):
    base = (0x100002000 if mac else 0x2000) + relocation
    code = bytearray(1536)
    def call(at, target):
        return b'\xe8' + struct.pack('<i', target - at - 5) if mac else branch(base + at, base + target)
    if mac:
        initial = bytes.fromhex('c783f8000000') + struct.pack('<f', speed) + bytes.fromhex('4c8d35') + bytes(4) + bytes.fromhex('c783fc000000') + struct.pack('<f', 1)
        reset = bytes.fromhex('554889e55350c787f8000000') + struct.pack('<f', speed) + bytes.fromhex('c6878c01000000')
        step = bytes.fromhex('f3410f2a8d84010000f3410f598dfc000000f3410f1085f8000000f30f59c1498b7d10')
        helper = bytes.fromhex('554889e54156534881ec80000000f30f1145804889fb8b7314488b7b38') + call(512 + 28, 900) + bytes.fromhex('4889c7')
        getter = bytes.fromhex('554889e54883ec3048897de8f30f104708f30f104f18f30f105728')
    else:
        # Synthetic constructor/reset with a legal Thumb modified immediate.
        initial = bytes.fromhex('4ff07e50d1f800a04ff08041c4f8b810c4f8bc00')
        reset = bytes.fromhex('90b540f200014ff08042c0f20001c0f8b820794401af0c68002180f83811')
        step = bytes.fromhex('98ed4c0a98ed2f2afbff000698ed2e1ad8f8080040ff920d00ff910d10ee101a')
        helper = bytes.fromhex('f0b503af2ded028b99b004460d46e168e06a') + call(512 + 18, 900) + bytes.fromhex('04ae01463046')
        getter = bytes.fromhex('80b56f4682b00191019991ed020a019991ed062a019991ed0a4a10ee101a12ee102a14ee103a')
    step += call(256 + len(step), 512)
    helper += call(512 + len(helper), 768)
    for at, value in [(64, initial), (160, reset), (256, step), (512, helper), (768, getter)]:
        code[at:at + len(value)] = value
    text = {'offset': 256, 'length': len(code), 'address': base, 'segment': b'__TEXT', 'name': b'__text'}
    return SimpleNamespace(data=bytes(256) + code, text=text, sections=[text], slice_offset=4096,
                           architecture='x86_64' if mac else 'armv7')


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class CruiseTests(unittest.TestCase):
    def test_independent_relocated_scalar_and_provenance(self):
        for mac in (True, False):
            for relocation in (0, 0x6200):
                result = extract_cruise(fixture(mac, relocation))
                self.assertEqual(result['speed_units_per_millisecond'], 3.5 if mac else 2.0)
                self.assertEqual(result['forward_axis'], [0, 0, 1])
                self.assertEqual([p['offset'] for p in result['provenance']],
                                 [4096 + 256 + i for i in (64, 160, 256, 512, 768)])
                self.assertEqual([p['bytes'] for p in result['provenance']],
                                 [27, 23, 40, 42, 27] if mac else [20, 30, 36, 32, 38])

    def test_missing_conflicting_or_wrong_direction_paths_are_unsupported(self):
        for mac in (True, False):
            for corruption in ('duplicate', 'reset', 'step', 'helper', 'getter', 'outside', 'extent'):
                mach = fixture(mac)
                data = bytearray(mach.data)
                if corruption == 'duplicate':
                    n = 27 if mac else 20
                    data[256 + 1024:256 + 1024 + n] = data[256 + 64:256 + 64 + n]
                elif corruption == 'reset':
                    # Different restored speed, retaining the declaration layout.
                    at = 256 + 160 + (11 if mac else 6)
                    replacement = struct.pack('<f', 4.0) if mac else bytes.fromhex('4ff08142')
                    data[at:at + 4] = replacement
                elif corruption == 'outside':
                    at = 256 + (35 if mac else 32)
                    data[256 + at:256 + at + (5 if mac else 4)] = (
                        b'\xe8' + struct.pack('<i', 8192 - at - 5) if mac else branch(mach.text['address'] + at, mach.text['address'] + 8192))
                elif corruption == 'extent': mach.text['length'] = 780
                else:
                    at = {'step': 256, 'helper': 512, 'getter': 768}[corruption]
                    data[256 + at] ^= 1
                mach.data = bytes(data)
                self.assertEqual(extract_cruise(mach), {}, (mac, corruption))

    def test_invalid_constants_and_throttle_do_not_become_motion(self):
        for speed in (0, -2, float('nan'), float('inf'), 1001):
            self.assertEqual(extract_cruise(fixture(True, speed=speed)), {})
        for mac in (True, False):
            mach = fixture(mac)
            data = bytearray(mach.data)
            if mac: data[256 + 64 + 23:256 + 64 + 27] = struct.pack('<f', 0.5)
            else: data[256 + 64:256 + 64 + 4] = bytes.fromhex('4ff07c50')
            mach.data = bytes(data)
            self.assertEqual(extract_cruise(mach), {})


def android(speed=0x40800000, throttle=0x3f800000, restored=None, field=0xb8, consumer_field=None,
            columns=(0x18, 8, 0x28), getter_second=True, pairs=1, omit=None, reset_field=None,
            throttle_field=None, speed_field=None, moves=True):
    """Synthetic player functions in the Android compiler's shape (4.0 units/ms)."""
    from android_fixture import TEXT, Thumb, library, stub
    getter, helper, update, reset, constructor = (TEXT + 0x100 * i for i in range(1, 6))
    names = {'getter': '_ZN11AbyssEngine6AEMath12MatrixGetDirERKNS0_6MatrixE', 'helper': '_ZN10AEGeometry11moveForwardEf',
             'update': '_ZN9PlayerEgo14updateManeuverEv', 'reset': '_ZN9PlayerEgo9stopBoostEv',
             'constructor': '_ZN9PlayerEgoC2EP6Player'}
    code = {}
    asm = Thumb(getter).ldr(3, 1, columns[0]).ldr(2, 1, columns[1]).ldr(1, 1, columns[2]).strd(2, 3, 0, 0).str(1, 0, 8).ret()
    code['getter'] = (asm.finish(), getter)
    asm = Thumb(helper).push()
    first, second = (stub('puts'), getter) if getter_second else (getter, stub('puts'))
    asm.call(first, exchange=first == stub('puts')).call(second, exchange=second == stub('puts')).pop()
    code['helper'] = (asm.finish(), helper)
    step = consumer_field if consumer_field is not None else field
    asm = Thumb(update).push().vldr(0, 4, 0x134).vcvt(0, 0).vldr(2, 4, throttle_field or step + 4).ldr(0, 4, 8).vmul(0, 0, 2)
    asm.vldr(2, 4, speed_field or step).vmul(0, 0, 2).vmov_core(1, 0)
    code['update'] = ((asm.call(helper, exchange=False) if moves else asm.call(stub('puts'))).pop().finish(), update)
    asm = Thumb(reset).push().mov_imm(2, speed if restored is None else restored).str_w(2, 0, reset_field or field).pop()
    code['reset'] = (asm.finish(), reset)
    asm = Thumb(constructor).push().mov_imm(10, throttle).nop().nop()
    for _ in range(pairs):
        asm.mov_imm(1, speed).strd(1, 10, 4, field)
    code['constructor'] = (asm.pop().finish(), constructor)
    from gof2_content.android_library import AndroidLibrary
    return AndroidLibrary(library([(names[k], c, a) for k, (c, a) in code.items() if k != omit], {}))


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidCruiseTests(unittest.TestCase):
    def test_named_declarations_give_speed_axis_and_spans(self):
        from android_fixture import TEXT
        result = extract_cruise(android())
        self.assertEqual((result['speed_units_per_millisecond'], result['forward_axis']), (4.0, [0, 0, 1]))
        # throttle, speed store, restore, consumer, helper up to the getter call, getter
        self.assertEqual([(p['offset'] - TEXT, p['bytes']) for p in result['provenance']],
                         [(0x502, 4), (0x50a, 8), (0x402, 8), (0x302, 34), (0x200, 10), (0x100, 14)])

    def test_each_broken_declaration_is_unsupported(self):
        cases = {'throttle': dict(throttle=0x3f000000), 'restored': dict(restored=0x40000000),
                 'consumer': dict(consumer_field=0xc0), 'columns': dict(columns=(0x1c, 0xc, 0x2c)),
                 'order': dict(getter_second=False), 'duplicate': dict(pairs=2), 'zero': dict(speed=0),
                 'reset field': dict(reset_field=0xc0), 'throttle field': dict(throttle_field=0xc0),
                 'speed field': dict(speed_field=0xc0), 'callee': dict(moves=False),
                 'fast': dict(speed=0x45000000)}
        for name, options in cases.items():
            self.assertEqual(extract_cruise(android(**options)), {}, name)
        for part in ('getter', 'helper', 'update', 'reset', 'constructor'):
            self.assertEqual(extract_cruise(android(omit=part)), {}, part)
