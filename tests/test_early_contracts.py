"""Contract terms require their own verified, relocated Mac source extents."""
import copy
from contextlib import contextmanager
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import early_contracts as reader


class EarlyContractTests(unittest.TestCase):
    @contextmanager
    def fixture(self, shift=0):
        mach, arrival, layouts = declaration_fixture({**reader.LAYOUTS, **reader.ACCEPTANCE_LAYOUTS}, shift)
        base = {key: layouts[key] for key in reader.LAYOUTS}
        acceptance = {key: layouts[key] for key in reader.ACCEPTANCE_LAYOUTS}
        with patch.object(reader, 'LAYOUTS', base), patch.object(reader, 'ACCEPTANCE_LAYOUTS', acceptance):
            yield mach, arrival, layouts

    def extract(self, mach, arrival, travel=None):
        if travel is None:
            travel = {'scope': 'mido_local_travel', 'return_visit': {'next_cursor': 13, 'next_kind': 150}}
        return reader.extract_early_contracts(mach, arrival, travel)

    def test_relocation_and_detached_data(self):
        for shift in [0, 0x800000]:
            with self.fixture(shift) as (mach, arrival, layouts):
                result = self.extract(mach, arrival)
                self.assertEqual(result['kind_choices'], [11, 0, 7, 4, 12])
                self.assertEqual(result['courier']['quantity_by_difficulty'], [14, 24])
                self.assertEqual(result['passenger']['quantity_by_difficulty'], [3, 5])
                self.assertEqual(result['acceptance']['fee_difficulty'], 1.5)
                for key, span in result['provenance'].items():
                    self.assertEqual(span['offset'], arrival['provenance']['actor']['offset'] + layouts[key][0])
                result['kind_choices'][0] = 150
                result['reward']['base'] = 0
                result['acceptance']['initial_credits'] = 10000
                self.assertEqual(self.extract(mach, arrival)['reward']['base'], 1500)
                self.assertEqual(self.extract(mach, arrival)['kind_choices'][0], 11)
                self.assertEqual(self.extract(mach, arrival)['acceptance']['initial_credits'], 0)

    def test_each_changed_or_truncated_span_rejects_terms(self):
        with self.fixture() as (mach, arrival, layouts):
            for key, (delta, _, _, _) in layouts.items():
                changed = copy.copy(mach)
                data = bytearray(mach.data)
                data[arrival['provenance']['actor']['offset'] - mach.slice_offset + delta] ^= 255
                changed.data = bytes(data)
                result = self.extract(changed, arrival)
                if key in reader.LAYOUTS:
                    self.assertFalse(result, key)
                else:
                    self.assertNotIn('acceptance', result, key)
                    self.assertEqual(result['kind_choices'], reader.VALUES['kind_choices'])
                    self.assertEqual(set(result['provenance']), set(reader.LAYOUTS))
            changed = copy.deepcopy(mach)
            changed.sections[-1]['length'] -= 1
            self.assertNotIn('acceptance', self.extract(changed, arrival))

    def test_requires_mac_and_lounge_story_boundary(self):
        with self.fixture() as (mach, arrival, _):
            self.assertFalse(self.extract(mach, arrival, {}))
            self.assertFalse(self.extract(mach, arrival, {'scope': 'mido_local_travel'}))
            mach.architecture = 'armv7'
            self.assertFalse(self.extract(mach, arrival))


ARRIVAL = {'scope': 'rescue_choreography', 'provenance': {'actor': {'offset': 5, 'bytes': 24, 'anchor': 1}}}
TRAVEL = {'scope': 'mido_local_travel', 'return_visit': {'next_cursor': 13, 'next_kind': 150}}
GROUPS = ('ANDROID', 'ANDROID_ACCEPTANCE')


class EarlyContractAndroidTests(unittest.TestCase):
    def synthetic(self, shift=0):
        import android_fixture
        from test_mido_travel import roomy
        merged = {k: v for group in GROUPS for k, v in getattr(reader, group).items()}
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            image, patched, _ = android_fixture.layout_library(merged, shift)
        return image, {group: {k: patched[k] for k in getattr(reader, group)} for group in GROUPS}

    def test_android_proofs_and_relocation(self):
        from gof2_content.android_library import AndroidLibrary
        for shift in (0, 0x1000):
            image, layouts = self.synthetic(shift)
            with patch.multiple(reader, **layouts):
                result = reader.extract_early_contracts(AndroidLibrary(image), ARRIVAL, TRAVEL)
                proof = result.pop('provenance')
                self.assertEqual(result, {**reader.MAC_VALUES, 'acceptance': reader.MAC_ACCEPTANCE})
                merged = {k: v for layout in layouts.values() for k, v in layout.items()}
                self.assertEqual(set(proof), set(merged))
                for key, span in proof.items():
                    self.assertEqual(span['offset'] - span['anchor'], merged[key][5] if len(merged[key]) == 6 else merged[key][1], key)
                result['kind_choices'][0] = 150
                result['acceptance']['initial_credits'] = 10000
                self.assertEqual(reader.MAC_VALUES['kind_choices'][0], 11)
                self.assertEqual(reader.MAC_ACCEPTANCE['initial_credits'], 0)

    def test_every_proven_byte_gates_its_capability(self):
        from gof2_content.android_library import AndroidLibrary
        image, layouts = self.synthetic()
        with patch.multiple(reader, **layouts):
            proof = reader.extract_early_contracts(AndroidLibrary(image), ARRIVAL, TRAVEL)['provenance']
            for group in GROUPS:
                for key in layouts[group]:
                    span = proof[key]
                    for at in {span['offset'], span['offset'] + span['bytes'] - 1}:
                        raw = bytearray(image)
                        raw[at] ^= 0xff
                        broken = reader.extract_early_contracts(AndroidLibrary(bytes(raw)), ARRIVAL, TRAVEL)
                        if group == 'ANDROID':
                            self.assertEqual(broken, {}, (key, at))
                        else:
                            self.assertNotIn('acceptance', broken, key)
                            self.assertEqual(set(broken['provenance']), set(layouts['ANDROID']), key)

    def test_android_requires_its_parents(self):
        from gof2_content.android_library import AndroidLibrary
        image, layouts = self.synthetic()
        with patch.multiple(reader, **layouts):
            lib = AndroidLibrary(image)
            self.assertTrue(reader.extract_early_contracts(lib, ARRIVAL, TRAVEL))
            self.assertEqual(reader.extract_early_contracts(lib, {}, TRAVEL), {})
            self.assertEqual(reader.extract_early_contracts(lib, {'provenance': ARRIVAL['provenance']}, TRAVEL), {})
            self.assertEqual(reader.extract_early_contracts(lib, {'scope': 'rescue_choreography', 'provenance': {}}, TRAVEL), {})
            self.assertEqual(reader.extract_early_contracts(lib, ARRIVAL, {}), {})
            self.assertEqual(reader.extract_early_contracts(lib, ARRIVAL, {**TRAVEL, 'return_visit': {'next_cursor': 13, 'next_kind': 11}}), {})

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'early_contract_definitions.gd', values='MAC_VALUES')
        assert_native_android(self, reader, 'early_contract_definitions.gd', values='MAC_ACCEPTANCE', layout='ANDROID_ACCEPTANCE')


if __name__ == '__main__':
    unittest.main()
