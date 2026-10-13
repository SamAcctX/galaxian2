"""Symbol-anchored Android proofs: found by function name, every byte checked."""
import importlib.util
import struct
import unittest
from android_fixture import layout_library
from gof2_content.android_library import AndroidLibrary
from gof2_content.declaration_layouts import recognize_symbols

LAYOUT = {'speed': ('_ZN1A5speedEv', 6, 10, '00' * 10),
          'table': ('_ZN1A5speedEv', 20, 24, 'sha256:' + '0' * 64, 'literal', 8),
          'reset': ('_ZN1B5resetEv', 0, 30, 'sha256:' + '0' * 64)}


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidLayoutTests(unittest.TestCase):
    def test_spans_are_found_by_name_wherever_the_function_sits(self):
        for shift in (0, 0x2000):
            image, layout, starts = layout_library(LAYOUT, shift)
            lib = AndroidLibrary(image)
            proof = recognize_symbols(lib, layout)
            self.assertEqual(set(proof), set(LAYOUT))
            self.assertEqual(proof['speed']['offset'] - proof['speed']['anchor'], 6)
            self.assertEqual(proof['reset']['offset'], proof['reset']['anchor'])
            self.assertEqual(proof['speed']['anchor'], starts['_ZN1A5speedEv'])  # file offsets equal addresses
            self.assertEqual(proof['table']['offset'], proof['table']['anchor'] + 8)
            self.assertEqual({span['bytes'] for span in proof.values()}, {10, 24, 30})

    def test_every_changed_byte_name_or_extent_is_refused(self):
        image, layout, _ = layout_library(LAYOUT)
        proof = recognize_symbols(AndroidLibrary(image), layout)
        for key, span in proof.items():
            for index in (0, span['bytes'] - 1):
                raw = bytearray(image)
                raw[span['offset'] + index] ^= 0xff
                self.assertEqual(recognize_symbols(AndroidLibrary(bytes(raw)), layout), {}, (key, index))
        image, layout, starts = layout_library(LAYOUT)
        # The reset proof's own bytes, claimed for the preceding function: outside its extent.
        outside = dict(layout, reset=('_ZN1A5speedEv', starts['_ZN1B5resetEv'] - starts['_ZN1A5speedEv'], 30, layout['reset'][3]))
        self.assertEqual(recognize_symbols(AndroidLibrary(image), outside), {})
        for change in ('name', 'delta', 'extent', 'kind', 'pair', 'start'):
            bad = dict(layout)
            symbol, delta, size, expected, *kind = bad['table'] if change in ('kind', 'pair', 'start') else bad['speed']
            if change == 'name': bad['speed'] = ('_ZN1A5otherEv', delta, size, expected)
            elif change == 'delta': bad['speed'] = (symbol, delta + 2, size, expected)
            elif change == 'extent': bad['speed'] = (symbol, delta, 4096, '00' * 4096)
            elif change == 'kind': bad['table'] = (symbol, delta, size, expected, 'pointer', 8)
            elif change == 'pair': bad['table'] = (symbol, delta + 2, size, expected, 'literal', 8)
            else: bad['table'] = (symbol, delta, size, expected, 'literal', 4)
            self.assertEqual(recognize_symbols(AndroidLibrary(image), bad), {}, change)

    def test_literal_pair_must_build_its_own_address(self):
        image, layout, starts = layout_library(LAYOUT)
        delta = LAYOUT['table'][1]
        for at, value in ((2, 0x79), (3, 0x46)):  # add r1, pc instead; mov r0, pc instead
            raw = bytearray(image)
            raw[starts['_ZN1A5speedEv'] + delta + at] = value
            self.assertEqual(recognize_symbols(AndroidLibrary(bytes(raw)), layout), {}, (at, value))
        here = starts['_ZN1A5speedEv'] + delta
        pool = ((here + 4) & ~3) + 4
        # Same address, but r0 is touched before the add (mov r0, r0), or loaded from r1 instead of pc.
        raw = bytearray(image)
        struct.pack_into('<HH', raw, here + 2, 0x4600, 0x4478)
        struct.pack_into('<I', raw, pool, (struct.unpack_from('<I', image, pool)[0] - 2) & 0xffffffff)
        self.assertEqual(recognize_symbols(AndroidLibrary(bytes(raw)), layout), {})
        raw = bytearray(image)
        struct.pack_into('<H', raw, here, 0x6848)  # ldr r0, [r1, #4]
        self.assertEqual(recognize_symbols(AndroidLibrary(bytes(raw)), layout), {})


if __name__ == '__main__':
    unittest.main()
