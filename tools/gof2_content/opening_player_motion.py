"""Recognize the fresh opening scripted player-flight declarations.

Static bounded readers emit constants/extents only. This motion precedes weapon
contacts and scripted placement; the first ordinary handoff is its scope limit.

Android: PlayerEgo's constructor leaves updates enabled and declares the
cruise speed; LevelScript's opening makes the player computer controlled
(PlayerEgo::setComputerControlled) until message 8 sets phase 4 and hands
control back; PlayerEgo::update then moves it forward by elapsed x speed
through AEGeometry::moveForward and skips ordinary maneuvering; MGame::
OnUpdate updates the player and the level before LevelScript::process.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols

VALUES = {'initial_scripted_flight':True,'scripted_ignores_throttle':True,
          'ordinary_motion_suppressed':True,'initial_update_enabled':True,
          'release_after_event_finished':8,'release_phase':4,
          'motion_before_controller':True}


def extract_opening_player_motion(mach, staging, camera, cruise, actors):
    arch=mach.architecture
    if arch == 'android-armv7':
        return android_motion(mach, staging, camera, cruise, actors)
    if arch not in LAYOUTS:return {}
    try:
        if not actors['player_initialization'] or not camera or cruise['speed_units_per_millisecond']!=2.0 or cruise['forward_axis']!=[0,0,1]:return {}
        if camera['pan']['follow_player_after_event_finished']!=VALUES['release_after_event_finished']:return {}
        initial=staging['provenance']['initial']
        if initial['bytes']!=(366 if arch=='x86_64' else 320):return {}
        origin=initial['offset']
        layouts=[LAYOUTS[arch]]+([MAC_ALTERNATE] if arch=='x86_64' else [])
        proof=recognize(mach,origin,layouts,{'speed':cruise['provenance'][0]['offset'],
                                           'forward_helper':cruise['provenance'][3]['offset']})
        if not proof:return {}
        result=copy.deepcopy(VALUES);result['provenance']=proof
        return result
    except (KeyError,ValueError,TypeError,IndexError,OverflowError):return {}


LAYOUTS = {'x86_64': {'player_before_weapons': [244328,
                                      40,
                                      'e804200300498b7d60e875ef020088c349637548498bbd90000000410fb6556b83e201e89933fcff'],
            'controller_call': [255610, 5, 'e8965afcff'],
            'player_delta': [449268, 7, '4589a684010000'],
            'initial_scripted': [65, 18, 'e8e9c0ffff4889c7be01000000e8f2b70600'],
            'scripted_setter': [440389, 13, '554889e54088b7880200005dc3'],
            'initial_update_enabled': [428577, 4, 'c6434000'],
            'update_gate': [449205, 11, '41f64640010f8579350000'],
            'scripted_gate': [454099,
                              68,
                              '418a868202000041f68688020000017512a801750e41f68681020000010f848e0000004c89ad60fbffff41c6869501000001a801740e418b868401000041018684020000'],
            'scripted_travel': [454167, 23, 'f3410f2ac4f3410f5986f8000000498b7e10e8192eecff'],
            'ordinary_suppression': [456905, 13, '0f57c041f6869501000001754d'],
            'release': [17756,
                        46,
                        '488b7840e8504f08003c010f856e2b000049c785a00000000000000041c74528040000004c89ff31f6e8bb720600'],
            'speed': [429564, 27, 'c783f8000000000000404c8d35cad01c00c783fc0000000000803f'],
            'forward_helper': [-844729,
                               42,
                               '554889e54156534881ec80000000f30f1145804889fb8b7314488b7b38e8a6cb1c004889c7e8bef71d00']},
 'armv7': {'player_before_weapons': [253418,
                                     40,
                                     '23f096fedbf854004ff0ff36b49621f095fcdbf83c1005469bf85b30dbf87000ca17b496c1f7e0f9'],
           'controller_call': [264340, 4, 'c2f7cdfd'],
           'player_delta': [400308, 4, 'cbf83061'],
           'initial_scripted': [26, 16, 'fcf7c0ff0121cdf85068012560f0cef9'],
           'scripted_setter': [394182, 6, '80f8f0117047'],
           'constructor_zero': [384198, 2, '0022'],
           'initial_update_enabled': [384452, 4, '84f82420'],
           'update_gate': [400264, 10, '9bf82400002842f0f384'],
           'scripted_gate': [404284,
                             60,
                             '9bf8ea019bf8f011002907d0cdf828a0c2468bf84141002809d10fe0002800f08b810120cdf828a0c2468bf84101dbf83001dbf8ec110844cbf8ec01'],
           'scripted_travel': [404344, 36, '46ec306b9bed2e0afbff2006dbf8080009964ff0ff36ec9600ff900d10ee101a7af641fb'],
           'ordinary_suppression': [406570, 6, '9bf8410170b9'],
           'release': [51082,
                       48,
                       '006ac4f824546cf0b7f9012877f45da8219e0df5005b04200021c6f88ca0c6f890a0b061cbf824541d9c204653f006fe'],
           'speed': [384956, 20, '4ff07e50d1f800a04ff08041c4f8b810c4f8bc00'],
           'forward_helper': [-1191394,
                              36,
                              'f0b503af2ded028b99b004460d46e168e06ad8f297f904ae01463046e4f2f2fa07a83146']}}


# One coherent Mac compiler layout; all frame/flag links retain the same contract.
MAC_ALTERNATE = {'player_before_weapons': [244051,
                           40,
                           'e831230300498b7d60e8a2f2020088c349637548498bbd90000000410fb6556b83e201e8ae34fcff'],
 'controller_call': [256122, 5, 'e89658fcff'],
 'player_delta': [449804, 7, '4589a684010000'],
 'initial_scripted': [65, 18, 'e8e9c0ffff4889c7be01000000e80aba0600'],
 'scripted_setter': [440925, 13, '554889e54088b7880200005dc3'],
 'initial_update_enabled': [429113, 4, 'c6434000'],
 'update_gate': [449741, 11, '41f64640010f8579350000'],
 'scripted_gate': [454635,
                   68,
                   '418a868202000041f68688020000017512a801750e41f68681020000010f848e0000004c89ad60fbffff41c6869501000001a801740e418b868401000041018684020000'],
 'scripted_travel': [454703, 23, 'f3410f2ac4f3410f5986f8000000498b7e10e8f914ecff'],
 'ordinary_suppression': [457441, 13, '0f57c041f6869501000001754d'],
 'release': [17756,
             46,
             '488b7840e8745108003c010f856e2b000049c785a00000000000000041c74528040000004c89ff31f6e8d3740600'],
 'speed': [430100, 27, 'c783f8000000000000404c8d358a761c00c783fc0000000000803f'],
 'forward_helper': [-850625,
                    42,
                    '554889e54156534881ec80000000f30f1145804889fb8b7314488b7b38e816d81c004889c7e89ef21d00']}


def android_motion(lib, staging, camera, cruise, actors):
    """Spans by function name; the parents are checked by value (release at message 8, cruise 2 units/ms along +Z)."""
    try:
        linked = (staging and actors['player_initialization']
                  and camera['pan']['follow_player_after_event_finished'] == ANDROID_VALUES['release_after_event_finished']
                  and cruise['speed_units_per_millisecond'] == 2.0 and cruise['forward_axis'] == [0, 0, 1])
    except (KeyError, TypeError):
        return {}
    proof = recognize_symbols(lib, ANDROID) if linked else {}
    return dict(copy.deepcopy(ANDROID_VALUES), provenance=proof) if proof else {}


# The constructor span runs from sl = 1.0 and r6 = 0 to the cruise speed store, past updates-enabled ([0x24] = r6).
ANDROID = {'player_before_weapons': ('_ZN5MGame8OnUpdateEv', 1872, 34, 'sha256:980c50d4eb27fd380d8e040ec7104a6457eb14c8e0411b30bd3a1e5f7ff69e64'),
           'controller_call': ('_ZN5MGame8OnUpdateEv', 10658, 16, 'dbf84010dbf878009bf85f40c1f608ed'),
           'update_gate': ('_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi', 56, 10, '99f82400002842f05d82'),
           'player_delta': ('_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi', 90, 4, 'c9f83481'),
           'scripted_gate': ('_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi', 3490, 300, 'sha256:6ccd26c22d4c89cde0ad0be4fe568bf399ade3b742e0f75110ad9344372301cd'),
           'scripted_travel': ('_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi', 3790, 28, 'sha256:1a8bc81ad4f3fababa7c47500932fb8cb30062125ae9488ddee58b7133c459f5'),
           'ordinary_suppression': ('_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi', 5262, 14, '9fed788a99f84501002840f0b280'),
           'ordinary_suppression_route': ('_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi', 5318, 14, '9fed6a8a99f84501002840f09680'),
           'initial_scripted': ('_ZN11LevelScriptC2EP5LevelP3HudP5RadarP18TargetFollowCamera', 520, 12, '0cf780e90121012410f77aec'),
           'scripted_setter': ('_ZN9PlayerEgo21setComputerControlledEb', 0, 6, '80f8f4117047'),
           'release': ('_ZN11LevelScript7processEi', 4336, 34, 'sha256:18508369ecea84381c33159218f1ac8638af7c83b18d6c6ba251ce45cf4ff0bf'),
           'constructor_defaults': ('_ZN9PlayerEgoC2EP6Player', 28, 626, 'sha256:3ad7cb263eac8b1acf7a2cb27b54cd717a64b15f03f8ee6d98a258bd34146529'),
           'forward_helper': ('_ZN10AEGeometry11moveForwardEf', 0, 196, 'sha256:2840a4e39050a43afb94813788a216a675bc125429812155e43fc069c1a319e5')}

ANDROID_VALUES = copy.deepcopy(VALUES)
