"""Source-bound Alioth portal and ordinary flight declarations.

Android: Level::createSpace builds the portal (model 16994) and
PlayerWormHole::update opens it over 3000 ms, closes it from 60000 ms and hides
it after 63001 ms (extent / 4096, scale shift 4 x 1/65536, facing + 0.5);
PlayerWormHole's constructor, reset, open, getPosition and render complete it.
Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_alioth_flight(mach,arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'alioth_flight_environment',
 'campaign_cursor': 16,
 'station_id': 98,
 'system_id': 19,
 'portal': {'model_id': 16994,
            'environment_slot': 3,
            'initial_elapsed_ms': 0,
            'initial_extent': 4096,
            'open_duration_ms': 3000,
            'close_start_ms': 60000,
            'hide_at_ms': 63001,
            'extent_scale': 4096,
            'model_scale_shift': 4,
            'model_scale_fraction': 1.52587890625e-05,
            'facing_x_offset': 0.5,
            'animation_advances_while_hidden': True,
            'closed_relocates': False}}

LAYOUTS = {'alioth_flight_portal_update': [655588,
                                 1380,
                                 '__text',
                                 '89f80ffadde43646b4c1835e9d937383e24ee8c0a882b7ef82e2261216b5f48c'],
 'alioth_flight_portal_vtable': [2401610,
                                 192,
                                 '__const',
                                 '0a963858cb5fc394999ebd61ba2f26b5a9e8ad750b567160454cc4abf66127ff'],
 'alioth_flight_portal_draw': [656968,
                               34,
                               '__text',
                               '2e6d1c311034330e95a597ba4646344a83a04ec5084b193e93c7280bbb55ea84'],
 'alioth_flight_portal_facing': [655548,
                                 26,
                                 '__text',
                                 '3f78d8ccdbeeb4ae6d48960cb5ac43e19e1078243e4251553eb31b603e8e0f0e'],
 'alioth_flight_portal_duration': [1546010,
                                   4,
                                   '__const',
                                   '99157bb0f934b23e522c1509fced2b666b562a3fa366b3c8857144536d43033a'],
 'alioth_flight_portal_extent': [1588942,
                                 4,
                                 '__const',
                                 'a34908edd12760df9e8f2b8a4afc349744ea5772b0ab93d3aff276d21b17b4f0'],
 'alioth_flight_portal_scale': [1575014,
                                4,
                                '__const',
                                '54e347282ecf0fd46f002970fa012534725e0bf3b2ad2f4ca0efc0134d7e1d28'],
 'alioth_flight_portal_facing_offset': [1544586,
                                        4,
                                        '__const',
                                        'd99e58435243d9fef9c88273b8d553b4fba4d0baf8009d29eae74fa99e0d9f57']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'alioth_flight_portal_update': [656136,
                                 1380,
                                 '__text',
                                 '298ee693d2bd261a3c09dd233a0b5a5b03e2c1b9326303db3a0609b239f9bb9a'],
 'alioth_flight_portal_vtable': [2379042,
                                 192,
                                 '__const',
                                 '76cec448c2abba81f2d4369f08ef9fe5ac55d0cd68714a46f6ae86d5c1fda8b1'],
 'alioth_flight_portal_draw': [657516,
                               34,
                               '__text',
                               '2e6d1c311034330e95a597ba4646344a83a04ec5084b193e93c7280bbb55ea84'],
 'alioth_flight_portal_facing': [656096,
                                 26,
                                 '__text',
                                 '13e37d5e6a5d9a16bab441c8539bc1dfbfe1dd220795ff3587728341ba144922'],
 'alioth_flight_portal_duration': [1520994,
                                   4,
                                   '__const',
                                   '99157bb0f934b23e522c1509fced2b666b562a3fa366b3c8857144536d43033a'],
 'alioth_flight_portal_extent': [1564038,
                                 4,
                                 '__const',
                                 'a34908edd12760df9e8f2b8a4afc349744ea5772b0ab93d3aff276d21b17b4f0'],
 'alioth_flight_portal_scale': [1550078,
                                4,
                                '__const',
                                '54e347282ecf0fd46f002970fa012534725e0bf3b2ad2f4ca0efc0134d7e1d28'],
 'alioth_flight_portal_facing_offset': [1519570,
                                        4,
                                        '__const',
                                        'd99e58435243d9fef9c88273b8d553b4fba4d0baf8009d29eae74fa99e0d9f57']}

# Android spans inside named functions and their tables; the values are VALUES.
ANDROID = {# PlayerWormHole::update: opens over 3000 ms, closes from 60000 ms, hides after 63001 ms; extent / 4096 scaled by 1/65536 << 4, facing + 0.5.
           'alioth_flight_portal_update': ('_ZN14PlayerWormHole6updateEi', 0, 1176, 'sha256:b5acf6c94d686058f788074d04453f1206c112e0f5cc437b026ae78c58850d44'),
           'alioth_flight_portal_constructor': ('_ZN14PlayerWormHoleC2EiP10AEGeometryfffb', 0, 156, 'sha256:3927c922ca5de71c81cd38545f9b628e207c6d288b51542aeb45894154fe41df'),
           'alioth_flight_portal_reset': ('_ZN14PlayerWormHole5resetEb', 0, 18, '002918bf4ef278614ff48052c0e954127047'),
           'alioth_flight_portal_open': ('_ZN14PlayerWormHole4openEv', 0, 16, '4ff248410022cff6ff71c0e954127047'),
           'alioth_flight_portal_draw': ('_ZN14PlayerWormHole11getPositionEv', 0, 38, 'sha256:fbe4aea3ef08ef5db9075367e2174fb941d4a247afbc32013ae5c910101a90c8'),
           'alioth_flight_portal_facing': ('_ZN14PlayerWormHole6renderEv', 0, 14, '90f8f11011b1806827f10db87047'),
           # Level::createSpace: the portal is model 16994 in environment slot 3.
           'alioth_flight_portal_model': ('_ZN5Level11createSpaceEv', 0, 3668, 'sha256:407ff360bb0ce9685a07653897850772aad545364475333f63f21dabb48175d7')}
