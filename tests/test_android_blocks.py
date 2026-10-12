"""Exact instruction shapes inside named functions of synthetic Android libraries."""
import importlib.util
import unittest

SHAPE = '''
push.w {r4, r5, r6, r7, r8, lr}
ldr r0, [pc, #{&slot}]
add r0, pc
movw r1, #{value}
cmp r1, #0
it eq
moveq r2, #{other}
beq @done
blx <_Znwj>
tbb [pc, r1] {cases:2}
done: pop.w {r4, r5, r6, r7, r8, lr}
'''


def function(address, shape=SHAPE, copies=1, values=None):
    from android_fixture import stub
    from thumb_shapes import assemble
    code, found = bytearray(b'\x00\xbf'), []
    for _ in range(copies):
        body, labels, at = assemble(shape, address + len(code), values or {'value': 0x1234, 'other': 7}, {'slot': 0x7000},
                                    {'_Znwj': stub('_Znwj'), '_Znaj': stub('_Znaj')}, {'cases': ['done', 'done']})
        found.append((address + len(code), labels, at))
        code += body
    return bytes(code), found


def library(**options):
    from android_fixture import TEXT, library
    from gof2_content.android_library import AndroidLibrary
    code, found = function(TEXT, **options)
    return AndroidLibrary(library([('f', code, TEXT)], {})), found


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidShapes(unittest.TestCase):
    def test_holes_labels_calls_literals_and_tables(self):
        from gof2_content.android_blocks import find, match
        lib, [(start, labels, at)] = library()
        block = find(lib, 'f', SHAPE)
        self.assertEqual(block['values'], {'value': 0x1234, 'other': 7})
        self.assertEqual(block['at'], {'value': at['value'], 'other': at['other']})
        self.assertEqual(block['labels'], {'done': labels['done']})
        self.assertEqual(block['refs'], {'slot': [0x7000]})
        table = labels['done'] - 2
        self.assertEqual(block['tables'], {'cases': (table, bytes([1, 1]))})
        self.assertEqual((block['start'], block['end']), (start, labels['done'] + 4))
        # Only from the named function's instructions: the same code in 'g' is not 'f'.
        from android_fixture import TEXT, library as build
        from gof2_content.android_library import AndroidLibrary
        both = AndroidLibrary(build([('f', function(TEXT)[0], TEXT), ('g', function(TEXT + 0x400)[0], TEXT + 0x400)], {}))
        self.assertIsNotNone(match(both, 'g', SHAPE, start + 0x400))
        self.assertIsNone(match(both, 'g', SHAPE, start))

    def test_each_difference_rejects(self):
        from gof2_content.android_blocks import find, matches
        lib, _ = library(shape=SHAPE.replace('cmp r1, #0', 'cmp r1, #1'))
        self.assertIsNone(find(lib, 'f', SHAPE), 'other text')
        # The code holds #0x1234: a shape reading #0x123 is no prefix of it.
        self.assertIsNone(find(library()[0], 'f', SHAPE.replace('movw r1, #{value}', 'movw r1, #0x123')), 'longer immediate')
        lib, _ = library(shape=SHAPE.replace('beq @done', 'beq @start').replace('push.w', 'start: push.w'))
        self.assertIsNone(find(lib, 'f', SHAPE), 'other branch target')
        lib, _ = library(shape=SHAPE.replace('<_Znwj>', '<_Znaj>'))
        self.assertIsNone(find(lib, 'f', SHAPE), 'other callee')
        lib, _ = library(copies=2)
        self.assertEqual((len(matches(lib, 'f', SHAPE)), find(lib, 'f', SHAPE)), (2, None))
        # A literal load whose address no `add rN, pc` completes.
        loose = SHAPE.replace('add r0, pc\n', 'mov r0, r1\n')
        lib, _ = library(shape=loose)
        self.assertIsNone(find(lib, 'f', loose), 'unfinished literal')
        self.assertIsNone(find(library()[0], 'g', SHAPE), 'other function')

    def test_literal_outside_the_code(self):
        from android_fixture import TEXT
        from thumb_shapes import thumb
        from gof2_content.android_blocks import find
        shape = 'ldr.w r0, [pc, #{&slot}]\nadd r0, pc\n'
        lib, _ = library(shape=shape)
        self.assertEqual(find(lib, 'f', shape)['refs'], {'slot': [0x7000]})
        # A pool past the end of .text (0x100 bytes here) holds no literal.
        from android_fixture import library as build
        from gof2_content.android_library import AndroidLibrary
        for offset, found in ((0xf8, True), (0xfc, False)):
            code = b'\x00\xbf' + thumb('ldr.w r0, [pc, #%#x]' % offset, TEXT + 2) + thumb('add r0, pc', TEXT + 6)
            lib = AndroidLibrary(build([('f', code, TEXT)], {}, text_size=0x100))
            self.assertEqual(find(lib, 'f', shape) is not None, found, offset)


if __name__ == '__main__': unittest.main()
