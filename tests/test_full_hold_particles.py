"""Android second-flight particle proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import unittest
from gof2_content import full_hold_particles as reader

FLIGHT = {'scope': 'full_hold_mining_flight_construction', 'actor_count': 1}
DEATH = {'scope': 'mac_starter_player_destruction', 'ship_id': 0}
DAMAGE = {'scope': 'damage_particle_sprite_presets', 'presets': [{'preset_id': 15}, {'preset_id': 42}], 'emitter_defaults': {},
          'owners': {'scope': 'fresh_opening_damage_emitters', 'npc_uses_detail_gate': True}}


class AndroidFullHoldParticlesTests(unittest.TestCase):
    def extract(self, lib, flight=FLIGHT, death=DEATH, damage=DAMAGE):
        return reader.extract_full_hold_particles(lib, {}, flight, death, damage)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, reader, self.extract, values='VALUES')
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            data = self.extract(lib)
            data['presets'][0]['capacity'] = 0
            self.assertEqual(reader.VALUES['presets'][0]['capacity'], 16)
            owners = DAMAGE['owners']
            cases = {'other flight': dict(flight=dict(FLIGHT, scope='x')), 'two actors': dict(flight=dict(FLIGHT, actor_count=2)),
                     'no flight': dict(flight={}), 'none': dict(flight=None), 'other death': dict(death=dict(DEATH, scope='x')),
                     'other ship': dict(death=dict(DEATH, ship_id=1)), 'other damage': dict(damage=dict(DAMAGE, scope='x')),
                     'other presets': dict(damage=dict(DAMAGE, presets=[{'preset_id': 42}, {'preset_id': 15}])),
                     'other owners': dict(damage=dict(DAMAGE, owners=dict(owners, scope='x'))),
                     'no detail gate': dict(damage=dict(DAMAGE, owners=dict(owners, npc_uses_detail_gate=False))),
                     'no defaults': dict(damage={k: v for k, v in DAMAGE.items() if k != 'emitter_defaults'})}
            for name, changes in cases.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'full_hold_particle_definitions.gd', values='VALUES')
