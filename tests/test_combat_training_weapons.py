"""Android combat-training weapon proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import copy
import unittest
from gof2_content import combat_training_weapons as reader

TRAINING, CONTROL = {'scope': 'combat_training_encounter_construction'}, {'scope': 'combat_training_live_control'}
EQUIPMENT = {'scope': 'var_hastra_equipment_tutorial'}
PLAYER = {'flight_cache': {'x': 1}, 'repair': {'x': 1}}
WEAPONS = {k: {'x': 1} for k in ['ordinary_hit_policy', 'player_hit_policy', 'collision_bounds', 'audio']}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidCombatTrainingWeaponTests(unittest.TestCase):
    def extract(self, lib, training=TRAINING, control=CONTROL, equipment=EQUIPMENT, player=PLAYER, weapons=WEAPONS):
        return reader.extract_combat_training_weapons(lib, {}, training, control, equipment, {'player_initialization': player}, weapons)

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
            data['npc_weapons'][0]['damage'] = 9
            self.assertEqual(reader.ANDROID_VALUES['npc_weapons'][0]['damage'], 1)
            cases = {'other training': dict(training={'scope': 'x'}), 'no training': dict(training={}), 'none': dict(training=None),
                     'other control': dict(control={'scope': 'full_hold_pirate_control'}), 'no control': dict(control={}),
                     'other equipment': dict(equipment={'scope': 'x'}), 'no equipment': dict(equipment=None),
                     'no cache': dict(player=dict(PLAYER, flight_cache={})), 'no repair': dict(player={'flight_cache': {'x': 1}}),
                     'bad player': dict(player=None)}
            for key in WEAPONS:
                cases['no ' + key] = dict(weapons={k: v for k, v in WEAPONS.items() if k != key})
                cases['empty ' + key] = dict(weapons=dict(WEAPONS, **{key: {}}))
            cases['bad weapons'] = dict(weapons=None)
            for name, changes in cases.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_values(self):
        # Only the cursor-7 pirates' damage differs from the Mac: trunc(3 x 0.5).
        expected = copy.deepcopy(reader.VALUES)
        for row in expected['npc_weapons']:
            if row['actor_kind'] == 8:
                self.assertEqual(row['damage'], 3)
                row['damage'] = int(3 * 0.5)
        self.assertEqual(reader.ANDROID_VALUES, expected)
        self.assertEqual([r['damage'] for r in reader.ANDROID_VALUES['npc_weapons']], [1, 1, 1, 3])

    def test_android_constants(self):
        rows = reader.ANDROID
        self.assertEqual(thumb(rows['training_damage_scale'][3]), [('vmov.f32', 's24, #5.000000e-01')])
        self.assertEqual(thumb(rows['training_damage_cursor'][3])[0], ('cmp.w', 'r8, #%d' % reader.VALUES['campaign_cursor']))
        code = thumb(rows['training_damage'][3])
        self.assertIn(('ldr', 'r0, [r0, #0x24]'), code)
        self.assertIn(('cmp', 'r0, #8'), code)
        self.assertIn(('vmul.f32', 's0, s0, s24'), code)
        self.assertEqual(code[-1], ('vstr', 's0, [r5, #0x60]'))
        self.assertEqual(thumb(rows['spread_setter'][3])[:2], [('vmov', 's0, r1'), ('vcvt.f32.s32', 's0, s0')])

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'combat_training_weapon_definitions.gd')
