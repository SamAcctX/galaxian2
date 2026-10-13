"""Optional Mac second-trip sprite declarations, recovered only at import.

Every supported value is guarded by bounded source context. No executable bytes
or original logic enter the content pack; simulation is independently native.

Android: ParticleSettings::init defines sets 9 (trails) and 11 (bursts);
Level::init builds the general manager (material 20099), Level::
initParticleSystems registers the world burst, PlayerEgo::setLevel and
PlayerFighter::setLevel the trails; PlayerFighter::update and PlayerEgo::update
emit the burst through ParticleSystemManager::emitManual.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols
from .station_exterior import declaration_bytes

def extract_full_hold_particles(mach,arrival,flight,death,damage):
    if mach.architecture == 'android-armv7':
        try:
            if flight['scope'] != 'full_hold_mining_flight_construction' or flight['actor_count'] != 1: return {}
            if death['scope'] != 'mac_starter_player_destruction' or death['ship_id'] != 0: return {}
            if damage['scope'] != 'damage_particle_sprite_presets' or [p['preset_id'] for p in damage['presets']] != [15, 42]: return {}
            if damage['owners']['scope'] != 'fresh_opening_damage_emitters' or not damage['owners']['npc_uses_detail_gate']: return {}
            if 'emitter_defaults' not in damage: return {}
        except (KeyError, TypeError): return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(copy.deepcopy(VALUES), provenance=proof) if proof else {}
    if mach.architecture!='x86_64':return {}
    try:
        if flight['scope']!='full_hold_mining_flight_construction' or flight['actor_count']!=1:return {}
        if death['scope']!='mac_starter_player_destruction' or death['ship_id']!=0:return {}
        if damage['scope']!='damage_particle_sprite_presets' or [p['preset_id'] for p in damage['presets']]!=[15,42]:return {}
        if damage['owners']['scope']!='fresh_opening_damage_emitters' or not damage['owners']['npc_uses_detail_gate']:return {}
        if 'emitter_defaults' not in damage:return {}
        origin=arrival['provenance']['actor']
        if origin['bytes']!=315:return {}
        layouts=[{k:[v[2],v[0],v[1],v[3]] for k,v in rows.items()} for rows in [LAYOUTS,MAC_ALTERNATE]]
        proof=recognize(mach,origin['offset'],layouts,reader=declaration_bytes)
        if not proof:return {}
        values=VALUES
        result=copy.deepcopy(values);result['provenance']=proof
        return result
    except (KeyError,TypeError,ValueError,IndexError,OverflowError):return {}

VALUES = {'scope': 'mac_full_hold_sprite_particles',
 'departure_cursor': 4,
 'story_cursors': [4, 5],
 'player_preset': 9,
 'npc_preset': 9,
 'npc_smoke_preset': 15,
 'npc_fire_preset': 42,
 'npc_count': 1,
 'burst_preset': 11,
 'burst_member_index': 0,
 'burst_count': 1,
 'burst_size_override': -1,
 'burst_position': 'statistics_before_death_spin',
 'player_root': 'physical',
 'npc_root': 'retained_unbanked',
 'player_smoke_fire_max_cursor': 1,
 'player_initial_emitting': False,
 'npc_initial_emitting': False,
 'burst_initial_emitting': True,
 'initial_visible': True,
 'manual_emission_ignores_flags': True,
 'presets': [{'preset_id': 9,
              'material_id': 20099,
              'flags': 33554465,
              'capacity': 16,
              'size_jitter': 1000,
              'lifetime_ms': 700,
              'even_spacing': 1,
              'fade_in_ms': 0,
              'size_growth_per_second': 500,
              'scatter_xz': 300,
              'scatter_y': 300,
              'velocity_scatter': 0,
              'animation_frames': 16,
              'size': 100.0,
              'emission_per_second': 8.0,
              'relative_velocity_factor': 1.0,
              'local_velocity_z': 0.0,
              'local_offset_y': 0.0,
              'local_offset_z': -250.0,
              'local_offset_z_jitter': 500.0,
              'start_rgba': [255, 255, 255, 255],
              'end_rgba': [255, 255, 255, 255],
              'uv_rect': [0.0, 0.0, 0.25, 0.25]},
             {'preset_id': 11,
              'material_id': 20099,
              'flags': 33554689,
              'capacity': 10,
              'size_jitter': 1000,
              'lifetime_ms': 1500,
              'even_spacing': 0,
              'fade_in_ms': 0,
              'size_growth_per_second': 500,
              'scatter_xz': 0,
              'scatter_y': 0,
              'velocity_scatter': 0,
              'animation_frames': 16,
              'size': 2000.0,
              'emission_per_second': 500.0,
              'relative_velocity_factor': 0.0,
              'local_velocity_z': 0.0,
              'local_offset_y': 0.0,
              'local_offset_z': 0.0,
              'local_offset_z_jitter': 0.0,
              'start_rgba': [255, 255, 255, 255],
              'end_rgba': [255, 255, 255, 255],
              'uv_rect': [0.0, 0.0, 0.25, 0.25]}]}

LAYOUTS = {'defaults': [483042,
              211,
              '__text',
              'sha256:a45d4e3d94355bfb5e51a7428f530d9c92088984bdfa01d4d591f7824e1409fd'],
 'trail_preset': [491375,
                  293,
                  '__text',
                  'sha256:a09d56cdb40262125c21cd7c628bb108c52ff4faa04617e56984cde0b2b2b099'],
 'burst_preset': [494947,
                  245,
                  '__text',
                  'sha256:20dc97e5ca54644530c7390921572c67704e203c78a0c9e0fbb45c14a30c9191'],
 'general_material': [-43613,
                      44,
                      '__text',
                      'sha256:20e3d9beca027c20fe826c45e3c05394b66f0647523208957b836d4f51df702e'],
 'player_registration': [559640,
                         232,
                         '__text',
                         'sha256:89e246271b3c12f5e2bb27221bf386674804baf03c8529e9c088aa3553774847'],
 'npc_registration': [608550,
                      340,
                      '__text',
                      'sha256:ead651ab5aa4ab355e3d610e866e3ceb41762ba3ba480a3bc8a52b75d07e367e'],
 'world_burst_registration': [63207,
                              30,
                              '__text',
                              'sha256:018e2d85cd3e640aa380acad50ef4360dc1dd74166f1620f763d3710c90e0f2e'],
 'emitter_registration': [510706,
                          264,
                          '__text',
                          'sha256:e05e9f8bbd492044708a2854a4cbad5ad7899e2eb2366c464a8d59159088da9f'],
 'initial_flags': [513047,
                   12,
                   '__text',
                   'sha256:065f536fb686a067fbaf9a456ca940a79f7e9fc46765109ef331bd522d80371b'],
 'continuous_gate': [514369,
                     85,
                     '__text',
                     'sha256:986cde10ae17365117341d164aebc40767fbed4f5acfcf98e5e8e996b25e58b5'],
 'manual_wrapper': [512454,
                    66,
                    '__text',
                    'sha256:04ef7809e58d51e038bfde2d33b607cb2ac30b9fd9c03e42d957bcd6b62e9a58'],
 'manual_emission': [518916,
                     1982,
                     '__text',
                     'sha256:25bc54cd1f06ddd7f8bccfb0f34db0896d2faa3f2f43d218991c050375441e82'],
 'burst_position_sample': [582756,
                           250,
                           '__text',
                           'sha256:c17468c5afb70212be3fdceb0176b4bacf2c5339a606a35f43cbcc8d3d70a55f'],
 'burst_position_retained': [583006,
                             1194,
                             '__text',
                             'sha256:38da048eeecf3f486136e538084735ffe3a14aec33ad442b9278208ada2ce8d6'],
 'statistics_position_getter': [1241402,
                                96,
                                '__text',
                                'sha256:c295638c90864edb169972d0ef2209e46964b25da3309b92ef6effc0e808b3fc'],
 'position_addition_value': [1059226,
                             144,
                             '__text',
                             'sha256:4ed6279091dd97cddc327271ac29cee71a25047ffd3967b8e54705f35392ff62'],
 'player_breakup': [584583,
                    93,
                    '__text',
                    'sha256:891c9a18d0889e6b02e426608985844866284e32b5d128a99b1025799caa3c07'],
 'npc_death_enable': [619399,
                      28,
                      '__text',
                      'sha256:c26924751852a748d87a67338edd924c719617a074a8942ef5f5af8e536582ec'],
 'npc_breakup_disable': [626315,
                         25,
                         '__text',
                         'sha256:ab976b8f0100bea22d2821813318edd45eedf4fdbf1c9963040e42bc31dea951']}

# Complete independently verified alternate Mac layout.
MAC_ALTERNATE = {'defaults': [483570, 211, '__text', 'sha256:a45d4e3d94355bfb5e51a7428f530d9c92088984bdfa01d4d591f7824e1409fd'],
 'trail_preset': [491903, 293, '__text', 'sha256:a09d56cdb40262125c21cd7c628bb108c52ff4faa04617e56984cde0b2b2b099'],
 'burst_preset': [495475, 245, '__text', 'sha256:acd7e191b67d25a3aa75d95401a7de7a815e1a104ab451026092fffb9d9a4814'],
 'general_material': [-43613, 44, '__text', 'sha256:358d4bd3cbc6f076ed7e06743ab9017b1ca2c849a80e7565c5842a33d2a559ee'],
 'player_registration': [560176,
                         232,
                         '__text',
                         'sha256:e05432c25e84830194c12a97d179257e307643856b8c346d8383cdb5bfce05ae'],
 'npc_registration': [609098, 340, '__text', 'sha256:172aab28bc563f1d8e4caa4a2e49729bdb3720bf48de588757680f00748429c4'],
 'world_burst_registration': [63207,
                              30,
                              '__text',
                              'sha256:fb94f929bebe90525089f8c9d1c6c525769d0aa215a5b2cec5391c910d9d591d'],
 'emitter_registration': [511242,
                          264,
                          '__text',
                          'sha256:0453ad1bc3746feff9bf520fe81760dfea34c5cf02a9899a996498239de95423'],
 'initial_flags': [513583, 12, '__text', 'sha256:065f536fb686a067fbaf9a456ca940a79f7e9fc46765109ef331bd522d80371b'],
 'continuous_gate': [514905, 85, '__text', 'sha256:986cde10ae17365117341d164aebc40767fbed4f5acfcf98e5e8e996b25e58b5'],
 'manual_wrapper': [512990, 66, '__text', 'sha256:04ef7809e58d51e038bfde2d33b607cb2ac30b9fd9c03e42d957bcd6b62e9a58'],
 'manual_emission': [519452, 1982, '__text', 'sha256:8a6c771714b985e65051074607c3c068ac6a73a4697d59daa811610e6bf213a6'],
 'burst_position_sample': [583292,
                           250,
                           '__text',
                           'sha256:58604c2824367de88b7c54bdb893bde9ea90d648ac8fbd7bf3f638768bbde490'],
 'burst_position_retained': [583542,
                             1194,
                             '__text',
                             'sha256:00703bb35c9c3a181b055ffffe6fab34b54917dad80d99f7bd9c9d059f8980e2'],
 'statistics_position_getter': [1234194,
                                96,
                                '__text',
                                'sha256:75a2032bb9fc753fff283f0ba674c5947d97ca4e3687d53eeb473f94c9105cca'],
 'position_addition_value': [1059954,
                             128,
                             '__text',
                             'sha256:7968f6d432915456876629893be624c3cce687a9c634e338de8eaf9179aa4d4e'],
 'player_breakup': [585119, 93, '__text', 'sha256:02f0e9a16a6767fa2f246a5276d15216f51d0663a20f065b27aceb1311cba56d'],
 'npc_death_enable': [619947, 28, '__text', 'sha256:aa4bb4099bb8d4807d6181e537af4ff69433834bc029a220a37bfae9e0c3fd4c'],
 'npc_breakup_disable': [626863,
                         25,
                         '__text',
                         'sha256:9cdfce1389f2aa75ce278c9b052aa130f9432d2f4f341e89e0579c891fd8880d']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {# ParticleSettings::init: the set defaults loop, then sets 9 (trail: material from Level::init's general
           # manager, flags 0x2000021, 16 particles, 700 ms) and 11 (burst: 10 particles, 1500 ms, size 2000).
           'defaults': ('_ZN16ParticleSettings4initEv', 14, 364, 'sha256:661d8fe72f7ca6a86453db628677cb72149ab02274429248c59479e19b0f3742'),
           'presets': ('_ZN16ParticleSettings4initEv', 378, 2754, 'sha256:a3c3c892f18bae87b5fc8f167bd231527a547942d1cc7d355f7455262b48b7af'),
           'general_material': ('_ZN5Level4initEv', 0, 1792, 'sha256:fceec130c720743b341b16f0e8ce63d43a1382808e075533d391370c9949a244'),
           # Level::initParticleSystems registers the world burst (set 11); PlayerEgo::setLevel and
           # PlayerFighter::setLevel the set-9 trails (smoke and fire only up to cursor 1 for the player).
           'world_burst_registration': ('_ZN5Level19initParticleSystemsEv', 0, 2120, 'sha256:06c77b32c546ea95b3c614a97871d57008a50b7ef9248a52041ccd2d7bf4142e'),
           'player_registration': ('_ZN9PlayerEgo8setLevelEP5Level', 0, 152, 'sha256:32e9a9fe4c78661baf5b4737a3fc9cb19858f6d639d807469ae764c6e9edf178'),
           'npc_registration': ('_ZN13PlayerFighter8setLevelEP5Level', 0, 214, 'sha256:9b84b0fd27be53fe3b82a5fcaa59b23cbed3d97e703c6bd7d420ef84a1dfc155'),
           # ParticleSystemManager / IParticleSystem: registration, emission gates and manual emission.
           'manager_add': ('_ZN21ParticleSystemManager9addSystemEPKN11AbyssEngine6AEMath6MatrixEN16ParticleSettings11ParticleSetEb', 0, 200, 'sha256:b55dfdc8117d8182393be1a4cc8fb816e52ab3e102e604f409af0fd96ef7f4c1'),
           'enable_emit': ('_ZN21ParticleSystemManager16enableSystemEmitEib', 0, 42, 'sha256:ee288145a3c05e19abc1a59cc18f7feaa7491b9f94a222d1775febdd3a602222'),
           'emitter_registration': ('_ZN15IParticleSystemC2EPN11AbyssEngine11PaintCanvasEPKNS0_6AEMath6MatrixERK5ArrayIN16ParticleSettings11ParticleSetEEbb', 0, 336, 'sha256:56150fd98fa4b5b08eda2311aa33699e11047f03676cd7566bbad7190b54a69c'),
           'continuous_gate': ('_ZN15IParticleSystem6updateEi', 0, 68, 'sha256:eeb78348e1cdf46f4101ca2de0c1154be728078804880094377b18fa6301d3f2'),
           'manual_wrapper': ('_ZN21ParticleSystemManager10emitManualEiRKN11AbyssEngine6AEMath6VectorEiS4_f', 0, 74, 'sha256:9ca90767f0386d4a0c8d48a4eb190121c5d3e4ff0d4c1fa29b7ae61ddeb13e0b'),
           'manual_emission': ('_ZN15IParticleSystem10emitManualEN11AbyssEngine6AEMath6VectorEiPKS2_f', 0, 1172, 'sha256:10e1a48844bfba41bc1c21c594a8c8d2ea265d992b22ab71c50c61456fd0534e'),
           # PlayerFighter::update and PlayerEgo::update emit the burst (size -1) where the ship dies.
           'npc_burst': ('_ZN13PlayerFighter6updateEi', 0, 10528, 'sha256:fb79b3bde0fb27a45861c89450940e96ec313695cb5d4b4c290220c25ef78d9e'),
           'player_breakup': ('_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi', 9224, 92, 'sha256:3a565b7bee37018ff8060442171596fe8747f2fe8839ad1930926fd1e8af19ba')}
