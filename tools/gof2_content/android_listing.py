"""Text listings of named Android functions for exact instruction-shape matching.

Each instruction renders as Capstone's `mnemonic op_str` on one line, except:
calls read `call SYMBOL`; PC-relative loads read `ldr rN, =0xWORD` (`vldr sN,
=0xWORD`, `vldr dN, =0xQWORD`); an `add rN, pc` whose literal was loaded into rN
in the same straight-line code reads `adr rN, 0xADDRESS`. Readers match regular
expressions over whole lines. Nothing is executed.
"""
import bisect
import re
import struct

from .android_library import instructions, is_jump


def names(lib):
    """Function start -> first symbol at that start (as android_library.callee)."""
    cache = lib.__dict__.get('_starts')
    if cache is None:
        cache = {}
        for name, (start, _) in lib.symbols.items():
            cache.setdefault(start, name)
        lib.__dict__['_starts'] = cache
    return cache


def number(token):
    """`#0x65`, `#-3`, `0xb2da8` or `#2.000000e+01` as an int or float."""
    token = token.lstrip('#')
    return float(token) if re.fullmatch(r'-?\d+\.\d+e[+-]\d+', token) else int(token, 0)


def word_float(word):
    return struct.unpack('<f', struct.pack('<I', word & 0xffffffff))[0]


class Listing:
    def __init__(self, lib, symbol):
        from capstone.arm_const import ARM_OP_IMM, ARM_OP_MEM, ARM_OP_REG, ARM_REG_PC
        self.lib = lib
        self.code = instructions(lib, symbol) or []
        starts = names(lib)
        targets = {ins.operands[-1].imm for ins in self.code
                   if ins.id and is_jump(ins) and ins.operands and ins.operands[-1].type == ARM_OP_IMM}
        lines, words = [], {}
        for ins in self.code:
            if ins.address in targets:
                words = {}
            line = '%s %s' % (ins.mnemonic, ins.op_str) if ins.id else '.byte'
            ops = ins.operands
            loaded = None
            if ins.mnemonic in ('bl', 'blx') and len(ops) == 1 and ops[0].type == ARM_OP_IMM:
                target = ops[0].imm & 0xffffffff
                line = 'call ' + (lib.imports.get(target) or starts.get(target & ~1) or hex(target))
            elif (ins.mnemonic in ('ldr', 'ldr.w', 'vldr') and len(ops) == 2 and ops[1].type == ARM_OP_MEM
                  and ops[1].mem.base == ARM_REG_PC and not ops[1].mem.index):
                width = 8 if ins.reg_name(ops[0].reg).startswith('d') else 4
                at = ((ins.address + 4) & ~3) + ops[1].mem.disp
                raw = lib.data[lib.text['offset'] + at - lib.text['address']:][:width] \
                    if lib.text['address'] <= at <= lib.text['address'] + lib.text['length'] - width else b''
                if len(raw) == width:
                    loaded = int.from_bytes(raw, 'little')
                    line = '%s %s, =%#x' % (ins.mnemonic.split('.')[0], ins.reg_name(ops[0].reg), loaded)
            elif (ins.mnemonic == 'add' and len(ops) == 2 and ops[1].type == ARM_OP_REG and ops[1].reg == ARM_REG_PC
                  and ops[0].reg in words):
                line = 'adr %s, %#x' % (ins.reg_name(ops[0].reg), (words[ops[0].reg] + ins.address + 4) & 0xffffffff)
            for register in (ins.regs_access()[1] if ins.id else ()):
                words.pop(register, None)
            if loaded is not None and ins.mnemonic != 'vldr':
                words[ops[0].reg] = loaded
            lines.append(line)
        self.lines = lines
        self.text = ''.join(line + '\n' for line in lines)
        self.starts = []
        at = 0
        for line in lines:
            self.starts.append(at)
            at += len(line) + 1

    def __bool__(self):
        return bool(self.code)

    def find(self, pattern):
        """Matches of a multi-line pattern that begin and end on whole lines."""
        return [m for m in re.finditer(pattern, self.text, re.M)
                if (m.start() == 0 or self.text[m.start() - 1] == '\n') and self.text[m.end() - 1:m.end()] == '\n']

    def index(self, match, group=0):
        """Instruction index of the line holding the start of a match group."""
        return bisect.bisect_right(self.starts, match.start(group)) - 1

    def last(self, match):
        return bisect.bisect_right(self.starts, match.end() - 1) - 1

    def definition(self, index, register):
        """Index of the last instruction before `index`, in address order, writing `register` (a name)."""
        for i in range(index - 1, -1, -1):
            ins = self.code[i]
            if ins.id and register in (ins.reg_name(r) for r in ins.regs_access()[1]):
                return i
        return None

    def at(self, address):
        """Instruction index at an address, or None."""
        found = [i for i, ins in enumerate(self.code) if ins.address == address]
        return found[0] if found else None

    def span(self, first, last):
        start = self.code[first].address
        end = self.code[last].address + self.code[last].size
        return {'offset': self.lib.text['offset'] + start - self.lib.text['address'], 'bytes': end - start}

    def match_span(self, match):
        return self.span(self.index(match), self.last(match))
