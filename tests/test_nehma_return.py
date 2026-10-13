"""Néhma39 import guards, edition identity and native constant parity."""
import copy
import json
from pathlib import Path
import re
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import nehma_return as reader


class NehmaReturnTests(unittest.TestCase):
    def test_every_source_guard_and_relocation(self):
        for name, expected, previous in (('LAYOUTS', reader.VALUES, reader.PREVIOUS),
                                         ('MAC_ALTERNATE', reader.MAC_VALUES, reader.MAC_PREVIOUS)):
            for relocation in (0, 0x800000):
                mach, arrival, layouts = declaration_fixture(getattr(reader, name), relocation)
                with patch.object(reader, name, layouts):
                    values, proof = reader.extract_nehma_return(mach, arrival, previous)
                    self.assertEqual(values, expected)
                    self.assertEqual(set(proof), set(layouts))
                    values['mission']['result_events'].clear()
                    self.assertEqual(reader.extract_nehma_return(mach, arrival, previous)[0], expected)
                    for key, (delta, _, _, _) in layouts.items():
                        damaged = copy.copy(mach)
                        raw = bytearray(mach.data)
                        raw[arrival['provenance']['actor']['offset'] - mach.slice_offset + delta] ^= 255
                        damaged.data = bytes(raw)
                        self.assertEqual(reader.extract_nehma_return(damaged, arrival, previous), ({}, {}), key)
                    self.assertEqual(reader.extract_nehma_return(mach, {'provenance': {}}, previous), ({}, {}))
                    mach.architecture = 'armv7'
                    self.assertEqual(reader.extract_nehma_return(mach, arrival, previous), ({}, {}))

    def test_foreign_predecessor_and_ambiguous_variants_rejected(self):
        mach, arrival, layouts = declaration_fixture(reader.LAYOUTS)
        with patch.object(reader, 'LAYOUTS', layouts):
            self.assertEqual(reader.extract_nehma_return(mach, arrival, reader.MAC_PREVIOUS), ({}, {}))
            altered = copy.deepcopy(reader.PREVIOUS)
            altered['next_mission']['station_id'] = 22
            self.assertEqual(reader.extract_nehma_return(mach, arrival, altered), ({}, {}))
            with patch.object(reader, 'MAC_ALTERNATE', layouts):
                self.assertEqual(reader.extract_nehma_return(mach, arrival, reader.PREVIOUS), ({}, {}))

    def test_native_parity_and_exact_pending_successor(self):
        text = (Path(__file__).resolve().parents[1] / 'game/src/content/nehma_return_definitions.gd').read_text()
        for name, expected in (('VALUES', reader.VALUES), ('MAC_VALUES', reader.MAC_VALUES),
                               ('SPANS', {key: row[:2] for key, row in reader.LAYOUTS.items()}),
                               ('MAC_SPANS', {key: row[:2] for key, row in reader.MAC_ALTERNATE.items()})):
            values = re.findall(r'^const ' + name + r'\s*=\s*(.+)$', text, re.M)
            self.assertEqual(len(values), 1)
            self.assertEqual(json.loads(values[0]), expected)
        for data, start in ((reader.VALUES, 2021), (reader.MAC_VALUES, 2007)):
            self.assertEqual(data['mission']['briefing_events'], [])
            self.assertEqual([event['text_id'] for event in data['mission']['result_events']], list(range(start, start+10)))
            self.assertEqual([event['voice_event_id'] for event in data['mission']['result_events']], list(range(401, 411)))
            self.assertEqual(data['next_mission'], {'campaign_cursor': 40, 'kind': 161, 'station_id': -1,
                                                   'story': True, 'reward': 0, 'bonus': 0, 'source_parameter': 0})


if __name__ == '__main__':
    unittest.main()


class NehmaReturnAndroidTests(unittest.TestCase):
    def test_android_proofs(self):
        import android_fixture
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            android_fixture.verify_android_proof(self, reader, lambda lib: reader.extract_nehma_return(lib, {'scope': 'rescue_choreography'}, reader.PREVIOUS), values='VALUES')
            image, layout, _ = android_fixture.layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertEqual(reader.extract_nehma_return(AndroidLibrary(image), {}, reader.PREVIOUS), ({}, {}))
            arrival = {'scope': 'rescue_choreography'}
            self.assertTrue(reader.extract_nehma_return(AndroidLibrary(image), arrival, reader.PREVIOUS)[1])
            # The Android library continues only after its own preceding declaration.
            for parent in (reader.MAC_PREVIOUS, {}, None):
                self.assertEqual(reader.extract_nehma_return(AndroidLibrary(image), arrival, parent), ({}, {}))

    def test_android_native_declarations(self):
        # The game file writes `const NAME:=`, which assert_native_android's pattern does not read.
        source = (Path(__file__).resolve().parents[1] / 'game/src/content/nehma_return_definitions.gd').read_text()
        spans = {k: [v[5] if len(v) == 6 else v[1], v[2]] for k, v in reader.ANDROID.items()}
        for name, value in [('VALUES', reader.VALUES), ('ANDROID_SPANS', spans)]:
            found = re.findall(r'^const ' + name + r' ?:?= ?(.+)$', source, re.MULTILINE)
            self.assertEqual(len(found), 1, name)
            self.assertEqual(json.loads(found[0]), value, name)
