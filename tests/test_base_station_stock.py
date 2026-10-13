"""Ordinary station stock is optional and requires its complete static proof."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import base_station_stock as reader


class BaseStationStockTests(unittest.TestCase):
    def test_relocation_and_source_mutations(self):
        for shift in (0,0x800000):
            mach,arrival,layouts=declaration_fixture(reader.LAYOUTS,shift)
            with patch.object(reader,'LAYOUTS',layouts):
                values,proof=reader.extract_base_station_stock(mach,arrival)
                self.assertEqual(values,reader.VALUES)
                self.assertEqual(set(proof),set(layouts))
                for name,(delta,_,_,_) in layouts.items():
                    changed=copy.copy(mach)
                    raw=bytearray(mach.data)
                    raw[arrival['provenance']['actor']['offset']-mach.slice_offset+delta]^=255
                    changed.data=bytes(raw)
                    self.assertEqual(reader.extract_base_station_stock(changed,arrival),({},{}),name)
                values['ships']['affiliations'][0]=-1
                self.assertEqual(reader.extract_base_station_stock(mach,arrival)[0],reader.VALUES)

    def test_other_architecture_remains_unavailable(self):
        mach,arrival,_=declaration_fixture(reader.LAYOUTS)
        mach.architecture='armv7'
        self.assertEqual(reader.extract_base_station_stock(mach,arrival),({},{}))


class BaseStationStockAndroidTests(unittest.TestCase):
    def test_android_proofs(self):
        from gof2_content import base_station_stock as reader
        import android_fixture
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        arrival = {'scope': 'rescue_choreography', 'provenance': {'actor': {'offset': 5, 'bytes': 24, 'anchor': 1}}}
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            android_fixture.verify_android_proof(self, reader, lambda lib: reader.extract_base_station_stock(lib, arrival), layout='ANDROID', values='ANDROID_VALUES')
            image, layout, _ = android_fixture.layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertFalse(reader.extract_base_station_stock(AndroidLibrary(image), {})[0])

    def test_android_native_declarations(self):
        from gof2_content import base_station_stock as reader
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'base_station_stock_definitions.gd', values='ANDROID_VALUES', layout='ANDROID')


class BaseStationStockAndroidValueTests(unittest.TestCase):
    def test_android_values_lack_only_the_temporary_item(self):
        import copy
        from gof2_content import base_station_stock as reader
        values = copy.deepcopy(reader.ANDROID_VALUES)
        # Generator::getItemBuyList holds no cursor-17-24 roll for item 68.
        self.assertEqual(values.pop('temporary_item'), {})
        self.assertEqual(reader.MAC_VALUES['temporary_item']['item_id'], 68)
        expected = copy.deepcopy(reader.MAC_VALUES)
        del expected['temporary_item']
        self.assertEqual(values, expected)
