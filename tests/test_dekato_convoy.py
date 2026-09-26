"""Paired source guards and detached declarations, without original fixtures."""
import copy
import json
from pathlib import Path
import re
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import dekato_convoy as reader


class DekatoConvoyTests(unittest.TestCase):
    def test_guarded_editions_relocation_corruption_and_detachment(self):
        self.assertEqual(len(reader.LAYOUTS), 25)
        self.assertEqual(set(reader.MAC_ALTERNATE), set(reader.LAYOUTS))
        for name, expected, parent, foreign in (
                ('LAYOUTS', reader.VALUES, reader.RETURN, reader.MAC_RETURN),
                ('MAC_ALTERNATE', reader.MAC_VALUES, reader.MAC_RETURN, reader.RETURN)):
            for shift in (0, 0x800000):
                with self.subTest(layout=name, shift=shift):
                    mach, arrival, layouts = declaration_fixture(getattr(reader, name), shift)
                    with patch.object(reader, name, layouts):
                        value, proof = reader.extract_dekato_convoy(mach, arrival, parent)
                        self.assertEqual(value, expected)
                        self.assertEqual(set(proof), set(layouts))
                        value['objectives']['failure']['end_actor'] = 1
                        value['mission']['result_events'].clear()
                        self.assertEqual(reader.extract_dekato_convoy(mach, arrival, parent)[0], expected)
                        for invalid in (None, {}, foreign):
                            self.assertEqual(reader.extract_dekato_convoy(mach, arrival, invalid), ({}, {}))
                        for key, (delta, _, _, _) in layouts.items():
                            changed = copy.copy(mach)
                            raw = bytearray(mach.data)
                            raw[arrival['provenance']['actor']['offset'] - mach.slice_offset + delta] ^= 255
                            changed.data = bytes(raw)
                            self.assertEqual(reader.extract_dekato_convoy(changed, arrival, parent), ({}, {}), key)
                        missing = copy.copy(mach); missing.sections = []
                        self.assertEqual(reader.extract_dekato_convoy(missing, arrival, parent), ({}, {}))
                        self.assertEqual(reader.extract_dekato_convoy(mach, {}, parent), ({}, {}))
                    with patch.object(reader, 'LAYOUTS', layouts), patch.object(reader, 'MAC_ALTERNATE', layouts):
                        self.assertEqual(reader.extract_dekato_convoy(mach, arrival, parent), ({}, {}))

    def test_native_declarations_match_reader(self):
        text = (Path(__file__).resolve().parents[1] / 'game/src/content/dekato_convoy_definitions.gd').read_text()
        for name, value in (('VALUES', reader.VALUES), ('MAC_VALUES', reader.MAC_VALUES),
                            ('SPANS', {k: v[:2] for k, v in reader.LAYOUTS.items()}),
                            ('MAC_SPANS', {k: v[:2] for k, v in reader.MAC_ALTERNATE.items()})):
            match = re.search(r'^const ' + name + r'\s*:?=\s*(\{.*\})$', text, re.MULTILINE)
            self.assertIsNotNone(match, name)
            self.assertEqual(json.loads(match.group(1)), value)

    def test_convoy_loss_is_all_not_any_and_never_contest_scoring(self):
        for data in (reader.VALUES, reader.MAC_VALUES):
            rules = data['objectives']
            self.assertEqual(rules['success'], {'kind': 18, 'first_actor': 2, 'end_actor': 7, 'requires_all': True})
            self.assertEqual(rules['failure'], {'kind': 7, 'first_actor': 0, 'end_actor': 2, 'requires_all': True})
            self.assertFalse(rules['filters_actor_kind'])
            self.assertFalse(rules['requires_player_kill_majority'])
            self.assertEqual(rules['destroyed_mode'], 4)
            self.assertEqual(data['population']['path_points'], [[90000, 10000, 80000]])
            self.assertEqual(data['next_mission']['station_id'], 30)
            for key in ('completed', 'available', 'reward_credits', 'advance_on_final_next_to_cursor'):
                self.assertNotIn(key, data)


if __name__ == '__main__':
    unittest.main()
