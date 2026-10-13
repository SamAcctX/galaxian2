"""Source mutations must not enable an unverified contract combat capability."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import contract_flight_results as reader


class ContractFlightResultsTests(unittest.TestCase):
    def test_relocation_preserves_detached_declarations(self):
        for shift in (0, 0x800000):
            mach, arrival, layouts = declaration_fixture(reader.LAYOUTS, shift)
            with patch.object(reader, 'LAYOUTS', layouts):
                values, proof = reader.extract_contract_flight_results(mach, arrival)
                self.assertEqual(values, reader.VALUES)
                self.assertEqual(set(proof), set(layouts))
                for key, span in layouts.items():
                    self.assertEqual(proof[key]['offset'], arrival['provenance']['actor']['offset']+span[0])
                values['ship_kinds'].clear()
                self.assertEqual(reader.extract_contract_flight_results(mach, arrival)[0]['ship_kinds'], [4, 12])

    def test_each_source_mutation_disables_flight_results(self):
        mach, arrival, layouts = declaration_fixture(reader.LAYOUTS)
        with patch.object(reader, 'LAYOUTS', layouts):
            for name, (delta, _, _, _) in layouts.items():
                changed = copy.copy(mach)
                raw = bytearray(mach.data)
                raw[arrival['provenance']['actor']['offset']-mach.slice_offset+delta] ^= 255
                changed.data = bytes(raw)
                self.assertEqual(reader.extract_contract_flight_results(changed, arrival), ({}, {}), name)

    def test_other_architecture_stays_unsupported(self):
        mach, arrival, _ = declaration_fixture(reader.LAYOUTS)
        mach.architecture = 'armv7'
        self.assertEqual(reader.extract_contract_flight_results(mach, arrival), ({}, {}))


class ContractFlightResultsAndroidTests(unittest.TestCase):
    def test_android_proofs(self):
        from gof2_content import contract_flight_results as reader
        import android_fixture
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        arrival = {'scope': 'rescue_choreography', 'provenance': {'actor': {'offset': 5, 'bytes': 24, 'anchor': 1}}}
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            android_fixture.verify_android_proof(self, reader, lambda lib: reader.extract_contract_flight_results(lib, arrival), layout='ANDROID', values='VALUES')
            image, layout, _ = android_fixture.layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertFalse(reader.extract_contract_flight_results(AndroidLibrary(image), {})[0])

    def test_android_native_declarations(self):
        from gof2_content import contract_flight_results as reader
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'contract_flight_result_definitions.gd', values='VALUES', layout='ANDROID')
