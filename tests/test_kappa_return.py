"""Return and arrival declarations reject missing or changed source evidence."""
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from declaration_fixture import verify_hashed_declarations
from gof2_content import kappa_return as reader


class KappaReturnTests(unittest.TestCase):
    def test_proofs_and_relocation(self):
        verify_hashed_declarations(self, reader, reader.extract_kappa_return, 'conversations')

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        verify_android_proof(self, reader, lambda lib: reader.extract_kappa_return(lib, {'scope': 'rescue_choreography'}))
        from unittest.mock import patch
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertEqual(reader.extract_kappa_return(AndroidLibrary(image), {}), ({}, {}))
        # Android ends the second conversation with the tractor-beam vendor lines.
        self.assertEqual(reader.ANDROID_VALUES['conversations'][1]['events'][:12], reader.MAC_VALUES['conversations'][1]['events'][:12])
        self.assertEqual([e['text_id'] for e in reader.ANDROID_VALUES['conversations'][1]['events'][12:]], [3388, 3389])

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'kappa_return_definitions.gd')
