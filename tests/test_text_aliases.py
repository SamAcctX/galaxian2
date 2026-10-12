"""Relocated compiler-layout fixtures with synthetic glyph values and switch data."""
import importlib.util
import re
import struct
from types import SimpleNamespace
import unittest
from gof2_content.text_aliases import MAC, MAC_ALTERNATE, ARM, MAC_CASES, MAC_ALTERNATE_CASES, ARM_CASES, extract_text_aliases


def fixture(mac, relocation=0, alternate=False):
    code = bytearray(4096)
    start = 128
    marks = {}
    cursor = start
    for token in ((MAC_ALTERNATE if alternate else MAC) if mac else ARM).split():
        if token.startswith('{'):
            name, size = token[1:-1].split(':'); size = int(size)
            marks[name] = cursor
            value = 0 if name == 'table' else 65 + int(name[5:])
            code[cursor:cursor + size] = value.to_bytes(size, 'little')
            cursor += size
        else:
            data = bytes.fromhex(token); code[cursor:cursor+len(data)] = data; cursor += len(data)
    cases = (MAC_ALTERNATE_CASES if alternate else MAC_CASES) if mac else ARM_CASES
    table = 2048 if mac else marks['table']
    if mac:
        struct.pack_into('<i', code, marks['table'], table - marks['table'] - 4)
    for i in range(22):
        target = start + cases[1 + i // 2] if i % 2 == 0 else cursor
        if mac: struct.pack_into('<i', code, table + 4*i, target-table)
        else: code[table+i] = (target-table)//2
    section = {'segment': b'__TEXT', 'name': b'__text', 'address': 0x10000 + relocation, 'offset': 64, 'length': len(code)}
    mach = SimpleNamespace(data=bytes(64)+code, text=section, sections=[section], slice_offset=4096, architecture='x86_64' if mac else 'armv7')
    return mach, marks, table


class TextAliases(unittest.TestCase):
    def test_alternate_mac_aliases_keep_cases_and_merge_distinct(self):
        for relocation in (0, 0x2000):
            mach, marks, table = fixture(True, relocation, alternate=True)
            result = extract_text_aliases(mach)
            self.assertEqual(result['aliases'], extract_text_aliases(fixture(True, relocation)[0])['aliases'])
            self.assertEqual(result['provenance']['declaration']['bytes'], 543)
            data = bytearray(mach.data)
            data[64 + table] ^= 1
            mach.data = bytes(data)
            self.assertEqual(extract_text_aliases(mach), {})

    def test_relocated_declarations(self):
        for mac in [False, True]:
            for relocation in [0, 0x2000]:
                mach, marks, table = fixture(mac, relocation)
                result = extract_text_aliases(mach)
                self.assertEqual(len(result['aliases']), 20)
                rows = dict(result['aliases'])
                self.assertEqual(rows[0x60], 65)
                self.assertEqual(rows[0x410], 66)
                self.assertNotIn(0x411, rows)
                self.assertEqual(rows[0x430], 77)
                self.assertEqual(result['provenance']['declaration']['offset'], 4288)
                self.assertEqual(result['provenance']['switch_table']['offset'], 4160 + table)

    def test_corrupt_and_ambiguous_declarations(self):
        for mac in [False, True]:
            for mutation in ['shape', 'target', 'control', 'duplicate', 'truncated']:
                mach, marks, table = fixture(mac)
                data = bytearray(mach.data)
                if mutation == 'shape': data[64+128] ^= 1
                elif mutation == 'target': data[64+table] ^= 1
                elif mutation == 'control': data[64+marks['value0']] = 10
                elif mutation == 'duplicate':
                    size = 602 if mac else 438
                    data[64+1024:64+1024+size] = data[64+128:64+128+size]
                elif mutation == 'truncated': data = data[:64+128+400]
                mach.data = bytes(data)
                self.assertEqual(extract_text_aliases(mach), {}, (mac, mutation))



CONDITIONS = {'eq': 0, 'ne': 1, 'hs': 2, 'lo': 3, 'hi': 8, 'ls': 9, 'ge': 10, 'lt': 11, 'gt': 12, 'le': 13}


def thumb(text, at):
    """Encoding of one Thumb instruction as Capstone prints it (the forms shapes use)."""
    from android_fixture import Thumb, branch_fields
    def fields(value):  # i and imm3:imm8 of a Thumb-2 modified immediate
        first, second = struct.unpack('<2H', Thumb(0).mov_imm(0, value).code)
        return first & 0x400, second & 0x70ff
    def half(*values): return struct.pack('<%dH' % len(values), *values)
    def wide(c, o):  # conditional b<c>.w
        return half(0xf000 | (o < 0) << 10 | CONDITIONS[c] << 6 | o >> 12 & 0x3f, 0x8000 | (o >> 18 & 1) << 13 | (o >> 19 & 1) << 11 | o >> 1 & 0x7ff)
    def far(o):  # b.w
        s, j1, j2, v = branch_fields(o, False)
        return half(0xf000 | s << 10 | v >> 11 & 0x3ff, 0x9000 | j1 << 13 | j2 << 11 | v & 0x7ff)
    reg = lambda name: int(name[1:])
    forms = [
        (r'movw (r\d+), #(\w+)', lambda d, v: Thumb(0).movw(reg(d), int(v, 0)).code),
        (r'mov (r\d+), (r\d+)', lambda d, m: Thumb(0).mov(reg(d), reg(m)).code),
        (r'(?:movs|mov[a-z]{2}) (r\d), #(\w+)', lambda d, v: half(0x2000 | reg(d) << 8 | int(v, 0))),
        (r'ldrh (r\d), \[(r\d)\]', lambda t, n: half(0x8800 | reg(n) << 3 | reg(t))),
        (r'strh (r\d+), \[(r\d+)\], #(\w+)', lambda t, n, v: half(0xf820 | reg(n), reg(t) << 12 | 0xb00 | int(v, 0))),
        (r'cmp (r\d), #(\w+)', lambda n, v: half(0x2800 | reg(n) << 8 | int(v, 0))),
        (r'cmp (r\d), (r\d)', lambda n, m: half(0x4280 | reg(m) << 3 | reg(n))),
        (r'cmp\.w (r\d+), #(\w+)', lambda n, v: half(0xf1b0 | fields(int(v, 0))[0] | reg(n), fields(int(v, 0))[1] | 0xf00)),
        (r'sub\.w (r\d+), (r\d+), #(\w+)', lambda d, n, v: half(0xf1a0 | fields(int(v, 0))[0] | reg(n), fields(int(v, 0))[1] | reg(d) << 8)),
        (r'subw (r\d+), (r\d+), #(\w+)', lambda d, n, v: Thumb(0).subw(reg(d), reg(n), int(v, 0)).code),
        (r'subs (r\d), #(\w+)', lambda d, v: half(0x3800 | reg(d) << 8 | int(v, 0))),
        (r'tbb \[pc, (r\d+)\]', lambda m: half(0xe8df, 0xf000 | reg(m))),
        (r'it (\w+)', lambda c: half(0xbf08 | CONDITIONS[c] << 4)),
        (r'b #(\w+)', lambda t: half(0xe000 | (int(t, 0) - at - 4) >> 1 & 0x7ff)),
        (r'b(\w\w) #(\w+)', lambda c, t: half(0xd000 | CONDITIONS[c] << 8 | (int(t, 0) - at - 4) >> 1 & 0xff)),
        (r'b(\w\w)\.w #(\w+)', lambda c, t: wide(c, int(t, 0) - at - 4)),
        (r'b\.w #(\w+)', lambda t: far(int(t, 0) - at - 4)),
    ]
    for pattern, encode in forms:
        found = re.fullmatch(pattern, text)
        if found:
            return encode(*found.groups())
    raise ValueError(text)


def assemble(shape, address, values, tables=lambda labels, rows, starts: {}):
    """Shape template to Thumb bytes: holes from `values`, case tables from
    `tables(labels, hole line addresses, table starts)`; two passes resolve labels."""
    lines = shape.strip().splitlines()
    labels, rows, starts, filled = {}, {}, {}, {}
    for _ in range(2):
        code = bytearray()
        for line in lines:
            label, _, line = line.rpartition(': ')
            at = address + len(code)
            if label: labels[label] = at
            table = re.fullmatch(r'(.*) \{(\w+):(\d+)\}', line)
            if table: line = table[1]
            for name in re.findall(r'\{(\w+)\}', line): rows[name] = at
            line = re.sub(r'\{(\w+)\}', lambda m: hex(values[m[1]]), line)
            line = re.sub(r'@(\w+)', lambda m: '#' + hex(labels.get(m[1], at)), line)
            code += thumb(line, at)
            if table:
                starts[table[2]] = address + len(code)
                code += filled.get(table[2], bytes(int(table[3])))
        filled = tables(labels, rows, starts)
    return bytes(code), labels, rows, starts


LOW = {i: 'value%d' % (5 + i // 2) for i in range(0, 22, 2)}  # 11 of the 22 low cases
HIGH = {0: 'value1', 3: 'value16', 5: 'value17', 7: 'value4'}


def android(values=None, low=LOW, high=HIGH, shape=None, copies=1, symbol='_ZN11AbyssEngine6String16getWCharFromUtf8EPci'):
    """getWCharFromUtf8 in the Android shape between unrelated code: glyphs 65+i and
    case tables {case: hole name of the target line, or a label}."""
    from android_fixture import TEXT, library
    from gof2_content.android_library import AndroidLibrary
    from gof2_content.text_aliases import ANDROID
    values = values or {'value%d' % i: 65 + i for i in range(19)}
    def cases(labels, rows, starts):
        targets = {**labels, **rows}
        return {name: bytes((targets[mapping.get(i, 'merge')] - starts[name]) // 2 for i in range(count))
                for name, mapping, count in (('table', low, 22), ('high_table', high, 8))}
    code, found = bytearray(b'\xf0\xb5\x00\xbf'), []  # push {r4-r7, lr}; nop
    for _ in range(copies):
        body, labels, rows, starts = assemble(shape or ANDROID, TEXT + len(code), values, cases)
        found.append((labels, starts))
        code += body
    code += b'\xf0\xbd'  # pop {r4-r7, pc}
    return AndroidLibrary(library([(symbol, bytes(code), TEXT)], {})), found


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidTextAliases(unittest.TestCase):
    def test_cases_and_equality_leaves_give_twenty_aliases(self):
        from android_fixture import TEXT
        lib, [(labels, starts)] = android()
        result = extract_text_aliases(lib)
        glyph = lambda name: 65 + int(name[5:])
        expected = sorted([[0x410 + i, glyph(n)] for i, n in LOW.items()] + [[0x43e + i, glyph(n)] for i, n in HIGH.items()]
                          + [[0x60, 83], [0xaa, 69], [0xba, 67], [0x430, 69], [0x435, 68]])
        self.assertEqual(result['aliases'], expected)
        # The block from movw to the loop's bne.w (180 bytes in this shape), and the low case table.
        self.assertEqual(result['provenance'], {'declaration': {'offset': TEXT + 4, 'bytes': labels['merge'] + 10 - TEXT - 4},
                                                'switch_table': {'offset': starts['table'], 'bytes': 22}})
        self.assertEqual(result['provenance']['declaration']['bytes'], 180)

    def test_each_broken_declaration_is_unsupported(self):
        from gof2_content.text_aliases import ANDROID
        cases = {'low glyph': dict(values={**{'value%d' % i: 65 + i for i in range(19)}, 'value18': 32}),
                 'case into code': dict(low={**LOW, 1: 'low'}),
                 'twenty one aliases': dict(high={**HIGH, 1: 'value15'}),
                 'nineteen aliases': dict(high={0: 'value1', 3: 'value16', 5: 'value17'}),
                 'other branch target': dict(shape=ANDROID.replace('bhi @above', 'bhi @merge')),
                 'other compare': dict(shape=ANDROID.replace('cmp r3, #0xaa', 'cmp r3, #0xab')),
                 'longer immediate': dict(shape=ANDROID.replace('cmp.w r3, #0x410', 'cmp.w r3, #0x4100')),
                 'two blocks': dict(copies=2), 'other function': dict(symbol='_ZN11AbyssEngine6String15ConvertFromUTF8Ev')}
        for name, options in cases.items():
            self.assertEqual(extract_text_aliases(android(**options)[0]), {}, name)


if __name__ == '__main__': unittest.main()
