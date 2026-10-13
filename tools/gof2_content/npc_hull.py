"""Recognize fresh NPC hull declarations; emit data, never executable content.

Android: Level::createShip reads the cursor, bases the hull on Status::getLevel
(14 x level + 20, level capped at 20), adds 4 x cursor or 180 after
Status::gameWon, keeps it for subtype 0, scales it by the difficulty - 0.5 and
passes it to Player::Player, which stores current and maximum hull;
Player::setHitpoints raises the maximum and Player::updateDamageRate keeps the
integer percentage (x 100). Status::resetGame sets level 1 and clears the
scores Status::checkForLevelUp sums against its 21 thresholds, and
MGame::OnInitialize runs that check before building the level.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols

VALUES = {'scope': 'fresh_opening', 'rank': 0, 'campaign_cursor': 0, 'factory_subtype': 0, 'hull_catalogue_ids': [2, 23, 2], 'base_hull': 20, 'difficulty_offset': -0.5, 'percentage_scale': 100.0, 'override_raises_maximum': True}


def extract_npc_hull(mach, actors):
    if mach.architecture == 'android-armv7':
        try:
            npc = actors['npc_initialization']
            if npc['world_initialization']['campaign_cursor'] != VALUES['campaign_cursor']:
                return {}
            if [a['hull_catalogue_id'] for a in actors['actors']] != VALUES['hull_catalogue_ids']:
                return {}
        except (KeyError, TypeError):
            return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(copy.deepcopy(VALUES), provenance=proof) if proof else {}
    arch=mach.architecture
    if arch not in LAYOUTS:return {}
    try:
        npc=actors['npc_initialization']
        if npc['world_initialization']['campaign_cursor']!=VALUES['campaign_cursor']:return {}
        if [a['hull_catalogue_id'] for a in actors['actors']]!=VALUES['hull_catalogue_ids']:return {}
        anchor=npc['provenance']['factory_entry']
        if anchor['bytes']!=4:return {}
        layouts=[LAYOUTS[arch]]+([MAC_ALTERNATE] if arch=='x86_64' else [])
        proof=recognize(mach,anchor['offset'],layouts,
                        constants=[key for key in LAYOUTS[arch] if key.endswith('_constant')])
        if not proof:return {}
        for key in ['hull_setter','cursor_getter']:
            if actors['provenance'][key]!=proof[key]:return {}
        result=copy.deepcopy(VALUES);result['provenance']=proof
        return result
    except (KeyError,TypeError,IndexError,ValueError,OverflowError):return {}

LAYOUTS = {'x86_64': {'factory_arguments': [17,
                                  38,
                                  '44894db04c89c3894db88955b48975bc48897dc0488d05de0a2400488b38e880e70b004189c4'],
            'rank_base': [166,
                          46,
                          'bb2c010000488d05580a2400488b38e80c2e0c0083f8147f15488d05440a2400488b38e8f82d0c006bd80e83c314'],
            'cursor_and_hull_modifiers': [224,
                                          129,
                                          '488d05230a2400488b38e8b5e60b00428d0ca50000000084c0b8b40000000f44c101d8448b75b84183fe3374284183fe3174144183fe2c752cf30f2ac0f30f590549d81600eb1af30f2ac0f30f590537d81600eb0cf30f2ac0f30f5905c5901600f30f2cc04183fc380f94c1418d5424cf83fa040f92c208cabb0e0100000f44d8'],
            'subtype': [399,
                        43,
                        '41bf983a0000837db401751f478d6c6d004183fe0e740b41bfc8af00008d1c9beb096bdb1941bfc8af0000'],
            'difficulty': [442,
                           73,
                           'f30f2ac3488d05a9092400f30f10482cf30f580d48d11600f30f59c8f30f58c8f3440f2cf14181fc9a000000751b488d051b092400488b38e85be50b00837dbc090f94c120c141d3e6'],
            'stats_argument': [558,
                               27,
                               '4c89e789de4489f2b90100000041b8010000004531c9e8c9f30600'],
            'stats_wrapper': [456210, 10, '554889e55de900000000'],
            'initial_capacity': [456393, 12, '89938000000089938c000000'],
            'hull_setter': [459070,
                            30,
                            '554889e589b78000000039b78c0000007d0689b78c0000005de994f8ffff'],
            'percentage': [457204,
                           42,
                           'f30f2a878c000000f30f2a8f80000000f30f5ec8f30f100536970f00f30f59c8f30f2cc18987a0000000'],
            'rank_getter': [798406, 12, '554889e58b87580200005dc3'],
            'rank_reset': [802796, 11, '41c7865802000001000000'],
            'cursor_getter': [780212, 12, '554889e58b87780200005dc3'],
            'cursor_predicate': [780196,
                                 16,
                                 '554889e583bf780200002c0f9fc05dc3'],
            'difficulty_constant': [1495834, 4, '000000bf'],
            'percentage_constant': [1478982, 4, '0000c842'],
            'entry_rank': [257276,
                           48,
                           '488d05071e2000488b38e879400800bf50030000e89f6412004889c34889dfbe03000000e8712cfaff49899e90000000'],
            'rank_calculation': [798084,
                                 136,
                                 '554889e58b8ff40000008b87340100004863c94869f11f85eb514863c04869c8565555554989c849c1e83f4889f248c1ea3f48c1ee20c1fe0431c001d648c1e9204401c1038f50020000448b8754020000488d15e6ea0a0001f1038ff8000000038f78020000428d0c41038f600200003b0a7c068987580200004883c204ffc083f81575eb5dc390'],
            'score_reset_a': [802734,
                              22,
                              '41c786500200000000000041c7865402000000000000'],
            'score_reset_b': [802818, 11, '41c7866002000000000000'],
            'score_reset_c': [803231,
                              22,
                              '49c786f80000000000000049c786f000000000000000'],
            'score_reset_d': [803684, 11, '49c7863001000000000000'],
            'rank_thresholds_constant': [1513666,
                                         84,
                                         '0000000007000000150000002a000000460000006900000093000000c4000000fc0000003b01000081010000ce010000220200007d020000df02000048030000b80300002f040000ad0400003205000072060000']},
 'armv7': {'factory_arguments': [28,
                                 28,
                                 '1092044611914bf60c20c0f228001d46784400680e900068b1f01cf8'],
           'rank_base': [226,
                         64,
                         'ddf838800aeb0502d8f8001030940b920beb06020a920c9a104409900846b5f0aefc142802dd4ff4967509e0d8f800003094b5f0a4fcc0ebc000142101eb4005'],
           'cursor_and_hull_modifiers': [290,
                                         116,
                                         'd8f80000129eddf834a03094b0f097ff4fea8a01002818bfb421332e0d4406d0312e0dd145ec305bc3ef112f0ee045ec305b9fed8d0afbff200640ff900d09e02c2e0bd1c0ef122f45ec305bfbff200640ffb20dbbff200710ee105aaaf13100072807d8012101fa00f010f08f0f18bf4ff48775'],
           'subtype': [446,
                       36,
                       '1098012806d101eb41010e2e05d11920454304e043f6982003e005eb85054af6c8700c90'],
           'difficulty': [482,
                          92,
                          '4bf6e200c0f22800c6ff102f784445ec305bfbff2006baf19a0f006890ed0b0a40ef222d40ffb22d40efa20dbbff200710ee105a10d10d914ff0ff3112960024d8f8000030911199092908bf0124b0f000ff2040854001e00d911296'],
           'stats_argument': [626, 8, '2a46012365f05bff'],
           'stats_wrapper': [418096,
                             30,
                             '90b501af82b00446b868d7f80c908de801022046fff72cfe204602b090bd'],
           'initial_capacity': [417296, 14, 'b2670396d7f80c90bd68c6f88420'],
           'hull_setter': [419896, 18, '8167d0f884208a42b8bfc0f88410fff727bc'],
           'percentage': [417944,
                          36,
                          '90ed1e0a90ed211abbff0006bbff011680ee011a9fed1c0a41ff100dbbff201780ed261a'],
           'rank_getter': [744032, 6, 'd0f8b4017047'],
           'rank_reset': [748506,
                          40,
                          '0124c0f888300a6800f5e071c0f89c31c0f8a031c0f8ac31c0f8b03101f98f8ac0f8d031c0f8b441'],
           'cursor_getter': [725104, 6, 'd0f8d4017047'],
           'cursor_predicate': [725088, 14, 'd0f8d41100202c29c8bf01207047'],
           'percentage_literal': [418080, 4, '0000c842'],
           'entry_rank': [270940,
                          44,
                          '28684ff0ff340c9473f08cfb4ff428700c94bef164ea0990012109980c910321a1f7dcfa0298099c80460467'],
           'rank_calculation': [743808,
                                120,
                                'b0b502af4df804bdd0f89c2048f21f53d0f8a090c5f2eb13d0f8cc1052fb03f245f25653c5f2555351fb03f1d0f8ac41d0f8b0b1d0f8d451d0f8bcc1131103ebd27245f2900301ebd171c0f2190321447b4411440022494401eb4b012944614453f82250a942a8bfc0f8b4210132152af6d15df804bbb0bd'],
           'score_reset_a': [748498,
                             56,
                             '80ef5080794400230124c0f888300a6800f5e071c0f89c31c0f8a031c0f8ac31c0f8b03101f98f8ac0f8d031c0f8b441c0f8b831c0f8bc31'],
           'score_reset_c': [748854, 8, '04f1980000f98f8a'],
           'score_reset_d': [749156, 8, '04f1c40606f98f8a'],
           'rank_thresholds_constant': [2402916,
                                        84,
                                        '0000000007000000150000002a000000460000006900000093000000c4000000fc0000003b01000081010000ce010000220200007d020000df02000048030000b80300002f040000ad0400003205000072060000']}}


# Complete alternate Mac proof set; native values keep the verified fresh context.
MAC_ALTERNATE = {'factory_arguments': [17,
                       38,
                       '44894db04c89c3894db88955b48975bc48897dc0488d05b6b22300488b38e8f8e90b004189c4'],
 'rank_base': [166,
               46,
               'bb2c010000488d0530b22300488b38e884300c0083f8147f15488d051cb22300488b38e870300c006bd80e83c314'],
 'cursor_and_hull_modifiers': [224,
                               129,
                               '488d05fbb12300488b38e82de90b00428d0ca50000000084c0b8b40000000f44c101d8448b75b84183fe3374284183fe3174144183fe2c752cf30f2ac0f30f5905e1761600eb1af30f2ac0f30f5905cf761600eb0cf30f2ac0f30f59051d2f1600f30f2cc04183fc380f94c1418d5424cf83fa040f92c208cabb0e0100000f44d8'],
 'subtype': [399,
             43,
             '41bf983a0000837db401751f478d6c6d004183fe0e740b41bfc8af00008d1c9beb096bdb1941bfc8af0000'],
 'difficulty': [442,
                73,
                'f30f2ac3488d0581b12300f30f10482cf30f580de06f1600f30f59c8f30f58c8f3440f2cf14181fc9a000000751b488d05f3b02300488b38e8d3e70b00837dbc090f94c120c141d3e6'],
 'stats_argument': [558, 27, '4c89e789de4489f2b90100000041b8010000004531c9e8e1f50600'],
 'stats_wrapper': [456746, 10, '554889e55de900000000'],
 'initial_capacity': [456929, 12, '89938000000089938c000000'],
 'hull_setter': [459606, 30, '554889e589b78000000039b78c0000007d0689b78c0000005de994f8ffff'],
 'percentage': [457740,
                42,
                'f30f2a878c000000f30f2a8f80000000f30f5ec8f30f100576330f00f30f59c8f30f2cc18987a0000000'],
 'rank_getter': [799038, 12, '554889e58b87580200005dc3'],
 'rank_reset': [803428, 11, '41c7865802000001000000'],
 'cursor_getter': [780844, 12, '554889e58b87780200005dc3'],
 'cursor_predicate': [780828, 16, '554889e583bf780200002c0f9fc05dc3'],
 'difficulty_constant': [1470898, 4, '000000bf'],
 'percentage_constant': [1453982, 4, '0000c842'],
 'entry_rank': [256976,
                48,
                '488d050bc71f00488b38e81d440800bf50030000e8170412004889c34889dfbe03000000e89d2dfaff49899e90000000'],
 'rank_calculation': [798716,
                      136,
                      '554889e58b8ff40000008b87340100004863c94869f11f85eb514863c04869c8565555554989c849c1e83f4889f248c1ea3f48c1ee20c1fe0431c001d648c1e9204401c1038f50020000448b8754020000488d1526870a0001f1038ff8000000038f78020000428d0c41038f600200003b0a7c068987580200004883c204ffc083f81575eb5dc390'],
 'score_reset_a': [803366, 22, '41c786500200000000000041c7865402000000000000'],
 'score_reset_b': [803450, 11, '41c7866002000000000000'],
 'score_reset_c': [803863, 22, '49c786f80000000000000049c786f000000000000000'],
 'score_reset_d': [804316, 11, '49c7863001000000000000'],
 'rank_thresholds_constant': [1488762,
                              84,
                              '0000000007000000150000002a000000460000006900000093000000c4000000fc0000003b01000081010000ce010000220200007d020000df02000048030000b80300002f040000ad0400003205000072060000']}

ANDROID = {'factory_arguments': ('_ZN5Level10createShipEiiiP8Waypointbb', 14, 24, '0f901e46dff8e40b93468a467844006800689af746ed8046'),
           'rank_base': ('_ZN5Level10createShipEiiiP8Waypointbb', 116, 40, 'sha256:ff8193ce2278b29fcb84471340191f9d360692ad35012826e12c4a873b380d36'),
           'cursor_and_hull_modifiers': ('_ZN5Level10createShipEiiiP8Waypointbb', 156, 122, 'sha256:57db865d351919f96790f159b154125a899461ce1818271da34638ac914bb357'),
           'subtype': ('_ZN5Level10createShipEiiiP8Waypointbb', 330, 34, 'sha256:ab80c1d27103a6abea8614692b1f7ce379a9561193abf6ee91e1a494182f2fc7'),
           'difficulty': ('_ZN5Level10createShipEiiiP8Waypointbb', 364, 80, 'sha256:76c5e0e0f6deaae4b2a825c8083c994d383f7ab3b76e90283eb6560d75ea5415'),
           'stats_argument': ('_ZN5Level10createShipEiiiP8Waypointbb', 470, 30, 'sha256:fedd068c5cf99a5b829dedd24cb498547a65fa117a0656935c5b922c130dab49'),
           'initial_capacity': ('_ZN6PlayerC2Eiiiii', 110, 6, 'a267c4f88420'),
           'hull_setter': ('_ZN6Player12setHitpointsEi', 0, 18, '8167d0f884208a42b8bfc0f8841029f115bc'),
           'percentage': ('_ZN6Player16updateDamageRateEv', 0, 36, 'sha256:9d2c1d373aacc9512009cae5e26a008bca91248b8aae28c2216bc04bf96efe50'),
           'percentage_literal': ('_ZN6Player16updateDamageRateEv', 132, 4, '0000c842'),
           'rank_getter': ('_ZN6Status8getLevelEv', 0, 6, 'd0f8c8017047'),
           'score_reset_a': ('_ZN6Status9resetGameEv', 8, 40, 'sha256:a1a9ff8a528027ef9d159984ee3b79a60980191be7b49d8b406e7ba78b9aa381'),
           # Level 1 and the score at 0x1d0.
           'rank_reset': ('_ZN6Status9resetGameEv', 48, 14, '0121c8f8e441c8e97214c8f8d041'),
           'score_reset_c': ('_ZN6Status9resetGameEv', 276, 12, 'c0ef500008f19c0040f98f0a'),
           'score_reset_d': ('_ZN6Status9resetGameEv', 488, 62, 'sha256:badb362353f37f9b926d40ef8817f3c9574a9f0ef8ac697e073439321a240e07'),
           'cursor_getter': ('_ZN6Status25getCurrentCampaignMissionEv', 0, 6, 'd0f8e8017047'),
           'cursor_predicate': ('_ZN6Status7gameWonEv', 0, 14, 'd0f8e81100202c29c8bf01207047'),
           'entry_rank': ('_ZN5MGame12OnInitializeEv', 618, 34, 'sha256:85bf3e5830d77c3d88309e36e0f0b3affb3a5050e8a794dd94bf3c74f2e8c761'),
           'rank_calculation': ('_ZN6Status15checkForLevelUpEv', 0, 104, 'sha256:382c341367d31244fa6f3d6c10b0e220fff6ae8b8311556375980d889900974b'),
           'rank_thresholds_constant': ('_ZN6Status15checkForLevelUpEv', 58, 84, 'sha256:3e64308cda1ff8cd1c97e1ab8e2b9edff4c81ef5f170f92f7c4224bc3a67fe54', 'literal', 0)}
