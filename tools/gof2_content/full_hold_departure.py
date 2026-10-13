"""Second Mac mining departure data. No original code is executed or emitted.

Android: Status::nextCampaignMission's cursor-4 case clears the cargo
(Ship::setCargo) and creates mission 154 at station 78 with status value 25;
ModStation::leaveStation and ModStation::OnTouchEnd launch after the
confirmation (text 386) with the cache reset; Status::departStation keeps
the mission; MGame::OnInitialize restores or refreshes the player pools.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols
from .station_exterior import declaration_bytes

def extract_full_hold_departure(mach, arrival, departure, station_return):
    if mach.architecture == 'android-armv7':
        try:
            if departure['scope'] != 'first_station_departure' or station_return['scope'] != 'first_mining_station_return': return {}
            if station_return['cursor_after_acknowledgement'] != 4 or station_return['next_mission_kind'] != 154 or station_return['next_mission_parameter'] != 25: return {}
        except (KeyError, TypeError): return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(VALUES, provenance=proof) if proof else {}
    if mach.architecture != 'x86_64': return {}
    try:
        if departure['scope'] != 'first_station_departure' or station_return['scope'] != 'first_mining_station_return': return {}
        if station_return['cursor_after_acknowledgement'] != 4 or station_return['next_mission_kind'] != 154 or station_return['next_mission_parameter'] != 25: return {}
        origin = arrival['provenance']['actor']
        if origin['bytes'] != 315: return {}
        layouts = [{key: [row[2], row[0], row[1], row[3]] for key, row in layout.items()}
                   for layout in [LAYOUTS, MAC_ALTERNATE]]
        proof = recognize(mach, origin['offset'], layouts, reader=declaration_bytes)
        if not proof: return {}
        result = copy.deepcopy(VALUES)
        result['provenance'] = proof
        return result
    except (KeyError, TypeError, ValueError, IndexError, OverflowError): return {}

VALUES = {'scope': 'full_hold_station_departure',
 'campaign_cursor': 4,
 'station_id': 78,
 'system_id': 15,
 'ship_id': 0,
 'source_state': 2,
 'world_type': 3,
 'confirmation_text_id': 386,
 'confirmation_required': True,
 'cache_reset': -1,
 'initial_cargo_used': 0,
 'audio_selector': 1,
 'previous_cursor': 3,
 'mission_kind': 154,
 'mission_parameter': 25,
 'requires_acknowledged_delivery': True,
 'requires_empty_cargo': True}

LAYOUTS = {'launch_gates': [437002,
                  744,
                  '__text',
                  'sha256:d0d030d90cc9a541d9a0dfe7b4a8243ec945b80f80a66eaa331ba9603b505d40'],
 'accepted_departure': [431746,
                        259,
                        '__text',
                        '498bbdb00000004489fe4489f2e834b0eeff83f8010f841506000085c00f85f50e000041f6851a010000010f84d200000041c6851a01000000488d1dc0a41e00488b3be862810600488b1b83f830752b488d05a1a41e00488b38be3a000000e8a25befff4889df4889c6e8c97a0600488d05daab1e00c60001eb134889dfe8df8006004889df4889c6e8aa7a0600488d056ba41e00488b08c781a8000000ffffffff488b08c781a0000000ffffffff488b08c781a4000000ffffffff488d0d6da51e00488b00c780ac000000ffffffff488b39e8f855eeff488d0569a41e00488d0d56ab1e00c70101000000488b38be02000000e89fee0d0041c6454000e9150e0000'],
 'mission_dispatch': [871418, 4, '__text', 'a8d5ffff'],
 'mission_factory': [860566,
                     82,
                     '__text',
                     '498bbe0002000031f6e88a05feffbf98000000e87e600a004889c34889dfbe9a00000031d2b94e000000e8d3f5f8ff4c89f74889dee8c8fbffff498b8610020000488b4008488b38be19000000e8cafaf8ff'],
 'station_keeps_ship': [414806,
                        548,
                        '__text',
                        'sha256:57804cdda50a7f2f996f3ed5d980a21aec957ba064c75ff335719a6b87c46d83'],
 'negative_pool_restore': [335297,
                           128,
                           '__text',
                           '488d05ba1d2000488b008bb0a800000085f67816498b4660488b38e8d5130300488d059a1d2000488b008bb0a000000085f67816498b4660488b38e8d3130300488d057a1d2000488b008bb0a400000085f67816498b4660488b38e8df130300488d055a1d2000488b008bb0ac00000085f6780c498b4660488b38e8df130300'],
 'ordinary_pool_refresh': [335425,
                           207,
                           '__text',
                           '498b7e60e84e5e0300488d05311d2000488b38e8d3f9070083f85f0f84ae0000004c8d25191d2000498b3c24e89cf907004889c7e816030600498b0c248981a8000000498b3c24e881f907004889c7e837030600498b0c248981a0000000498b3c24e866f907004889c7e8d6020600498b0c248981a4000000498b0424c780ac00000064000000498b1c244889dfe810f907004889c7e8bcde07004189c7498b3c24e844f907004889df4489fe89c2e8394908000f57c90f2ec175137a11498b4660488b38be64000000e810130300'],
 'cargo_clear': [730926,
                 112,
                 '__text',
                 '554889e54156534989fe4989767841c74610000000004885f67423833e00741e31db488b4608488b3cd8e8958ef3ff4101461048ffc3498b76783b1e72e44c89f7e8a8f2ffff418b46284103460c412b4610488d0dfb131a00488b0939813c0100007d0689813c0100005b415e5dc390'],
 'gamma_environment': [878638,
                       300,
                       '__text',
                       '554889e54157415653504189d789f34989fe488d053bd31700488b00488bb8080200004885ff7419e86fb4f8ff3db7000000750df30f1005b4e00a00e9b60000008d43930f57c083f8040f87a70000004183ff697f3583f8040f8795000000f30f100521590a00488d0daa000000486304814801c8ffe0f30f10058da20a00eb76f30f1005b72c0a00eb6c4181be780200009d0000007f4583f8047757f30f1005db580a00488d0d58000000486304814801c8ffe0f30f10056f590a00eb38f30f1005ad280a00eb2ef30f10058b280a00eb24f30f1005e59f0a00eb1a83fb6d0f94c00fb6c0488d0d07e00a00f30f100481eb030f57c04883c4085b415e415f5dc36690f3ffffffb1ffffffbbffffffc5ffffffcfffffffdfffffff5fffffff5fffffffbbffffff69ffffff']}

# Complete independently verified alternate Mac layout.
MAC_ALTERNATE = {'launch_gates': [437438,
                  820,
                  '__text',
                  'sha256:b42951550f5c6a726503b78855f078637d3d93139a66928ea83d253b3995dd64'],
 'accepted_departure': [432174,
                        259,
                        '__text',
                        '498bbdb00000004489fe4489f2e88097eeff83f8010f841506000085c00f85fd0e000041f68522010000010f84d200000041c6852201000000488d1dec4a1e00488b3be82e820600488b1b83f830752b488d05cd4a1e00488b38be3a000000e8f642efff4889df4889c6e8957b0600488d051e521e00c60001eb134889dfe8ab8106004889df4889c6e8767b0600488d05974a1e00488b08c781a8000000ffffffff488b08c781a0000000ffffffff488b08c781a4000000ffffffff488d0da14b1e00488b00c780ac000000ffffffff488b39e8443deeff488d05954a1e00488d0d92511e00c70101000000488b38be02000000e89bce0d0041c6454000e91d0e0000'],
 'mission_dispatch': [872050, 4, '__text', 'a8d5ffff'],
 'mission_factory': [861198,
                     82,
                     '__text',
                     '498bbe0002000031f6e88a05feffbf98000000e852fc09004889c34889dfbe9a00000031d2b94e000000e85ff5f8ff4c89f74889dee8c8fbffff498b8610020000488b4008488b38be19000000e856faf8ff'],
 'station_keeps_ship': [415224,
                        550,
                        '__text',
                        'sha256:d5257e11b5fe0a6fa07ead67b399f5395374ffd70e3632899dd9351038fa73d9'],
 'negative_pool_restore': [334997,
                           128,
                           '__text',
                           '488d05bec61f00488b008bb0a800000085f67816498b4660488b38e819170300488d059ec61f00488b008bb0a000000085f67816498b4660488b38e817170300488d057ec61f00488b008bb0a400000085f67816498b4660488b38e823170300488d055ec61f00488b008bb0ac00000085f6780c498b4660488b38e823170300'],
 'ordinary_pool_refresh': [335125,
                           207,
                           '__text',
                           '498b7e60e892610300488d0535c61f00488b38e877fd070083f85f0f84ae0000004c8d251dc61f00498b3c24e840fd07004889c7e8b2060600498b0c248981a8000000498b3c24e825fd07004889c7e8d3060600498b0c248981a0000000498b3c24e80afd07004889c7e872060600498b0c248981a4000000498b0424c780ac00000064000000498b1c244889dfe8b4fc07004889c7e860e207004189c7498b3c24e8e8fc07004889df4489fe89c2e8dd4c08000f57c90f2ec175137a11498b4660488b38be64000000e854160300'],
 'cargo_clear': [731558,
                 112,
                 '__text',
                 '554889e54156534989fe4989767841c74610000000004885f67423833e00741e31db488b4608488b3cd8e81d8cf3ff4101461048ffc3498b76783b1e72e44c89f7e8a0f2ffff418b46284103460c412b4610488d0d5bb91900488b0939813c0100007d0689813c0100005b415e5dc390'],
 'gamma_environment': [879270,
                       300,
                       '__text',
                       '554889e54157415653504189d789f34989fe488d059b781700488b00488bb8080200004885ff7419e8fbb3f8ff3db7000000750df30f1005f47c0a00e9b60000008d43930f57c083f8040f87a70000004183ff697f3583f8040f8795000000f30f100501f50900488d0daa000000486304814801c8ffe0f30f1005ad3e0a00eb76f30f100587c80900eb6c4181be780200009d0000007f4583f8047757f30f1005bbf40900488d0d58000000486304814801c8ffe0f30f10054ff50900eb38f30f10057dc40900eb2ef30f10055bc40900eb24f30f1005053c0a00eb1a83fb6d0f94c00fb6c0488d0d477c0a00f30f100481eb030f57c04883c4085b415e415f5dc36690f3ffffffb1ffffffbbffffffc5ffffffcfffffffdfffffff5fffffff5fffffffbbffffff69ffffff']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {# ModStation::leaveStation, the accepted confirmation (text 386), the destination and the -1 cache
           # reset with source state 2 (ModStation::OnTouchEnd); Status::departStation keeps the mission.
           'launch_gates': ('_ZN10ModStation12leaveStationEv', 0, 684, 'sha256:312550b1ddc5c8aaf2d57ee470e9d8eb501690835f2699e068ebed55c62b4120'),
           'accept': ('_ZN10ModStation10OnTouchEndEiiPv', 1808, 20, '94f8ae00002800f0f580dff89c08002184f8ae10'),
           'destination': ('_ZN10ModStation10OnTouchEndEiiPv', 1982, 60, 'sha256:541dddffa5fcde9b38a23b46e21b70bae0b7abc96e406344c4a61f8ccfd0c6f0'),
           'cache_reset_and_state': ('_ZN10ModStation10OnTouchEndEiiPv', 2532, 84, 'sha256:0617b3f4542623e94b12edfb7d5c49d9a0a8d22dd1e10929cef4c416c59bdd41'),
           'mission_selection': ('_ZN6Status13departStationEP7Station', 0, 1072, 'sha256:b7432b338855a0a259aa2b3d0d678bb305ea5293e9903e68114efafe3b6170d6'),
           # Status::nextCampaignMission: cursor 4 (tbh entry 3) clears the cargo (Ship::setCargo(0)) and
           # creates mission 154 at station 78 with status value 25.
           'mission_dispatch': ('_ZN6Status19nextCampaignMissionEb', 74, 2, 'ac0c'),
           'mission_factory': ('_ZN6Status19nextCampaignMissionEb', 6556, 52, 
                               'c4f8e8310021c9e900ced4f88c01b3f7cced6420aff7e4eb05469a2100224e23b3f77aed20462946b3f782edd4f89401192129e3'),
           'mission_parameter': ('_ZN6Status19nextCampaignMissionEb', 8228, 14, '4068006801b0bde8f04320f17fb9'),
           # The kept ship: empty cargo counts 0 (Ship::setCargo, Ship::getCurrentLoad) and Ship::clone.
           'cargo_clear': ('_ZN4Ship8setCargoEP5ArrayIP4ItemE', 0, 92, 'sha256:71a00bf8d9656ccfc6fe7984f4d7e5663bef8a101d0b3aa4cd3f566af6554bcf'),
           'cargo_used': ('_ZN4Ship14getCurrentLoadEv', 0, 4, '00697047'),
           'station_keeps_ship': ('_ZN4Ship5cloneEv', 0, 136, 'sha256:021703f0f9e1b9c2368f4fc1d6c7083fd5be4f7bf12daa095d2b717f6ad0f091'),
           # MGame::OnInitialize: world 3, cache values >= 0 restore the pools, else the ship maxima and
           # gamma 100 when the station has no gamma damage (Status::getGammaRayDamagePerSecond); audio selector 1.
           'world_entry': ('_ZN5MGame12OnInitializeEv', 618, 40, 'sha256:5de34cff731716588906fd2eae404c607a5931b9bf1459e0e252272691040ba5'),
           'negative_pool_restore': ('_ZN5MGame12OnInitializeEv', 670, 112, 'sha256:7963d0f30c3fd2ff266acceeb577fd6a477da47ac30ad754becb9fa9af2ca86a'),
           'ordinary_pool_refresh': ('_ZN5MGame12OnInitializeEv', 782, 126, 'sha256:6925d90120932aaebde49080a4670f6553faa9995f9d8cf92f018c223d54a60c'),
           'gamma_environment': ('_ZN6Status26getGammaRayDamagePerSecondEii', 0, 80, 'sha256:d2344fecf64f4c5be2745d07ee0f160583c95f1fccb92bb2b543497c95488677'),
           'audio_selector_consumer': ('_ZN5MGame12OnInitializeEv', 2072, 48, 'sha256:9fdb99239d5f6ba5cc6cb23bdc94dc948495413f184d6f7b605e45063a485e38')}
