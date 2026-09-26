"""Contest result and shared-condition declarations; no original files required."""
import copy
import json
from pathlib import Path
import re
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import bakka_contest as reader


class BakkaContestTests(unittest.TestCase):
    def extract(self, mach, arrival, parent):
        return reader.extract_bakka_contest(mach, arrival, parent)

    def test_layout_relocation_corruption_and_detachment(self):
        for name, expected, parent in (
                ('LAYOUTS', reader.VALUES, reader.GAKKRR_APP),
                ('MAC_ALTERNATE', reader.MAC_VALUES, reader.GAKKRR_OLD)):
            for shift in (0, 0x800000):
                with self.subTest(layout=name, shift=shift):
                    mach, arrival, layouts = declaration_fixture(getattr(reader, name), shift)
                    with patch.object(reader, name, layouts):
                        value, proof = self.extract(mach, arrival, parent)
                        self.assertEqual(value, expected)
                        self.assertEqual(set(proof), set(layouts))
                        value['result_events'].clear()
                        value['objectives']['challenge_first_actor'] = 0
                        value['mission']['briefing_events'].clear()
                        value['population']['waypoints'][0][0] = 0
                        proof['bakka_result36_pairs']['offset'] += 1
                        self.assertEqual(self.extract(mach, arrival, parent)[0], expected)
                        for key, (delta, _, _, _) in layouts.items():
                            damaged = copy.copy(mach)
                            raw = bytearray(mach.data)
                            raw[arrival['provenance']['actor']['offset'] - mach.slice_offset + delta] ^= 255
                            damaged.data = bytes(raw)
                            self.assertEqual(self.extract(damaged, arrival, parent), ({}, {}), key)
                        missing = copy.copy(mach); missing.sections = []
                        self.assertEqual(self.extract(missing, arrival, parent), ({}, {}))
                        foreign = copy.copy(mach); foreign.architecture = 'armv7'
                        self.assertEqual(self.extract(foreign, arrival, parent), ({}, {}))
                        self.assertEqual(self.extract(mach, {}, parent), ({}, {}))

    def test_matching_prerequisites_and_unambiguous_source_required(self):
        for name, parent, other in (
                ('LAYOUTS', reader.GAKKRR_APP, reader.GAKKRR_OLD),
                ('MAC_ALTERNATE', reader.GAKKRR_OLD, reader.GAKKRR_APP)):
            mach, arrival, layouts = declaration_fixture(getattr(reader, name))
            with patch.object(reader, name, layouts):
                for invalid in (None, {}, other):
                    self.assertEqual(self.extract(mach, arrival, invalid), ({}, {}))
                changed = copy.deepcopy(parent); changed['next_mission']['station_id'] = 29
                self.assertEqual(self.extract(mach, arrival, changed), ({}, {}))
                self.assertIn('bakka_defeat_conditions', layouts)
                self.assertIn('bakka_population_gate', layouts)
            with patch.object(reader, 'LAYOUTS', layouts), patch.object(reader, 'MAC_ALTERNATE', layouts):
                self.assertEqual(self.extract(mach, arrival, parent), ({}, {}))

    def test_native_values_and_source_extents_match(self):
        text = (Path(__file__).resolve().parents[1] /
                'game/src/content/bakka_contest_definitions.gd').read_text()
        for name, expected in (
                ('VALUES', reader.VALUES), ('MAC_VALUES', reader.MAC_VALUES),
                ('SPANS', {key: row[:2] for key, row in reader.LAYOUTS.items()}),
                ('MAC_SPANS', {key: row[:2] for key, row in reader.MAC_ALTERNATE.items()})):
            found = re.search(r'^const ' + name + r'\s*:?=\s*(\{.*\})$', text, re.MULTILINE)
            self.assertIsNotNone(found, name)
            self.assertEqual(json.loads(found.group(1)), expected, name)

    def test_story_population_is_not_a_generated_lounge_offer(self):
        for data, name_id in ((reader.VALUES, 1593), (reader.MAC_VALUES, 1585)):
            population = data['population']
            self.assertEqual(population['actor_count'], 8)
            self.assertEqual(population['condition_first_actor'], 1)
            self.assertEqual(population['condition_end_actor'], 8)
            self.assertEqual(population['rival_actor_kind'], 1)
            self.assertEqual(population['rival_hull_catalogue_id'], 9)
            self.assertEqual(population['rival_name_text_id'], name_id)
            self.assertEqual(population['waypoints'], [[110000, -10000, -80000],
                [70000, 0, -100000], [-100000, 10000, -80000], [-130000, -50000, -150000]])
            self.assertFalse(population['rival_retains_cargo'])
            self.assertTrue(population['pirates_retain_cargo_and_routes'])
            self.assertNotIn('mission_difficulty', population)

    def test_shared_scoring_and_dialogue_do_not_authorize_progress(self):
        for data, parent, first in ((reader.VALUES, reader.GAKKRR_APP, 2007),
                                    (reader.MAC_VALUES, reader.GAKKRR_OLD, 1993)):
            self.assertEqual(data['mission'], parent['next_mission'])
            self.assertEqual(data['objectives'], reader.LIFECYCLE['objectives'])
            self.assertEqual(data['result_events'], [
                {'speaker_id': 7, 'text_id': first, 'voice_event_id': 389},
                {'speaker_id': 0, 'text_id': first + 1, 'voice_event_id': 390}])
            self.assertEqual(data['authored_radio_events'], [])
            for key in ('completion', 'next_mission', 'actor_count', 'reward_credits', 'available'):
                self.assertNotIn(key, data)
                self.assertNotIn(key, data['mission'])
            self.assertNotIn('result_events', parent['next_mission'])


if __name__ == '__main__':
    unittest.main()
