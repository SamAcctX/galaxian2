"""Optional contact declarations require complete, source-specific proof."""
import copy
import json
from pathlib import Path
import re
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import persistent_contacts as reader


class PersistentContactTests(unittest.TestCase):
    def test_relocated_variants_are_detached_and_every_span_is_required(self):
        for name in ('LAYOUTS', 'MAC_ALTERNATE'):
            for relocation in (0, 0x800000):
                mach, arrival, layouts = declaration_fixture(getattr(reader, name), relocation)
                with patch.object(reader, name, layouts):
                    result = reader.extract_persistent_contacts(mach, arrival, reader.ORDINARY_VALUES)
                    self.assertEqual({k: v for k, v in result.items() if k != 'provenance'}, reader.VALUES)
                    self.assertEqual(set(result['provenance']), set(layouts))
                    result['supported_contact_ids'].clear()
                    result['provenance'].clear()
                    self.assertEqual(reader.extract_persistent_contacts(mach, arrival, reader.ORDINARY_VALUES)['supported_contact_ids'], [5])
                    for key, (delta, size, _, _) in layouts.items():
                        for endpoint in (0, size - 1):
                            damaged = copy.copy(mach)
                            raw = bytearray(mach.data)
                            raw[arrival['provenance']['actor']['offset'] - mach.slice_offset + delta + endpoint] ^= 255
                            damaged.data = bytes(raw)
                            self.assertEqual(reader.extract_persistent_contacts(damaged, arrival, reader.ORDINARY_VALUES), {}, (name, key, endpoint))
                    missing = copy.copy(mach);missing.sections = []
                    self.assertEqual(reader.extract_persistent_contacts(missing, arrival, reader.ORDINARY_VALUES), {})

    def test_unrelated_generation_missing_anchor_and_ambiguity_refuse(self):
        mach, arrival, layouts = declaration_fixture(reader.LAYOUTS)
        with patch.object(reader, 'LAYOUTS', layouts):
            for ordinary in ({}, {'scope': reader.ORDINARY_VALUES['scope']}):
                self.assertEqual(reader.extract_persistent_contacts(mach, arrival, ordinary), {})
            for invalid in ({}, {'provenance': {}}, {'provenance': {'actor': {'bytes': 314}}}):
                self.assertEqual(reader.extract_persistent_contacts(mach, invalid, reader.ORDINARY_VALUES), {})
            changed = copy.copy(mach);changed.architecture = 'armv7'
            self.assertEqual(reader.extract_persistent_contacts(changed, arrival, reader.ORDINARY_VALUES), {})
        with patch.object(reader, 'LAYOUTS', layouts), patch.object(reader, 'MAC_ALTERNATE', layouts):
            self.assertEqual(reader.extract_persistent_contacts(mach, arrival, reader.ORDINARY_VALUES), {})

    def test_native_declarations_match_and_keep_services_separate(self):
        native = (Path(__file__).resolve().parents[1] / 'game/src/content/persistent_contact_definitions.gd').read_text()
        for name, value in [('VALUES', reader.VALUES), ('SPANS', {k: v[:2] for k, v in reader.LAYOUTS.items()}),
                            ('MAC_SPANS', {k: v[:2] for k, v in reader.MAC_ALTERNATE.items()})]:
            found = re.findall(r'^const ' + name + r' = (.+)$', native, re.MULTILINE)
            self.assertEqual(len(found), 1, name)
            self.assertEqual(json.loads(found[0]), value, name)
        self.assertEqual(reader.VALUES['supported_contact_ids'], [5])
        self.assertEqual(reader.VALUES['fields']['blueprint'], 6)
        self.assertNotIn('purchase', reader.VALUES)
        self.assertNotIn('reward', reader.VALUES)
        self.assertTrue(reader.VALUES['hostile_replacement_requires_generated'])


if __name__ == '__main__':
    unittest.main()


class PersistentContactsAndroidTests(unittest.TestCase):
    ARRIVAL = {'scope': 'rescue_choreography', 'provenance': {'actor': {'offset': 5, 'bytes': 24, 'anchor': 1}}}

    def test_android_proofs(self):
        import android_fixture
        from unittest.mock import patch
        from gof2_content import persistent_contacts as reader
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        ordinary = reader.ORDINARY_VALUES
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            android_fixture.verify_android_proof(self, reader, lambda lib: reader.extract_persistent_contacts(lib, self.ARRIVAL, ordinary), values='ANDROID_VALUES')
            image, layout, _ = android_fixture.layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            self.assertTrue(reader.extract_persistent_contacts(lib, self.ARRIVAL, ordinary))
            self.assertEqual(reader.extract_persistent_contacts(lib, {}, ordinary), {})
            self.assertEqual(reader.extract_persistent_contacts(lib, self.ARRIVAL, {}), {})

    def test_android_native_declarations(self):
        from gof2_content import persistent_contacts as reader
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'persistent_contact_definitions.gd', values='ANDROID_VALUES')

    def test_android_vendor_is_the_only_difference(self):
        from gof2_content import persistent_contacts as reader
        android = dict(reader.ANDROID_VALUES)
        self.assertEqual(android.pop('tractor_vendor'), {'creation_cursor': 23, 'station_id': 10, 'faction': 0, 'male': True, 'role': 2,
                                                         'item_id': 68, 'quantity': 1, 'total_price': 100000, 'dialogue_cursor': 24,
                                                         'text_ids': [3390, 3391], 'separator': '\n', 'departure_cursor': 24})
        self.assertEqual(android, reader.VALUES)
