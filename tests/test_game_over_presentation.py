"""Android game-over presentation proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import game_over_presentation as reader
from test_player_destruction import thumb

DEATH = {'scope': 'mac_starter_player_destruction', 'game_over_image_id': None, 'continue_text_id': 188}


class AndroidGameOverTests(unittest.TestCase):
    def extract(self, lib, death=DEATH):
        return reader.extract_game_over_presentation(lib, {}, death)

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
            data['prompt_rgb'].clear()
            self.assertEqual(reader.ANDROID_VALUES['prompt_rgb'], [255, 255, 255])
            cases = {'other scope': dict(DEATH, scope='full_hold_pirate_destruction'), 'Mac image': dict(DEATH, game_over_image_id=1313),
                     'other prompt': dict(DEATH, continue_text_id=3393), 'no image key': {k: v for k, v in DEATH.items() if k != 'game_over_image_id'},
                     'empty': {}, 'none': None}
            for name, death in cases.items():
                self.assertEqual(self.extract(lib, death), {}, name)

    def test_android_values(self):
        image = {'image_id', 'texture_id', 'region', 'resource'}
        self.assertEqual({k for k in reader.VALUES if reader.VALUES[k] != reader.ANDROID_VALUES[k]}, image)
        self.assertEqual({reader.ANDROID_VALUES[k] for k in image}, {None})
        self.assertEqual(set(reader.ANDROID_VALUES), set(reader.VALUES))

    def test_android_constants(self):
        values = reader.ANDROID_VALUES
        # MGame::MGame: the image handle starts (and stays) at -1.
        self.assertEqual(thumb(reader.ANDROID['image_handle'][3]), [('mov.w', 'r1, #-1'), ('strd', 'r1, r0, [r4, #0x10]')])
        # PaintCanvas::GetImage2DHeight: 0 for a handle past the image count.
        height = thumb(reader.ANDROID['image_height'][3])
        self.assertEqual(height[1:4], [('cmp', 'r2, r1'), ('iteee', 'ls'), ('movls', 'r0, #0')])
        self.assertEqual(struct.unpack('<f', bytes.fromhex(reader.ANDROID['blink_constant'][3]))[0], values['blink_radians_per_millisecond'])
        self.assertEqual(struct.unpack('<2f', bytes.fromhex(reader.ANDROID['fade_constants'][3]))[1], 255.0)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'game_over_definitions.gd')
