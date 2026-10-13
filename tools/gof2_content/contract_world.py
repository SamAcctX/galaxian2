"""Original impact-table declarations; no executable payloads.

Android: Gun::setIndex looks up a gun's impact model in the item table (items
0, 3, 7, 19, 22 and 25: 14600, 14601, 14603, 14605, 14606, 14606). Values
equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_contract_world(mach, arrival):
    if getattr(mach, 'architecture', None) == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'mido_contract_world_initialization',
 'campaign_cursor': 13,
 'impact_models': [{'item_id': 0, 'resource_id': 14600},
                   {'item_id': 3, 'resource_id': 14601},
                   {'item_id': 7, 'resource_id': 14603},
                   {'item_id': 19, 'resource_id': 14605},
                   {'item_id': 22, 'resource_id': 14606},
                   {'item_id': 25, 'resource_id': 14606}]}

LAYOUTS = {'contract_world_impact_0': [1572842,
                             4,
                             '__const',
                             '2f71717123e07e2e209cc0dc807e9d1e48dd2e9d0cddb9e5238afa837b209770'],
 'contract_world_impact_3': [1572854,
                             4,
                             '__const',
                             '5d46ede9eac9a05b6830c14009889862d39d162f725c5b949cf477e10051247c'],
 'contract_world_impact_7': [1572870,
                             4,
                             '__const',
                             'a03abcf8785a21a27c62f0f7300d747792b7d3aa67ebb20c8712dd1ea7b97e77'],
 'contract_world_impact_19': [1572918,
                              4,
                              '__const',
                              'ba68c0bc07a4ca462026f5108537fb3a023f3095f79c0d4c205fde3e86089e80'],
 'contract_world_impact_22': [1572930,
                              4,
                              '__const',
                              'b18cc146d20e56ff0808059bc8ddf272dc008ee143402c5d32424175d3b54720'],
 'contract_world_impact_25': [1572942,
                              4,
                              '__const',
                              'b18cc146d20e56ff0808059bc8ddf272dc008ee143402c5d32424175d3b54720']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'contract_world_impact_0': [1547906,
                             4,
                             '__const',
                             '2f71717123e07e2e209cc0dc807e9d1e48dd2e9d0cddb9e5238afa837b209770'],
 'contract_world_impact_3': [1547918,
                             4,
                             '__const',
                             '5d46ede9eac9a05b6830c14009889862d39d162f725c5b949cf477e10051247c'],
 'contract_world_impact_7': [1547934,
                             4,
                             '__const',
                             'a03abcf8785a21a27c62f0f7300d747792b7d3aa67ebb20c8712dd1ea7b97e77'],
 'contract_world_impact_19': [1547982,
                              4,
                              '__const',
                              'ba68c0bc07a4ca462026f5108537fb3a023f3095f79c0d4c205fde3e86089e80'],
 'contract_world_impact_22': [1547994,
                              4,
                              '__const',
                              'b18cc146d20e56ff0808059bc8ddf272dc008ee143402c5d32424175d3b54720'],
 'contract_world_impact_25': [1548006,
                              4,
                              '__const',
                              'b18cc146d20e56ff0808059bc8ddf272dc008ee143402c5d32424175d3b54720']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {'contract_world_impact_lookup': ('_ZN3Gun8setIndexEi', 56, 16, '33496066794451f82580b8f1000f53db'),
           'contract_world_impact_models': ('_ZN3Gun8setIndexEi', 56, 104, 'sha256:281673842ca38e22a22daa0ae78e3ac72a58d17ec3af869219ff5e09a1b13395', 'literal', 0)}
