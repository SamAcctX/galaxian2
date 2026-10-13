"""Relocated compiler-layout fixtures with synthetic glyph values and switch data."""
import importlib.util
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



LOW = {i: 'value%d' % (5 + i // 2) for i in range(0, 22, 2)}  # 11 of the 22 low cases
HIGH = {0: 'value1', 3: 'value16', 5: 'value17', 7: 'value4'}


def android(values=None, low=LOW, high=HIGH, shape=None, copies=1, symbol='_ZN11AbyssEngine6String16getWCharFromUtf8EPci'):
    """getWCharFromUtf8 in the Android shape between unrelated code: glyphs 65+i and
    case tables {case: hole name of the target line, or a label}."""
    from android_fixture import TEXT, library
    from thumb_shapes import assemble
    from gof2_content.android_library import AndroidLibrary
    from gof2_content.text_aliases import ANDROID
    values = values or {'value%d' % i: 65 + i for i in range(19)}
    tables = {name: [mapping.get(i, 'merge') for i in range(count)] for name, mapping, count in (('table', low, 22), ('high_table', high, 8))}
    code, found = bytearray(b'\xf0\xb5\x00\xbf'), []  # push {r4-r7, lr}; nop
    for _ in range(copies):
        body, labels, _ = assemble(shape or ANDROID, TEXT + len(code), values, tables=tables)
        found.append(labels)
        code += body
    code += b'\xf0\xbd'  # pop {r4-r7, pc}
    return AndroidLibrary(library([(symbol, bytes(code), TEXT)], {})), found


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidTextAliases(unittest.TestCase):
    def test_cases_and_equality_leaves_give_twenty_aliases(self):
        from android_fixture import TEXT
        lib, [labels] = android()
        result = extract_text_aliases(lib)
        glyph = lambda name: 65 + int(name[5:])
        expected = sorted([[0x410 + i, glyph(n)] for i, n in LOW.items()] + [[0x43e + i, glyph(n)] for i, n in HIGH.items()]
                          + [[0x60, 83], [0xaa, 69], [0xba, 67], [0x430, 69], [0x435, 68]])
        self.assertEqual(result['aliases'], expected)
        # The block from movw to the loop's bne.w (180 bytes in this shape), and the low case table.
        self.assertEqual(result['provenance'], {'declaration': {'offset': TEXT + 4, 'bytes': labels['merge'] + 10 - TEXT - 4},
                                                'switch_table': {'offset': TEXT + 4 + 32, 'bytes': 22}})  # after the tbb
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
