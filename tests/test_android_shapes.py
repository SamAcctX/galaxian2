"""Instruction-shape listings of named functions in synthetic Android libraries."""
import importlib.util
import unittest


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'optional static-reader dependency')
class AndroidShapes(unittest.TestCase):
    def setUp(self):
        from android_text_fixture import text_library
        from gof2_content.android_shapes import Listing
        self.lib, self.addresses = text_library({
            '_ZN1A1fEv': '''
push {r4, r5, r6, r7, lr}
mov r4, r0
ldr r0, =0x12345678
add r0, pc
vldr s0, =0x3fc00000
call _ZN1B1gEv
call puts
movw r1, #0x10
movt r1, #0x20
movw r2, #0x10
movt r3, #0x20
cmp r0, #2
bhi.w #out
tbh [pc, r0, lsl #1]
.cases one, two, out
one:
movs r0, #1
two:
movs r0, #2
out:
pop {r4, r5, r6, r7, pc}''',
            '_ZN1C1hEv': 'cmp r0, #1\nbhi #done\ntbh [pc, r0, lsl #1]\n.cases done\nnop\ndone:\nbx lr',
            '_ZN1D1iEv': 'cmp r0, #1\nbhi #done\ntbb [pc, r0]\n.cases first, done\nfirst:\nnop\ndone:\nbx lr'})
        self.listing = Listing(self.lib, '_ZN1A1fEv')

    def test_rendering_names_calls_and_pool_words(self):
        lines = self.listing.lines
        self.assertEqual(lines[2:7], ['ldr r0, =0x12345678', 'add r0, pc', 'vldr s0, =0x3fc00000', 'call _ZN1B1gEv', 'call puts'])
        from gof2_content.android_shapes import Listing
        self.assertEqual(Listing(self.lib, '_ZN1Z1zEv').lines, [])

    def test_templates_capture_and_repeat_tokens(self):
        from gof2_content.android_shapes import number
        pair = 'movw {r}, #{low}\nmovt {r}, #{high}'
        found = self.listing.find(pair)
        self.assertEqual([(s.first, s.last, s['r'], s.value('low'), s.value('high')) for s in found], [(7, 8, 'r1', 16, 32)])
        self.assertEqual(found[0].span(), {'offset': self.addresses['_ZN1A1fEv'] + 20, 'bytes': 8})
        self.assertEqual(len(self.listing.find('movw {}, #0x10')), 2)
        self.assertIsNone(self.listing.unique('movw {}, #0x10'))
        self.assertEqual(self.listing.unique('movw {}, #0x10', 8).first, 9)
        self.assertEqual(self.listing.find('movw r1, #0x10', 8), [])
        self.assertIsNone(self.listing.at('movt r1, #0x20', 7))
        self.assertEqual(self.listing.at('movt r1, #0x20', 8).first, 8)
        # Literal text: brackets and dots are not pattern syntax.
        self.assertEqual(len(self.listing.find('tbh [pc, r0, lsl #1]')), 1)
        self.assertEqual(self.listing.find('tbh [pc, r0. lsl #1]'), [])
        # Whole lines only.
        self.assertEqual(self.listing.find('r0, #2'), [])
        self.assertEqual(self.listing.find('movs r0, #'), [])
        self.assertEqual((number('#0x96'), number('#-3'), number('0x10'), number('#1.500000e+00'), number('#-0x25c')), (150, -3, 16, 1.5, -604))

    def test_branches_cases_and_register_writes(self):
        listing = self.listing
        branch = listing.unique('bhi.w {out}')
        # The three table entries decode as three lines after tbh (13).
        self.assertEqual(listing.target(branch['out']), 19)
        self.assertEqual(listing.follow(branch, 'out', 'pop {r4, r5, r6, r7, pc}').first, 19)
        self.assertIsNone(listing.follow(branch, 'out', 'movs r0, #1'))
        self.assertIsNone(listing.follow(None, 'out', 'push {r4, r5, r6, r7, lr}'))
        self.assertIsNone(listing.target('#0x1'))
        self.assertEqual([listing.case(13, n) for n in range(3)], [17, 18, 19])
        from gof2_content.android_shapes import Listing
        short = Listing(self.lib, '_ZN1C1hEv')
        self.assertEqual(short.case(2, 0), 5)
        # Entries past the function's end are not read.
        self.assertIsNone(short.case(2, 40))
        bytes_table = Listing(self.lib, '_ZN1D1iEv')
        self.assertEqual([bytes_table.lines[bytes_table.case(2, n)] for n in (0, 1)], ['nop', 'bx lr'])
        self.assertTrue(listing.writes(7, 8, 'r1'))
        self.assertFalse(listing.writes(9, 10, 'r1'))
        self.assertFalse(listing.writes(7, 8, 'r4'))
        self.assertTrue(listing.writes(0, 1, 'r4'))

    def test_pool_addresses_and_vtables(self):
        from android_text_fixture import text_library
        from gof2_content.android_shapes import Listing, objects, relocation, vtable_slot
        lib, addresses = text_library({'_ZN1E1jEv': 'ldr.w r0, =&_ZTV1E\nmovs r1, #0x11\nadd r0, pc\nldr r2, =0x10\nadd r1, pc\nadd r3, pc\nbx lr'},
                                      {'_ZTV1E': [0, 0, '_ZN1E1jEv', 7, '_ZN1F1kEv'], '_ZTV1F': ['_ZTV1E']})
        listing = Listing(lib, '_ZN1E1jEv')
        table = objects(lib)['_ZTV1E']
        name, span = relocation(lib, listing.address(2))
        self.assertEqual(name, '_ZTV1E')
        rel = lib.elf_sections['.rel.dyn']
        self.assertEqual(lib.data[span['offset']:span['offset'] + 4], listing.address(2).to_bytes(4, 'little'))
        self.assertTrue(rel['offset'] <= span['offset'] < rel['offset'] + rel['length'] and span['bytes'] == 8)
        # r1 was last written by movs, not a pool load; r3 never.
        self.assertEqual((listing.address(4), listing.address(5), listing.address(1)), (None, None, None))
        self.assertEqual([vtable_slot(lib, '_ZTV1E', n) - table for n in range(3)], [8, 12, 16])
        self.assertEqual([(relocation(lib, vtable_slot(lib, '_ZTV1E', n)) or [None])[0] for n in range(3)], ['_ZN1E1jEv', None, '_ZN1F1kEv'])
        self.assertIsNone(vtable_slot(lib, '_ZTV1G', 0))
        self.assertEqual(relocation(lib, objects(lib)['_ZTV1F'])[0], '_ZTV1E')
        self.assertEqual(lib.data[table + 12:table + 16], bytes([7, 0, 0, 0]))
        self.assertNotIn('_ZN1E1jEv', objects(lib))

    def test_this_register(self):
        from android_text_fixture import text_library
        from gof2_content.android_shapes import Listing
        lib, _ = text_library({'_ZN1H1aEv': 'mov r4, r0\ncall _ZN1B1gEv\nbx lr', '_ZN1H1bEv': 'movs r0, #1\nmov r4, r0\nbx lr',
                               '_ZN1H1cEv': 'mov r4, r0\nmovs r4, #1\nmov r4, r0\nbx lr', '_ZN1H1dEv': 'movs r1, #0\nmov r4, r0\nbx lr'})
        held = lambda name, last: Listing(lib, name).holds_this('r4', last)
        self.assertEqual([held('_ZN1H1aEv', 2), held('_ZN1H1bEv', 2), held('_ZN1H1cEv', 0), held('_ZN1H1cEv', 2), held('_ZN1H1dEv', 0), held('_ZN1H1dEv', 2)],
                         [True, False, True, False, False, True])
        self.assertFalse(Listing(lib, '_ZN1H1aEv').holds_this('r5', 2))
