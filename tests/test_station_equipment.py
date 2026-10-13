"""Android station equipment proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import station_equipment as reader
from test_player_destruction import thumb


def immediate(operands):
    return int(operands.rsplit('#', 1)[1], 0)


class AndroidStationEquipmentTests(unittest.TestCase):
    def extract(self, lib, station_return={'scope': 'full_hold_station_return'}):
        return reader.extract_station_equipment(lib, {}, station_return)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, reader, self.extract, values='MAC_VALUES')
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            data = self.extract(lib)
            data['stock'][0]['quantity'] = 9
            self.assertEqual(reader.MAC_VALUES['stock'][0]['quantity'], 1)
            for name, station_return in {'other return': {'scope': 'first_mining_station_return'}, 'no return': {}, 'none': None}.items():
                self.assertEqual(self.extract(lib, station_return), {}, name)

    def test_android_stock(self):
        values = reader.MAC_VALUES
        gate = thumb(reader.ANDROID['tutorial_gate'][3])
        self.assertEqual([gate[2], gate[9], gate[10][0]], [('cmp', 'r0, #%#x' % values['station_id']), ('cmp', 'r0, #%d' % values['stock_maximum_cursor']), 'bgt'])
        items = thumb(reader.ANDROID['tutorial_items'][3])
        # Globals::items entries (4 bytes each) passed to Item::makeItem(1, 0).
        loads = [o for m, o in items if m in ('ldr', 'ldr.w') and o.startswith('r0, [r0') and o != 'r0, [r0, #4]']
        offsets = [0 if o == 'r0, [r0]' else immediate(o.rstrip(']')) for o in loads]
        self.assertEqual([offset // 4 for offset in offsets], [row['item_id'] for row in values['stock']])
        self.assertEqual(sum(1 for m, o in items if (m, o) == ('movs', 'r1, #1')), len(values['stock']) + 1)
        self.assertEqual({(row['quantity'], row['unit_price']) for row in values['stock']}, {(1, 0)})
        # Item::makeItem(amount, price): price at +0x18, amount at +0x34 (Item::init's layout).
        self.assertEqual(thumb(reader.ANDROID['stock_clone'][3])[5:7], [('str', 'r4, [r0, #0x18]'), ('str', 'r5, [r0, #0x34]')])

    def test_android_item_fields(self):
        values = reader.MAC_VALUES
        fields = thumb(reader.ANDROID['item_fields'][3])
        stores = {o.split('[r0')[1].strip(', ]#') or '0': fields[i - 1][1] for i, (m, o) in enumerate(fields) if m == 'str' and o.startswith('r2, [r0')}
        # Item::getType reads +4, Item::getSort +8.
        self.assertEqual(thumb(reader.ANDROID['category'][3])[0], ('ldr', 'r0, [r0, #4]'))
        self.assertEqual(thumb(reader.ANDROID['subtype'][3])[0], ('ldr', 'r0, [r0, #8]'))
        self.assertEqual(stores['4'], 'r2, [r1, #%#x]' % (4 * values['item_category_value_index']))
        self.assertEqual(stores['8'], 'r2, [r1, #%#x]' % (4 * values['item_subtype_value_index']))
        table = bytes.fromhex(reader.ANDROID['multiple_subtype_table'][3])
        self.assertEqual(sum(bit << sort for sort, bit in enumerate(table)), values['multiple_subtype_mask'])
        from gof2_content.text_ids import canonical_id
        name = thumb(reader.ANDROID['item_text'][3])[4]
        self.assertEqual(name[0], 'addw')
        self.assertEqual(canonical_id(immediate(name[1])), values['item_text_offset'])
        self.assertEqual((immediate(thumb(reader.ANDROID['mount_sound'][3])[0][1]), immediate(thumb(reader.ANDROID['unmount_sound'][3])[0][1])),
                         (values['mount_audio_id'], values['unmount_audio_id']))

    def test_android_completion(self):
        values = reader.MAC_VALUES
        dispatch = bytes.fromhex(reader.ANDROID['equipment_dispatch'][3])
        lines = thumb(reader.ANDROID['equipment_dispatch'][3][:36])
        self.assertEqual(lines[2:5], [('sub.w', 'r1, r0, #0x96'), ('cmp', 'r1, #0x27'), ('bhi', '#0x72')])
        # Status::missionCompleted: tbh at +14, case kind - 150 leads to the equipment loop.
        case = struct.unpack_from('<H', dispatch, 18 + 2 * (values['mission_kind'] - 150))[0]
        self.assertEqual(reader.ANDROID['equipment_dispatch'][1] + 18 + 2 * case, reader.ANDROID['equipment_check'][1])
        check = thumb(reader.ANDROID['equipment_check'][3])
        self.assertEqual(check[11:13], [('cbz', 'r0, #0x4a'), ('blx', '#0xfffb0f24')])
        self.assertEqual(check[13][0], 'cbz')  # category 0 marks the weapon
        self.assertEqual(values['weapon_category'], 0)
        self.assertEqual(check[18], ('cmp', 'r0, #%#x' % values['armor_subtype']))
        # Status::nextCampaignMission: case 5 makes the tutorial mission, case 6 (cursor 7) the next one.
        story = bytes.fromhex(reader.ANDROID['story_dispatch'][3])
        delta = reader.ANDROID['story_dispatch'][1]
        for cursor, key in [(values['campaign_cursor'], 'equipment_mission'), (values['cursor_after_acknowledgement'], 'next_mission')]:
            entry = struct.unpack_from('<H', story, 10 + 2 * (cursor - 1))[0]
            self.assertEqual(delta + 10 + 2 * entry, reader.ANDROID[key][1], key)
        self.assertEqual(thumb(reader.ANDROID['story_increment'][3]), [('mov', 'r0, r3'), ('adds', 'r3, r0, #1')])
        made = [immediate(o) for _, o in thumb(reader.ANDROID['equipment_mission_arguments'][3])[:3]]
        self.assertEqual(made, [values['mission_kind'], 0, values['station_id']])
        made = [immediate(o) for _, o in thumb(reader.ANDROID['next_mission_arguments'][3])[:3]]
        self.assertEqual(made, [values['next_mission_kind'], values['next_mission_parameter'], values['station_id']])

    def test_android_dialogue(self):
        from gof2_content.text_ids import canonical_id
        values = reader.MAC_VALUES
        labels = [canonical_id(immediate(thumb(reader.ANDROID[key][3])[0][1])) for key in ('next_label', 'final_label')]
        self.assertEqual(labels, [values['next_text_id'], values['final_text_id']])
        counts = struct.unpack('<7i', bytes.fromhex(reader.ANDROID['mode1_counts'][3]))
        cursor = values['campaign_cursor']
        self.assertEqual((counts[cursor], sum(counts[:cursor]) * 4), (2 * len(values['events']), reader.ANDROID['mode1_event'][5]))
        speaker, text = struct.unpack('<2i', bytes.fromhex(reader.ANDROID['mode1_event'][3]))
        voice_text, voice = struct.unpack('<2i', bytes.fromhex(reader.ANDROID['voice'][3]))
        self.assertEqual([(speaker, canonical_id(text), voice)], [(e['speaker_id'], e['text_id'], e['voice_event_id']) for e in values['events']])
        self.assertEqual(voice_text, text)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'station_equipment_definitions.gd', values='MAC_VALUES')
