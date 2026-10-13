"""Static reading of the Android game library (ELF, ARMv7 Thumb-2, -fPIC). No execution.

`AndroidLibrary` gives the ARM shared object the reader interface of `MachO`.
`android_records` reads its resource registrations. Android's compiler builds
each record from position-independent string literals and heap objects, so the
reader decodes the declaring functions instruction by instruction and follows
values only through straight-line code: register state resets at every branch
target, and no branch is ever taken.
"""
import bisect
import collections
import hashlib
import re
import struct

from .bundle import safe_name
from .formats import ContentError

MAX_LIBRARY = 64 * 1024 * 1024
MAX_SECTIONS = 256
MAX_SYMBOLS = 200000
MAX_FUNCTION = 1024 * 1024
MAX_RECORDS = 20000
# ELF sections under the Mach-O names the declaration readers look up.
SECTION_NAMES = {'.text': [(b'__TEXT', b'__text')],
                 '.rodata': [(b'__TEXT', b'__cstring'), (b'__TEXT', b'__const')],
                 '.data.rel.ro': [(b'__DATA', b'__const')],
                 '.data': [(b'__DATA', b'__data')],
                 '.plt': [(b'__TEXT', b'__picsymbolstub4')]}
MEMCPY = {'memcpy', '__aeabi_memcpy', '__aeabi_memcpy4', '__aeabi_memcpy8'}


class AndroidLibrary:
    def __init__(self, source):
        if not 52 <= len(source) <= MAX_LIBRARY:
            raise ContentError('Unsupported library size')
        self.data = source
        self.source_sha256 = hashlib.sha256(source).hexdigest()
        self.source_bytes = len(source)
        self.slice_offset = 0
        # Not 'armv7': iOS layouts come from another compiler and never apply here.
        self.architecture = 'android-armv7'
        self.edition = 'android-hd'
        # 32-bit little-endian ARM shared object.
        if source[:7] != b'\x7fELF\x01\x01\x01' or self.unpack('<HH', 16) != (3, 40):
            raise ContentError('Unsupported Android library architecture/layout')
        offset, = self.unpack('<I', 32)
        size, count, names = self.unpack('<HHH', 46)
        if size != 40 or not 1 <= count <= MAX_SECTIONS or names >= count or offset + size * count > len(source):
            raise ContentError('Invalid ELF section index')
        headers = [self.unpack('<10I', offset + size * i) for i in range(count)]
        strings = headers[names]
        self.elf_sections = {}
        for name, kind, _, address, at, length, link, _, _, entry in headers[1:]:
            if kind == 8:  # NOBITS: not file-backed input.
                continue
            if at + length > len(source) or name >= strings[5]:
                raise ContentError('ELF section outside the file')
            label = source[strings[4] + name:source.find(b'\0', strings[4] + name, strings[4] + strings[5])]
            label = label.decode('ascii', errors='replace')
            if label in self.elf_sections:
                raise ContentError('Duplicate ELF section ' + label)
            self.elf_sections[label] = dict(name=label, address=address, offset=at, length=length, link=link, entry=entry)
        self.sections = []
        for label, aliases in SECTION_NAMES.items():
            section = self.elf_sections.get(label)
            if section and section['address'] and section['length']:
                for segment, name in aliases:
                    self.sections.append(dict(name=name, segment=segment, address=section['address'],
                                              length=section['length'], offset=section['offset']))
        for key, label in (('text', '.text'), ('cstring', '.rodata')):
            matches = [s for s in self.sections if s['address'] == self.elf_sections.get(label, {}).get('address')
                       and s['name'] == b'__' + key.encode()]
            if len(matches) != 1:
                raise ContentError('Missing ELF ' + label)
            setattr(self, key, matches[0])
        self.functions = self.read_functions()
        self.imports = self.read_imports()
        self.symbols = {name: (start, size) for start, size, name in self.functions}

    def unpack(self, fmt, offset):
        size = struct.calcsize(fmt)
        if offset < 0 or offset + size > len(self.data):
            raise ContentError('Truncated ELF scalar')
        return struct.unpack_from(fmt, self.data, offset)

    def symbol_name(self, index):
        table, names = self.elf_sections.get('.dynsym'), self.elf_sections.get('.dynstr')
        if not table or not names or (index + 1) * 16 > table['length']:
            return None
        at, = self.unpack('<I', table['offset'] + 16 * index)
        end = self.data.find(b'\0', names['offset'] + at, names['offset'] + names['length'])
        if at >= names['length'] or end < 0:
            return None
        return self.data[names['offset'] + at:end].decode('ascii', errors='replace')

    def read_functions(self):
        """Defined Thumb function extents from the dynamic symbol table, sorted."""
        table = self.elf_sections.get('.dynsym')
        if not table or table['length'] % 16 or table['length'] // 16 > MAX_SYMBOLS:
            return []
        text = self.text
        rows = []
        for index in range(table['length'] // 16):
            _, value, size, info, _, shndx = self.unpack('<IIIBBH', table['offset'] + 16 * index)
            if info & 15 == 2 and shndx and value & 1 and 0 < size <= MAX_FUNCTION:
                start = value & ~1
                if text['address'] <= start and start + size <= text['address'] + text['length']:
                    rows.append((start, size, self.symbol_name(index)))
        return sorted(set(rows))

    def read_imports(self):
        """PLT stub address to imported symbol name, for stubs that load their own relocation slot."""
        relocations, stubs = self.elf_sections.get('.rel.plt'), self.elf_sections.get('.plt')
        if not relocations or not stubs or relocations['length'] % 8:
            return {}
        count = relocations['length'] // 8
        if stubs['length'] != 20 + 12 * count:
            return {}
        result = {}
        for index in range(count):
            slot, info = self.unpack('<II', relocations['offset'] + 8 * index)
            if info & 255 != 22:  # R_ARM_JUMP_SLOT
                continue
            entry = stubs['address'] + 20 + 12 * index
            first, second, third = self.unpack('<3I', stubs['offset'] + 20 + 12 * index)
            # add ip, pc, #a ; add ip, ip, #b ; ldr pc, [ip, #c]!
            if first & 0xfffff000 != 0xe28fc000 or second & 0xfffff000 != 0xe28cc000 or third & 0xfffff000 != 0xe5bcf000:
                continue
            target = entry + 8 + rotated(first) + rotated(second) + (third & 0xfff)
            if target & 0xffffffff == slot:
                result[entry] = self.symbol_name(info >> 8)
        return result

    def resource_string(self, address):
        s = self.cstring
        if not s['address'] <= address < s['address'] + s['length']:
            return None
        position = s['offset'] + address - s['address']
        if position > s['offset'] and self.data[position - 1] != 0:
            return None
        end = self.data.find(b'\0', position, min(position + 1025, s['offset'] + s['length']))
        if end < 0:
            return None
        try:
            value = self.data[position:end].decode('utf-8', errors='strict')
        except UnicodeError:
            return None
        if not value.startswith('data/') or not value.endswith(('.aem', '.aei')):
            return None
        safe_name(re.sub(r"/+", "/", value))
        return value


def rotated(word):
    value, rotation = word & 255, (word >> 8 & 15) * 2
    return ((value >> rotation) | (value << (32 - rotation))) & 0xffffffff


def literal_references(lib):
    """Addresses of `add rN, pc` that complete a PC-relative resource string address.

    A candidate is a literal load into rN followed within 40 bytes by the add.
    Only the decoding of whole functions below proves these are instructions.
    """
    text = lib.text
    code = lib.data[text['offset']:text['offset'] + text['length']]
    base = text['address']
    found = []
    for at in range(0, len(code) - 4, 2):
        half, = struct.unpack_from('<H', code, at)
        pc = (base + at + 4) & ~3
        if half >> 11 == 9:  # ldr rN, [pc, #imm8*4]
            register, pool, width = half >> 8 & 7, pc + (half & 255) * 4, 2
        elif half in (0xf85f, 0xf8df):  # ldr.w rN, [pc, #+-imm12]
            second, = struct.unpack_from('<H', code, at + 2)
            register, pool, width = second >> 12, pc + ((second & 0xfff) if half == 0xf8df else -(second & 0xfff)), 4
        else:
            continue
        if not base <= pool <= base + len(code) - 4:
            continue
        word, = struct.unpack_from('<I', code, pool - base)
        add = struct.pack('<H', 0x4478 | register if register < 8 else 0x44f8 | register & 7)
        for following in range(at + width, min(at + width + 40, len(code) - 2), 2):
            if code[following:following + 2] == add:
                if lib.resource_string((word + base + following + 4) & 0xffffffff):
                    found.append(base + following)
                break
    return found


def decode_function(lib, decoder, start, size, anchors):
    """Linear decode of one function. Every anchor must fall on an instruction boundary.

    The only bytes skipped are those an unconditional forward branch jumps over
    before the next anchor (a literal pool between instructions). Decoding stops
    at the first undecodable bytes after the last anchor (the closing pool).
    """
    from capstone.arm_const import ARM_OP_IMM
    text = lib.text
    result = []
    address = start
    for stop in sorted(anchors) + [start + size]:
        while address < stop:
            at = text['offset'] + address - text['address']
            ins = next(decoder.disasm(lib.data[at:at + 4], address), None)
            if ins is None:
                # Past the last anchor only a trailing literal pool may remain.
                return result if stop == start + size else None
            result.append(ins)
            address += ins.size
            if (ins.mnemonic in ('b', 'b.w') and ins.operands and ins.operands[0].type == ARM_OP_IMM
                    and address < ins.operands[0].imm <= stop):
                address = ins.operands[0].imm
        if address != stop and stop != start + size:
            return None
    return result


class Straight:
    """Values of registers, stack slots and heap objects along straight-line code.

    Slots are 32-bit words at sp offsets. A callee or a store through an unknown
    pointer can reach the frame only from `exposed` up: the lowest sp offset the
    function ever hands out as an address (the frame pointer reaches everything).
    """

    def __init__(self, exposed):
        self.objects = []
        self.registers, self.slots = {}, {}
        self.exposed = exposed

    def forget(self, low=0, high=None):
        self.slots = {k: v for k, v in self.slots.items() if not (k + 4 > low and (high is None or k < high))}

    def escape(self):
        if self.exposed is not None:
            self.forget(self.exposed)

    def shift(self, delta):
        """sp moved down by delta: every sp-relative offset grows by it."""
        self.slots = {k + delta: v for k, v in self.slots.items()}
        self.registers = {r: ('stack', v[1] + delta) if v[0] == 'stack' else v for r, v in self.registers.items()}

    def allocate(self, kind, size, address):
        self.objects.append(dict(kind=kind, size=size, address=address, fields={}, copied=None, poisoned=False))
        return ('object', len(self.objects) - 1, 0)

    def store(self, target, offset, value, width):
        if not target or target[0] != 'object':
            return
        record = self.objects[target[1]]
        record['touched'] = True
        at = target[2] + offset
        if value and value[0] == 'value':
            value = ('value', value[1] & ((1 << 8 * width) - 1))
        if any(at < start + size and start < at + width for start, (_, size) in record['fields'].items()):
            record['poisoned'] = True
        record['fields'][at] = (value, width)

    def snapshot(self):
        """Registers, slots and copies of every object they reach, for a branch's other path."""
        seen, todo = {}, [v for v in list(self.registers.values()) + list(self.slots.values())]
        while todo:
            value = todo.pop()
            if value and value[0] == 'object' and value[1] not in seen:
                item = self.objects[value[1]]
                seen[value[1]] = dict(item, fields=dict(item['fields']))
                todo.extend(field for field, _ in item['fields'].values())
        return dict(self.registers), dict(self.slots), seen

    def restore(self, snapshot):
        """Continue on a branch's other path with new copies of the objects it reaches, so
        the two alternatives never write into one record. A copy keeps its allocation's
        address; one this path never writes to is dropped at the end (`settle`)."""
        registers, slots, copies = snapshot
        moved = {}
        for index, item in copies.items():
            self.objects.append(dict(item, clone=True, touched=False))
            moved[index] = len(self.objects) - 1
        def remap(value):
            return ('object', moved[value[1]], value[2]) if value and value[0] == 'object' and value[1] in moved else value
        for index in moved.values():
            item = self.objects[index]
            item['fields'] = {at: (remap(value), width) for at, (value, width) in item['fields'].items()}
        self.registers = {r: remap(v) for r, v in registers.items()}
        self.slots = {k: remap(v) for k, v in slots.items()}

    def poison(self, target):
        if target and target[0] == 'object':
            self.objects[target[1]].update(poisoned=True, touched=True)

    def frame(self, base, disp, sp):
        """sp offset addressed by [base, #disp], or None."""
        if base == sp:
            return disp
        value = self.registers.get(base)
        return value[1] + disp if value and value[0] == 'stack' else None

    def write(self, base, disp, value, width, sp, fp):
        """A store of known width through [base, #disp]."""
        at = self.frame(base, disp, sp)
        if at is not None:
            self.forget(at, at + width)
            if width == 4:
                self.slots[at] = value
            return
        target = self.registers.get(base)
        if target and target[0] == 'object':
            self.store(target, disp, value, width)
        elif base == fp:
            self.slots = {}
        else:
            self.escape()

    def clobber(self, base, sp, fp):
        """A store of unknown width or shape through base."""
        target = self.registers.get(base)
        if self.frame(base, 0, sp) is not None or base == fp:
            self.slots = {}
        elif target and target[0] == 'object':
            self.poison(target)
        else:
            self.escape()


def interpret(lib, instructions):
    import capstone
    from capstone import arm_const as arm
    sp, fp = arm.ARM_REG_SP, arm.ARM_REG_R7
    targets = collections.Counter()
    for ins in instructions:
        if is_jump(ins) and ins.operands and ins.operands[-1].type == arm.ARM_OP_IMM:
            targets[ins.operands[-1].imm] += 1
    state = Straight(exposure(instructions, targets, sp, fp))
    # State at the one forward branch into a block that nothing falls into: a
    # literal-pool skip continues the same path; a conditional branch starts the
    # other alternative, on copies of the objects it reaches.
    entries = {}
    flows, guarded = True, 0
    for n, ins in enumerate(instructions):
        if ins.address in targets:
            entry = entries.pop(ins.address, None)
            if targets[ins.address] == 1 and not flows and entry is not None:
                if entry[0] == 'same':
                    state.registers, state.slots = entry[1], entry[2]
                else:
                    state.restore(entry[1])
            else:
                state.registers, state.slots = {}, {}
        elif not flows:
            state.registers, state.slots = {}, {}
        flows = True
        registers = state.registers
        mnemonic = ins.mnemonic.split('.')[0]
        ops = ins.operands
        # Instructions are decoded one at a time, so IT blocks are tracked here.
        conditional = guarded > 0 or ins.cc not in (arm.ARM_CC_AL, arm.ARM_CC_INVALID)
        guarded = len(mnemonic) - 1 if mnemonic.startswith('it') and len(mnemonic) <= 5 else max(0, guarded - 1)
        returns = mnemonic == 'pop' and any(o.type == arm.ARM_OP_REG and o.reg == arm.ARM_REG_PC for o in ops)
        if is_jump(ins) or ins.group(capstone.CS_GRP_RET) or returns:
            target = ops[-1].imm if is_jump(ins) and ops and ops[-1].type == arm.ARM_OP_IMM else None
            alternative = conditional or mnemonic in ('cbz', 'cbnz')
            if target is not None and target > ins.address and targets[target] == 1:
                entries[target] = ('other', state.snapshot()) if alternative else ('same', dict(registers), dict(state.slots))
            if not alternative:
                flows = False
            continue
        written = ins.regs_access()[1]
        if conditional or mnemonic.startswith('it'):
            for register in written:
                registers.pop(register, None)
            for op in ops:
                if op.type == arm.ARM_OP_MEM and mnemonic.startswith(('st', 'vst')):
                    state.clobber(op.mem.base, sp, fp)
            if mnemonic in ('bl', 'blx'):
                state.escape()
                for register in (arm.ARM_REG_R0, arm.ARM_REG_R1, arm.ARM_REG_R2, arm.ARM_REG_R3, arm.ARM_REG_R12):
                    registers.pop(register, None)
            if sp in written:
                state.registers, state.slots = {}, {}
            continue
        if mnemonic in ('bl', 'blx'):
            callee = lib.imports.get(ops[0].imm) if ops and ops[0].type == arm.ARM_OP_IMM else None
            first, second = registers.get(arm.ARM_REG_R0), registers.get(arm.ARM_REG_R1)
            for register in (arm.ARM_REG_R0, arm.ARM_REG_R1, arm.ARM_REG_R2, arm.ARM_REG_R3, arm.ARM_REG_R12, arm.ARM_REG_LR):
                registers.pop(register, None)
            if callee not in ('_Znwj', '_Znaj', 'strlen') and not (callee in MEMCPY and first and first[0] == 'object'):
                state.escape()
            if callee == '_Znwj' and first and first[0] == 'value':
                registers[arm.ARM_REG_R0] = state.allocate('object', first[1], ins.address)
            elif callee == '_Znaj':
                registers[arm.ARM_REG_R0] = state.allocate('array', None, ins.address)
            elif callee in MEMCPY and first and first[0] == 'object' and first[2] == 0:
                buffer = state.objects[first[1]]
                if buffer['kind'] == 'array' and buffer['copied'] is None and second and second[0] == 'string':
                    buffer['copied'] = (second[1], ins.address)
                else:
                    buffer['poisoned'] = True
            continue
        destination = ops[0].reg if ops and ops[0].type == arm.ARM_OP_REG else None
        immediates = [o.imm for o in ops[1:] if o.type == arm.ARM_OP_IMM]
        sources = [o.reg for o in ops[1:] if o.type == arm.ARM_OP_REG]
        memory = ops[-1].mem if ops and ops[-1].type == arm.ARM_OP_MEM else None
        disp = displacement(memory, registers) if memory is not None else None
        plain = disp is not None and not ins.writeback and len(ops) == 2
        value = None
        if mnemonic in ('str', 'strh', 'strb') and plain:
            width = {'str': 4, 'strh': 2, 'strb': 1}[mnemonic]
            state.write(memory.base, disp, registers.get(ops[0].reg), width, sp, fp)
            continue
        if mnemonic == 'strd' and disp is not None and not ins.writeback and len(ops) == 3:
            pair = (registers.get(ops[0].reg), registers.get(ops[1].reg))
            state.write(memory.base, disp, pair[0], 4, sp, fp)
            state.write(memory.base, disp + 4, pair[1], 4, sp, fp)
            continue
        if mnemonic in ('stm', 'stmia') and ops and ops[0].type == arm.ARM_OP_REG and ops[0].reg != sp:
            target = registers.get(ops[0].reg)
            for index, op in enumerate(ops[1:]):
                state.write(ops[0].reg, 4 * index, registers.get(op.reg), 4, sp, fp)
            if ins.writeback:
                registers.pop(ops[0].reg, None)
                if target and target[0] == 'object':
                    registers[ops[0].reg] = ('object', target[1], target[2] + 4 * (len(ops) - 1))
            continue
        if mnemonic.startswith(('st', 'vst')):
            for op in ops:
                if op.type == arm.ARM_OP_MEM:
                    state.clobber(op.mem.base, sp, fp)
            if ops and ops[0].type == arm.ARM_OP_REG and mnemonic.startswith('stm'):
                state.clobber(ops[0].reg, sp, fp)
        elif mnemonic in ('mov', 'movs', 'movw') and len(ops) == 2 and immediates:
            value = ('value', immediates[0] & 0xffffffff)
        elif mnemonic in ('mov', 'movs') and len(ops) == 2 and sources == [sp]:
            value = ('stack', 0)
        elif mnemonic in ('mov', 'movs') and len(ops) == 2 and sources and sources[0] != arm.ARM_REG_PC:
            value = registers.get(sources[0])
        elif mnemonic in ('mvn', 'mvns') and len(ops) == 2 and immediates:
            value = ('value', ~immediates[0] & 0xffffffff)
        elif mnemonic == 'movt' and immediates:
            low = registers.get(destination)
            if low and low[0] == 'value':
                value = ('value', (low[1] & 0xffff) | (immediates[0] & 0xffff) << 16)
        elif mnemonic in ('add', 'adds', 'addw', 'sub', 'subs', 'subw') and immediates and len(ops) in (2, 3):
            source = sources[0] if len(ops) == 3 else destination
            origin = ('stack', 0) if source == sp else registers.get(source)
            delta = immediates[0] if mnemonic.startswith('add') else -immediates[0]
            if origin and origin[0] == 'value':
                value = ('value', (origin[1] + delta) & 0xffffffff)
            elif origin and origin[0] == 'object':
                value = ('object', origin[1], origin[2] + delta)
            elif origin and origin[0] == 'stack' and destination != sp:
                value = ('stack', origin[1] + delta)
            elif destination == sp and source == sp:
                state.shift(-delta)
                continue
        elif mnemonic == 'add' and len(ops) == 2 and sources == [arm.ARM_REG_PC]:
            pool = registers.get(destination)
            if pool and pool[0] == 'literal':
                path = lib.resource_string((pool[1] + ins.address + 4) & 0xffffffff)
                value = ('string', path) if path else None
        elif mnemonic == 'ldr' and plain and memory.base == arm.ARM_REG_PC and memory.index == 0:
            at = ((ins.address + 4) & ~3) + disp
            text = lib.text
            if text['address'] <= at and at + 4 <= text['address'] + text['length']:
                value = ('literal', struct.unpack_from('<I', lib.data, text['offset'] + at - text['address'])[0])
        elif mnemonic == 'ldr' and plain and state.frame(memory.base, disp, sp) is not None:
            value = state.slots.get(state.frame(memory.base, disp, sp))
        elif mnemonic in ('push', 'pop') and not ins.writeback:
            registers_moved = len([o for o in ops if o.type == arm.ARM_OP_REG])
            for register in written:
                if register != sp:
                    registers.pop(register, None)
            if mnemonic == 'pop':
                state.forget(0, 4 * registers_moved)
            state.shift(4 * registers_moved if mnemonic == 'push' else -4 * registers_moved)
            continue
        for register in written:
            registers.pop(register, None)
        if sp in written:
            state.registers, state.slots = {k: v for k, v in registers.items() if v[0] != 'stack'}, {}
            registers = state.registers
        if destination is not None and value is not None and destination in written:
            registers[destination] = value
    # A copy that its path never wrote to is no record of its own.
    for item in state.objects:
        if item.get('clone') and not item['touched']:
            item.update(kind='unused copy', size=None)
    return state.objects


def displacement(memory, registers):
    """Byte offset from the base register, when any index register holds a known value."""
    if memory.index == 0:
        return memory.disp
    index = registers.get(memory.index)
    if not index or index[0] != 'value':
        return None
    return memory.disp + memory.scale * (index[1] << memory.lshift)


def exposure(instructions, targets, sp, fp):
    """Lowest sp offset whose address may reach a callee or memory, or None.

    A register computed from sp/fp exposes the frame from its offset up (from 0
    for fp or an index) unless, until it is redefined, it serves only as the
    base of loads and stores in the same straight-line code.
    """
    import capstone
    from capstone import arm_const as arm
    exposed = None
    for n, ins in enumerate(instructions):
        ops = ins.operands
        used = [o.reg for o in ops[1:] if o.type == arm.ARM_OP_REG]
        if (ins.mnemonic.split('.')[0] not in ('add', 'adds', 'addw', 'sub', 'subs', 'subw', 'mov', 'movs')
                or ops[0].type != arm.ARM_OP_REG or ops[0].reg in (sp, fp) or not (sp in used or fp in used)):
            continue
        if not escapes(instructions, n, ops[0].reg, targets):
            continue
        offset = ops[-1].imm if used == [sp] and len(ops) == 3 and ops[-1].type == arm.ARM_OP_IMM else 0
        exposed = offset if exposed is None else min(exposed, offset)
    return exposed


def escapes(instructions, start, register, targets, window=64):
    import capstone
    from capstone import arm_const as arm
    arguments = (arm.ARM_REG_R0, arm.ARM_REG_R1, arm.ARM_REG_R2, arm.ARM_REG_R3)
    for ins in instructions[start + 1:start + 1 + window]:
        mnemonic = ins.mnemonic.split('.')[0]
        if ins.address in targets or is_jump(ins) or ins.group(capstone.CS_GRP_RET):
            return True
        if mnemonic in ('bl', 'blx'):
            if register in arguments:
                return True
            if register == arm.ARM_REG_R12:
                return False
            continue
        reads, writes = ins.regs_access()
        ops = ins.operands
        if register in reads:
            bases = [o.mem.base for o in ops if o.type == arm.ARM_OP_MEM and o.mem.index != register]
            multiple = mnemonic in ('stm', 'stmia', 'ldm', 'ldmia') and ops[0].type == arm.ARM_OP_REG and ops[0].reg == register
            as_value = [o for o in ops if o.type == arm.ARM_OP_REG and o.reg == register and not (multiple and o is ops[0])]
            if as_value or ins.writeback or not (register in bases or multiple):
                return True
        if register in writes:
            return False
    return True


def is_jump(ins):
    import capstone
    return ins.group(capstone.CS_GRP_JUMP) and ins.mnemonic.split('.')[0] not in ('bl', 'blx')


def android_records(lib, checkpoint):
    try:
        import capstone
    except ImportError as error:
        raise ContentError('Install tools/requirements-bindings.txt for ARM static declaration reading') from error
    from .registrations import record
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    decoder.detail = True
    starts = [f[0] for f in lib.functions]
    anchors = collections.defaultdict(list)
    for address in literal_references(lib):
        index = bisect.bisect_right(starts, address) - 1
        if index >= 0 and address < starts[index] + lib.functions[index][1]:
            anchors[index].append(address)
    rows = []
    text = lib.text
    for done, (index, points) in enumerate(sorted(anchors.items())):
        checkpoint('Reading Android resource declarations', done / len(anchors))
        start, size, _ = lib.functions[index]
        instructions = decode_function(lib, decoder, start, size, points)
        if instructions is None:
            continue
        objects = interpret(lib, instructions)
        for item in objects:
            row = declaration(objects, item)
            if row is None:
                continue
            identifier, kind, path, payload, address = row
            result = record(lib, text['offset'] + address - text['address'], identifier, kind, path)
            if kind == 2 and path.endswith('.aei') and set(payload) == {4} and payload[4][1] == 4:
                result['texture_parameter_bits'] = payload[4][0]
            elif kind in (4, 6) and path.endswith('.aem') and set(payload) == {4, 6} and (payload[4][1], payload[6][1]) == (2, 1):
                target = result if kind == 4 else result.setdefault('_payload', {})
                target['material_id'], target['mesh_flags'] = payload[4][0], payload[6][0]
            rows.append(result)
            if len(rows) > MAX_RECORDS:
                raise ContentError('Too many resource declarations')
    return rows


def declaration(objects, item):
    """(id, kind, path, payload fields, address) of one complete registration record, else None.

    Record: 16 bytes = u16 id, u32 kind, u32 -1, payload pointer. Payload: 8 bytes =
    pointer to a buffer that received one copy of a resource path, then nothing,
    a u32 texture parameter, or a u16 material and u8 flags.
    """
    if item['kind'] != 'object' or item['size'] != 16 or item['poisoned']:
        return None
    fields = item['fields']
    if sorted(fields) != [0, 4, 8, 12] or [fields[k][1] for k in (0, 4, 8, 12)] != [2, 4, 4, 4]:
        return None
    (identifier, _), (kind, _), (sentinel, _), (link, _) = (fields[k] for k in (0, 4, 8, 12))
    if (not identifier or identifier[0] != 'value' or not kind or kind[0] != 'value' or sentinel != ('value', 0xffffffff)
            or not link or link[0] != 'object' or link[2] != 0):
        return None
    payload = objects[link[1]]
    if payload['kind'] != 'object' or payload['size'] != 8 or payload['poisoned'] or payload['fields'].get(0, (None,))[1:] != (4,):
        return None
    buffer = payload['fields'][0][0]
    if not buffer or buffer[0] != 'object' or buffer[2] != 0:
        return None
    copy = objects[buffer[1]]
    if copy['kind'] != 'array' or copy['poisoned'] or not copy['copied']:
        return None
    rest = {at: field for at, field in payload['fields'].items() if at}
    if (sorted((at, width) for at, (_, width) in rest.items()) not in ([], [(4, 4)], [(4, 2), (6, 1)])
            or any(not value or value[0] != 'value' for value, _ in rest.values())):
        return None
    rest = {at: (value[1], width) for at, (value, width) in rest.items()}
    return identifier[1], kind[1], copy['copied'][0], rest, item['address']


def instructions(lib, symbol):
    """Linear Thumb decode, with operand detail, of a named function (None if absent).

    Literal pools inside the function decode as data-shaped instructions; readers
    match exact instruction shapes, so pool words cannot pose as the code they seek.
    """
    import capstone
    cache = lib.__dict__.setdefault('_decoded', {})
    if symbol not in cache:
        extent = getattr(lib, 'symbols', {}).get(symbol)
        if extent is None:
            cache[symbol] = None
        else:
            decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
            decoder.detail = True
            decoder.skipdata = True
            start, size = extent
            at = lib.text['offset'] + start - lib.text['address']
            cache[symbol] = [ins if ins.id else Data(ins.address, ins.size)
                             for ins in decoder.disasm(lib.data[at:at + size], start)]
    return cache[symbol]


class Data:
    """Undecodable bytes inside a function (a literal pool): no operands, no effects."""
    mnemonic, operands, id = '.byte', (), 0

    def __init__(self, address, size):
        self.address, self.size = address, size

    def regs_access(self):
        return [], []


def callee(lib, ins):
    """Symbol called by a bl/blx with an immediate target: PLT import or local function."""
    from capstone.arm_const import ARM_OP_IMM
    if ins.mnemonic not in ('bl', 'blx') or len(ins.operands) != 1 or ins.operands[0].type != ARM_OP_IMM:
        return None
    target = ins.operands[0].imm & 0xffffffff
    if target in lib.imports:
        return lib.imports[target]
    return next((name for name, (start, _) in lib.symbols.items() if start == target & ~1), None)
