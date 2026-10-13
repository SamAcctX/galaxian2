"""Source-specific Kappa departure requirements. Import-only constants.

Android: ModStation::leaveStation refuses (text 520, Android id 531) to leave
the target station at cursor 20, and at cursor 21 unless the ship carries at
least one of items 41-43 (Ship::hasEquipment); Status, Station, Mission, Item
and Ship getters complete it. Values are the Mac 1.0.7 ones (MAC_VALUES).
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_kappa_departure(mach, arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(MAC_VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy((VALUES, MAC_VALUES)[variant]), proof) if proof else ({}, {})

VALUES = {'scope': 'kappa_station_departure',
 'preparation_cursor': 20,
 'rescue_cursor': 21,
 'target_station_only': True,
 'installed_item_ids': [41],
 'minimum_quantity': 1,
 'refusal_text_id': 520}

LAYOUTS = {'kappa_departure_launch': [437002,
                            744,
                            '__text',
                            'd0d030d90cc9a541d9a0dfe7b4a8243ec945b80f80a66eaa331ba9603b505d40'],
 'kappa_departure_installed_quantity': [730284,
                                        106,
                                        '__text',
                                        'd322613970be53ee9873ab4809336bbefb3539ee5b24e99e5b759baac900dca3'],
 'kappa_departure_item_id': [-84678,
                             8,
                             '__text',
                             '46e7df051d544d763be777fd992892f1904ae1956482595eac68f089656cd596'],
 'kappa_departure_item_quantity': [-84494,
                                   9,
                                   '__text',
                                   '221a001bb6968eee5817d95a055aa8ff5b5ce6d2af636b128c7e0c544b4153ab'],
 'kappa_departure_station_id': [851352,
                                9,
                                '__text',
                                '51fb1dcf2edddabe3d0b0cfb84542175c990f2b03e95668e5f713b584b9ab817'],
 'kappa_departure_mission_station': [400888,
                                     9,
                                     '__text',
                                     'd51650db0d3ab68b287a1c439e14f1bf7889629e896ab148d32ef52d70fd0cec'],
 'kappa_departure_inventory': [858126,
                               13,
                               '__text',
                               'a85a422bc4ba2fd3ca47339b1cbca25d19fff857c40efca32eaf13471817cb8c'],
 'kappa_departure_station': [858084,
                             13,
                             '__text',
                             'c55ad102dc49abfb7aec0ee3fc82e57683fc4f4a0f78604926c25de66a86a7a2'],
 'kappa_departure_mission': [858168,
                             20,
                             '__text',
                             '96c6d6a3f7701ede45291df93e760bc3cf70887ebf7d7fe1a652f3863227a4ca'],
 'kappa_departure_cursor': [858156,
                            12,
                            '__text',
                            '57d338d367eed66aba7f519da867a0a180e1608c52476ddc2eed325740b689d1'],
 'kappa_departure_installed_slots': [730042,
                                     10,
                                     '__text',
                                     '9624067a219b5715fb6aabc614cd28310a74739206a88a5fa7b6f65e0a76a0d0']}

MAC_VALUES = {'scope': 'kappa_station_departure',
 'preparation_cursor': 20,
 'rescue_cursor': 21,
 'target_station_only': True,
 'installed_item_ids': [41, 42, 43],
 'minimum_quantity': 1,
 'refusal_text_id': 520}

MAC_ALTERNATE = {'kappa_departure_launch': [437438,
                            820,
                            '__text',
                            'b42951550f5c6a726503b78855f078637d3d93139a66928ea83d253b3995dd64'],
 'kappa_departure_installed_quantity': [730916,
                                        106,
                                        '__text',
                                        'b6f1661468b6e9b8ef5b4b24bad76113a07997e2d8e44545aad4243bad8abb3e'],
 'kappa_departure_item_id': [-84678,
                             8,
                             '__text',
                             '46e7df051d544d763be777fd992892f1904ae1956482595eac68f089656cd596'],
 'kappa_departure_item_quantity': [-84494,
                                   9,
                                   '__text',
                                   '221a001bb6968eee5817d95a055aa8ff5b5ce6d2af636b128c7e0c544b4153ab'],
 'kappa_departure_station_id': [851984,
                                9,
                                '__text',
                                '51fb1dcf2edddabe3d0b0cfb84542175c990f2b03e95668e5f713b584b9ab817'],
 'kappa_departure_mission_station': [401404,
                                     9,
                                     '__text',
                                     'd51650db0d3ab68b287a1c439e14f1bf7889629e896ab148d32ef52d70fd0cec'],
 'kappa_departure_inventory': [858758,
                               13,
                               '__text',
                               'a85a422bc4ba2fd3ca47339b1cbca25d19fff857c40efca32eaf13471817cb8c'],
 'kappa_departure_station': [858716,
                             13,
                             '__text',
                             'c55ad102dc49abfb7aec0ee3fc82e57683fc4f4a0f78604926c25de66a86a7a2'],
 'kappa_departure_mission': [858800,
                             20,
                             '__text',
                             '96c6d6a3f7701ede45291df93e760bc3cf70887ebf7d7fe1a652f3863227a4ca'],
 'kappa_departure_cursor': [858788,
                            12,
                            '__text',
                            '57d338d367eed66aba7f519da867a0a180e1608c52476ddc2eed325740b689d1'],
 'kappa_departure_installed_slots': [730666,
                                     10,
                                     '__text',
                                     '9624067a219b5715fb6aabc614cd28310a74739206a88a5fa7b6f65e0a76a0d0']}

ANDROID = {# ModStation::leaveStation: cursors 20 and 21 at the target station; items 41, 42 or 43, at least one.
           'kappa_departure_launch': ('_ZN10ModStation12leaveStationEv', 198, 234, 'sha256:2e3995d34cc8a95762e4c3f23a3c6ffe2ee2d63d1318e1fdfde96fe1639e1def'),
           'kappa_departure_refusal': ('_ZN10ModStation12leaveStationEv', 554, 32, 'sha256:4e0833c1de6a12c1d40f07ba2be2bbf6ac7cf074c330052c6768dac8fd92f158'),
           'kappa_departure_installed_quantity': ('_ZN4Ship12hasEquipmentEii', 0, 76, 'sha256:a454bb4a59caed4a36c48fe2f0d109c8a9d8df513923486509133edbca2a05ef'),
           'kappa_departure_item_id': ('_ZN4Item8getIndexEv', 0, 4, '00687047'),
           'kappa_departure_item_quantity': ('_ZN4Item9getAmountEv', 0, 4, '406b7047'),
           'kappa_departure_station_id': ('_ZN7Station8getIndexEv', 0, 4, '80687047'),
           'kappa_departure_mission_station': ('_ZN7Mission16getTargetStationEv', 0, 4, '006b7047'),
           'kappa_departure_inventory': ('_ZN6Status7getShipEv', 0, 6, 'd0f88c017047'),
           'kappa_departure_station': ('_ZN6Status10getStationEv', 0, 6, 'd0f898017047'),
           'kappa_departure_mission': ('_ZN6Status18getCampaignMissionEv', 0, 10, 'd0f89401406800687047'),
           'kappa_departure_cursor': ('_ZN6Status25getCurrentCampaignMissionEv', 0, 6, 'd0f8e8017047'),
           'kappa_departure_installed_slots': ('_ZN4Ship12getEquipmentEv', 0, 4, 'c06e7047')}
