"""Verify ordinary ship setup declarations require every original source proof."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import free_lifecycle as reader

class FreeLifecycleTests(unittest.TestCase):
    def test_proofs_and_relocation(self):
        for relocation in (0,0x800000):
            mach,arrival,layouts=declaration_fixture(reader.LAYOUTS,relocation)
            with patch.object(reader,'LAYOUTS',layouts):
                values,proof=reader.extract_free_lifecycle(mach,arrival)
                self.assertEqual(values,reader.VALUES)
                self.assertEqual(set(proof),set(layouts))
                values['standing']['axes'].clear()
                self.assertEqual(reader.extract_free_lifecycle(mach,arrival)[0],reader.VALUES)
                for name,(delta,_,_,_) in layouts.items():
                    changed=copy.copy(mach);raw=bytearray(mach.data)
                    raw[arrival['provenance']['actor']['offset']-mach.slice_offset+delta]^=255
                    changed.data=bytes(raw)
                    self.assertEqual(reader.extract_free_lifecycle(changed,arrival),({},{}),name)
                mach.architecture='armv7'
                self.assertEqual(reader.extract_free_lifecycle(mach,arrival),({},{}))


class FreeLifecycleAndroidTests(unittest.TestCase):
    def test_android_proofs(self):
        import android_fixture
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            android_fixture.verify_android_proof(self, reader, lambda lib: reader.extract_free_lifecycle(lib, {'scope': 'rescue_choreography'}), values='VALUES')
            image, layout, _ = android_fixture.layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertEqual(reader.extract_free_lifecycle(AndroidLibrary(image), {}), ({}, {}))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'free_lifecycle_definitions.gd', values='VALUES')
