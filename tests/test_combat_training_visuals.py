"""Android combat-training weapon visual proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import combat_training_visuals as reader

WEAPONS = {'scope': 'combat_training_ordinary_weapons'}
STAGING = {'projectile_visuals': {'x': 1}, 'projectile_impacts': {'x': 1}}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidCombatTrainingVisualTests(unittest.TestCase):
    def extract(self, lib, weapons=WEAPONS, staging=STAGING):
        return reader.extract_combat_training_visuals(lib, {}, weapons, staging)

    def test_android_proofs(self):
        from unittest.mock import patch
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, reader, self.extract, values='VALUES')
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            data = self.extract(lib)
            data['weapons'][0]['capacity'] = 1
            self.assertEqual(reader.VALUES['weapons'][0]['capacity'], 20)
            cases = {'other weapons': dict(weapons={'scope': 'combat_training_live_control'}), 'no weapons': dict(weapons={}),
                     'none': dict(weapons=None), 'no visuals': dict(staging=dict(STAGING, projectile_visuals={})),
                     'no impacts': dict(staging={'projectile_visuals': {'x': 1}}), 'bad staging': dict(staging=None)}
            for name, changes in cases.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_tables(self):
        rows = reader.ANDROID
        impacts = struct.unpack('<26i', bytes.fromhex(rows['impact_models'][3]))
        projectiles = struct.unpack('<23i', bytes.fromhex(rows['projectile_models'][3]))
        for row in reader.VALUES['weapons']:
            self.assertEqual(impacts[row['item_id']], row['impact_model_id'], row['item_id'])
            if row['owner'] == 'player':
                self.assertEqual(projectiles[row['item_id']], row['projectile_model_id'], row['item_id'])
        # Gun::isPlayerGun reads the byte Gun::setPlayerGun writes; MatrixGetUp returns row words 1, 5 and 9.
        self.assertEqual(thumb(rows['player_flag'][3])[0], ('ldrb.w', 'r0, [r0, #0xf0]'))
        self.assertEqual(thumb(rows['player_flag_setter'][3])[0], ('strb.w', 'r1, [r0, #0xf0]'))
        self.assertEqual(thumb(rows['matrix_up'][3])[:3], [('ldr', 'r3, [r1, #0x14]'), ('ldr', 'r2, [r1, #4]'), ('ldr', 'r1, [r1, #0x24]')])

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'combat_training_visual_definitions.gd', values='VALUES')
