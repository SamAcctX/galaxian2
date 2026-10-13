"""Android first mining cargo objective proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import mining_objective as reader

FLIGHT, PRESENTATION, BRIEFING = {'scope': 'first_mining_flight_construction'}, {'scope': 'first_station_presentation'}, {'scope': 'first_mining_briefing'}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidMiningObjectiveTests(unittest.TestCase):
    def extract(self, lib, flight=FLIGHT, presentation=PRESENTATION, briefing=BRIEFING, desktop={}):
        return reader.extract_mining_objective(lib, {}, flight, presentation, desktop, briefing)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, reader, self.extract)
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            data = self.extract(lib)
            data['events'][0]['text_id'] = 0
            data['key_tokens'].append('#KEY_DOCK')
            self.assertEqual((reader.ANDROID_VALUES['events'][0]['text_id'], reader.ANDROID_VALUES['key_tokens']), (1717, []))
            self.assertEqual(self.extract(lib, desktop={'scope': 'mac_desktop_text', 'pairs': [[1719, 1720]]}), self.extract(lib))
            for name, changes in {'other flight': dict(flight={'scope': 'x'}), 'no flight': dict(flight={}), 'none': dict(flight=None),
                                  'other presentation': dict(presentation={'scope': 'x'}), 'no presentation': dict(presentation={}),
                                  'other briefing': dict(briefing={'scope': 'x'}), 'no briefing': dict(briefing={})}.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_values(self):
        from gof2_content.text_ids import canonical_id
        values, rows = reader.ANDROID_VALUES, reader.ANDROID
        # Only the desktop pair and key tokens are gone: Android shows text 1719 itself.
        self.assertEqual({k for k in reader.MAC_VALUES if reader.MAC_VALUES[k] != values[k]}, {'desktop_instruction', 'key_tokens'})
        self.assertEqual((values['desktop_instruction'], values['key_tokens']), ([], []))
        counts = struct.unpack('<3i', bytes.fromhex(rows['mode1_counts'][3]))
        self.assertEqual((counts[2], sum(counts[:2]) * 4), (2 * len(values['events']), rows['mode1_events'][5]))
        pairs = struct.unpack('<6i', bytes.fromhex(rows['mode1_events'][3]))
        self.assertEqual([(pairs[i], canonical_id(pairs[i + 1])) for i in range(0, 6, 2)], [(e['speaker_id'], e['text_id']) for e in values['events']])
        voices = struct.unpack('<4i', bytes.fromhex(rows['voice_events'][3]))
        self.assertEqual([(canonical_id(voices[i]), voices[i + 1]) for i in range(0, 4, 2)], [(e['text_id'], e['voice_event_id']) for e in values['events'][:2]])
        # Cursor 2 (tbh entry 1) builds Mission(154, 0, 78) with status value 10; cursor 3 (entry 2) mission 11.
        entries = struct.unpack('<3H', bytes.fromhex(rows['dispatch_entries'][3]))
        self.assertEqual([68 + 2 * e for e in entries[1:]], [rows['mission_creation'][1], rows['return_mission'][1]])
        code = thumb(rows['mission_creation'][3])
        self.assertIn(('movs', 'r1, #0x%x' % values['mission_kind']), code)
        self.assertIn(('movs', 'r3, #0x%x' % values['station_id']), code)
        self.assertEqual(code[-2], ('movs', 'r1, #0x%x' % values['required_cargo']))
        # missionCompleted: kind 154 is case 4 of kinds 150..189 and compares the load with the status value.
        entry, = struct.unpack('<H', bytes.fromhex(rows['cargo_entry'][3]))
        self.assertEqual(((rows['cargo_entry'][1] - 208) // 2 + 150, 208 + 2 * entry), (values['mission_kind'], rows['cargo_check'][1]))
        self.assertEqual(thumb(rows['cargo_check'][3])[7:9], [('cmp', 'r5, r0'), ('blt.w', '#0x292')])

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'mining_objective_definitions.gd')
