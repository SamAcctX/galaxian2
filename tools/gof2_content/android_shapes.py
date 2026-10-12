"""Exact instruction shapes in named Android functions.

`Listing(lib, symbol)` decodes one named Thumb function and renders each
instruction as one line of Capstone text, `mnemonic op_str`, except that calls
read `call SYMBOL` and PC-relative loads read `MNEMONIC REG, =0xWORD` (the pool
word). Readers match templates line by line: text is literal, `{name}` captures
one operand token (a register, `#` value or branch address) and a repeated
`{name}` must repeat the same token. A line may open with a `label:` that
`{@label}` branches inside the template must reach. Nothing is executed.
"""
import functools
import re
import struct

from .android_library import callee, instructions

TOKEN = r'[^\s,\[\]{}]+'


@functools.lru_cache(maxsize=None)
def compile_shape(template):
    """(pattern, {label: line}) for a template."""
    seen, parts, labels = set(), [], {}
    lines = [line.strip() for line in template.strip().splitlines() if line.strip()]
    for index, line in enumerate(lines):
        label = re.match(r'(\w+): ', line)
        if label:
            labels[label[1]] = index
            lines[index] = line[label.end():]
    for piece in re.split(r'(\{@?\w*\})', '\n'.join(lines)):
        name = piece[1:-1].replace('@', 'at_') if piece.startswith('{') and piece.endswith('}') else None
        if name is None:
            parts.append(re.escape(piece))
        elif not name:
            parts.append('(?:%s)' % TOKEN)
        elif name in seen:
            parts.append('(?P=%s)' % name)
        else:
            seen.add(name)
            parts.append('(?P<%s>%s)' % (name, TOKEN))
    assert {name[3:] for name in seen if name.startswith('at_')} <= set(labels), 'branch to an undefined template label'
    return re.compile('^' + ''.join(parts) + '\n', re.M), labels


def number(token):
    """`#0x96`, `#-3`, `0xb95ca` or `#1.500000e+00` as int or float."""
    token = token[1:] if token.startswith('#') else token
    return float(token) if 'e' in token and not token.startswith(('0x', '-0x')) else int(token, 0)


class Shape:
    def __init__(self, listing, match, first, last):
        self.listing, self.match, self.first, self.last = listing, match, first, last

    def __getitem__(self, name):
        return self.match[name]

    def value(self, name):
        return number(self.match[name])

    def span(self):
        return self.listing.span(self.first, self.last)

    def index(self, name):
        """Instruction index of the line holding group `name`."""
        return self.first + self.match.string.count('\n', self.match.start(), self.match.start(name))

    def pool(self, name):
        """(word, provenance) of the pool word the load holding group `name` reads."""
        return self.value(name), self.listing.pool(self.index(name))


class Listing:
    def __init__(self, lib, symbol):
        self.lib, self.symbol = lib, symbol
        self.code = instructions(lib, symbol) or []
        self.lines = [render(lib, ins) for ins in self.code]
        self.text = ''.join(line + '\n' for line in self.lines)
        self.starts, at = {}, 0
        for i, line in enumerate(self.lines):
            self.starts[at] = i
            at += len(line) + 1
        self.offsets = {i: at for at, i in self.starts.items()}
        self.index = {ins.address: i for i, ins in enumerate(self.code)}

    def find(self, template, first=0):
        """Every match starting at instruction `first` or later whose labels its branches reach."""
        pattern, labels = compile_shape(template)
        result = []
        for match in pattern.finditer(self.text, self.offsets.get(first, len(self.text))):
            start = self.starts[match.start()]
            if all(self.target(match['at_' + label]) == start + line for label, line in labels.items() if 'at_' + label in match.groupdict()):
                result.append(Shape(self, match, start, start + match[0].count('\n') - 1))
        return result

    def unique(self, template, first=0):
        found = self.find(template, first)
        return found[0] if len(found) == 1 else None

    def at(self, template, first):
        """The template matched exactly at instruction `first`, or None."""
        found = self.find(template, first)
        return found[0] if found and found[0].first == first else None

    def follow(self, shape, name, template):
        """The template matched exactly at the branch target `shape[name]`, or None."""
        index = self.target(shape[name]) if shape else None
        return None if index is None else self.at(template, index)

    def target(self, token):
        """Instruction index of a branch address token, or None."""
        return self.index.get(number(token))

    def span(self, first, last):
        start = self.code[first].address
        text = self.lib.text
        return {'offset': self.lib.slice_offset + text['offset'] + start - text['address'],
                'bytes': self.code[last].address + self.code[last].size - start}

    def pool(self, index):
        """Provenance of the pool word the PC-relative load at `index` reads."""
        ins = self.code[index]
        word = ((ins.address + 4) & ~3) + ins.operands[1].mem.disp
        return {'offset': self.lib.slice_offset + self.lib.text['offset'] + word - self.lib.text['address'], 'bytes': 4}

    def case(self, index, value):
        """Target index of case `value` (>= 0) of the tbb/tbh at instruction `index`.

        The caller checks `value` against the dispatch bound; the entry must lie in the function.
        """
        ins = self.code[index]
        width = 1 if ins.mnemonic == 'tbb' else 2
        start, size = self.lib.symbols[self.symbol]
        table = ins.address + 4 + width * value
        if table + width > start + size:
            return None
        at = self.lib.text['offset'] + table - self.lib.text['address']
        entry = self.lib.data[at] if width == 1 else struct.unpack_from('<H', self.lib.data, at)[0]
        return self.index.get(ins.address + 4 + 2 * entry)

    def address(self, index):
        """Address the `add rN, pc` at `index` builds from the latest pool load into rN, or None."""
        add = re.fullmatch(r'add (\w+), pc', self.lines[index])
        back = next((i for i in range(index - 1, -1, -1) if add and self.writes(i, i, add[1])), None)
        load = re.search(r'=(0x[0-9a-f]+)$', self.lines[back]) if back is not None else None
        return (int(load[1], 16) + self.code[index].address + 4) & 0xffffffff if load else None

    def holds(self, register, last, argument='r0'):
        """Whether the first `mov REG, ARG` copies the incoming argument register (r0: `this`)
        and REG keeps it through `last`. Callees preserve r4-r11, so calls in between do not matter.
        """
        copy = (self.find('mov %s, %s' % (register, argument)) or [None])[0]
        return (copy is not None and copy.first <= last and not self.writes(0, copy.first - 1, argument)
                and not self.writes(copy.first + 1, last, register))

    def writes(self, first, last, register):
        """Whether any instruction in [first, last] writes the named register."""
        return any(ins.reg_name(r) == register for ins in self.code[first:last + 1] for r in ins.regs_access()[1])


def render(lib, ins):
    from capstone.arm_const import ARM_OP_MEM, ARM_REG_PC
    if not ins.id:
        return '.byte'
    name = callee(lib, ins)
    if name:
        return 'call ' + name
    ops = ins.operands
    if (ins.mnemonic in ('ldr', 'ldr.w', 'vldr') and len(ops) == 2 and ops[1].type == ARM_OP_MEM
            and ops[1].mem.base == ARM_REG_PC and not ops[1].mem.index):
        pool = ((ins.address + 4) & ~3) + ops[1].mem.disp
        text = lib.text
        at = text['offset'] + pool - text['address']
        if text['address'] <= pool and pool + 4 <= text['address'] + text['length']:
            return '%s %s, =%#x' % (ins.mnemonic, ins.reg_name(ops[0].reg), struct.unpack_from('<I', lib.data, at)[0])
    return ('%s %s' % (ins.mnemonic, ins.op_str)).strip()


def relocation(lib, address):
    """(symbol, provenance of its .rel.dyn entry) for a relocated word, or None ('' for relative words)."""
    cache = lib.__dict__.get('_relocations')
    if cache is None:
        cache = {}
        section = lib.elf_sections.get('.rel.dyn')
        if section and not section['length'] % 8:
            for at in range(section['offset'], section['offset'] + section['length'], 8):
                where, info = lib.unpack('<II', at)
                cache[where] = (lib.symbol_name(info >> 8), {'offset': lib.slice_offset + at, 'bytes': 8})
        lib.__dict__['_relocations'] = cache
    return cache.get(address)


def objects(lib):
    """Address of each defined data symbol in .dynsym, by name."""
    cache = lib.__dict__.get('_objects')
    if cache is None:
        cache = {}
        table = lib.elf_sections.get('.dynsym')
        if table and not table['length'] % 16:
            for index in range(table['length'] // 16):
                _, value, _, info, _, shndx = lib.unpack('<IIIBBH', table['offset'] + 16 * index)
                if info & 15 == 1 and shndx:
                    cache[lib.symbol_name(index)] = value
        lib.__dict__['_objects'] = cache
    return cache


def vtable_slot(lib, table, slot):
    """Address of `slot` in the vtable symbol `table` (after its two header words), or None."""
    start = objects(lib).get(table)
    return None if start is None else start + 8 + 4 * slot
