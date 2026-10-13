"""Convoy-specific ordinary ship lifecycle declarations, import only.

Android: Level::createShip gives hull 14 the battleship explosion model 18304
(PlayerFixedObject::setWreckedMeshId: wreck layout 0);
PlayerFixedObject::update plays the capital death (materials 34716 and 33356,
one capital kill, medal 39, 9999999 damage to attached actors); the KIPlayer,
PlayerFighter and PlayerFixedObject constructors attach nothing by default;
Standing::isEnemy and isFriend turn Terrans hostile below -70 and friendly
above 70. Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_convoy_lifecycle(mach,arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'mido_convoy_ship_lifecycle',
 'campaign_cursor': 14,
 'terran_hostility': {'actor_kind': 0,
                      'axis': 0,
                      'hostile_below': -70,
                      'friendly_above': 70},
 'capital_death': {'model_id': 18304,
                   'model_resource': 'resources/data/assets/main/3d/meshes/ships/battleship_terran_explosion_anim.aem',
                   'initial_material_id': 34716,
                   'wreck_material_id': 33356,
                   'wreck_layout_id': 0,
                   'capital_kills_delta': 1,
                   'medal_id': 39,
                   'attached_damage': 9999999,
                   'attached_actor_ids': []}}

LAYOUTS = {'convoy_lifecycle_factory_death_model': [79935,
                                          13,
                                          '__text',
                                          'c186282b99e10a72c52674b261cfb64da1970de2f9456f9c0cf094d0b93b3f03'],
 'convoy_lifecycle_death_model_context': [633586,
                                          336,
                                          '__text',
                                          '60031382ce306285da9f4ea5978465bf1295001c511d16e7ae77f2e8c9d07fe7'],
 'convoy_lifecycle_capital_death_effects': [634134,
                                            4064,
                                            '__text',
                                            '1e9e3720758477dd246383e87b80ea89bc8a9cdba7cd5e597538605c9f146449'],
 'convoy_lifecycle_default_attachment': [-81548,
                                         948,
                                         '__text',
                                         'f12861749d41ef2ca9eac32cd4814ba5a3e3e9b12d3d34206d636457a5c0835e'],
 'convoy_lifecycle_small_ship_constructor': [605172,
                                             2562,
                                             '__text',
                                             '9872cce6e7b565f4b3dbeb762598ade1997e62a1d03100f33cfc538edab0800b'],
 'convoy_lifecycle_large_ship_constructor': [631244,
                                             1108,
                                             '__text',
                                             '39596638f6c7393a8e4af981e4162d2f1ffeb8e3f51bf20045112a50014d0da6'],
 'convoy_lifecycle_hostility': [807440,
                                128,
                                '__text',
                                '209daf40d4ec5e88c1313c37445ee4a0ef33d73404653b3a058a617a037fae4d'],
 'convoy_lifecycle_friendliness': [807568,
                                   128,
                                   '__text',
                                   'a32c7ef7f73abed32663bdf810d8affba26b4f3c3dccb168afc7abfaa939f8ed']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'convoy_lifecycle_factory_death_model': [79935,
                                          13,
                                          '__text',
                                          'c186282b99e10a72c52674b261cfb64da1970de2f9456f9c0cf094d0b93b3f03'],
 'convoy_lifecycle_death_model_context': [634134,
                                          336,
                                          '__text',
                                          '749376daa2364b02e990cdfdb75449de79c1aa5e426db70ca83dba025b77155c'],
 'convoy_lifecycle_capital_death_effects': [634682,
                                            4064,
                                            '__text',
                                            '1fcae1e52a8e660198a8848c7aaf10a4d899c62314132da2eb1fcbd6462569f7'],
 'convoy_lifecycle_default_attachment': [-81548,
                                         948,
                                         '__text',
                                         '88437b7848d85fadf366a7bec5c102e8f85b0aa6455fb37d60ea50e6c8ca5d6f'],
 'convoy_lifecycle_small_ship_constructor': [605720,
                                             2562,
                                             '__text',
                                             '69ffded45ed01c0720d4524c45cb78a5be444af55b84ea7c93f85df3bf003325'],
 'convoy_lifecycle_large_ship_constructor': [631792,
                                             1108,
                                             '__text',
                                             'da32bb3227d19f7636735e421a93bb29534de26db93526df2a102370f9e37d2f'],
 'convoy_lifecycle_hostility': [808072,
                                128,
                                '__text',
                                '209daf40d4ec5e88c1313c37445ee4a0ef33d73404653b3a058a617a037fae4d'],
 'convoy_lifecycle_friendliness': [808200,
                                   128,
                                   '__text',
                                   'a32c7ef7f73abed32663bdf810d8affba26b4f3c3dccb168afc7abfaa939f8ed']}

# Android spans inside named functions and their tables; the values are VALUES.
ANDROID = {# Level::createShip gives hull 14 the battleship explosion model 18304.
           'convoy_lifecycle_factory_death_model': ('_ZN5Level10createShipEiiiP8Waypointbb', 0, 3112, 'sha256:678eef9996991343994b4360f4e6ce25dc05eb2aab54b3b5f09e665f7f83d91c'),
           'convoy_lifecycle_death_model_context': ('_ZN17PlayerFixedObject16setWreckedMeshIdEi', 0, 192, 'sha256:0eddfaaefee7aa0a7ffe17609b092f742042a0adf689940f1cea6f89c4a5f57c'),
           # PlayerFixedObject::update: the capital death (materials 34716 and 33356, one capital kill, medal 39).
           'convoy_lifecycle_capital_death_effects': ('_ZN17PlayerFixedObject6updateEi', 0, 2888, 'sha256:f84fa1d1be257b92fd04b8e98c2c500190c596804150929bb95ecb8d0da7a252'),
           'convoy_lifecycle_default_attachment': ('_ZN8KIPlayerC2EiiP6PlayerP10AEGeometryfffb', 0, 604, 'sha256:3a02b0c7ce6b25d113ff6b119a914a61a149997d03f3853b159537f02d2efee8'),
           'convoy_lifecycle_small_ship_constructor': ('_ZN13PlayerFighterC2EiiP6PlayerP10AEGeometryfffb', 0, 1668, 'sha256:9722fa1dff717e74e4f5d93a1ee0e2af195659b26021723e8d5632f5ba9eaf91'),
           'convoy_lifecycle_large_ship_constructor': ('_ZN17PlayerFixedObjectC2EiiP6PlayerP10AEGeometryfff', 0, 804, 'sha256:8e92f8e152d9f1a0c3d99ecc26346df1f048501ee0014047ed2c3a1d67aaec75'),
           # Standing: Terrans (axis 0) turn hostile below -70 and friendly above 70.
           'convoy_lifecycle_hostility': ('_ZN8Standing7isEnemyEi', 0, 118, 'sha256:e48dc557d39a1d28df8cd83c0ffd928da627c0a2e569b8c51369bd5c27b71ce0'),
           'convoy_lifecycle_friendliness': ('_ZN8Standing8isFriendEi', 0, 120, 'sha256:3e77281a49c10603f4c6dc5ce9fa3a5eda0e86c1610935ddc7c30ffcc65d92c4')}
