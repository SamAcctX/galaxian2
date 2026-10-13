"""Every ordinary contact/offer source declaration is required and detached."""
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from declaration_fixture import verify_hashed_declarations
from gof2_content import ordinary_generation as reader

class OrdinaryGenerationTests(unittest.TestCase):
    def test_proofs_and_relocation(self):
        verify_hashed_declarations(self, reader, reader.extract_ordinary_generation, 'offers')


class OrdinaryGenerationAndroidTests(unittest.TestCase):
    def test_android_proofs(self):
        from gof2_content import ordinary_generation as reader
        import android_fixture
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        arrival = {'scope': 'rescue_choreography', 'provenance': {'actor': {'offset': 5, 'bytes': 24, 'anchor': 1}}}
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            android_fixture.verify_android_proof(self, reader, lambda lib: reader.extract_ordinary_generation(lib, arrival), layout='ANDROID', values='VALUES')
            image, layout, _ = android_fixture.layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertFalse(reader.extract_ordinary_generation(AndroidLibrary(image), {})[0])

    def test_android_native_declarations(self):
        from gof2_content import ordinary_generation as reader
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'ordinary_generation_definitions.gd', values='VALUES', layout='ANDROID')
