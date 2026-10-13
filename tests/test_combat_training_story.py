"""Android combat-training story proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import json
import re
import struct
import unittest
from pathlib import Path
from gof2_content import combat_training_story as reader
from gof2_content.text_ids import canonical_id

PARENTS = dict(training={'scope': 'combat_training_encounter_construction'}, destruction={'scope': 'combat_training_cargo_destruction'},
               briefing={'scope': 'first_mining_briefing'}, objective={'scope': 'first_mining_cargo_objective'},
               dialogue={'campaign_cursor': 0, 'timing': reader.VALUES['radio_timing']}, shared_story={'scope': 'full_hold_mining_story'})


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


def events(hex_code):
    words = struct.unpack('<%di' % (len(hex_code) // 8), bytes.fromhex(hex_code))
    return [(words[i], canonical_id(words[i + 1])) for i in range(0, len(words), 2)]


class AndroidCombatTrainingStoryTests(unittest.TestCase):
    def extract(self, lib, **changes):
        return reader.extract_combat_training_story(lib, {}, **dict(PARENTS, **changes))

    def test_android_proofs(self):
        from unittest.mock import patch
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, reader, self.extract)
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            data = self.extract(lib)
            data['station_return']['events'].clear()
            data['navigation']['progress_notice']['text_ids'].append(1)
            self.assertEqual(len(reader.ANDROID_VALUES['station_return']['events']), 9)
            self.assertEqual(reader.ANDROID_VALUES['navigation']['progress_notice']['text_ids'], [532])
            cases = {'other training': dict(training={'scope': 'x'}), 'no training': dict(training={}), 'none': dict(training=None),
                     'other destruction': dict(destruction={'scope': 'x'}), 'no destruction': dict(destruction=None),
                     'other briefing': dict(briefing={'scope': 'x'}), 'no briefing': dict(briefing={}),
                     'other objective': dict(objective={'scope': 'x'}), 'no objective': dict(objective=None),
                     'other cursor': dict(dialogue=dict(PARENTS['dialogue'], campaign_cursor=1)),
                     'other timing': dict(dialogue=dict(PARENTS['dialogue'], timing={})), 'no dialogue': dict(dialogue={}),
                     'other story': dict(shared_story={'scope': 'x'}), 'no story': dict(shared_story=None)}
            for name, changes in cases.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_dialogue_tables(self):
        rows, values = reader.ANDROID, reader.ANDROID_VALUES
        briefing_counts = struct.unpack('<8i', bytes.fromhex(rows['mode0_counts'][3]))
        success_counts = struct.unpack('<9i', bytes.fromhex(rows['mode1_counts'][3]))
        # Events start at the sum of the earlier cursors' word counts.
        self.assertEqual((sum(briefing_counts[:7]), briefing_counts[7]), (rows['mode0_events'][5] // 4, rows['mode0_events'][2] // 4))
        self.assertEqual((sum(success_counts[:7]), success_counts[7]), (rows['mode1_events'][5] // 4, rows['mode1_events'][2] // 4))
        self.assertEqual((sum(success_counts[:8]), success_counts[8]), (rows['station_return_events'][5] // 4, rows['station_return_events'][2] // 4))
        def pairs(rows):
            return [(row['speaker_id'], row['text_id']) for row in rows]
        self.assertEqual(events(rows['mode0_events'][3]), pairs(values['briefing_events']))
        self.assertEqual(events(rows['mode1_events'][3]), pairs(values['completion_events']))
        self.assertEqual(events(rows['station_return_events'][3]), pairs(values['station_return']['events']))
        text, voice = struct.unpack('<2i', bytes.fromhex(rows['briefing_voice'][3]))
        self.assertEqual((canonical_id(text), voice), (values['briefing_events'][0]['text_id'], values['briefing_events'][0]['voice_event_id']))
        # Globals::replaceKeyBindingTokens(this, text) returns String(text, false): no key token is replaced.
        self.assertEqual(thumb(rows['key_tokens'][3])[2:4], [('mov', 'r1, r2'), ('movs', 'r2, #0')])

    def test_android_radio_and_next_missions(self):
        rows, values = reader.ANDROID, reader.ANDROID_VALUES
        code = thumb(rows['radio_declaration'][3])
        texts = [int(op.split('#')[1], 0) for m, op in code if m == 'movw' and op.startswith('r1,')]
        self.assertEqual([canonical_id(t) for t in texts], [row['text_id'] for row in values['radio_events']])
        speakers = [int(op.split('#')[1], 0) for m, op in code if m == 'movs' and op.startswith('r2,')]
        conditions = [int(op.split('#')[1], 0) for m, op in code if m == 'movs' and op.startswith('r3,')]
        self.assertEqual(speakers, [row['speaker_id'] for row in values['radio_events']])
        self.assertEqual(conditions, [row['condition'] for row in values['radio_events']])
        self.assertIn(('movs', 'r0, #2'), code)
        # tbh entry 7 of createRadioMessages and entries 7 / 8 of nextCampaignMission.
        dispatch = bytes.fromhex(rows['radio_dispatch'][3])
        self.assertEqual(rows['radio_dispatch'][1] + 10 + 2 * struct.unpack_from('<H', dispatch, 10 + 2 * 7)[0], rows['radio_declaration'][1])
        table = bytes.fromhex(rows['next_dispatch'][3])
        start = rows['next_dispatch'][1] + 10
        self.assertEqual(start + 2 * struct.unpack_from('<H', table, 10 + 2 * 7)[0], rows['next_mission_and_equipment'][1])
        self.assertEqual(start + 2 * struct.unpack_from('<H', table, 10 + 2 * 8)[0], rows['station_next_factory'][1])
        factory = thumb(rows['station_next_factory'][3])
        self.assertIn(('movs', 'r1, #0x%x' % values['station_return']['next_mission_kind']), factory)
        self.assertIn(('movs', 'r3, #0x%x' % values['station_return']['station_id']), factory)
        self.assertEqual(thumb(rows['price_getter'][3])[0], ('ldr', 'r0, [r0, #0x18]'))
        self.assertEqual(thumb(rows['price_setter'][3])[0], ('str', 'r1, [r0, #0x18]'))
        # The notice of event 23 is text 543 (Mac 532).
        notice = thumb(rows['navigation_notice'][3])
        self.assertIn(('movw', 'r1, #0x%x' % (values['navigation']['progress_notice']['text_ids'][0] + 11)), notice)

    def test_android_native_declarations(self):
        source = (Path(__file__).resolve().parents[1] / 'game/src/content/combat_training_story_definitions.gd').read_text()
        def const(name):
            found = re.findall(r'^const ' + name + r' :?= (.+)$', source, re.MULTILINE)
            self.assertEqual(len(found), 1, name)
            return json.loads(found[0])
        spans = {k: [v[5] if len(v) == 6 else v[1], v[2]] for k, v in reader.ANDROID.items()}
        self.assertEqual(const('ANDROID_SPANS'), spans)
        values = reader.ANDROID_VALUES
        self.assertEqual(const('MAC_VALUES'), {k: v for k, v in values.items() if k not in ('station_return', 'navigation')})
        self.assertEqual(const('MAC_RETURN_VALUES'), values['station_return'])
        self.assertEqual(const('NAVIGATION_VALUES'), values['navigation'])
