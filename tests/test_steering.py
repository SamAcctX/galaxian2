"""Synthetic manual rotation declarations and independently relocated constants."""
import importlib.util
import struct
from types import SimpleNamespace
import unittest
from test_ship_models import branch
from android_fixture import library
from gof2_content.steering import extract_manual_rotation


def fixture(mac, relocation=0):
    base = (0x100002000 if mac else 0x2000) + relocation
    code = bytearray(2048)
    constants = struct.pack('<3f', 1 / 1024, 6.0, 0.025)
    address = base + (8192 if mac else 1400)
    if mac:
        loads = b''
        for i, (opcode, index) in enumerate([('f30f1015', 2), ('f30f101d', 1), ('f30f100d', 0)]):
            loads += bytes.fromhex(opcode) + struct.pack('<i', address + index * 4 - base - 300 - i * 8 - 8)
        code[300:324] = loads
        consumer = bytes.fromhex('f3410f10842414030000f30f59c1f30f59c3f30f59c4f30f59c2f3410f598c2418030000f30f59cbf30f59ccf30f59caf3410f10104c89f6e8') + struct.pack('<i', 1024 - 512 - 61)
        helper = bytes.fromhex('554889e54883ec504889f848ba3c00000000000000488975f8f30f1145f4f30f114df0f30f1155ecf30f5a45f4')
    else:
        def load(offset, index):
            delta = address + index * 4 - ((base + 512 + offset + 4) & ~3)
            return bytes([0x9f, 0xed, delta // 4, 0x0a])
        consumer = (load(0, 0) + bytes.fromhex('94ed9d1a94ed9e2a40f2000041ff104dc0f2000042ff102d')
                    + load(28, 1) + bytes.fromhex('784444ff900d006842ff902d') + load(44, 2)
                    + bytes.fromhex('48ff300d48ff322d00ff901d02ff900d11ee102a10ee103a90ed000a28a88ded000a20ef1001')
                    + branch(base + 512 + 86, base + 1024))
        helper = bytes.fromhex('80b56f468eb043ec103bb0ee402a42ec102bb0ee404a97ed026a3c22')
        code[1400:1412] = constants
    code[512:512 + len(consumer)] = consumer
    code[1024:1024 + len(helper)] = helper
    text = dict(offset=256, address=base, length=2048, segment=b'__TEXT', name=b'__text')
    sections = [text]
    if mac: sections.append(dict(offset=2304, address=address, length=12, segment=b'__TEXT', name=b'__literal4'))
    return SimpleNamespace(data=bytes(256) + code + (constants if mac else b''), text=text,
                           sections=sections, architecture='x86_64' if mac else 'armv7', slice_offset=4096)


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class SteeringTests(unittest.TestCase):
    def test_new_mac_helper_preserves_linked_constants_and_rejects_a_mixed_layout(self):
        from gof2_content.steering import MAC_HELPERS
        for relocation in (0, 0x3400):
            m = fixture(True, relocation)
            data = bytearray(m.data)
            at = 256 + 1024
            helper = bytes.fromhex(MAC_HELPERS[1])
            data[at:at + 45] = helper.ljust(45, b'\x90')
            m.data = bytes(data)
            result = extract_manual_rotation(m, {'available': True})
            self.assertEqual(result['provenance'][-1], {'offset': 4096 + at, 'bytes': 35})
            self.assertAlmostEqual(result['time_scale'], 0.025)
            # Neither a mixed stack frame nor an unlinked helper is supported.
            data[at + 7] = 0x50
            m.data = bytes(data)
            self.assertEqual(extract_manual_rotation(m, {'available': True}), {})

    def test_constants_relocation_and_profile_layout(self):
        for mac in (True, False):
            for relocation in (0, 0x3400):
                m = fixture(mac, relocation)
                result = extract_manual_rotation(m, {'available': True})
                self.assertEqual(result['angle_unit_scale'], 1 / 1024)
                self.assertEqual(result['radians_per_turn'], 6.0)
                self.assertAlmostEqual(result['time_scale'], 0.025)
                self.assertEqual(result['rotation_order'], 'local_x_y')
                self.assertEqual([p['bytes'] for p in result['provenance']],
                                 [24, 61, 4, 4, 4, 45] if mac else [90, 4, 4, 4, 28])
                self.assertEqual(result['provenance'][-1]['offset'], 4096 + 256 + 1024)
                self.assertEqual(extract_manual_rotation(m, {}), {})

    def test_invalid_constants_and_broken_links_remain_unsupported(self):
        for mac in (True, False):
            for corruption in ('duplicate', 'consumer', 'helper', 'target', 'zero', 'nan', 'negative', 'range', 'extent', 'load'):
                m = fixture(mac); data = bytearray(m.data)
                if corruption == 'duplicate':
                    count = 61 if mac else 90
                    data[256 + 1600:256 + 1600 + count] = data[256 + 512:256 + 512 + count]
                elif corruption == 'extent': m.sections[-1]['length'] -= (1 if mac else 650)
                elif corruption in ('zero', 'nan', 'negative', 'range'):
                    value = {'zero': 0, 'nan': float('nan'), 'negative': -1, 'range': 11}[corruption]
                    at = 2304 if mac else 256 + 1400
                    struct.pack_into('<f', data, at + 4, value)
                else:
                    at = {'consumer': 512 + (0 if mac else 4), 'helper': 1024,
                          'target': 512 + (57 if mac else 87), 'load': 300 if mac else 512}[corruption]
                    data[256 + at] ^= 1
                m.data = bytes(data)
                self.assertEqual(extract_manual_rotation(m, {'available': True}), {}, (mac, corruption))


def vfp(asm, base, sd, sn=0, sm=0):
    """A VFP single-precision instruction: base | D:Vd, N:Vn, M:Vm fields."""
    word = base | (sd & 1) << 22 | (sn >> 1) << 16 | (sd >> 1) << 12 | (sn & 1) << 7 | (sm & 1) << 5 | sm >> 1
    return asm.half(word >> 16, word & 0xffff)


def vadd(asm, sd, sn, sm): return vfp(asm, 0xee300a00, sd, sn, sm)
def vsub(asm, sd, sn, sm): return vfp(asm, 0xee300a40, sd, sn, sm)
def vdiv(asm, sd, sn, sm): return vfp(asm, 0xee800a00, sd, sn, sm)
def vneg(asm, sd, sm): return vfp(asm, 0xeeb10a40, sd, 0, sm)
def vmov_s(asm, sd, sm): return vfp(asm, 0xeeb00a40, sd, 0, sm)  # vmov.f32 sd, sm
def vcvt_s32(asm, sd, sm): return vfp(asm, 0xeebd0ac0, sd, 0, sm)  # vcvt.s32.f32 (toward zero)
def vmov_from_core(asm, sn, rt): return vfp(asm, 0xee000a10 | rt << 12, 0, sn, 0)  # vmov sn, rt


def vmov_imm(asm, sd, value):
    """vmov.f32 sd, #value: the VFP 8-bit immediate (VFPExpandImm) that equals value."""
    def expand(imm):
        return (-1) ** (imm >> 7) * (16 + (imm & 15)) / 16 * 2.0 ** (((imm >> 4 & 7) ^ 4) - 3)
    imm = next(i for i in range(256) if struct.pack('<f', expand(i)) == struct.pack('<f', value))
    return vfp(asm, 0xeeb00a00 | (imm >> 4) << 16 | imm & 15, sd)


def wide(asm, word): return asm.half(word >> 16, word & 0xffff)
def smmla(asm, rd, rn, rm, ra): return wide(asm, 0xfb500000 | rn << 16 | ra << 12 | rd << 8 | rm)
def asrs(asm, rd, rm, shift): return asm.half(0x1000 | shift << 6 | rm << 3 | rd)
def add_lsr(asm, rd, rn, rm, shift, kind=1):  # add.w rd, rn, rm, lsr #shift (kind 0: lsl)
    return wide(asm, 0xeb000000 | rn << 16 | (shift >> 2) << 12 | rd << 8 | (shift & 3) << 6 | kind << 4 | rm)
def modified(value):
    """Thumb-2 modified immediate (i:imm3:imm8) of a value below 256 or an 8-bit rotated pattern."""
    if value < 256:
        return value
    return next(rotation << 7 | rotated & 0x7f for rotation in range(8, 32)
                for rotated in [(value << rotation | value >> (32 - rotation)) & 0xffffffff] if rotated < 256 and rotated & 0x80)


def add_imm(asm, rd, rn, imm):  # add.w rd, rn, #imm
    field = modified(imm)
    return wide(asm, 0xf1000000 | (field >> 11) << 26 | rn << 16 | (field >> 8 & 7) << 12 | rd << 8 | field & 255)
def strb_w(asm, rt, rn, offset): return wide(asm, 0xf8800000 | rn << 16 | rt << 12 | offset)
def blx_reg(asm, rm): return asm.half(0x4780 | rm << 3)
def add_pc(asm, rd): return asm.half(0x4478 | rd)
def ldrb(asm, rt, rn, offset): return asm.half(0x7800 | offset << 6 | rn << 3 | rt)
def cmp_imm(asm, rn, imm): return asm.half(0x2800 | rn << 8 | imm)
def it_ne(asm): return asm.half(0xbf18)
def vstr(asm, sd, rn, offset): return asm.half(0xed80 | (sd & 1) << 6 | rn, (sd >> 1) << 12 | 0xa00 | offset // 4)
def ldr_w(asm, rt, rn, offset): return wide(asm, 0xf8d00000 | rn << 16 | rt << 12 | offset)  # ldr.w rt, [rn, #offset]
def ldr_reg(asm, rt, rn, rm, shift=None):  # ldr rt, [rn, rm] or ldr.w rt, [rn, rm, lsl #shift]
    return asm.half(0x5800 | rm << 6 | rn << 3 | rt) if shift is None else wide(asm, 0xf8500000 | rn << 16 | rt << 12 | shift << 4 | rm)
def cmp_w(asm, rn, imm): return wide(asm, 0xf1b00f00 | rn << 16 | imm)  # cmp.w rn, #imm (< 256)
def cmp_reg(asm, rn, rm):
    return asm.half(0x4280 | rm << 3 | rn) if rn < 8 and rm < 8 else asm.half(0x4500 | (rn >> 3) << 7 | rm << 3 | rn & 7)
def adds8(asm, rd, imm): return asm.half(0x3000 | rd << 8 | imm)  # adds rd, #imm
def tbb(asm, rm): return wide(asm, 0xe8dff000 | rm)
def vmov_scalar(asm, dd, index, rt): return wide(asm, 0xee000b10 | index << 21 | (dd & 15) << 16 | rt << 12 | (dd >> 4) << 7)
def str_pre(asm, rt, rn, imm): return wide(asm, 0xf8400f00 | rn << 16 | rt << 12 | imm)  # str rt, [rn, #imm]!
def ldrd(asm, rt, rt2, rn, offset): return wide(asm, 0xe9d00000 | rn << 16 | rt << 12 | rt2 << 8 | offset // 4)
def subs_w(asm, rd, rn, rm): return wide(asm, 0xebb00000 | rn << 16 | rd << 8 | rm)
def sbc_w(asm, rd, rn, rm): return wide(asm, 0xeb600000 | rn << 16 | rd << 8 | rm)
def vmov_q8_zero(asm): return wide(asm, 0xefc00050)  # vmov.i32 q8, #0
def vpush_d8(asm): return wide(asm, 0xed2d8b02)
def push_r7(asm): return asm.half(0xb580)  # push {r7, lr}
def pop_r7(asm): return asm.half(0xbd80)  # pop {r7, pc}


CONDITIONS = {'eq': 0, 'ne': 1, 'hs': 2, 'lo': 3, 'mi': 4, 'pl': 5, 'hi': 8, 'ls': 9, 'ge': 10, 'lt': 11, 'gt': 12, 'le': 13}


def cbz(asm, rn, target, nonzero=False):  # cbz (or cbnz) rn, target
    offset = target - (asm.here() + 4)
    assert 0 <= offset < 128
    return asm.half((0xb900 if nonzero else 0xb100) | (offset >> 6 & 1) << 9 | (offset >> 1 & 31) << 3 | rn)


def sub_sp(asm, imm): return asm.half(0xb080 | imm // 4)  # sub sp, #imm
def ldr_lit(asm, rt, offset): return asm.half(0x4800 | rt << 8 | offset // 4)  # ldr rt, [pc, #offset]


def b_to(asm, target, condition=None, wide_form=False):
    """b/b<cond> (16-bit) or b.w/b<cond>.w (32-bit) to an address."""
    offset = target - (asm.here() + 4)
    if wide_form and condition is None:  # b.w
        from android_fixture import branch_fields
        sign, j1, j2, value = branch_fields(offset, False)
        return asm.half(0xf000 | sign << 10 | value >> 11 & 0x3ff, 0x9000 | j1 << 13 | j2 << 11 | value & 0x7ff)
    if wide_form:
        value = offset >> 1 & 0xfffff
        return asm.half(0xf000 | (offset < 0) << 10 | CONDITIONS[condition] << 6 | value >> 11 & 63,
                        0x8000 | (value >> 17 & 1) << 13 | (value >> 18 & 1) << 11 | value & 0x7ff)
    if condition is None:
        return asm.half(0xe000 | offset >> 1 & 0x7ff)
    return asm.half(0xd000 | CONDITIONS[condition] << 8 | offset >> 1 & 0xff)


def roomy_library(functions, strings=None):
    """android_fixture.library with .dynstr moved to the image's end: its fixed slot holds about 500 name bytes."""
    from android_fixture import IMPORTS
    image = bytearray(library(functions, strings or {}))
    names = b'\0' + b''.join(name.encode() + b'\0' for name in IMPORTS) + b''.join(f[0].encode() + b'\0' for f in functions)
    table, = struct.unpack_from('<I', image, 32)
    struct.pack_into('<III', image, table + 40 * 2 + 12, len(image), len(image), len(names))  # .dynstr address, offset, size
    return bytes(image + names)


def assemble(address, emit):
    """Thumb code from `emit(asm, labels)`, run twice so branches reach labels set later.

    The first pass sees no labels (`labels.get(name, asm.here() + 4)` keeps encodings in range);
    encodings have fixed sizes, so the second pass places every label where the first did.
    """
    from android_fixture import Thumb
    labels = {}
    for _ in range(2):
        asm = Thumb(address)
        emit(asm, labels)
        labels = dict(asm.labels)
    return asm


def vldr_pc(asm, sd, target):
    """vldr sd, [pc, #+-k]: target - Align(pc, 4) (the fixture's vldr only adds)."""
    disp = target - ((asm.here() + 4) & ~3)
    return asm.vldr(sd, 15, disp) if disp >= 0 else asm.half(0xed1f | (sd & 1) << 6, (sd >> 1) << 12 | 0xa00 | -disp // 4)


def android(constants=(1 / 1024, 6.0, 0.025), fields=(0x278, 0x27c), steps=1, call=None, pool='inside', omit=None):
    """PlayerEgo::handleShip's rotation step in the Android compiler's shape.

    pool 'after'/'before' moves the last float just past the handler's end
    (into the helper) or just before its start (into a preceding function).
    """
    from android_fixture import TEXT, Thumb, library, stub
    from gof2_content.android_library import AndroidLibrary
    from gof2_content.steering import ANDROID_HANDLER, ANDROID_HELPER
    words = [struct.unpack('<I', struct.pack('<f', v))[0] for v in constants]
    before, handler, helper = TEXT + 0x80, TEXT + 0x100, TEXT + 0x400
    table = handler + 0x100
    last = {'inside': table + 8, 'after': helper + 4, 'before': before + 4}[pool]
    asm = Thumb(handler).push()
    for _ in range(steps):
        vldr_pc(asm, 0, table).vldr(2, 11, fields[0]).vldr(4, 11, fields[1]).vcvt(16, 6).vmul(2, 2, 0).str_w(9, 13, 0).vmul(0, 4, 0)
        vldr_pc(asm, 4, table + 4).vmul(2, 2, 4).vmul(0, 0, 4)
        vldr_pc(asm, 4, last).vmul(2, 16, 2).vmul(0, 16, 0).vmul(2, 2, 4).vmul(0, 0, 4).vmov_core(2, 2).vmov_core(3, 0)
        asm.call(stub(call) if call else helper)
    asm.pop()
    while asm.here() < table:
        asm.nop()
    code = asm.data(*words[:2] + (words[2:] if pool == 'inside' else [])).finish()
    functions = [(ANDROID_HANDLER, code, handler), (ANDROID_HELPER, Thumb(helper).push().pop().data(words[2]).finish(), helper),
                 ('_Z6beforev', Thumb(before).push().pop().data(words[2]).finish(), before)]
    return AndroidLibrary(library([f for f in functions if f[0] != omit], {}))


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidSteeringTests(unittest.TestCase):
    def test_test_encodings_are_the_named_instructions(self):
        import capstone
        from android_fixture import Thumb
        asm = Thumb(0x2000)
        vadd(asm, 0, 0, 2); vsub(asm, 6, 8, 6); vdiv(asm, 2, 2, 6); vneg(asm, 4, 16); vmov_s(asm, 6, 8); vcvt_s32(asm, 4, 4)
        vmov_from_core(asm, 10, 5); vmov_imm(asm, 12, 20.0); vmov_imm(asm, 6, 1.25); vmov_imm(asm, 6, -0.125)
        smmla(asm, 0, 1, 0, 0); asrs(asm, 1, 0, 5); add_lsr(asm, 0, 1, 0, 31); add_imm(asm, 2, 0, 0x18); add_pc(asm, 0)
        ldrb(asm, 1, 0, 0x11); cmp_imm(asm, 1, 0); it_ne(asm); add_imm(asm, 2, 0, 0x14)
        vstr(asm, 0, 4, 0x154); ldr_w(asm, 12, 2, 0); ldr_reg(asm, 0, 0, 5); ldr_reg(asm, 1, 2, 3, 2); cmp_w(asm, 12, 0)
        cmp_reg(asm, 3, 1); cmp_reg(asm, 3, 12); adds8(asm, 3, 1); tbb(asm, 0); add_lsr(asm, 0, 14, 2, 2, 0)
        cbz(asm, 2, asm.here() + 4 + 0x42); b_to(asm, 0x2000, 'lo'); b_to(asm, 0x2200); b_to(asm, 0x2400, 'hi', True)
        b_to(asm, 0x1000, 'eq', True); b_to(asm, 0x3000, None, True); cbz(asm, 1, asm.here() + 8, True); sub_sp(asm, 0x14)
        ldr_lit(asm, 0, 0x6c); vmov_q8_zero(asm); vpush_d8(asm); push_r7(asm); pop_r7(asm)
        vmov_scalar(asm, 16, 0, 0); vmov_scalar(asm, 17, 1, 1); str_pre(asm, 0, 1, 0x40); ldrd(asm, 12, 2, 0, 0x70)
        subs_w(asm, 0, 12, 3); sbc_w(asm, 1, 2, 1); add_imm(asm, 8, 13, 0x1e8); add_imm(asm, 9, 13, 0x190); strb_w(asm, 6, 9, 0x48)
        blx_reg(asm, 4)
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        self.assertEqual([f'{i.mnemonic} {i.op_str}' for i in decoder.disasm(bytes(asm.code), 0x2000)],
                         ['vadd.f32 s0, s0, s2', 'vsub.f32 s6, s8, s6', 'vdiv.f32 s2, s2, s6', 'vneg.f32 s4, s16',
                          'vmov.f32 s6, s8', 'vcvt.s32.f32 s4, s4', 'vmov s10, r5', 'vmov.f32 s12, #2.000000e+01',
                          'vmov.f32 s6, #1.250000e+00', 'vmov.f32 s6, #-1.250000e-01', 'smmla r0, r1, r0, r0',
                          'asrs r1, r0, #5', 'add.w r0, r1, r0, lsr #31', 'add.w r2, r0, #0x18', 'add r0, pc',
                          'ldrb r1, [r0, #0x11]', 'cmp r1, #0', 'it ne', 'addne.w r2, r0, #0x14', 'vstr s0, [r4, #0x154]',
                          'ldr.w ip, [r2]', 'ldr r0, [r0, r5]', 'ldr.w r1, [r2, r3, lsl #2]', 'cmp.w ip, #0', 'cmp r3, r1',
                          'cmp r3, ip', 'adds r3, #1', 'tbb [pc, r0]', 'add.w r0, lr, r2, lsl #2', 'cbz r2, #0x20a8',
                          'blo #0x2000', 'b #0x2200', 'bhi.w #0x2400', 'beq.w #0x1000', 'b.w #0x3000', 'cbnz r1, #0x207c', 'sub sp, #0x14',
                          'ldr r0, [pc, #0x6c]', 'vmov.i32 q8, #0', 'vpush {d8}',
                          'push {r7, lr}', 'pop {r7, pc}', 'vmov.32 d16[0], r0', 'vmov.32 d17[1], r1', 'str r0, [r1, #0x40]!',
                          'ldrd ip, r2, [r0, #0x70]', 'subs.w r0, ip, r3', 'sbc.w r1, r2, r1', 'add.w r8, sp, #0x1e8',
                          'add.w sb, sp, #0x190', 'strb.w r6, [sb, #0x48]', 'blx r4'])

    def test_pc_literal_operands_in_both_number_styles(self):
        from android_fixture import Thumb
        from gof2_content.android_library import AndroidLibrary, instructions
        from gof2_content.steering import PC, shape_at
        asm = Thumb(0x2100)
        for target in (0x2108, 0x2108, 0x20fc, 0x2400):
            vldr_pc(asm, 0, target)
        lib = AndroidLibrary(library([('_Z1fv', asm.finish(), 0x2100)], {}))
        code = instructions(lib, '_Z1fv')
        self.assertEqual([i.op_str for i in code], ['s0, [pc, #4]', 's0, [pc]', 's0, [pc, #-0x10]', 's0, [pc, #0x2f0]'])
        self.assertEqual(shape_at(code, [('vldr', 's0, ' + PC)]), [0, 1, 2, 3])
        self.assertEqual(shape_at(code, [('vldr', 's1, ' + PC)]), [])

    def test_shape_calls_name_their_target(self):
        from android_fixture import Thumb
        from gof2_content.android_library import AndroidLibrary, instructions
        from gof2_content.steering import shape_at
        lib = AndroidLibrary(library([('_Z1fv', Thumb(0x2100).push().call(0x2200).pop().finish(), 0x2100),
                                      ('_Z1gv', Thumb(0x2200).ret().finish(), 0x2200), ('_Z1hv', Thumb(0x2300).ret().finish(), 0x2300)], {}))
        code = instructions(lib, '_Z1fv')
        self.assertEqual(shape_at(code, [('blx', '=_Z1gv')], lib), [1])
        self.assertEqual(shape_at(code, [('blx', '=_Z1hv')], lib), [])

    def test_roomy_library_keeps_long_names(self):
        from android_fixture import Thumb
        from gof2_content.android_library import AndroidLibrary
        names = ['_Z%dlong%s' % (i, 'x' * 60) for i in range(12)]
        functions = [(name, Thumb(0x2100 + 0x10 * i).ret().finish(), 0x2100 + 0x10 * i) for i, name in enumerate(names)]
        self.assertEqual(set(AndroidLibrary(roomy_library(functions)).symbols) & set(names), set(names))
        self.assertNotEqual(set(AndroidLibrary(library(functions, {})).symbols) & set(names), set(names))

    def test_shape_branch_targets_are_shape_instructions(self):
        from android_fixture import Thumb
        from gof2_content.android_library import AndroidLibrary, instructions
        from gof2_content.steering import shape_at
        asm = Thumb(0x2100)
        cbz(asm, 0, 0x2106).nop().nop().ret()
        b_to(asm, 0x2100)
        lib = AndroidLibrary(library([('_Z1fv', asm.finish(), 0x2100)], {}))
        code = instructions(lib, '_Z1fv')
        self.assertEqual(shape_at(code, [('cbz', 'r0, @3'), ('nop', ''), ('nop', ''), ('bx', 'lr')]), [0])
        self.assertEqual(shape_at(code, [('cbz', 'r0, @2'), ('nop', ''), ('nop', '')]), [])
        # A target past the decoded code never matches.
        self.assertEqual(shape_at(code[:5], [('b', '@1')]), [])

    def test_named_handler_gives_constants_and_spans(self):
        from android_fixture import TEXT
        from gof2_content.android_library import instructions
        from gof2_content.steering import ANDROID_HANDLER
        lib = android()
        # The synthetic encodings are the instructions the reader expects.
        self.assertEqual([(i.mnemonic, i.op_str) for i in instructions(lib, ANDROID_HANDLER)[1:4]],
                         [('vldr', 's0, [pc, #0xfc]'), ('vldr', 's2, [fp, #0x278]'), ('vldr', 's4, [fp, #0x27c]')])
        self.assertEqual(instructions(android(pool='before'), ANDROID_HANDLER)[11].op_str, 's4, [pc, #-0xa8]')
        result = extract_manual_rotation(lib, {'available': True})
        self.assertEqual((result['angle_unit_scale'], result['radians_per_turn'], result['rotation_order']), (1 / 1024, 6.0, 'local_x_y'))
        self.assertAlmostEqual(result['time_scale'], 0.025)
        # step (18 instructions), the three pool floats, the whole helper
        self.assertEqual([(p['offset'] - TEXT, p['bytes']) for p in result['provenance']],
                         [(0x102, 72), (0x200, 4), (0x204, 4), (0x208, 4), (0x400, 8)])
        self.assertEqual(extract_manual_rotation(lib, {}), {})

    def test_each_broken_declaration_is_unsupported(self):
        cases = {'x field': dict(fields=(0x274, 0x27c)), 'y field': dict(fields=(0x278, 0x280)), 'duplicate': dict(steps=2),
                 'callee': dict(call='puts'), 'pool after': dict(pool='after'), 'pool before': dict(pool='before'),
                 'zero': dict(constants=(0, 6.0, 0.025)), 'nan': dict(constants=(1 / 1024, float('nan'), 0.025)),
                 'negative': dict(constants=(1 / 1024, 6.0, -0.025)), 'unit range': dict(constants=(2, 6.0, 0.025)),
                 'turn range': dict(constants=(1 / 1024, 11, 0.025)), 'time range': dict(constants=(1 / 1024, 6.0, 2))}
        from gof2_content.steering import ANDROID_HANDLER, ANDROID_HELPER
        cases.update({name: dict(omit=name) for name in (ANDROID_HANDLER, ANDROID_HELPER)})
        for name, options in cases.items():
            self.assertEqual(extract_manual_rotation(android(**options), {'available': True}), {}, name)

    def test_imported_helper_without_a_definition_is_unsupported(self):
        from unittest.mock import patch
        import android_fixture
        from gof2_content.steering import ANDROID_HELPER
        with patch.object(android_fixture, 'IMPORTS', android_fixture.IMPORTS + (ANDROID_HELPER,)):
            lib = android(call=ANDROID_HELPER, omit=ANDROID_HELPER)
            stubbed = android_fixture.stub(ANDROID_HELPER)
        self.assertEqual(lib.imports[stubbed], ANDROID_HELPER)
        self.assertEqual(extract_manual_rotation(lib, {'available': True}), {})
