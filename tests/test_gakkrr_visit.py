"""Source-bounded Ga'kkrr declarations; no original executable is required."""
import copy
import json
from pathlib import Path
import re
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import gakkrr_visit as reader


class GakkrrVisitTests(unittest.TestCase):
    def test_both_layouts_relocate_and_reject_every_corrupted_guard(self):
        for index, (name, expected, parent) in enumerate((
                ('LAYOUTS', reader.VALUES, reader.NEHMA_APP),
                ('MAC_ALTERNATE', reader.MAC_VALUES, reader.NEHMA_OLD))):
            for shift in (0, 0x800000):
                with self.subTest(edition=index, relocation=shift):
                    mach, arrival, layouts = declaration_fixture(getattr(reader, name), shift)
                    with patch.object(reader, name, layouts):
                        value, proof = reader.extract_gakkrr_visit(mach, arrival, parent)
                        self.assertEqual(value, expected)
                        self.assertEqual(set(proof), set(layouts))
                        value['mission35']['result_events'].clear()
                        proof['gakkrr_factory36']['offset'] += 1
                        self.assertEqual(reader.extract_gakkrr_visit(mach, arrival, parent)[0], expected)
                        for key, (delta, _, _, _) in layouts.items():
                            changed = copy.copy(mach)
                            raw = bytearray(mach.data)
                            raw[arrival['provenance']['actor']['offset'] - mach.slice_offset + delta] ^= 255
                            changed.data = bytes(raw)
                            self.assertEqual(reader.extract_gakkrr_visit(changed, arrival, parent), ({}, {}), key)
                        self.assertEqual(reader.extract_gakkrr_visit(mach, {}, parent), ({}, {}))
                        missing = copy.copy(mach); missing.sections = []
                        self.assertEqual(reader.extract_gakkrr_visit(missing, arrival, parent), ({}, {}))
                        foreign = copy.copy(mach); foreign.architecture = 'armv7'
                        self.assertEqual(reader.extract_gakkrr_visit(foreign, arrival, parent), ({}, {}))

    def test_prerequisite_identity_and_ambiguous_source_fail_closed(self):
        for name, parent, other in (('LAYOUTS', reader.NEHMA_APP, reader.NEHMA_OLD),
                                    ('MAC_ALTERNATE', reader.NEHMA_OLD, reader.NEHMA_APP)):
            mach, arrival, layouts = declaration_fixture(getattr(reader, name))
            with patch.object(reader, name, layouts):
                for wrong in (None, {}, other):
                    self.assertEqual(reader.extract_gakkrr_visit(mach, arrival, wrong), ({}, {}))
                changed = copy.deepcopy(parent); changed['next_mission']['station_id'] = 30
                self.assertEqual(reader.extract_gakkrr_visit(mach, arrival, changed), ({}, {}))
            with patch.object(reader, 'LAYOUTS', layouts), patch.object(reader, 'MAC_ALTERNATE', layouts):
                self.assertEqual(reader.extract_gakkrr_visit(mach, arrival, parent), ({}, {}))

    def test_native_values_and_extents_match_the_reader(self):
        text = (Path(__file__).resolve().parents[1] /
                'game/src/content/gakkrr_visit_definitions.gd').read_text()
        for name, expected in (
                ('VALUES', reader.VALUES), ('MAC_VALUES', reader.MAC_VALUES),
                ('SPANS', {k: v[:2] for k, v in reader.LAYOUTS.items()}),
                ('MAC_SPANS', {k: v[:2] for k, v in reader.MAC_ALTERNATE.items()})):
            match = re.search(r'^const ' + name + r'\s*:?=\s*(\{.*\})$', text, re.MULTILINE)
            self.assertIsNotNone(match, name)
            self.assertEqual(json.loads(match.group(1)), expected, name)

    def test_modal_order_and_next_contest_are_not_rewards(self):
        for values, first in ((reader.VALUES, 1995), (reader.MAC_VALUES, 1981)):
            mission = values['mission35']; result = mission['result_events']
            self.assertEqual([e['speaker_id'] for e in result], [7, 0] * 5)
            self.assertEqual([e['text_id'] for e in result], list(range(first, first + 10)))
            self.assertEqual([e['voice_event_id'] for e in result], list(range(379, 389)))
            self.assertEqual(mission['briefing_events'], [])
            end = mission['completion']
            self.assertTrue(end['requires_landed_target'])
            self.assertTrue(end['final_next_requires_all_modal_acknowledgements'])
            self.assertEqual((end['result_mode'], end['intermediate_next_keeps_cursor'],
                              end['final_next_advances_to_cursor'], end['stays_landed_station_id']), (1, 35, 36, 29))
            self.assertEqual(end['reward_credits'], 0)
            for key in ('cargo_or_equipment_change', 'ship_change',
                        'extra_blueprint_change', 'extra_system_access_granted'):
                self.assertFalse(end[key], key)
            next_mission = values['next_mission']
            self.assertEqual((next_mission['campaign_cursor'], next_mission['kind'],
                              next_mission['station_id'], next_mission['system_id']), (36, 12, 27, 5))
            self.assertEqual([e['text_id'] for e in next_mission['briefing_events']], [first + 10, first + 11])
            self.assertEqual([e['voice_event_id'] for e in next_mission['briefing_events']], [182, 183])
            self.assertNotIn('completion', next_mission)
            self.assertNotIn('result_events', next_mission)


if __name__ == '__main__':
    unittest.main()
