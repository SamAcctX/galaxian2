"""Optional Mac player exhaust declarations, recovered at import only.

These bounded source spans establish constant content. Executable bytes are
never retained, and particle behavior is implemented independently in Godot.

Android: ParticleSettings::init fills SET_BASIC (flags 17, 20 particles, size
250, velocity scatter 100, z velocity -4000, ...) and copies it into sets
29..38; Level::init builds the material-20090 manager; Level::createPlayer
reads the nozzle positions (FileRead::loadWeaponPositions, group 3);
Level::initParticleSystems adds set 29 + i per nozzle on the player's matrix
and sets its lifetime 80 x min(scale x 1.5, 1), size 250 x scale, spacing 8,
20 particles, growth -1000, z velocity -4000 x min(scale x 1.5, 1), colors
0xddddddff -> 0, relative velocity 0.8 and the sprite of the ship's family
(Status::getShip, Ship::getIndex, family table: Betty 3, ship 10 0). Values
equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols
from .station_exterior import declaration_bytes

def extract_engine_particles(mach,arrival,damage):
    if mach.architecture == 'android-armv7':
        try:
            if damage['scope'] != 'damage_particle_sprite_presets' or 'emitter_defaults' not in damage: return {}
        except (KeyError, TypeError): return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(copy.deepcopy(ANDROID_VALUES), provenance=proof) if proof else {}
    if mach.architecture!='x86_64':return {}
    try:
        if damage['scope']!='damage_particle_sprite_presets' or 'emitter_defaults' not in damage:return {}
        origin=arrival['provenance']['actor']
        if origin['bytes']!=315:return {}
        layouts=[{k:[v[2],v[0],v[1],v[3]] for k,v in rows.items()} for rows in [LAYOUTS,MAC_ALTERNATE]]
        proof=recognize(mach,origin['offset'],layouts,reader=declaration_bytes)
        if not proof:return {}
        result=copy.deepcopy(VALUES)
        # The opening player uses ship 10, whose family selects a different
        # atlas rectangle. This capability is emitted only when all three
        # additional source declarations agree with one compiler layout.
        opening_layouts=[{k:[v[2],v[0],v[1],v[3]] for k,v in rows.items()}
                         for rows in [{**LAYOUTS,**MAC_OPENING_SPANS},
                                      {**MAC_ALTERNATE,**OPENING_SPANS}]]
        opening=recognize(mach,origin['offset'],opening_layouts,reader=declaration_bytes)
        if opening:
            result['opening_ship']=copy.deepcopy(OPENING_SHIP)
            proof=opening
        result['provenance']=proof
        return result
    except (KeyError,TypeError,ValueError,IndexError,OverflowError):return {}

VALUES = {'scope': 'mac_betty_nozzle_particles',
 'ship_id': 0,
 'attachment_category': 3,
 'nozzle_count': 4,
 'first_preset': 29,
 'scale_multiplier': 1.5,
 'scale_limit': 1.0,
 'initial_emitting': True,
 'material_type': 3,
 'texture_id': 24202,
 'preset': {'preset_id': 29,
            'material_id': 20090,
            'flags': 17,
            'capacity': 20,
            'size_jitter': 0,
            'lifetime_ms': 80,
            'even_spacing': 1,
            'fade_in_ms': 0,
            'size_growth_per_second': -1000,
            'scatter_xz': 0,
            'scatter_y': 0,
            'velocity_scatter': 100,
            'animation_frames': 0,
            'size': 250.0,
            'distance_spacing': 8.0,
            'relative_velocity_factor': 0.800000011920929,
            'local_velocity_z': -4000.0,
            'local_offset_x': 0.0,
            'local_offset_y': 0.0,
            'local_offset_z': 0.0,
            'local_offset_z_jitter': 0.0,
            'minimum_squared_speed': 1,
            'start_rgba': [221, 221, 221, 255],
            'end_rgba': [0, 0, 0, 0],
            'uv_rect': [0.005859375, 0.005859375, 0.119140625, 0.119140625]}}

OPENING_SHIP = {'ship_id': 10, 'nozzle_count': 3, 'first_preset': 29,
                'family_index': 0,
                'uv_rect': [0.251953125, 0.001953125, 0.373046875, 0.123046875]}

# Relative to the same independently identified arrival actor anchor. The
# getters establish that the family-table index is the actual player ship ID;
# the table proof includes entries 0 through 10, not just Betty's first word.
OPENING_SPANS = {
    'player_ship_getter': [858758, 14, '__text', 'sha256:97a99414d0805a97d19bb703a3c388586fa10a02e733bb562d9ee68d368ce187'],
    'ship_id_getter': [729808, 8, '__text', 'sha256:46e7df051d544d763be777fd992892f1904ae1956482595eac68f089656cd596'],
    'ship_family_table': [1551074, 44, '__const', 'sha256:db1358021bae40c65c6d4ebbe5c8608929361a33ec9e06011851310994d10f9e'],
}
MAC_OPENING_SPANS = {
    'player_ship_getter': [858126, 14, '__text', 'sha256:97a99414d0805a97d19bb703a3c388586fa10a02e733bb562d9ee68d368ce187'],
    'ship_id_getter': [729184, 8, '__text', 'sha256:46e7df051d544d763be777fd992892f1904ae1956482595eac68f089656cd596'],
    'ship_family_table': [1576010, 44, '__const', 'sha256:db1358021bae40c65c6d4ebbe5c8608929361a33ec9e06011851310994d10f9e'],
}

LAYOUTS = {'defaults': [483042,
              211,
              '__text',
              'sha256:a45d4e3d94355bfb5e51a7428f530d9c92088984bdfa01d4d591f7824e1409fd'],
 'basic_and_four_copies': [483319,
                           2344,
                           '__text',
                           'sha256:4f724e4fd68ede043f7ac5f905693eff9362905107b0d26e03f94a645c9630b8'],
 'nozzle_setup': [61403,
                  694,
                  '__text',
                  'sha256:73a3a672452aece3899787c80fe596a6f09d29f2f8ac334631b3ea50926b654b'],
 'nozzle_constants': [1582362,
                      32,
                      '__const',
                      'sha256:6910dcd8fe2e9423be9b60b97a8de56c1681144145aa2f40455f36400efde5f2'],
 'size_constant': [1575358,
                   4,
                   '__const',
                   'sha256:790ae12c34496bfe41c52a4786035ab076ce6771b936c6adf4608fd641420958'],
 'speed_constant': [1575098,
                    4,
                    '__const',
                    'sha256:d4d7872536d6219129a11acebac252c04c1129ef770c2ecc9ebdf1ac7d5abc93'],
 'hull_color': [1576010,
                4,
                '__const',
                'sha256:9d9f290527a6be626a8f5985b26e19b237b44872b03631811df4416fc1713178'],
 'color_cases': [64294,
                 36,
                 '__text',
                 'sha256:67ce6de3545b8bb2fa539afcd8f67777e2c44526df277265e724879d852b2845'],
 'manager': [-43546,
             44,
             '__text',
             'sha256:43ea15109f982ad5e4eee9df6f07298a086a138b672d26282428af7e3b8547a8'],
 'attachment_positions': [-36633,
                          278,
                          '__text',
                          'sha256:52e99e9f75d8e10acc771cefef3f8dedfa6e9be670f130a1a57a29b57e95ae19']}

# Complete independently verified alternate Mac layout.
MAC_ALTERNATE = {'defaults': [483570, 211, '__text', 'sha256:a45d4e3d94355bfb5e51a7428f530d9c92088984bdfa01d4d591f7824e1409fd'],
 'basic_and_four_copies': [483847,
                           2344,
                           '__text',
                           'sha256:ac3a2bb6a2737430818e9e59d309d6abc434748160a6ea61b96eac5f0ef1b2f3'],
 'nozzle_setup': [61403, 694, '__text', 'sha256:534bd53681883c2ade3f5eeccca2b62b0be24cde0fe5af6818a24ba6956d01a3'],
 'nozzle_constants': [1557426,
                      32,
                      '__const',
                      'sha256:6910dcd8fe2e9423be9b60b97a8de56c1681144145aa2f40455f36400efde5f2'],
 'size_constant': [1550422, 4, '__const', 'sha256:790ae12c34496bfe41c52a4786035ab076ce6771b936c6adf4608fd641420958'],
 'speed_constant': [1550162, 4, '__const', 'sha256:d4d7872536d6219129a11acebac252c04c1129ef770c2ecc9ebdf1ac7d5abc93'],
 'hull_color': [1551074, 4, '__const', 'sha256:9d9f290527a6be626a8f5985b26e19b237b44872b03631811df4416fc1713178'],
 'color_cases': [64294, 36, '__text', 'sha256:67ce6de3545b8bb2fa539afcd8f67777e2c44526df277265e724879d852b2845'],
 'manager': [-43546, 44, '__text', 'sha256:89d1650a4d86ed0e3a07f603d5af6eadeda6c8e70a3d3f87791205024e6c176a'],
 'attachment_positions': [-36633,
                          280,
                          '__text',
                          'sha256:34354cad39ffb2d9e161b5d6d2a891366c110ad5db9c91a8db12913ac3cf7e82']}

# Android: the VALUES with the opening ship (family table entry 10 is 0); spans inside named functions and tables.
ANDROID_VALUES = copy.deepcopy({**VALUES, 'opening_ship': OPENING_SHIP})
ANDROID = {# ParticleSettings::init: the set defaults, SET_BASIC (its three vectors) and its copies into sets 29..38.
           'defaults': ('_ZN16ParticleSettings4initEv', 14, 364, 'sha256:661d8fe72f7ca6a86453db628677cb72149ab02274429248c59479e19b0f3742'),
           'basic_vectors': ('_ZN16ParticleSettings4initEv', 112, 48, '01000000ffffffffff000000000000000cfeffff0000000000000000640000000000303f6f12833a7b143e3f0000803d'),
           'basic_and_copies': ('_ZN16ParticleSettings4initEv', 378, 426, 'sha256:b85041724c183a3af3d9576655bd578d56077208e528d3d6af03ca2864004507'),
           # Level::initParticleSystems: one set-29 + i system per nozzle and its overrides (80.0, 250, -4000.0),
           # the family sprites and the ship-family table.
           'nozzle_setup': ('_ZN5Level19initParticleSystemsEv', 0, 2120, 'sha256:06c77b32c546ea95b3c614a97871d57008a50b7ef9248a52041ccd2d7bf4142e'),
           'nozzle_scales': ('_ZN5Level19initParticleSystemsEv', 960, 24, '000000000000544000007a43aff30080000000000040afc0'),
           'nozzle_sprites': ('_ZN5Level19initParticleSystemsEv', 1920, 96, '0080203f0000003b00803f3f0000fc3d0080003f0000003b00801f3f0000fc3d0000c13e0000003b0000ff3e0000fc3d0000043e0000c03b00007c3e0000f83d0000c03b0000c03b0000f43d0000f43d0000813e0000003b0000bf3e0000fc3d'),
           'family_table': ('_ZN5Level19initParticleSystemsEv', 124, 44, '0300000000000000080000000300000002000000000000000300000000000000090000000100000000000000', 'literal', 0),
           # Level::init: the material-20090 manager; Level::createPlayer: the nozzle attachments.
           'manager': ('_ZN5Level4initEv', 326, 50, 'sha256:6386b9098501e48fd38b014cd266c246ab9cb0043151169fea31f2c6b15244b2'),
           'attachment_positions': ('_ZN5Level12createPlayerEv', 440, 230, 'sha256:1dbcee2be8d1849b87249f239a6cba664be730b4a30170dd5f47996901e7f72f'),
           'player_ship_getter': ('_ZN6Status7getShipEv', 0, 6, 'd0f88c017047'),
           'ship_id_getter': ('_ZN4Ship8getIndexEv', 0, 4, '00687047')}
