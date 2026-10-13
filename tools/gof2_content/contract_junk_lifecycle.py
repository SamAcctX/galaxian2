"""Verified Junk declarations; no original executable code is emitted.

Android: PlayerJunk::update destroys debris (Level::junkDied counts it, sound
22), drops item 99 (1-10) for random(100) <= 9 in a KIPlayer::createCrate
container and bursts particle set 21 (ParticleSystemManager::emitManual, size
-1), PlayerJunk::render draws live debris; ParticleSettings::init defines set
21 (SET_EXPLOSION_MANUALLY_JUNK) and Level::initParticleSystems registers it;
MGame::gameOverCheck fails the contract after its deadline unless
Objective::isSurvivalObjective; Status::resetGame clears the debris statistic.
Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants


def extract_contract_junk_lifecycle(mach, arrival):
    if getattr(mach, 'architecture', None) == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})


VALUES = {'scope': 'mido_contract_junk_lifecycle',
 'campaign_cursor': 13,
 'kind': 7,
 'initial_mode': 0,
 'destroyed_mode': 4,
 'initial_active': True,
 'initial_targeting_blocked': False,
 'initial_model_draw_enabled': True,
 'hostile_remaining_delta': -1,
 'debris_destroyed_delta': 1,
 'initial_debris_destroyed': 0,
 'sound_id': 22,
 'drop_draw_bound': 100,
 'drop_inclusive_maximum': 9,
 'cargo_item_id': 99,
 'quantity_draw_bound': 10,
 'quantity_add': 1,
 'cargo_model_id': 16990,
 'cargo_model_resource': 'resources/data/assets/main/3d/meshes/misc/container_001_midorian.aem',
 'cargo_retains_activity': True,
 'empty_disables_activity': True,
 'empty_clears_selected_target': True,
 'stationary': True,
 'cargo_cleanup_milliseconds': -1,
 'burst_member_index': 0,
 'burst_count': 1,
 'burst_size_override': -1,
 'burst_initial_emitting': True,
 'burst_preset': {'preset_id': 21,
                  'material_id': 20099,
                  'flags': 33554689,
                  'capacity': 10,
                  'size_jitter': 200,
                  'lifetime_ms': 1000,
                  'even_spacing': 0,
                  'fade_in_ms': 0,
                  'size_growth_per_second': 500,
                  'scatter_xz': 0,
                  'scatter_y': 0,
                  'velocity_scatter': 0,
                  'animation_frames': 16,
                  'size': 1600.0,
                  'emission_per_second': 500.0,
                  'relative_velocity_factor': 0.0,
                  'local_velocity_z': 0.0,
                  'local_offset_y': 0.0,
                  'local_offset_z': 0.0,
                  'local_offset_z_jitter': 0.0,
                  'start_rgba': [255, 255, 255, 255],
                  'end_rgba': [255, 255, 255, 255],
                  'uv_rect': [0.0, 0.0, 0.25, 0.25]},
 'deadline_milliseconds': 121000,
 'deadline_comparison': 'strictly_greater',
 'deadline_uses_periodic_poll': True,
 'deadline_requires_idle_radio': False,
 'success_precedes_deadline': True,
 'failure_credit_delta': 0}

LAYOUTS = {'junk_lifecycle_update': [640402,
                           508,
                           '__text',
                           '66e435376d5175fae8645fe528c375eae65d5a3ec9766c69d1284f3bb5d8308b'],
 'junk_lifecycle_render': [640910,
                           62,
                           '__text',
                           '774327b85fcf50d3590d544846a97b31e0407c24b9a9b8db55bcfd3d072bddcc'],
 'junk_lifecycle_world_count': [107554,
                                28,
                                '__text',
                                'f0bcdead1de61dd80a66711f261e245e44a7f2840a84fef034af8b2cf025bcc9'],
 'junk_lifecycle_deadline_exclusion': [482186,
                                       12,
                                       '__text',
                                       'c65e7871bf910d88cd8e831c948aaa17a4e8b0c5eb7e195660b790ceee0df5f7'],
 'junk_lifecycle_deadline_poll': [388744,
                                  340,
                                  '__text',
                                  '9ba436b9b2edb90b772d60363b1693ca286895b7ace20bec4cfef38d7e3595cc'],
 'junk_lifecycle_particle_registration': [63495,
                                          30,
                                          '__text',
                                          '8e9e47be3f8e6b558184c3bffa87a1e336dffb5ca9c01b04dcd4fd50240ef284'],
 'junk_lifecycle_particle_copy': [498043,
                                  1407,
                                  '__text',
                                  '56f52784c79659b5c31c027cba57a0684da445a2377d9c5b38284493f533162c'],
 'junk_lifecycle_initial_statistic': [881233,
                                      11,
                                      '__text',
                                      'f1f8fe6a1184bbb8779679a1278f498f7920af77e4d530f580606429b90ff2ce'],
 'junk_lifecycle_burst_size': [1556978,
                               4,
                               '__const',
                               'c68830a25204a09f8e77aada6bc5807f607cccaaa0ebb2a7122d317584478a8b']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'junk_lifecycle_update': [640950,
                           508,
                           '__text',
                           '94d9d7218154ee7a027f8b08f249f61603ed61e74747462f756636a6204e71bb'],
 'junk_lifecycle_render': [641458,
                           62,
                           '__text',
                           'dc836b136b88150f5910975ac1c1972ce9d69928ddc93f4e0089defef1185214'],
 'junk_lifecycle_world_count': [107554,
                                28,
                                '__text',
                                '3a5f7994f3df990378ed6063291fb807857d0ec70b7c8a161184fa4d1019bd16'],
 'junk_lifecycle_deadline_exclusion': [482714,
                                       12,
                                       '__text',
                                       'c65e7871bf910d88cd8e831c948aaa17a4e8b0c5eb7e195660b790ceee0df5f7'],
 'junk_lifecycle_deadline_poll': [389260,
                                  340,
                                  '__text',
                                  '8c2f8a277792a1c343d6db309dad69e9cc227774f8b6049f59a29bd5c55052b1'],
 'junk_lifecycle_particle_registration': [63495,
                                          30,
                                          '__text',
                                          'dfc6c8afea4e17f0fbae90b73e18ee3963273da5bab0106da2e67b1d1ec0abb4'],
 'junk_lifecycle_particle_copy': [498571,
                                  1407,
                                  '__text',
                                  'e232dfda5c87972626b3bd1cf34920618dd297421a03b6d75060e2f77ed5b7c7'],
 'junk_lifecycle_initial_statistic': [881865,
                                      11,
                                      '__text',
                                      'f1f8fe6a1184bbb8779679a1278f498f7920af77e4d530f580606429b90ff2ce'],
 'junk_lifecycle_burst_size': [1531978,
                               4,
                               '__const',
                               'c68830a25204a09f8e77aada6bc5807f607cccaaa0ebb2a7122d317584478a8b']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {'junk_lifecycle_update': ('_ZN10PlayerJunk6updateEi', 0, 368, 'sha256:e0475bd7577cfcfd396b8bdc1446f71c3430b2651dad018d873c8f232558c441'),
           'junk_lifecycle_render': ('_ZN10PlayerJunk6renderEv', 0, 36, 'sha256:f4d5643e1a26860302be69e997587958b2a9236f87c2d374dd0307254b9c771e'),
           'junk_lifecycle_world_count': ('_ZN5Level8junkDiedEv', 0, 36, 'sha256:328066320bb132d2761038511421b2cb8318a210fc3cee84e9d8af34a6b72052'),
           'junk_lifecycle_deadline_exclusion': ('_ZN9Objective19isSurvivalObjectiveEv', 0, 12, '01680020032908bf01207047'),
           'junk_lifecycle_deadline_poll': ('_ZN5MGame13gameOverCheckEv', 412, 168, 'sha256:f513d1975925c278c374f4939e61866cb937b746f5f2091a1f98cc0a9920e4e4'),
           'junk_lifecycle_particle_registration': ('_ZN5Level19initParticleSystemsEv', 1522, 48, 'sha256:aff9247daa1974928091a06a64ce81ec86e1236f31fa35d91d3e6f09eaf8d16a'),
           'junk_lifecycle_particle_presets': ('_ZN16ParticleSettings4initEv', 0, 5828, 'sha256:c1f14b60756290f7c689ddb614fabcd1ff5b653699be7fae10840b1d8d83ef29'),
           'junk_lifecycle_initial_statistic': ('_ZN6Status9resetGameEv', 310, 6, '0020c8f8b000')}
