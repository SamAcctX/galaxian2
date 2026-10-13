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
        mac = copy.deepcopy(reader.VALUES)
        self.assertEqual(mac['pricing'].pop('special_multiplier'), 1.0499999523162842)
        self.assertEqual(android, mac)
