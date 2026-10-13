"""Ordinary shopping declarations require each independent source proof."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from declaration_fixture import verify_hashed_declarations
from gof2_content import ordinary_shopping as reader

class OrdinaryShoppingTests(unittest.TestCase):
    def test_proofs_and_relocation(self):
        verify_hashed_declarations(self, reader, reader.extract_ordinary_shopping, 'pricing')


class OrdinaryShoppingAndroidTests(unittest.TestCase):
    def test_android_proofs(self):
        import android_fixture
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            android_fixture.verify_android_proof(self, reader, lambda lib: reader.extract_ordinary_shopping(lib, {'scope': 'rescue_choreography'}), values='ANDROID_VALUES')
            image, layout, _ = android_fixture.layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertEqual(reader.extract_ordinary_shopping(AndroidLibrary(image), {}), ({}, {}))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'ordinary_shopping_definitions.gd', values='ANDROID_VALUES')

    def test_android_special_price(self):
        # Status::calcCargoPrices keeps system 25's maximum price; the Mac adds 5 %.
        android = copy.deepcopy(reader.ANDROID_VALUES)
        self.assertEqual(android['pricing'].pop('special_multiplier'), 1.0)
        self.assertEqual(set(android.pop('blueprints')), {'shipping_unit_cost', 'autocomplete'})
        mac = copy.deepcopy(reader.VALUES)
        self.assertEqual(mac['pricing'].pop('special_multiplier'), 1.0499999523162842)
        self.assertEqual(android, mac)

    def test_android_blueprint_constants(self):
        # The blueprint values are the immediates and literal of their proof spans.
        from gof2_content.text_ids import canonical_id
        rows, rules = reader.ANDROID, reader.ANDROID_VALUES['blueprints']
        auto = rules['autocomplete']
        for key in ['blueprint_shipping_quote', 'blueprint_shipping_commit']:
            code = thumb(rows[key][3])
            self.assertEqual(code[0][0], 'blx', key)
            self.assertIn(('movs', 'r1, #%#x' % rules['shipping_unit_cost']), code, key)
            self.assertTrue(any(op == 'mul' for op, _ in code), key)
        self.assertEqual(thumb(rows['blueprint_autocomplete_item'][3]), [('ldr', 'r0, [r4, #0x1c]'), ('cmp', 'r0, #%#x' % auto['special_item_id'])])
        add = thumb(rows['blueprint_autocomplete_add'][3])
        self.assertEqual([op for op, _ in add], ['add.w', 'add.w'])
        self.assertEqual(sum(int(arg.split('#')[1], 16) for _, arg in add), auto['special_add'])
        price = thumb(rows['blueprint_autocomplete_multiplier'][3])
        self.assertEqual(price[0], ('vmov.f32', 's0, #%e' % auto['multiplier']))
        self.assertEqual([op for op, _ in price[1:]], ['muls', 'vmov', 'vcvt.f32.s32', 'vmul.f32', 'vcvt.s32.f32'])
        base = thumb(rows['blueprint_base_quantity'][3])
        self.assertEqual(base[2:6], [('movs', 'r1, #1'), ('cmp', 'r0, #1'), ('it', 'eq'), ('moveq', 'r1, #0xa')])
        self.assertEqual(base[-2], ('str', 'r1, [r4, #0x20]'))
        self.assertEqual(canonical_id(int(thumb(rows['blueprint_autocomplete_text'][3])[0][1].split('#')[1], 16)), auto['text_id'])
        self.assertEqual(canonical_id(int(thumb(rows['blueprint_autocomplete_shortfall_text'][3])[0][1].split('#')[1], 16)), auto['shortfall_text_id'])
        self.assertEqual(bytes.fromhex(rows['blueprint_autocomplete_label'][3]), auto['label'].encode() + b'\0')


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]
