"""Original early Mido normal-hit and freighter collision declarations.

These declarations do not unlock a mission or supply destruction behavior.

Android: Level::createShip builds the freighter (hull x5, the race-3 boxes),
KIPlayer's and Player's constructors the actor (mode 0, active) and its
statistics, Player::damage the normal hit; PlayerFixedObject's constructor,
setPosition, outerCollide and update (hostility), KIPlayer::outerCollide,
BoundingAAB's constructor (half extents) and outerCollide and
Gun::calcCharacterCollision the point collisions. Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants
from .ambient_population import VALUES as POPULATION_VALUES

def extract_ambient_combat(mach,arrival,population):
    if not isinstance(population,dict) or any(population.get(key)!=value for key,value in POPULATION_VALUES.items()):return {}
    if mach.architecture=='android-armv7':
        proof=recognize_symbols(mach,ANDROID) if arrival else {}
        if not proof:return {}
        result=copy.deepcopy(VALUES);result['provenance']=proof
        return result
    _variant,proof=hashed_variants(mach,arrival,[LAYOUTS,MAC_ALTERNATE])
    if not proof:return {}
    result=copy.deepcopy(VALUES);result['provenance']=proof
    return result

VALUES = {'scope': 'early_mido_ambient_combat',
 'campaign_cursor': 11,
 'station_id': 79,
 'system_id': 15,
 'actor_kind': 3,
 'supported_ranks': [0, 1, 2],
 'initial_actor_mode': 0,
 'initial_active': True,
 'freighter': {'subtype': 1,
               'hull_catalogue_id': 15,
               'hull_multiplier': 5,
               'point_geometry': True,
               'boxes': [{'offset': [0, -199, 4708], 'half_extents': [490, 765, 620]},
                         {'offset': [0, -14, -98], 'half_extents': [2250, 702.5, 4430]}]}}

LAYOUTS = {'factory': [77944,
             3478,
             '__text',
             '9b9cfd3e564cc131a926a3f0704be2479fa2ee4dcf4c291e129e904aeb57b6cb'],
 'base_actor': [-81548,
                948,
                '__text',
                'f12861749d41ef2ca9eac32cd4814ba5a3e3e9b12d3d34206d636457a5c0835e'],
 'statistics': [534164,
                980,
                '__text',
                'e235632f01e8c249256c9ec437003dd47e24d213c1f137d04836fab3437d958b'],
 'freighter_constructor': [631244,
                           1108,
                           '__text',
                           '39596638f6c7393a8e4af981e4162d2f1ffeb8e3f51bf20045112a50014d0da6'],
 'normal_hit': [538936,
                1846,
                '__text',
                'bf43e8c8d5ea3461a0c97d0794cf51c69df8f95220efcaf59786d0042e357778'],
 'point_wrapper': [-76580,
                   26,
                   '__text',
                   '9bead5a886f6540a33e6b291db2ce8b8ce31f47b43028700a06efa9ae6676fb0'],
 'freighter_point': [638832,
                     218,
                     '__text',
                     'f3939053e839e83f54fc8886f028bf8daef9d07c152b299addb966381e760e57'],
 'box_constructor': [-710254,
                     138,
                     '__text',
                     '26f9914c4ae9807b7ead0893f11d3b516edb4916968681a9c74a4ad086080962'],
 'box_point': [-710024,
               122,
               '__text',
               'ed39d6edebadeaa30e762599d6c92439c73a5786159abc733801b6cf712a8f76'],
 'freighter_position': [633042,
                        280,
                        '__text',
                        '241b12d3d590c5c8684aecacf28bc717857e2a440cb61c439f7b0a06fda7f26f'],
 'projectile_point_selection': [-181241,
                                192,
                                '__text',
                                '514132460b0c5a267454acc7f8ba7a5242bf8617196ff1a7f14e2f59718c489e'],
 'freighter_hostility': [634203,
                         154,
                         '__text',
                         'eedbaf93e238e789270652b36e3295696d78817ee0177c3e75cc144136cf0575'],
 'box_values': [1575362,
                32,
                '__const',
                'abbc25d14673f54cff918e1102c121ccada75722b5dce4ec0e6e32502637896c'],
 'half_extent_scale': [1544586,
                       4,
                       '__const',
                       'd99e58435243d9fef9c88273b8d553b4fba4d0baf8009d29eae74fa99e0d9f57']}


MAC_ALTERNATE = {'factory': [77944, 3478, '__text', '1edb599619eeabcc4601e757d01307eba28fc1a7bfb5ea74ea86ef4b365fcbf3'],
 'base_actor': [-81548, 948, '__text', '88437b7848d85fadf366a7bec5c102e8f85b0aa6455fb37d60ea50e6c8ca5d6f'],
 'statistics': [534700, 980, '__text', 'f74bfc6d9e7e68d48cb5b5ae52bc98df1c187a60f4df61330abdecf1bcf553fd'],
 'freighter_constructor': [631792,
                           1108,
                           '__text',
                           'da32bb3227d19f7636735e421a93bb29534de26db93526df2a102370f9e37d2f'],
 'normal_hit': [539472, 1846, '__text', '407b208cd78b7b7e70b5bc505bc9509f70781ad9d1af9c2b9a9f80104cd54242'],
 'point_wrapper': [-76580, 26, '__text', '9bead5a886f6540a33e6b291db2ce8b8ce31f47b43028700a06efa9ae6676fb0'],
 'freighter_point': [639380,
                     218,
                     '__text',
                     'f3939053e839e83f54fc8886f028bf8daef9d07c152b299addb966381e760e57'],
 'box_constructor': [-716150,
                     138,
                     '__text',
                     'ed1b33eabc9ac0588b159815a2100fdf8b20ca75e7019d44467390d4b60fb660'],
 'box_point': [-715920, 122, '__text', 'ed39d6edebadeaa30e762599d6c92439c73a5786159abc733801b6cf712a8f76'],
 'freighter_position': [633590,
                        280,
                        '__text',
                        'fdfb300814052a7b8fadea53652fee5b0557ca5c5b48d48304398659bc426237'],
 'projectile_point_selection': [-181733,
                                192,
                                '__text',
                                '591e882df968a35960bcddd6d8bc0cf9242e782cbf320030727ee07138d8e57b'],
 'freighter_hostility': [634751,
                         154,
                         '__text',
                         '36e02ad30f047a9e0a0e4417dadd7b5a80b6bfc0e03ec1daa13da4eb0ddc5c5c'],
 'box_values': [1550426, 32, '__const', 'abbc25d14673f54cff918e1102c121ccada75722b5dce4ec0e6e32502637896c'],
 'half_extent_scale': [1519570,
                       4,
                       '__const',
                       'd99e58435243d9fef9c88273b8d553b4fba4d0baf8009d29eae74fa99e0d9f57']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {# Subtype 1: a PlayerFixedObject with hull x5; race 3: two boxes (offsets and full extents), death model 18300.
           'ambient_combat_factory': ('_ZN5Level10createShipEiiiP8Waypointbb', 0, 3112, 'sha256:678eef9996991343994b4360f4e6ce25dc05eb2aab54b3b5f09e665f7f83d91c'),
           # Mode 0, active.
           'ambient_combat_base_actor': ('_ZN8KIPlayerC2EiiP6PlayerP10AEGeometryfffb', 0, 604, 'sha256:3a02b0c7ce6b25d113ff6b119a914a61a149997d03f3853b159537f02d2efee8'),
           'ambient_combat_statistics': ('_ZN6PlayerC2Eiiiii', 0, 600, 'sha256:f15c0c4c5617f8ed5b0e4e522e5dfda30338d712d628ecf861a9d79e6a041988'),
           'ambient_combat_freighter_constructor': ('_ZN17PlayerFixedObjectC2EiiP6PlayerP10AEGeometryfff', 0, 804, 'sha256:8e92f8e152d9f1a0c3d99ecc26346df1f048501ee0014047ed2c3a1d67aaec75'),
           'ambient_combat_normal_hit': ('_ZN6Player6damageEibi', 0, 1376, 'sha256:577391dd7b7a6d8ee3273ce37004ea80f21a4f1a173666529c7b926f4449f3d5'),
           # Points test the freighter's boxes (half the full extents).
           'ambient_combat_point_wrapper': ('_ZN8KIPlayer12outerCollideERKN11AbyssEngine6AEMath6VectorE', 0, 26, 'sha256:f17e832adf701edfbae43085c2eee53d9a06a6a41bf0fb96dc70f9be22857316'),
           'ambient_combat_freighter_point': ('_ZN17PlayerFixedObject12outerCollideEfff', 0, 148, 'sha256:2b8d1feff21a6ac17690be9e8d7e03dea48be571433282b0d7323310809b8992'),
           'ambient_combat_box_constructor': ('_ZN11BoundingAABC2Efffffffff', 0, 152, 'sha256:88e2b82e14a97cf1bcc053f19e3bbd4ecbb97bc093ad8e92e36157a5098663bc'),
           'ambient_combat_box_point': ('_ZN11BoundingAAB12outerCollideEfff', 0, 158, 'sha256:b8089f86f85235aaa8e5a2aca0acb9d26a41e44b224ff50c8ec55c4712f274a5'),
           'ambient_combat_freighter_position': ('_ZN17PlayerFixedObject11setPositionEfff', 0, 204, 'sha256:108d1b61120403f2e1f74f8e23ff699fe4f0ad3aecad25a82f1d0307cfaa5ad2'),
           'ambient_combat_projectile_points': ('_ZN3Gun22calcCharacterCollisionEv', 0, 2024, 'sha256:ee0110d3a7495e15d266903440f69f9b21dd2a6b23b30b4a5aafb5e4720eab9b'),
           # Races 8 and 9 are enemies; others by standing.
           'ambient_combat_freighter_hostility': ('_ZN17PlayerFixedObject6updateEi', 0, 2888, 'sha256:f84fa1d1be257b92fd04b8e98c2c500190c596804150929bb95ecb8d0da7a252')}
