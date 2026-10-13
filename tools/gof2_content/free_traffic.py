"""Verified ordinary ship setup declarations, independent of travel permission.

Android: Level::createShip builds the Nivelian's three collision boxes
(BoundingAAB with immediate extents; the Mac reads them from a constant
table) and PlayerFighter::update picks opponents (factions 8, 9 and 10
against all others, 0 against 1, 2 against 3). Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_free_traffic(mach, arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'augmenta_ordinary_ship_setup',
 'campaign_cursor': 18,
 'opposition': {'exclusive_factions': [8, 9, 10], 'pairs': [[0, 1], [2, 3]]},
 'nivelian_boxes': [{'offset': [0, -85, 24], 'half_extents': [2167.5, 622.5, 5440]},
                    {'offset': [0, 710, 292], 'half_extents': [1495, 467.5, 5725]},
                    {'offset': [0, 1510, -2886], 'half_extents': [1375, 505, 1375]}]}

LAYOUTS = {'free_traffic_nivelian_boxes': [80500,
                                 278,
                                 '__text',
                                 '3f39eead7833aafc377395e5e9d332e0fc6d64d35efd1616ae9e81de803e5b1e'],
 'free_traffic_box_values': [1575482,
                             48,
                             '__const',
                             '61005225e16dba67c95d8c35984042cdcb6dcd0f7aa44a275b19ceefc6439e92'],
 'free_traffic_opposition': [614052,
                             268,
                             '__text',
                             'f0cef08b7978855b3ee22bba5d5a57afc0ee7e8dee6bc4d433771050e68717af']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'free_traffic_nivelian_boxes': [80500,
                                 278,
                                 '__text',
                                 '5cf5fe9055552b9825d4e5bfb02ac2a73f201ae081cdc41965ba27801cbf1705'],
 'free_traffic_box_values': [1550546,
                             48,
                             '__const',
                             '61005225e16dba67c95d8c35984042cdcb6dcd0f7aa44a275b19ceefc6439e92'],
 'free_traffic_opposition': [614600, 268, '__text', 'f3d5620be640cc069471477c50f961e0fada34885c4e70e1c75485df434c06da']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {# Level::createShip: three boxes (offset, full extents) and wreck 18301 for the Nivelian.
           'free_traffic_nivelian_boxes': ('_ZN5Level10createShipEiiiP8Waypointbb', 2200, 250, 'sha256:de31f7d86f93911e2c4d65a2ca0d45acd806bd82d33cc24e40acd966f0bfef2a'),
           # PlayerFighter::update: the exclusive factions and the two pairs.
           'free_traffic_opposition': ('_ZN13PlayerFighter6updateEi', 2174, 206, 'sha256:8e46a41fd82257d1ded1262b7fd1d1e3a1a1282c1ba8967e3201e4aa00e86a89')}
