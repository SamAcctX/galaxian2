"""Assemble android_blocks templates into synthetic Thumb code. Never executed.

`thumb` encodes one instruction from its Capstone text (only the forms the
shapes use); `assemble` fills a shape's holes, lays a literal pool after the
code for its `{&role}` loads and its case tables from labels. Readers decode
the result with Capstone, so every acceptance test also checks these encodings.
"""
import re
import struct

from android_fixture import Thumb, branch_fields

CONDITIONS = {'eq': 0, 'ne': 1, 'hs': 2, 'lo': 3, 'mi': 4, 'pl': 5, 'hi': 8, 'ls': 9, 'ge': 10, 'lt': 11, 'gt': 12, 'le': 13}
NAMES = {'sb': 9, 'sl': 10, 'fp': 11, 'ip': 12, 'sp': 13, 'lr': 14, 'pc': 15}


def reg(name):
    return NAMES[name] if name in NAMES else int(name[1:])


def half(*values):
    return struct.pack('<%dH' % len(values), *values)


def fields(value):
    """i and imm3:imm8 of a Thumb-2 modified immediate."""
    first, second = struct.unpack('<2H', Thumb(0).mov_imm(0, value).code)
    return first & 0x400, second & 0x70ff


def mask(names):
    return sum(1 << reg(name.strip()) for name in names.split(','))


def thumb(text, at):
    """Encoding of one Thumb instruction as Capstone prints it."""
    number = lambda v: int(v, 0)
    offset = lambda t: number(t) - at - 4

    def wide_branch(c, o):  # b<c>.w
        return half(0xf000 | (o < 0) << 10 | CONDITIONS[c] << 6 | o >> 12 & 0x3f,
                    0x8000 | (o >> 18 & 1) << 13 | (o >> 19 & 1) << 11 | o >> 1 & 0x7ff)

    def far(o):  # b.w
        s, j1, j2, v = branch_fields(o, False)
        return half(0xf000 | s << 10 | v >> 11 & 0x3ff, 0x9000 | j1 << 13 | j2 << 11 | v & 0x7ff)

    def literal(t, v, wide):
        if wide:
            return half(0xf8df if number(v) >= 0 else 0xf85f, reg(t) << 12 | abs(number(v)))
        return half(0x4800 | reg(t) << 8 | number(v) // 4)

    def cbz(n, t):
        o = offset(t)
        return half(0xb100 | (o >> 6 & 1) << 9 | (o >> 1 & 0x1f) << 3 | reg(n))

    forms = [
        (r'push\.w \{(.*)\}', lambda l: half(0xe92d, mask(l))),
        (r'pop\.w \{(.*)\}', lambda l: half(0xe8bd, mask(l))),
        (r'movw (\w+), #(\S+)', lambda d, v: Thumb(0).movw(reg(d), number(v)).code),
        (r'movt (\w+), #(\S+)', lambda d, v: Thumb(0).movt(reg(d), number(v)).code),
        (r'mov\.w (\w+), #-1', lambda d: Thumb(0).minus_one(reg(d)).code),
        (r'mov\.w (\w+), #(\S+)', lambda d, v: Thumb(0).mov_imm(reg(d), number(v)).code),
        (r'mov(?:eq|ne)? (\w+), (\w+)', lambda d, m: Thumb(0).mov(reg(d), reg(m)).code),
        (r'(?:movs|mov[a-z]{2}) (r\d), #(\S+)', lambda d, v: half(0x2000 | reg(d) << 8 | number(v))),
        (r'ldr (r\d), \[pc, #(\S+)\]', lambda t, v: literal(t, v, False)),
        (r'ldr\.w (\w+), \[pc, #(\S+)\]', lambda t, v: literal(t, v, True)),
        (r'ldr (r\d), \[(r\d)(?:, #(\S+))?\]', lambda t, n, v=None: half(0x6800 | number(v or '0') // 4 << 6 | reg(n) << 3 | reg(t))),
        (r'ldr\.w (\w+), \[(r\d+)\]', lambda t, n: half(0xf8d0 | reg(n), reg(t) << 12)),
        (r'str (r\d), \[sp, #(\S+)\]', lambda t, v: half(0x9000 | reg(t) << 8 | number(v) // 4)),
        (r'strh (r\d), \[(r\d)\]', lambda t, n: half(0x8000 | reg(n) << 3 | reg(t))),
        (r'stm (r\d)!, \{(.*)\}', lambda n, l: half(0xc000 | reg(n) << 8 | mask(l))),
        (r'sub sp, #(\S+)', lambda v: half(0xb080 | number(v) // 4)),
        (r'orrs (r\d), (r\d)', lambda d, m: half(0x4300 | reg(m) << 3 | reg(d))),
        (r'tst\.w (\w+), #(\S+)', lambda n, v: half(0xf010 | fields(number(v))[0] | reg(n), fields(number(v))[1] | 0xf00)),
        (r'ldrb (r\d), \[(r\d)\]', lambda t, n: half(0x7800 | reg(n) << 3 | reg(t))),
        (r'ldrh (r\d), \[(r\d)\]', lambda t, n: half(0x8800 | reg(n) << 3 | reg(t))),
        (r'strb (r\d), \[(r\d), #(\S+)\]', lambda t, n, v: half(0x7000 | number(v) << 6 | reg(n) << 3 | reg(t))),
        (r'strb\.w (\w+), \[(\w+), #(\S+)\]', lambda t, n, v: half(0xf880 | reg(n), reg(t) << 12 | number(v))),
        (r'strh (\w+), \[(\w+)\], #(\S+)', lambda t, n, v: half(0xf820 | reg(n), reg(t) << 12 | 0xb00 | number(v))),
        (r'add (r\d), pc', lambda d: half(0x4478 | reg(d))),
        (r'add (r\d), sp, #(\S+)', lambda d, v: half(0xa800 | reg(d) << 8 | number(v) // 4)),
        (r'(?:adds|add[a-z]{2}) (r\d), #(\S+)', lambda d, v: half(0x3000 | reg(d) << 8 | number(v))),
        (r'(?:adds|add[a-z]{2}) (r\d), (r\d), #(\S+)', lambda d, n, v: half(0x1c00 | number(v) << 6 | reg(n) << 3 | reg(d))),
        (r'(?:subs|sub[a-z]{2}) (r\d), (r\d), #(\S+)', lambda d, n, v: half(0x1e00 | number(v) << 6 | reg(n) << 3 | reg(d))),
        (r'subs (r\d), #(\S+)', lambda d, v: half(0x3800 | reg(d) << 8 | number(v))),
        (r'sub\.w (\w+), (\w+), #(\S+)', lambda d, n, v: half(0xf1a0 | fields(number(v))[0] | reg(n), fields(number(v))[1] | reg(d) << 8)),
        (r'subw (\w+), (\w+), #(\S+)', lambda d, n, v: Thumb(0).subw(reg(d), reg(n), number(v)).code),
        (r'sxth (r\d), (r\d)', lambda d, m: half(0xb200 | reg(m) << 3 | reg(d))),
        (r'cmp (r\d), #(\S+)', lambda n, v: half(0x2800 | reg(n) << 8 | number(v))),
        (r'cmp (r\d), (r\d)', lambda n, m: half(0x4280 | reg(m) << 3 | reg(n))),
        (r'cmp\.w (\w+), #(\S+)', lambda n, v: half(0xf1b0 | fields(number(v))[0] | reg(n), fields(number(v))[1] | 0xf00)),
        (r'tbb \[pc, (\w+)\]', lambda m: half(0xe8df, 0xf000 | reg(m))),
        (r'tbh \[pc, (\w+), lsl #1\]', lambda m: half(0xe8df, 0xf010 | reg(m))),
        (r'it (\w+)', lambda c: half(0xbf08 | CONDITIONS[c] << 4)),  # one conditional instruction
        (r'cbz (r\d), #(\S+)', cbz),
        (r'bl #(\S+)', lambda t: Thumb(at).call(number(t), exchange=False).code),
        (r'blx #(\S+)', lambda t: Thumb(at).call(number(t)).code),
        (r'b #(\S+)', lambda t: half(0xe000 | offset(t) >> 1 & 0x7ff)),
        (r'b\.w #(\S+)', lambda t: far(offset(t))),
        (r'b(\w\w) #(\S+)', lambda c, t: half(0xd000 | CONDITIONS[c] << 8 | offset(t) >> 1 & 0xff)),
        (r'b(\w\w)\.w #(\S+)', lambda c, t: wide_branch(c, offset(t))),
    ]
    for pattern, encode in forms:
        found = re.fullmatch(pattern, text)
        if found:
            return encode(*[g for g in found.groups() if g is not None])
    raise ValueError(text)


def assemble(shape, address, values=None, refs=None, calls=None, tables=None, pool=None):
    """(bytes, labels, hole line addresses) of a shape at `address`.

    values: {hole: int}; refs: {role: address} for `{&role}` loads, whose literal
    pool follows the code or, with pool=(address, bytearray), is appended to that
    shared pool; calls: {symbol: address}; tables: {name: [label or hole name]}
    case targets. Two passes resolve forward labels.
    """
    values, refs, calls, tables = values or {}, refs or {}, calls or {}, tables or {}
    lines = [line for line in shape.strip().splitlines() if line.strip()]
    labels, at_line, adds, layout = {}, {}, {}, None
    for _ in range(2):
        code = bytearray()
        loads = []  # (ldr position, register, role)
        starts = {}
        for line in lines:
            label, _, line = line.rpartition(': ')
            here = address + len(code)
            if line == '...':  # a literal pool gap
                code += b'\xff\xff\xff\xff'
                continue
            if label:
                labels[label] = here
            line = re.sub(r'\{([\w.]+)(?:\|[\w.]+)+\}', lambda m: m[1], line)  # first alternative
            table = re.fullmatch(r'(.*) \{(\w+):(\d+)\}', line)
            if table:
                line = table[1]
            for name in re.findall(r'\{(\w+)\}', line):
                at_line[name] = here
            role = re.search(r'(\w+), \[pc, #\{&(\w+)\}\]', line)
            if role:
                loads.append((len(code), role[1], role[2]))
                word = layout['pool'] + 4 * (len(loads) - 1) if layout else here + 4
                line = line.replace('{&%s}' % role[2], hex(word - ((here + 4) & ~3)))
            added = re.fullmatch(r'add (\w+), pc', line)
            if added:
                adds[next(len(loads) - 1 - i for i, row in enumerate(reversed(loads)) if row[1] == added[1])] = here
            line = re.sub(r'\{(\w+)\}', lambda m: hex(values[m[1]]), line)
            line = re.sub(r'@(\w+)', lambda m: '#' + hex(labels.get(m[1], here)), line)
            line = re.sub(r'<(\w+)>', lambda m: '#' + hex(calls[m[1]]), line)
            code += thumb(line, here)
            if table:
                starts[table[2]] = address + len(code)
                targets = {**at_line, **labels}
                entries = [(targets.get(name, starts[table[2]]) - starts[table[2]]) // 2 for name in tables.get(table[2], [])]
                count = int(table[3])
                raw = bytes(entries) if line.startswith('tbb') else struct.pack('<%dH' % len(entries), *entries)
                code += raw.ljust(count, b'\0') if layout else bytes(count)
        if pool is None and (address + len(code)) % 4:
            code += half(0xbf00)
        layout = {'pool': pool[0] + len(pool[1]) if pool else address + len(code)}
    words = b''.join(struct.pack('<I', (refs[role] - (adds.get(index, 0) + 4)) & 0xffffffff) for index, (_, _, role) in enumerate(loads))
    if pool:
        pool[1].extend(words)
    else:
        code += words
    return bytes(code), labels, at_line
