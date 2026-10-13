"""Original planet/arrival declarations require every proof and detached values."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from declaration_fixture import verify_hashed_declarations
from gof2_content import local_arrival_environment as reader

class LocalArrivalEnvironmentTests(unittest.TestCase):
    def test_proofs_and_relocation(self):
        verify_hashed_declarations(self,reader,reader.extract_local_arrival_environment,'arrival')


class LocalArrivalEnvironmentAndroidTests(unittest.TestCase):
    def test_android_proofs(self):
        import android_fixture
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            android_fixture.verify_android_proof(self, reader, lambda lib: reader.extract_local_arrival_environment(lib, {'scope': 'rescue_choreography'}), values='VALUES')
            image, layout, _ = android_fixture.layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertEqual(reader.extract_local_arrival_environment(AndroidLibrary(image), {}), ({}, {}))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'local_arrival_environment_definitions.gd', values='VALUES')
