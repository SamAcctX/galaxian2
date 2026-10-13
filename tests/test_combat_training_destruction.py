"""Android combat-training destruction proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import combat_training_destruction as reader

TRAINING, CONTROL = {'scope': 'combat_training_encounter_construction'}, {'scope': 'combat_training_live_control'}
WEAPONS = {'scope': 'combat_training_ordinary_weapons'}
NPC = {'destruction': {'x': 1}, 'death_accounting': {'x': 1}, 'construction': {'x': 1}}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidCombatTrainingDestructionTests(unittest.TestCase):
    def extract(self, lib, training=TRAINING, control=CONTROL, weapons=WEAPONS, npc=NPC):
        return reader.extract_combat_training_destruction(lib, {}, training, control, weapons, {'npc_initialization': npc})

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
            data['actors'][0]['hostile'] = False
            self.assertTrue(reader.VALUES['actors'][0]['hostile'])
            cases = {'other training': dict(training={'scope': 'x'}), 'no training': dict(training={}), 'none': dict(training=None),
                     'other control': dict(control={'scope': 'full_hold_pirate_control'}), 'no control': dict(control=None),
                     'other weapons': dict(weapons={'scope': 'x'}), 'no weapons': dict(weapons={}),
                     'no destruction': dict(npc=dict(NPC, destruction={})), 'no accounting': dict(npc=dict(NPC, death_accounting=None)),
                     'no construction': dict(npc={k: v for k, v in NPC.items() if k != 'construction'}), 'bad npc': dict(npc=None)}
            for name, changes in cases.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_constants(self):
        rows, values = reader.ANDROID, reader.VALUES
        cargo = values['cargo']
        decay, cutoff = struct.unpack('<2f', bytes.fromhex(rows['drift_constants'][3]))
        self.assertEqual((decay, cutoff), (cargo['cargo_drift_decay'], cargo['cargo_drift_cutoff']))
        self.assertEqual(struct.unpack('<2f', bytes.fromhex(rows['angle_constants'][3])), (cargo['cargo_angle_fraction'], cargo['cargo_angle_tau']))
        self.assertIn(('subs', 'r1, #%d' % -values['nonhostile_remaining_delta']), thumb(rows['nonhostile_counter'][3]))
        self.assertIn(('cmp', 'r1, #%d' % values['defeat_condition']['actor_mode']), thumb(rows['death_predicate'][3]))
        # Objective(kind, begin, end, level) stores its three integers first.
        self.assertIn(('stm.w', 'r0, {r1, r2, r3, ip, lr}'), thumb(rows['condition_constructor'][3]))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'combat_training_destruction_definitions.gd', values='VALUES')
