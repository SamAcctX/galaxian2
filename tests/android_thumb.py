"""More Thumb-2 encodings for synthetic Android functions (models, scenery and visuals readers).

`Asm` extends android_fixture.Thumb with the encodings these readers match;
test_android_listing checks every one against Capstone. `build` lays out named
functions (plus `bx lr` stubs for every other name they call) and data blobs.
"""
import struct

from android_fixture import TEXT, Thumb, library

CONDITIONS = {'eq': 0, 'ne': 1, 'hs': 2, 'lo': 3, 'mi': 4, 'pl': 5, 'hi': 8, 'ls': 9, 'ge': 10, 'lt': 11, 'gt': 12, 'le': 13}


def modified(value):
    """Thumb modified immediate (i:imm3:imm8): a byte, or a rotated byte with its top bit set."""
    value &= 0xffffffff
    if value < 256:
        return value
    return next(rotation << 7 | rotated & 0x7f for rotation in range(8, 32)
                for rotated in [(value << rotation | value >> (32 - rotation)) & 0xffffffff]
                if rotated < 256 and rotated & 0x80)


class Asm(Thumb):
    def __init__(self, address):
        super().__init__(address)
        self.branches = []  # (position, condition or None, label, wide)
        self.named = []  # (position, function name): `bl` patched by build()

    def wide(self, top, rn, rest, imm12=0):
        return self.half(top | (imm12 >> 11 & 1) << 10 | rn, (imm12 >> 8 & 7) << 12 | rest | imm12 & 255)

    def cmp(self, rn, imm):
        return self.half(0x2800 | rn << 8 | imm) if rn < 8 and imm < 256 else self.cmp_w(rn, imm)

    def cmp_w(self, rn, imm): return self.wide(0xf1b0, rn, 0x0f00, modified(imm))

    def cmp_reg(self, rn, rm): return self.half(0x4280 | rm << 3 | rn) if rn < 8 and rm < 8 else self.half(0x4500 | (rn >> 3) << 7 | rm << 3 | rn & 7)

    def add_imm(self, rd, rn, imm): return self.wide(0xf100, rn, rd << 8, modified(imm))  # add.w

    def sub_imm(self, rd, rn, imm): return self.wide(0xf1a0, rn, rd << 8, modified(imm))  # sub.w

    def adds8(self, rd, imm): return self.half(0x3000 | rd << 8 | imm)  # adds rd, #imm8

    def add_reg(self, rd, rn, rm, shift=0):  # add.w rd, rn, rm, lsl #shift
        return self.half(0xeb00 | rn, (shift >> 2) << 12 | rd << 8 | (shift & 3) << 6 | rm)

    def add_low(self, rd, rm): return self.half(0x4400 | (rd >> 3) << 7 | rm << 3 | rd & 7)  # add rd, rm

    def ldr_w(self, rt, rn, offset=0):  # ldr.w rt, [rn, #offset]
        return self.half(0xf8d0 | rn, rt << 12 | offset) if offset >= 0 else self.half(0xf850 | rn, rt << 12 | 0xc00 | -offset)

    def str_neg(self, rt, rn, offset): return self.half(0xf840 | rn, rt << 12 | 0xc00 | offset)  # str rt, [rn, #-offset]

    def ldr_index(self, rt, rn, rm, shift=2): return self.half(0xf850 | rn, rt << 12 | shift << 4 | rm)  # ldr.w rt, [rn, rm, lsl #s]

    def ldrh_index(self, rt, rn, rm, shift=1): return self.half(0xf830 | rn, rt << 12 | shift << 4 | rm)

    def ldrb(self, rt, rn, offset): return self.half(0x7800 | offset << 6 | rn << 3 | rt)

    def ldrh(self, rt, rn, offset): return self.half(0x8800 | (offset // 2) << 6 | rn << 3 | rt)

    def uxth(self, rd, rm): return self.half(0xb280 | rm << 3 | rd)

    def uxtb(self, rd, rm): return self.half(0xb2c0 | rm << 3 | rd)

    def it(self, condition, mask=8): return self.half(0xbf00 | CONDITIONS[condition] << 4 | mask)

    def orrs(self, rd, rm): return self.half(0x4300 | rm << 3 | rd)

    def lsls(self, rd, rm, imm): return self.half(rd | rm << 3 | imm << 6)

    def strb_w(self, rt, rn, offset): return self.half(0xf880 | rn, rt << 12 | offset)

    def strh_w(self, rt, rn, offset): return self.half(0xf8a0 | rn, rt << 12 | offset)

    def str_sp_w(self, rt, offset): return self.half(0xf8cd, rt << 12 | offset)  # str.w rt, [sp, #offset]

    def ldr_sp_w(self, rt, offset): return self.half(0xf8dd, rt << 12 | offset)

    def vreg(self, sd, d=False): return (sd >> 4 & 1, sd & 15) if d else (sd & 1, sd >> 1)

    def vstr(self, sd, rn, offset):
        return self.half(0xed80 | (sd & 1) << 6 | rn, (sd >> 1) << 12 | 0xa00 | offset // 4)

    def vldr_pc(self, sd, value):  # vldr sd, [pc, #k] with its own pool word
        self.literals.append((len(self.code), lambda add, word=value: word, 'vldr'))
        return self.half(0xed9f | (sd & 1) << 6, (sd >> 1) << 12 | 0xa00)

    def ldr_pc(self, rt, value):  # ldr.w rt, [pc, #k] with its own pool word
        self.literals.append((len(self.code), lambda add, word=value: word, 'ldr.w'))
        return self.half(0xf8df, rt << 12)

    def vmov_imm(self, sd, imm8):  # vmov.f32 sd, #imm (VFP 8-bit float)
        return self.half(0xeeb0 | (sd & 1) << 6 | imm8 >> 4, (sd >> 1) << 12 | 0xa00 | imm8 & 15)

    def vmov_from(self, sn, rt): return self.half(0xee00 | sn >> 1, rt << 12 | 0xa10 | (sn & 1) << 7)  # vmov sn, rt

    def vadd(self, sd, sn, sm):
        return self.half(0xee30 | (sd & 1) << 6 | sn >> 1, (sd >> 1) << 12 | 0xa00 | (sn & 1) << 7 | (sm & 1) << 5 | sm >> 1)

    def vdiv(self, sd, sn, sm):
        return self.half(0xee80 | (sd & 1) << 6 | sn >> 1, (sd >> 1) << 12 | 0xa00 | (sn & 1) << 7 | (sm & 1) << 5 | sm >> 1)

    def vcvt_u(self, sd, sm): return self.half(0xeeb8 | (sd & 1) << 6, (sd >> 1) << 12 | 0xa40 | (sm & 1) << 5 | sm >> 1)

    def call_to(self, name):
        self.named.append((len(self.code), name))
        return self.half(0, 0)

    def branch(self, condition, label, wide=False):
        """b<cond> label (None: unconditional); 16-bit unless `wide`."""
        self.branches.append((len(self.code), condition, label, wide))
        return self.half(0, 0) if wide else self.half(0)

    def cbz(self, rn, label, nonzero=False):
        self.branches.append((len(self.code), 'cbnz' if nonzero else 'cbz', label, rn))
        return self.half(0)

    def finish(self):
        for at, condition, label, wide in self.branches:
            offset = self.labels[label] - (self.address + at + 4)
            if condition in ('cbz', 'cbnz'):
                assert 0 <= offset < 128
                struct.pack_into('<H', self.code, at, (0xb900 if condition == 'cbnz' else 0xb100)
                                 | (offset >> 6 & 1) << 9 | (offset >> 1 & 31) << 3 | wide)
            elif not wide and condition is None:
                struct.pack_into('<H', self.code, at, 0xe000 | (offset >> 1) & 0x7ff)
            elif not wide:
                struct.pack_into('<H', self.code, at, 0xd000 | CONDITIONS[condition] << 8 | (offset >> 1) & 255)
            else:
                value, sign = offset >> 1, 1 if offset < 0 else 0
                if condition is None:
                    j1, j2 = (1 - (value >> 22 & 1)) ^ sign, (1 - (value >> 21 & 1)) ^ sign
                    struct.pack_into('<2H', self.code, at, 0xf000 | sign << 10 | value >> 11 & 0x3ff,
                                     0x9000 | j1 << 13 | j2 << 11 | value & 0x7ff)
                else:
                    struct.pack_into('<2H', self.code, at, 0xf000 | sign << 10 | CONDITIONS[condition] << 6 | value >> 11 & 0x3f,
                                     0x8000 | (value >> 18 & 1) << 13 | (value >> 17 & 1) << 11 | value & 0x7ff)
        plain = [(at, value) for at, value, *kind in self.literals if not kind]
        wide = [(at, value, kind[0]) for at, value, *kind in self.literals if kind]
        self.literals = plain
        code = super().finish()
        if not wide:
            return code
        self.code = bytearray(code)
        while len(self.code) % 4:
            self.nop()
        for at, value, kind in wide:
            pc = (self.address + at + 4) & ~3
            word = len(self.code)
            self.code += struct.pack('<I', value(None))
            second, = struct.unpack_from('<H', self.code, at + 2)
            offset = self.address + word - pc
            struct.pack_into('<H', self.code, at + 2, second | (offset // 4 if kind == 'vldr' else offset))
        return bytes(self.code)


def build(functions, data=None):
    """functions: {name: Asm}; data: {address: bytes} within .rodata's first 4 KiB.
    Every function called by name without a body becomes a `bx lr` stub after the functions."""
    from android_fixture import branch_fields
    from gof2_content.android_library import AndroidLibrary
    laid = {name: [bytearray(asm.finish()), asm.address] for name, asm in functions.items()}
    address = max(a + len(c) for c, a in laid.values()) + 16 & ~15
    for asm in functions.values():
        for _, name in asm.named:
            if name not in laid:
                laid[name] = [bytearray(b'\x70\x47'), address]
                address += 16
    assert address < TEXT + 0x5000
    for name, asm in functions.items():
        for at, callee in asm.named:
            sign, j1, j2, value = branch_fields(laid[callee][1] - (asm.address + at + 4), True)
            struct.pack_into('<2H', laid[name][0], at, 0xf000 | sign << 10 | value >> 11 & 0x3ff,
                             0xd000 | j1 << 13 | j2 << 11 | value & 0x7ff)
    return AndroidLibrary(library([(name, bytes(c), a) for name, (c, a) in laid.items()], data or {}))
