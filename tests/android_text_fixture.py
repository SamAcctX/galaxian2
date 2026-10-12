"""Synthetic Android functions written as instruction text. Never executed.

`text_library({symbol: text})` assembles each function from lines in the shape
`android_shapes.Listing` renders (`mnemonic operands`, `call SYMBOL`,
`ldr rN, =0xWORD`), with `name:` labels and `#name` branch targets, lays them
out in a synthetic ELF (android_fixture.library) and checks every line against
Capstone: the rendered listing must read back exactly as written. Called or
vtable-listed symbols that are not given become one-instruction functions.
"""
import re
import struct

from android_fixture import IMPORTS, TEXT, branch_fields, library, stub

REGISTERS = {**{'r%d' % i: i for i in range(13)}, 'sb': 9, 'sl': 10, 'fp': 11, 'ip': 12, 'sp': 13, 'lr': 14, 'pc': 15}
CONDITIONS = {c: i for i, c in enumerate(['eq', 'ne', 'hs', 'lo', 'mi', 'pl', 'vs', 'vc', 'hi', 'ls', 'ge', 'lt', 'gt', 'le'])}
LOW_STORES = {'str': (0x6000, 4), 'ldr': (0x6800, 4), 'strb': (0x7000, 1), 'ldrb': (0x7800, 1), 'strh': (0x8000, 2), 'ldrh': (0x8800, 2)}
WIDE_STORES = {'str': 0xf8c0, 'ldr': 0xf8d0, 'strb': 0xf880, 'ldrb': 0xf890, 'strh': 0xf8a0, 'ldrh': 0xf8b0, 'ldrsb': 0xf990, 'ldrsh': 0xf9b0}
INDEXED = {'str': 0x5000, 'strh': 0x5200, 'strb': 0x5400, 'ldrsb': 0x5600, 'ldr': 0x5800, 'ldrh': 0x5a00, 'ldrb': 0x5c00, 'ldrsh': 0x5e00}
NARROW_ALU = {'ands': 0, 'eors': 1, 'lsls': 2, 'lsrs': 3, 'asrs': 4, 'adcs': 5, 'sbcs': 6, 'rors': 7, 'tst': 8, 'rsbs': 9, 'cmn': 11, 'orrs': 12, 'muls': 13, 'bics': 14, 'mvns': 15}
MODIFIED = {'and': 0xf000, 'bic': 0xf020, 'orr': 0xf040, 'eor': 0xf080, 'add': 0xf100, 'sub': 0xf1a0, 'rsb': 0xf1c0}
SHIFTED = {'and': 0xea00, 'orr': 0xea40, 'eor': 0xea80, 'add': 0xeb00, 'sub': 0xeba0, 'rsb': 0xebc0}
VFP3 = {'vmul.f32': (0xee20, 0), 'vnmul.f32': (0xee20, 0x40), 'vadd.f32': (0xee30, 0), 'vsub.f32': (0xee30, 0x40),
        'vdiv.f32': (0xee80, 0), 'vmla.f32': (0xee00, 0), 'vmls.f32': (0xee00, 0x40)}
VFP2 = {'vcvt.f32.s32': (0xeeb8, 0xc0), 'vcvt.f32.u32': (0xeeb8, 0x40), 'vcvt.s32.f32': (0xeebd, 0xc0), 'vcvt.u32.f32': (0xeebc, 0xc0),
        'vcmpe.f32': (0xeeb4, 0xc0), 'vcmp.f32': (0xeeb4, 0x40), 'vmov.f32': (0xeeb0, 0x40), 'vneg.f32': (0xeeb1, 0x40),
        'vabs.f32': (0xeeb0, 0xc0), 'vsqrt.f32': (0xeeb1, 0xc0)}


def modified(value):
    """Thumb-2 modified immediate (i:imm3:imm8) for a 32-bit value, or None."""
    value &= 0xffffffff
    low = value & 255
    if value < 256:
        return value
    if value == low << 16 | low:
        return 0x100 | low
    if value == (value >> 8 & 255) * 0x01000100:
        return 0x200 | (value >> 8 & 255)
    if value == low * 0x01010101:
        return 0x300 | low
    for rotation in range(8, 32):
        rotated = (value << rotation | value >> (32 - rotation)) & 0xffffffff
        if rotated < 256 and rotated & 0x80:
            return rotation << 7 | rotated & 0x7f
    return None


def vfp_immediate(value):
    for imm8 in range(256):
        a, b, cdefgh = imm8 >> 7, imm8 >> 6 & 1, imm8 & 63
        bits = a << 31 | (b ^ 1) << 30 | (0x1f if b else 0) << 25 | cdefgh << 19
        if struct.unpack('<f', struct.pack('<I', bits))[0] == value:
            return imm8
    raise ValueError('no VFP immediate for %r' % value)


def split(operands):
    """Operands at top-level commas: brackets and braces stay whole."""
    parts, depth, current = [], 0, ''
    for ch in operands:
        if ch in '[{':
            depth += 1
        elif ch in ']}':
            depth -= 1
        if ch == ',' and depth == 0:
            parts.append(current.strip())
            current = ''
        else:
            current += ch
    if current.strip():
        parts.append(current.strip())
    return parts


def sreg(name):
    return int(name[1:]) if re.fullmatch(r's\d+', name) else None


def vfp_fields(sd):
    """(Vd, D) for single register number sd."""
    return sd >> 1, sd & 1


class Assembler:
    def __init__(self, address, resolve):
        self.address, self.resolve = address, resolve
        self.code = bytearray()
        self.fixups, self.labels, self.lines = [], {}, []
        self.it = 0

    def here(self):
        return self.address + len(self.code)

    def half(self, *values):
        for value in values:
            self.code += struct.pack('<H', value & 0xffff)

    def imm(self, token):
        token = token[1:] if token.startswith('#') else token
        return int(token, 0)

    def line(self, text):
        text = text.strip()
        if not text:
            return
        if text.endswith(':'):
            self.labels[text[:-1]] = self.here()
            return
        start = self.here()
        mnemonic, _, rest = text.partition(' ')
        ops = split(rest)
        if self.it:
            self.it -= 1
            base = mnemonic.split('.')
            for cond in CONDITIONS:
                if base[0].endswith(cond) and base[0][:-len(cond)]:
                    base[0] = base[0][:-len(cond)]
                    break
            mnemonic = '.'.join(base)
            if mnemonic in ('mov', 'add', 'sub') and len(ops) == 2 and ops[1].startswith('#') and REGISTERS[ops[0]] < 8 and self.imm(ops[1]) < 256:
                mnemonic += 's'  # the 16-bit flag-setting forms read without `s` inside IT
        self.encode(mnemonic, ops, text)
        if mnemonic != '.cases':
            self.lines.append((start, text))

    def encode(self, m, ops, text):
        R = REGISTERS
        def reg(i): return R[ops[i]]
        def low(*indexes): return all(R.get(ops[i], 99) < 8 for i in indexes)
        def mem(token): return [p.strip() for p in token.strip('[]').split(',')]
        if m.startswith('it') and len(m) <= 5:
            cond = CONDITIONS[ops[0]]
            mask, extra = 0, m[2:]
            for i, letter in enumerate(extra):
                bit = cond & 1 if letter == 't' else (cond & 1) ^ 1
                mask |= bit << (3 - i)
            mask |= 1 << (3 - len(extra))
            self.it = len(extra) + 1
            return self.half(0xbf00 | cond << 4 | mask)
        if m == 'nop':
            return self.half(0xbf00)
        if m == '.cases':
            width = 1 if self.lines and self.lines[-1][1].startswith('tbb ') else 2
            self.fixups.append((len(self.code), '.cases', (width, ops)))
            self.code += bytes(width * len(ops) + (width * len(ops)) % 2)
            return
        if m == 'call':
            target = self.resolve(ops[0])
            here = self.here()
            sign, j1, j2, value = branch_fields(target - (here + 4), True)
            return self.half(0xf000 | sign << 10 | value >> 11 & 0x3ff, 0xd000 | j1 << 13 | j2 << 11 | value & 0x7ff)
        if m in ('bx', 'blx') and len(ops) == 1 and ops[0] in R:
            return self.half((0x4700 if m == 'bx' else 0x4780) | reg(0) << 3)
        if m in ('push', 'pop') and ops[0].startswith('{'):
            names = [n.strip() for n in ops[0].strip('{}').split(',')]
            extra = 'lr' if m == 'push' else 'pc'
            bits = sum(1 << R[n] for n in names if n != extra)
            return self.half((0xb400 if m == 'push' else 0xbc00) | (extra in names) << 8 | bits)
        if m in ('push.w', 'pop.w'):
            names = [n.strip() for n in ops[0].strip('{}').split(',')]
            return self.half(0xe92d if m == 'push.w' else 0xe8bd, sum(1 << R[n] for n in names))
        if m in ('vpush', 'vpop'):
            names = [n.strip() for n in ops[0].strip('{}').split(',')]
            first = int(names[0][1:])
            return self.half((0xed2d if m == 'vpush' else 0xecbd) | (first >> 4) << 6, (first & 15) << 12 | 0xb00 | 2 * len(names))
        branch = re.fullmatch(r'b(%s)?(\.w)?' % '|'.join(CONDITIONS), m)
        if branch:
            self.fixups.append((len(self.code), m, ops[0][1:]))
            return self.half(*([0, 0] if branch.group(2) else [0]))
        if m in ('cbz', 'cbnz'):
            self.fixups.append((len(self.code), m, (reg(0), ops[1][1:])))
            return self.half(0)
        if m in ('tbb', 'tbh'):  # `.cases` entries follow
            inner = mem(ops[0])
            return self.half(0xe8df, 0xf000 | (0x10 if m == 'tbh' else 0) | R[inner[1]])
        if m in ('ldr', 'ldr.w', 'vldr') and ops[-1].startswith('='):
            word = ops[-1][1:]  # `&NAME`: the GOT slot of NAME, through the next `add rN, pc`
            self.fixups.append((len(self.code), m, (ops[0], word if word.startswith('&') else int(word, 0))))
            return self.half(*([0] if m == 'ldr' else [0, 0]))
        if m == 'movs' and len(ops) == 2 and ops[1].startswith('#') and low(0):
            return self.half(0x2000 | reg(0) << 8 | self.imm(ops[1]))
        if m == 'movs' and len(ops) == 2 and low(0, 1):
            return self.half(reg(1) << 3 | reg(0))
        if m == 'mov' and len(ops) == 2 and ops[1] in R:
            rd = reg(0)
            return self.half(0x4600 | (rd >> 3) << 7 | reg(1) << 3 | rd & 7)
        if m in ('mov.w', 'movs.w', 'mvn', 'mvn.w') and ops[1].startswith('#'):
            v = modified(self.imm(ops[1]))
            top = {'mov.w': 0xf04f, 'movs.w': 0xf05f}.get(m, 0xf06f)
            return self.half(top | (v >> 11) << 10, (v >> 8 & 7) << 12 | reg(0) << 8 | v & 255)
        if m in ('movw', 'movt'):
            v = self.imm(ops[1])
            return self.half((0xf240 if m == 'movw' else 0xf2c0) | (v >> 12 & 15) | (v >> 11 & 1) << 10, (v >> 8 & 7) << 12 | reg(0) << 8 | v & 255)
        if m == 'cmp' and ops[1].startswith('#') and low(0):
            return self.half(0x2800 | reg(0) << 8 | self.imm(ops[1]))
        if m == 'cmp' and ops[1] in R:
            if low(0, 1):
                return self.half(0x4280 | reg(1) << 3 | reg(0))
            rn = reg(0)
            return self.half(0x4500 | (rn >> 3) << 7 | reg(1) << 3 | rn & 7)
        if m in ('cmp.w', 'cmn.w', 'tst.w') and ops[1].startswith('#'):
            v = modified(self.imm(ops[1]))
            top = {'cmp.w': 0xf1b0, 'cmn.w': 0xf110, 'tst.w': 0xf010}[m]
            return self.half(top | (v >> 11) << 10 | reg(0), (v >> 8 & 7) << 12 | 0xf00 | v & 255)
        if m in ('adds', 'subs') and len(ops) == 2 and ops[1].startswith('#'):
            return self.half((0x3000 if m == 'adds' else 0x3800) | reg(0) << 8 | self.imm(ops[1]))
        if m in ('adds', 'subs') and len(ops) == 3 and ops[2].startswith('#') and low(0, 1) and self.imm(ops[2]) < 8:
            return self.half((0x1c00 if m == 'adds' else 0x1e00) | self.imm(ops[2]) << 6 | reg(1) << 3 | reg(0))
        if m in ('adds', 'subs') and len(ops) == 3 and low(0, 1, 2):
            return self.half((0x1800 if m == 'adds' else 0x1a00) | reg(2) << 6 | reg(1) << 3 | reg(0))
        if m == 'add' and len(ops) == 2 and ops[1] in R:
            rd = reg(0)
            return self.half(0x4400 | (rd >> 3) << 7 | reg(1) << 3 | rd & 7)
        if m == 'add' and len(ops) == 3 and ops[1] == 'sp' and low(0):
            return self.half(0xa800 | reg(0) << 8 | self.imm(ops[2]) // 4)
        if m in ('add', 'sub') and len(ops) == 2 and ops[0] == 'sp':
            return self.half((0xb000 if m == 'add' else 0xb080) | self.imm(ops[1]) // 4)
        if m in NARROW_ALU and low(*range(len(ops))) and not any(o.startswith('#') for o in ops):
            rm = reg(1)
            return self.half(0x4000 | NARROW_ALU[m] << 6 | rm << 3 | reg(0))
        if m in ('lsls', 'lsrs', 'asrs') and len(ops) == 3 and ops[2].startswith('#'):
            return self.half({'lsls': 0, 'lsrs': 0x800, 'asrs': 0x1000}[m] | self.imm(ops[2]) << 6 | reg(1) << 3 | reg(0))
        if m in ('uxtb', 'uxth', 'sxtb', 'sxth'):
            return self.half({'uxtb': 0xb2c0, 'uxth': 0xb280, 'sxtb': 0xb240, 'sxth': 0xb200}[m] | reg(1) << 3 | reg(0))
        alu = re.fullmatch(r'(and|bic|orr|eor|add|sub|rsb)(s?)(\.w)?', m)
        if alu and len(ops) == 3 and ops[2].startswith('#') and modified(self.imm(ops[2])) is not None and (alu.group(3) or alu.group(1) in ('rsb', 'bic', 'orr', 'eor', 'and')):
            v = modified(self.imm(ops[2]))
            return self.half(MODIFIED[alu.group(1)] | (0x10 if alu.group(2) else 0) | (v >> 11) << 10 | reg(1), (v >> 8 & 7) << 12 | reg(0) << 8 | v & 255)
        if m in ('addw', 'subw'):
            v = self.imm(ops[2])
            return self.half((0xf200 if m == 'addw' else 0xf2a0) | (v >> 11 & 1) << 10 | reg(1), (v >> 8 & 7) << 12 | reg(0) << 8 | v & 255)
        if alu and len(ops) in (3, 4) and all(o in R for o in ops[:3]):
            shift = ops[3].split() if len(ops) == 4 else ['lsl', '#0']
            n = self.imm(shift[1])
            kind = {'lsl': 0, 'lsr': 1, 'asr': 2, 'ror': 3}[shift[0]]
            return self.half(SHIFTED[alu.group(1)] | (0x10 if alu.group(2) else 0) | reg(1), (n >> 2) << 12 | reg(0) << 8 | (n & 3) << 6 | kind << 4 | reg(2))
        if m in ('lsl.w', 'lsr.w', 'asr.w') and len(ops) == 3 and ops[2].startswith('#'):
            n = self.imm(ops[2])
            kind = {'lsl.w': 0, 'lsr.w': 1, 'asr.w': 2}[m]
            return self.half(0xea4f, (n >> 2) << 12 | reg(0) << 8 | (n & 3) << 6 | kind << 4 | reg(1))
        if m in ('lsl.w', 'lsr.w', 'asr.w') and len(ops) == 3:
            return self.half({'lsl.w': 0xfa00, 'lsr.w': 0xfa20, 'asr.w': 0xfa40}[m] | reg(1), 0xf000 | reg(0) << 8 | reg(2))
        if m in ('ldrd', 'strd'):
            inner = mem(ops[2])
            offset = self.imm(inner[1]) if len(inner) > 1 else 0
            top = (0xe9d0 if m == 'ldrd' else 0xe9c0) if offset >= 0 else (0xe950 if m == 'ldrd' else 0xe940)
            return self.half(top | R[inner[0]], reg(0) << 12 | reg(1) << 8 | abs(offset) // 4)
        base = m[:-2] if m.endswith('.w') else m
        if base in WIDE_STORES and len(ops) == 2 and ops[1].startswith('[') and ops[1].endswith('!'):
            inner = mem(ops[1][:-1])
            offset = self.imm(inner[1])
            return self.half(WIDE_STORES[base] - 0x80 | R[inner[0]], reg(0) << 12 | (0xf00 if offset >= 0 else 0xd00) | abs(offset))
        if base in WIDE_STORES and len(ops) == 2 and ops[1].startswith('['):
            inner = mem(ops[1])
            rn = R[inner[0]]
            if len(inner) == 3 or (len(inner) == 2 and inner[1] in R):
                shift = self.imm(inner[2].split()[1]) if len(inner) == 3 else 0
                if not m.endswith('.w') and low(0) and rn < 8 and R[inner[1]] < 8 and shift == 0:
                    return self.half(INDEXED[base] | R[inner[1]] << 6 | rn << 3 | reg(0))
                return self.half(WIDE_STORES[base] - 0x80 | rn, reg(0) << 12 | shift << 4 | R[inner[1]])
            offset = self.imm(inner[1]) if len(inner) == 2 else 0
            if not m.endswith('.w') and offset >= 0:
                if base in LOW_STORES and low(0) and rn < 8:
                    opcode, scale = LOW_STORES[base]
                    if offset % scale == 0 and offset // scale < 32:
                        return self.half(opcode | (offset // scale) << 6 | rn << 3 | reg(0))
                if base in ('ldr', 'str') and rn == 13 and low(0) and offset < 1024:
                    return self.half((0x9800 if base == 'ldr' else 0x9000) | reg(0) << 8 | offset // 4)
            if offset < 0:
                return self.half(WIDE_STORES[base] - 0x80 | rn, reg(0) << 12 | 0xc00 | -offset)
            return self.half(WIDE_STORES[base] | rn, reg(0) << 12 | offset)
        if m in ('vldr', 'vstr'):
            inner = mem(ops[1])
            offset = self.imm(inner[1]) if len(inner) == 2 else 0
            top = (0xed10 if m == 'vldr' else 0xed00) | (0x80 if offset >= 0 else 0)
            if sreg(ops[0]) is not None:
                vd, d = vfp_fields(sreg(ops[0]))
                return self.half(top | d << 6 | R[inner[0]], vd << 12 | 0xa00 | abs(offset) // 4)
            dd = int(ops[0][1:])
            return self.half(top | (dd >> 4) << 6 | R[inner[0]], (dd & 15) << 12 | 0xb00 | abs(offset) // 4)
        if m == 'vmov.f32' and ops[1].startswith('#'):
            vd, d = vfp_fields(sreg(ops[0]))
            imm8 = vfp_immediate(float(ops[1][1:]))
            return self.half(0xeeb0 | d << 6 | imm8 >> 4, vd << 12 | 0xa00 | imm8 & 15)
        if m == 'vmov' and len(ops) == 2:
            if sreg(ops[0]) is not None:
                vn, n = vfp_fields(sreg(ops[0]))
                return self.half(0xee00 | vn, reg(1) << 12 | 0xa10 | n << 7)
            vn, n = vfp_fields(sreg(ops[1]))
            return self.half(0xee10 | vn, reg(0) << 12 | 0xa10 | n << 7)
        if m in VFP3:
            top, op = VFP3[m]
            (vd, d), (vn, n), (vm, mm) = (vfp_fields(sreg(o)) for o in ops)
            return self.half(top | d << 6 | vn, vd << 12 | 0xa00 | op | n << 7 | mm << 5 | vm)
        if m in ('vcmpe.f32', 'vcmp.f32') and ops[1] == '#0':
            vd, d = vfp_fields(sreg(ops[0]))
            return self.half(0xeeb5 | d << 6, vd << 12 | 0xa00 | (0xc0 if m == 'vcmpe.f32' else 0x40))
        if m in VFP2:
            top, op = VFP2[m]
            (vd, d), (vm, mm) = (vfp_fields(sreg(o)) for o in ops)
            return self.half(top | d << 6, vd << 12 | 0xa00 | op | mm << 5 | vm)
        if m == 'vmrs':
            return self.half(0xeef1, 0xfa10)
        if m == 'adr':
            return self.half(0xa000 | reg(0) << 8 | self.imm(ops[1]) // 4)
        if m == 'vmov.i32' and ops[1] == '#0':
            q = 2 * int(ops[0][1:])
            return self.half(0xef80 | (q >> 4) << 6, (q & 15) << 12 | 0x50)
        if m in ('vst1.32', 'vld1.32', 'vst1.64', 'vld1.64'):
            names = [n.strip() for n in ops[0].strip('{}').split(',')]
            first = int(names[0][1:])
            base, _, align = ops[1].strip('[]').partition(':')
            alignment = {'': 0, '0x40': 1, '0x80': 2}[align]
            kind = {1: 0x7, 2: 0xa}[len(names)]
            return self.half((0xf920 if m.startswith('vld') else 0xf900) | (first >> 4) << 6 | R[base],
                             (first & 15) << 12 | kind << 8 | (3 if m.endswith('64') else 2) << 6 | alignment << 4 | 15)
        raise ValueError('unsupported synthetic instruction: ' + text)

    def finish(self):
        if len(self.code) % 4:
            self.half(0xbf00)
        for at, kind, operand in self.fixups:
            source = self.address + at
            if kind == '.cases':
                width, names = operand
                for i, name in enumerate(names):
                    struct.pack_into('<B' if width == 1 else '<H', self.code, at + width * i, (self.labels[name] - source) // 2)
                continue
            if kind in ('ldr', 'ldr.w', 'vldr'):
                register, word = operand
                if isinstance(word, str):
                    add = next(a for a, t in self.lines if a > source and t == 'add %s, pc' % register)
                    word = (self.resolve(word) - (add + 4)) & 0xffffffff
                    self.lines = [(a, t.replace('=' + operand[1], '=%#x' % word) if a == source else t) for a, t in self.lines]
                pool = len(self.code)
                self.code += struct.pack('<I', word)
                offset = self.address + pool - ((source + 4) & ~3)
                if kind == 'ldr':
                    struct.pack_into('<H', self.code, at, 0x4800 | REGISTERS[register] << 8 | offset // 4)
                elif kind == 'ldr.w':
                    struct.pack_into('<2H', self.code, at, 0xf8df, REGISTERS[register] << 12 | offset)
                else:
                    vd, d = vfp_fields(sreg(register))
                    struct.pack_into('<2H', self.code, at, 0xed9f | d << 6, vd << 12 | 0xa00 | offset // 4)
                continue
            if kind in ('cbz', 'cbnz'):
                register, name = operand
                offset = self.labels[name] - (source + 4)
                struct.pack_into('<H', self.code, at, (0xb100 if kind == 'cbz' else 0xb900) | (offset >> 6 & 1) << 9 | (offset >> 1 & 31) << 3 | register)
                continue
            offset = self.labels[operand] - (source + 4) if operand in self.labels else self.resolve(operand) - (source + 4)
            cond = re.fullmatch(r'b(\w\w)?(\.w)?', kind).group(1)
            if kind.endswith('.w') and cond:
                d = offset & 0x1fffff
                struct.pack_into('<2H', self.code, at, 0xf000 | (d >> 20) << 10 | CONDITIONS[cond] << 6 | (d >> 12) & 63,
                                 0x8000 | (d >> 18 & 1) << 13 | (d >> 19 & 1) << 11 | (d >> 1) & 2047)
            elif kind.endswith('.w'):
                sign, j1, j2, value = branch_fields(offset, False)
                struct.pack_into('<2H', self.code, at, 0xf000 | sign << 10 | value >> 11 & 0x3ff, 0x9000 | j1 << 13 | j2 << 11 | value & 0x7ff)
            elif cond:
                struct.pack_into('<H', self.code, at, 0xd000 | CONDITIONS[cond] << 8 | (offset >> 1) & 255)
            else:
                struct.pack_into('<H', self.code, at, 0xe000 | (offset >> 1) & 0x7ff)
        return bytes(self.code)


def text_library(functions, objects=None, *, check=True):
    """(AndroidLibrary, {symbol: address}) for {symbol: instruction text}.

    `objects` adds data symbols ({name: [entry, ...]}, an entry a symbol name
    relocated by R_ARM_ABS32, or an int word) in .data.rel.ro; `=&NAME` pool
    loads address a GOT slot relocated to NAME (R_ARM_GLOB_DAT). Each line is
    checked against the importer's rendering of the assembled code.
    """
    from gof2_content.android_library import AndroidLibrary
    from gof2_content.android_shapes import Listing
    objects = objects or {}
    called, slots = [], []
    for text in functions.values():
        called += [line.split()[1] for line in text.strip().splitlines() if line.split()[:1] == ['call']]
        slots += re.findall(r'=&(\w+)', text)
    called += [entry for entries in objects.values() for entry in entries if isinstance(entry, str) and entry not in objects]
    names = list(functions) + [n for n in dict.fromkeys(called) if n not in functions and n not in IMPORTS]
    bodies = {name: functions.get(name, 'bx lr') for name in names}
    # Two passes: sizes do not depend on targets.
    addresses, address = {}, TEXT + 0x100
    for name in names:
        addresses[name] = address
        size = len(assemble(bodies[name], address, lambda n: address)[0])
        address = (address + size + 15) & ~15
    text_size = max(0x5000, (address - TEXT + 0xfff) & ~0xfff)
    # Data after library()'s .rodata and PLT slots: objects, then one GOT word per `&NAME`.
    data_address = TEXT + text_size + 0x3000
    data, places = bytearray(), {}
    for name, entries in objects.items():
        places[name] = data_address + len(data)
        data += bytes(4 * len(entries))
    got = {name: data_address + len(data) + 4 * i for i, name in enumerate(dict.fromkeys(slots))}
    data += bytes(4 * len(got))
    resolve = lambda n: got[n[1:]] if n.startswith('&') else addresses[n] if n in addresses else stub(n)
    built, listings = [], {}
    for name in names:
        code, lines, labels = assemble(bodies[name], addresses[name], resolve)
        built.append((name, code, addresses[name]))
        listings[name] = (lines, labels)
    image = bytearray(library(built, {}, text_size=text_size, rodata=TEXT + text_size, got=TEXT + text_size + 0x1000))
    lib = AndroidLibrary(bytes(extend(image, built, data_address, data, places, objects, got)))
    if check:
        for name, (lines, labels) in listings.items():
            listing = Listing(lib, name)
            for at, text in lines:
                spots = {**addresses, **labels}
                expected = re.sub(r'#(\w+)$', lambda m: '#%#x' % spots[m[1]] if m[1] in spots else m[0], text)
                index = listing.index.get(at)
                found = listing.lines[index] if index is not None else None
                if found != expected:
                    raise AssertionError('%s %#x: wrote %r, Capstone reads %r' % (name, at, expected, found))
    return lib, addresses


def extend(image, built, data_address, data, places, objects, got):
    """Rebuild the symbol, string, data and relocation sections at the end of library()'s image.

    library() keeps .dynstr in a 512-byte slot and has no data symbols or .rel.dyn.
    """
    old_table, = struct.unpack_from('<I', image, 32)
    sections = [list(struct.unpack_from('<10I', image, old_table + 40 * i)) for i in range(8)]
    labels = list(IMPORTS) + [name for name, _, _ in built]
    symbols = bytearray(image[0x200:0x200 + 16 * (1 + len(labels))])
    strings = bytearray(b'\0')
    for index, label in enumerate(labels):
        struct.pack_into('<I', symbols, 16 * (index + 1), len(strings))
        strings += label.encode() + b'\0'
    index_of = {label: index + 1 for index, label in enumerate(labels)}
    for name, entries in objects.items():
        index_of[name] = len(symbols) // 16
        symbols += struct.pack('<IIIBBH', len(strings), places[name], 4 * len(entries), 0x11, 0, 8)
        strings += name.encode() + b'\0'
    relocations = bytearray()
    for name, entries in objects.items():
        for i, entry in enumerate(entries):
            if isinstance(entry, str):
                relocations += struct.pack('<II', places[name] + 4 * i, index_of[entry] << 8 | 2)
            elif entry:
                struct.pack_into('<I', data, places[name] - data_address + 4 * i, entry)
    for name, slot in got.items():
        relocations += struct.pack('<II', slot, index_of[name] << 8 | 21)
    image += bytes(data_address - len(image))
    blobs = {}
    for key, blob in (('.data.rel.ro', data), ('.dynsym', symbols), ('.dynstr', strings), ('.rel.dyn', relocations)):
        blobs[key] = len(image)
        image += blob + bytes(-len(blob) % 16)
    shstr = b'\0.dynsym\0.dynstr\0.rel.plt\0.plt\0.text\0.rodata\0.shstrtab\0.data.rel.ro\0.rel.dyn\0'
    def at(label): return shstr.index(label.encode() + b'\0')
    sections[1][3:6] = [blobs['.dynsym']] * 2 + [len(symbols)]
    sections[2][3:6] = [blobs['.dynstr']] * 2 + [len(strings)]
    sections[7][4] = len(image)
    sections[7][0], sections[7][5] = at('.shstrtab'), len(shstr)
    sections.append([at('.data.rel.ro'), 1, 3, blobs['.data.rel.ro'], blobs['.data.rel.ro'], len(data), 0, 0, 4, 0])
    sections.append([at('.rel.dyn'), 9, 2, blobs['.rel.dyn'], blobs['.rel.dyn'], len(relocations), 1, 0, 4, 8])
    image += shstr + bytes(-len(shstr) % 4)
    table = len(image)
    for row in sections:
        image += struct.pack('<10I', *row)
    struct.pack_into('<I', image, 32, table)
    struct.pack_into('<HHH', image, 46, 40, len(sections), 7)
    return image


def assemble(text, address, resolve):
    asm = Assembler(address, resolve)
    for line in text.strip().splitlines():
        asm.line(line)
    return asm.finish(), asm.lines, asm.labels


def fill(template, blank='0x10', **values):
    """A reader template with its placeholders replaced: `{name}` by values[name], `{}` by `blank`."""
    return re.sub(r'\{(\w*)\}', lambda m: str(values[m[1]]) if m[1] else blank, template)
