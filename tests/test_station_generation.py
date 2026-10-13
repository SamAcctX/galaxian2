"""Stock and hidden contact support requires every bounded source declaration."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import station_generation as reader


class StationGenerationTests(unittest.TestCase):
    def test_relocation_and_source_mutations(self):
        for shift in (0,0x800000):
            mach,arrival,layouts=declaration_fixture(reader.LAYOUTS,shift)
            with patch.object(reader,'LAYOUTS',layouts):
                values,proof=reader.extract_station_generation(mach,arrival)
                self.assertEqual(values,reader.VALUES)
                self.assertEqual(set(proof),set(layouts))
                for name,(delta,_,_,_) in layouts.items():
                    changed=copy.copy(mach)
                    raw=bytearray(mach.data)
                    raw[arrival['provenance']['actor']['offset']-mach.slice_offset+delta]^=255
                    changed.data=bytes(raw)
                    self.assertEqual(reader.extract_station_generation(changed,arrival),({},{}),name)
                values['initial_history'][0]=True
                self.assertEqual(reader.extract_station_generation(mach,arrival)[0],reader.VALUES)

    def test_other_architecture_remains_unavailable(self):
        mach,arrival,_=declaration_fixture(reader.LAYOUTS)
        mach.architecture='armv7'
        self.assertEqual(reader.extract_station_generation(mach,arrival),({},{}))


class StationGenerationAndroidTests(unittest.TestCase):
    def test_android_proofs(self):
        from gof2_content import station_generation as reader
        import android_fixture
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        arrival = {'scope': 'rescue_choreography', 'provenance': {'actor': {'offset': 5, 'bytes': 24, 'anchor': 1}}}
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            android_fixture.verify_android_proof(self, reader, lambda lib: reader.extract_station_generation(lib, arrival), layout='ANDROID', values='ANDROID_VALUES')
            image, layout, _ = android_fixture.layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertFalse(reader.extract_station_generation(AndroidLibrary(image), {})[0])

    def test_android_native_declarations(self):
        from gof2_content import station_generation as reader
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'station_generation_definitions.gd', values='ANDROID_VALUES', layout='ANDROID')


class StationGenerationAndroidValueTests(unittest.TestCase):
    def test_android_values_differ_only_in_the_stock_progress(self):
        from gof2_content import station_generation as reader
        values = copy.deepcopy(reader.ANDROID_VALUES)
        # Generator::getItemBuyList: (cursor + 25) / 45 (`adds r0, #0x19`); the Mac adds 10.
        self.assertEqual(values['availability'].pop('progress_add'), 25)
        self.assertEqual(reader.VALUES['availability']['progress_add'], 10)
        expected = copy.deepcopy(reader.VALUES)
        del expected['availability']['progress_add']
        self.assertEqual(values, expected)
