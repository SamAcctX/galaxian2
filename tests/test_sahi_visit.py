"""Sahi arrival declarations retain complete, source-specific evidence."""
import copy
import json
from pathlib import Path
import re
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import sahi_visit as reader


class SahiVisitTests(unittest.TestCase):
    def test_complete_source_variants_relocation_and_corruption(self):
        for name, expected in [('LAYOUTS', reader.VALUES), ('MAC_ALTERNATE', reader.MAC_VALUES)]:
            for relocation in (0, 0x800000):
                with self.subTest(source=name, relocation=relocation):
                    mach, arrival, layouts = declaration_fixture(getattr(reader, name), relocation)
                    with patch.object(reader, name, layouts):
                        values, proof = reader.extract_sahi_visit(mach, arrival)
                        self.assertEqual(values, expected)
                        self.assertEqual(set(proof), set(layouts))
                        values['briefing']['events'].clear()
                        self.assertEqual(reader.extract_sahi_visit(mach, arrival)[0], expected)
                        for key, (delta, _, _, _) in layouts.items():
                            changed = copy.copy(mach)
                            raw = bytearray(mach.data)
                            raw[arrival['provenance']['actor']['offset'] - mach.slice_offset + delta] ^= 255
                            changed.data = bytes(raw)
                            self.assertEqual(reader.extract_sahi_visit(changed, arrival), ({}, {}), key)
                        for invalid in [{}, {'provenance': {}}, {'provenance': {'actor': {'bytes': 314}}}]:
                            self.assertEqual(reader.extract_sahi_visit(mach, invalid), ({}, {}))
                        missing = copy.copy(mach)
                        missing.sections = []
                        self.assertEqual(reader.extract_sahi_visit(missing, arrival), ({}, {}))
                        mach.architecture = 'armv7'
                        self.assertEqual(reader.extract_sahi_visit(mach, arrival), ({}, {}))

    def test_ambiguous_source_variant_is_rejected(self):
        mach, arrival, layouts = declaration_fixture(reader.LAYOUTS)
        with patch.object(reader, 'LAYOUTS', layouts), patch.object(reader, 'MAC_ALTERNATE', layouts):
            self.assertEqual(reader.extract_sahi_visit(mach, arrival), ({}, {}))

    def test_native_declarations_keep_matching_source_values_and_extents(self):
        source = (Path(__file__).resolve().parents[1] / 'game/src/content/sahi_visit_definitions.gd').read_text()
        for name, value in [('VALUES', reader.VALUES), ('MAC_VALUES', reader.MAC_VALUES),
                            ('SPANS', {k: v[:2] for k, v in reader.LAYOUTS.items()}),
                            ('MAC_SPANS', {k: v[:2] for k, v in reader.MAC_ALTERNATE.items()})]:
            found = re.findall(r'^const ' + name + r' = (.+)$', source, re.MULTILINE)
            self.assertEqual(len(found), 1, name)
            self.assertEqual(json.loads(found[0]), value, name)


if __name__ == '__main__':
    unittest.main()


class SahiVisitAndroidTests(unittest.TestCase):
    def test_android_proofs(self):
        import android_fixture
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            android_fixture.verify_android_proof(self, reader, lambda lib: reader.extract_sahi_visit(lib, {'scope': 'rescue_choreography'}), values='MAC_VALUES')
            image, layout, _ = android_fixture.layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertEqual(reader.extract_sahi_visit(AndroidLibrary(image), {}), ({}, {}))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'sahi_visit_definitions.gd', values='MAC_VALUES')
