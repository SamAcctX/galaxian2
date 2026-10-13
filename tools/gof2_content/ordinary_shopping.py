"""Original ordinary hangar pricing, transfers and departure capacity boundary. Constant declarations only.

Android: HangarWindow::initialize (free mode at station 108 with story value
3), Status::calcCargoPrices (cargo, installed, stock; distance ratio via
Galaxy::distancePercent, SolarSystem::getX/getY and Globals::sqrt; variation
0.02, global raise 0.01; AERandom::reset), Item::Item and Item::init
(properties 4, 5, 7, 8), Item::transaction, Status::changeCredits,
HangarWindow::transaction (texts 312 and 192, Android 323 and 203),
HangarWindow::update (x5 after 4000 ms), the list commits in setSellMode and
OnTouchBegin (Item::extractItems, Ship::setCargo, Station::setItems,
Item::mixItems) and ModStation::leaveStation (text 193, Android 204).
Unlike the Mac (maximum price x 1.05), Status::calcCargoPrices prices system
25's goods at their maximum price unchanged: ANDROID_VALUES has special
multiplier 1.0.

Android-only hangar blueprint rules (ANDROID_VALUES 'blueprints'): shipping
costs 200 per unit (HangarWindow::OnTouchBegin quote and OnTouchEnd charge;
the Mac's imul $0x14 at 0x1000960e0 charges 20, the game's default), and every
unlocked blueprint offers "Autocomplete" (HangarList::fillIngredientsList slot
row, HangarWindow::initialize button 23 and render). OnTouchEnd asks text 3392
(Android 195) with #C = BluePrint::getAutoCompletionPrice: item 210 costs its
remaining ingredient value (getIngredientsValue: remaining x Item::getSinglePrice)
+ 2000000, every other (int)((float)(Item::getMaxPrice x base quantity) x 1.25f)
(BluePrint::BluePrint: 10 for type 1, else 1). Yes with too few credits shows
text 192 (Android 203); otherwise an empty blueprint (BluePrint::isEmpty) takes
the current station, BluePrint::complete, setSellMode's completion
(isCompleted, cargo here or a pending product there, reset) and changeCredits.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_ordinary_shopping(mach, arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(ANDROID_VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'ordinary_station_shopping',
 'catalogue': {'origin_property': 4,
               'maximum_origin_property': 5,
               'minimum_price_property': 7,
               'maximum_price_property': 8,
               'system_coordinate_fields': [3, 4]},
 'pricing': {'distance_percent_scale': 100.0,
             'ratio_maximum': 1.0,
             'variation_fraction': 0.019999999552965164,
             'percent_fraction': 0.009999999776482582,
             'special_multiplier': 1.0499999523162842,
             'minimum_variation': 1,
             'nonpositive_price_unchanged': True,
             'list_order': ['cargo', 'installed', 'stock'],
             'special_mission_kind': 25},
 'transfer': {'unit_quantity': 1,
              'buy_capacity_guard': False,
              'free_mode_station_id': 108,
              'free_mode_story_value': 3,
              'maximum_credit_delta': 1000000000,
              'minimum_credits': 0,
              'overfilled_departure_text_id': 193,
              'protected_item_text_id': 312,
              'insufficient_credits_text_id': 192,
              'repeat_acceleration_ms': 4000,
              'repeat_quantity': 1,
              'accelerated_quantity': 5}}

LAYOUTS = {'shopping_hangar_entry': [-172628,
                           157,
                           '__text',
                           'a079de7ff91d12f71514a78d524ec81e5e23906492164d2e2f914441b4a881c8'],
 'shopping_prices': [877404,
                     892,
                     '__text',
                     'a6bfb5087d8365943901fce8ffd04068890bd06d2ee31df6b8e5b98a67334a0c'],
 'shopping_item_constructor': [-85882,
                               172,
                               '__text',
                               'a960749b99bcf620bcdcba13d8fbdc88f40d4d9800b1d9371782bc3b61e1956c'],
 'shopping_system_x': [734968,
                       10,
                       '__text',
                       'fdf5949505972320f2d3bcf9fddf25e254bc63dd4cc89090ddea739cf2855e73'],
 'shopping_system_y': [734978,
                       10,
                       '__text',
                       'c0748b1656107d8edea7411eb10e4bc6d95d66d67e46c9e944880a7b482078c9'],
 'shopping_distance': [-658544,
                       46,
                       '__text',
                       'ffed460523875a72ca6bb3372089953399263df528c6abac5d171d3539f292c0'],
 'shopping_root_input': [-192316,
                         10,
                         '__text',
                         '0c4d82293e055f31ac41cc677605631ef9929775d824ae78bc688231a0455dfd'],
 'shopping_root': [1248266,
                   48,
                   '__text',
                   '182bc3123eaee7050ecdada69a01c2a792af2ad0aabdd287a9ca4d9bc728fa96'],
 'shopping_station_match': [853288,
                            22,
                            '__text',
                            '88fd654fbe9f154dc3b1abf97b31858eb99c0710a7cb258faaef2c2e729145e5'],
 'shopping_cargo_list': [730052,
                         10,
                         '__text',
                         '7dc22ae292921b71218a097733f4c40dfa07570814d0765b4cf6b066faec18b3'],
 'shopping_installed_list': [730042,
                             10,
                             '__text',
                             '9624067a219b5715fb6aabc614cd28310a74739206a88a5fa7b6f65e0a76a0d0'],
 'shopping_unit_transfer': [-84322,
                            104,
                            '__text',
                            'ef1507d1f4bad3ab0e4a30fe5e8e1333fd08c2602f2316145cbe577b172e2e0d'],
 'shopping_wallet': [872054,
                     48,
                     '__text',
                     'cece6e99aa8073131c9b9995c8563da1824339b15ae2f1722aaf5221826435c8'],
 'shopping_wallet_commit': [-163098,
                            33,
                            '__text',
                            '97fe264adabf606305b14490dd0b91bf996be94f769135eb93935112af901506'],
 'shopping_funds_message': [-163710,
                            97,
                            '__text',
                            'c613c5789375987b7ad56fe9bc07fbaed591789913e091ed6266da0a559d1b64'],
 'shopping_protected_transfer': [-164060,
                                 118,
                                 '__text',
                                 'bfe3d30630190107c772aa7c2680e71eef7786117f6448c5adb63817bce8fa6c'],
 'shopping_combine': [-82728,
                      782,
                      '__text',
                      'e39345d71728b9ab36707148f3ebc014a2a6d23b0552b18f436a4d8d7ff5d038'],
 'shopping_split': [-83178,
                    244,
                    '__text',
                    'c0d2c522bdecd91ebb5f4dfce7285ce72dc7789e83c5a1aaa845e85651baac35'],
 'shopping_list_commit': [-166486,
                          78,
                          '__text',
                          '6e5b86825a02e5d71ced376920e2e89c75e8a77f727da0a69e90b379c13bd4df'],
 'shopping_cargo_setter': [730926,
                           112,
                           '__text',
                           '7fae7b47820b56ee852f6a7cb6f0a24df8cd82844be061a094afb47a92d78ee9'],
 'shopping_stock_setter': [851930,
                           226,
                           '__text',
                           'cd396dcc10147a70773e3f023305fc262479db629f539c18d94283e9946ddb7b'],
 'shopping_repeat_quantity': [-167068,
                              47,
                              '__text',
                              '05ac6c09ce3ee0c26d6c2825f70628389161a149fd361f8f28f9b680e5402525'],
 'shopping_overfilled_departure': [437002,
                                   87,
                                   '__text',
                                   'b984e9d2aa90317f2389862a5228bfd797b58054e41bba0b7ef8172f360556d3'],
 'shopping_reseed': [1120906,
                     64,
                     '__text',
                     'df692d942b2df8e783edf8dcd0bef8f67487b2515f414533f62c8a90a15f8397'],
 'shopping_distance_percent_scale': [1556926,
                                     4,
                                     '__const',
                                     '2238f30df488055daf5e8f362cf904e370011a172d20df193c1b7ae8e5db8e01'],
 'shopping_ratio_maximum': [1544610,
                            4,
                            '__const',
                            'e00e5eb9444182f352323374ef4e08ebcb784725fdd4fd612d7730540b3e0c8c'],
 'shopping_variation_fraction': [1582590,
                                 4,
                                 '__const',
                                 '8b35fe1a9b331dc0217e0419be35288af59676e9c57022a334110ab0e4799df4'],
 'shopping_percent_fraction': [1556914,
                               4,
                               '__const',
                               '0d66bd808e9247acb560fe33efaa62ad6f11ee6f85cc4f61bd17673263de04ee'],
 'shopping_special_multiplier': [1573882,
                                 4,
                                 '__const',
                                 '5af2169fc7e6a3268ca6146f2ba18f312fde17563e7dff42572633d9b0b92c7c']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'shopping_hangar_entry': [-173120, 157, '__text', 'd20566f62c40be7e33e6b96b4991a0936f7728769c138497af6e69c1a848188f'],
 'shopping_prices': [878036, 892, '__text', 'f89e2e6d9ce6d6013a1c6a0b83c1e063114351bd41b5031ff1f3d33d97fee1f1'],
 'shopping_item_constructor': [-85882,
                               172,
                               '__text',
                               '79134de9aa905a016959e217240597a668c203b159e54a83d6263fa171011f9f'],
 'shopping_system_x': [735600, 10, '__text', 'fdf5949505972320f2d3bcf9fddf25e254bc63dd4cc89090ddea739cf2855e73'],
 'shopping_system_y': [735610, 10, '__text', 'c0748b1656107d8edea7411eb10e4bc6d95d66d67e46c9e944880a7b482078c9'],
 'shopping_distance': [-664432, 46, '__text', '034dacfe370a259795834afa8da8082f3e1d69f1a8a2468b3a8f6bfbd15b5850'],
 'shopping_root_input': [-192808, 10, '__text', '3d15fc2abcdb6555eaaac57867a9033b075dbf52a60cafab61508d37b8e00579'],
 'shopping_root': [1241090, 48, '__text', 'd09924084c0e86d34b21bdd09df1d492403a33c2d2f34e74356ba31103ca5004'],
 'shopping_station_match': [853920, 22, '__text', '88fd654fbe9f154dc3b1abf97b31858eb99c0710a7cb258faaef2c2e729145e5'],
 'shopping_cargo_list': [730676, 10, '__text', '7dc22ae292921b71218a097733f4c40dfa07570814d0765b4cf6b066faec18b3'],
 'shopping_installed_list': [730666, 10, '__text', '9624067a219b5715fb6aabc614cd28310a74739206a88a5fa7b6f65e0a76a0d0'],
 'shopping_unit_transfer': [-84322, 104, '__text', '6a49d8936842a624dc9e86c983e56b6f46f8bb4c1d444a041c7685aa6a54221f'],
 'shopping_wallet': [872686, 48, '__text', 'cece6e99aa8073131c9b9995c8563da1824339b15ae2f1722aaf5221826435c8'],
 'shopping_wallet_commit': [-163580, 33, '__text', '67c12a10b62a7f4ecce407d6a71db9e228061d582978b48371318a075c5929ad'],
 'shopping_funds_message': [-164192, 97, '__text', 'b68963506b6218aafe4c819062eb1d81a0adaa63f9d2e9860c2f01153a29b2df'],
 'shopping_protected_transfer': [-164542,
                                 118,
                                 '__text',
                                 '4058f0e463d260b7e117029d0222d2aa69796b575baf87afb9c1b32bed42a104'],
 'shopping_combine': [-82728, 782, '__text', '339ecd896a89ba8dc45a9ec49dbb0644e5a4bcbf3fcbb50be885b61eccbe58ba'],
 'shopping_split': [-83178, 244, '__text', '363e8968f13bf872565805bfc433ceb2518c430cba2283729552339be143bf1f'],
 'shopping_list_commit': [-166978, 78, '__text', 'd4c5570f763f95a68c3025959069e29b9f4bb97091661fbd8c15fa80462e0f6d'],
 'shopping_cargo_setter': [731558, 112, '__text', 'f76d4d7ff55b56e546388ab231a0ea296c2e2f34eff1c1dbfe47e9e0e30af373'],
 'shopping_stock_setter': [852562, 226, '__text', '72e6f1228d72d769b345ae39eb7f992f8a5e7cc868a2c548bd74c34bc5226643'],
 'shopping_repeat_quantity': [-167560,
                              47,
                              '__text',
                              '49f13106ad08e00cd36d5bfff6946fed2b989b6efc9a82ca765da35b89244149'],
 'shopping_overfilled_departure': [437438,
                                   85,
                                   '__text',
                                   '61dbb232159b1d6d29bf9331eced4f7bec200b49608594b38bb09421d8139596'],
 'shopping_reseed': [1120354, 64, '__text', 'c33a8f66a77543b1d2c760bcea9d3dd50a10c387afb7e3bdfbae1b46ba6acee5'],
 'shopping_distance_percent_scale': [1531926,
                                     4,
                                     '__const',
                                     '2238f30df488055daf5e8f362cf904e370011a172d20df193c1b7ae8e5db8e01'],
 'shopping_ratio_maximum': [1519594, 4, '__const', 'e00e5eb9444182f352323374ef4e08ebcb784725fdd4fd612d7730540b3e0c8c'],
 'shopping_variation_fraction': [1557654,
                                 4,
                                 '__const',
                                 '8b35fe1a9b331dc0217e0419be35288af59676e9c57022a334110ab0e4799df4'],
 'shopping_percent_fraction': [1531914,
                               4,
                               '__const',
                               '0d66bd808e9247acb560fe33efaa62ad6f11ee6f85cc4f61bd17673263de04ee'],
 'shopping_special_multiplier': [1548946,
                                 4,
                                 '__const',
                                 '5af2169fc7e6a3268ca6146f2ba18f312fde17563e7dff42572633d9b0b92c7c']}

# Android: system 25's goods cost their maximum price, without the Mac's 1.05 markup.
ANDROID_VALUES = copy.deepcopy(VALUES)
ANDROID_VALUES['pricing']['special_multiplier'] = 1.0
# Android: blueprint shipping and autocomplete (the Mac has neither key; it ships for 20 per unit).
ANDROID_VALUES['blueprints'] = {'shipping_unit_cost': 200,
                                'autocomplete': {'label': 'Autocomplete', 'text_id': 3392, 'shortfall_text_id': 192,
                                                 'multiplier': 1.25, 'special_item_id': 210, 'special_add': 2000000}}

# Android spans inside named functions; the values are ANDROID_VALUES.
ANDROID = {# HangarWindow::initialize: free mode (station 108, story value 3), prices, the merged list.
           'shopping_hangar_entry': ('_ZN12HangarWindow10initializeEv', 30, 92, 'sha256:098ad9637d9d5ecbd595ebc5336940b28834b0954d9bdf9d9bed02a328bbe088'),
           # Status::calcCargoPrices: system 25 takes the maximum price (Mac: x 1.05) at 0xa9fa0..0xa9fae.
           'shopping_prices': ('_ZN6Status15calcCargoPricesEv', 0, 764, 'sha256:454dee38036c70b75f6641fb36d6621878d6db18296751f23830a346a17fbc97'),
           # Item::init reads properties 4, 5, 7 and 8 (price systems and bounds).
           'shopping_item_constructor': ('_ZN4ItemC2EP5ArrayIiES2_S2_', 0, 22, 'd0b502af044604f1280c8ce80e007af7bae92046d0bd'),
           'shopping_item_init': ('_ZN4Item4initEv', 0, 78, 'sha256:2958dfb1982a848d6f960cdb302d8f062ef241c5d66ccd336fcb72ca1fc2176e'),
           'shopping_system_x': ('_ZN11SolarSystem4getXEv', 0, 4, '006a7047'),
           'shopping_system_y': ('_ZN11SolarSystem4getYEv', 0, 4, '406a7047'),
           'shopping_distance': ('_ZN6Galaxy15distancePercentEiiii', 0, 60, 'sha256:5abadcaa2c7c7199a698b9fa044bb7782bdb483624e6c41aff697c51499c346f'),
           'shopping_root': ('_ZN7Globals4sqrtEf', 0, 6, '0846dbf0ddbe'),
           'shopping_station_match': ('_ZN7Station6equalsEPS_', 0, 18, '0246002021b1896892688a4208bf01207047'),
           'shopping_cargo_list': ('_ZN4Ship8getCargoEv', 0, 4, '006f7047'),
           'shopping_installed_list': ('_ZN4Ship12getEquipmentEv', 0, 4, 'c06e7047'),
           # Transfers one unit; the wallet ignores changes above 1e9 and stops at 0.
           'shopping_unit_transfer': ('_ZN4Item11transactionEbib', 0, 88, 'sha256:e9c3c18c0f35a70469c27e04ccafeb6cd41f5333569fd06b32d739af1d9ee546'),
           'shopping_wallet': ('_ZN6Status13changeCreditsEi', 0, 40, 'sha256:3db9059bda43f3b08a4900d461d0fc0dd7e2b4e6bd61f4988873498d8d4cdd47'),
           'shopping_wallet_commit': ('_ZN12HangarWindow11transactionEb', 844, 20, '9bf81d0130b92a485146784400680068f7f68ceb'),
           'shopping_funds_check': ('_ZN12HangarWindow11transactionEb', 374, 46, 'sha256:7ccfa97a8d256f7f13884ca54c23381840f57fce39fd9a1e8e8d48c9cd9d7771'),
           'shopping_funds_message': ('_ZN12HangarWindow11transactionEb', 598, 246, 'sha256:b9c6205a0d8f7d754e32d2d13391f703e90064c1f15a3b027f8e1db991101b23'),
           'shopping_protected_transfer': ('_ZN12HangarWindow11transactionEb', 24, 74, 'sha256:13d0b8d61e601d01d438b7d413cea5b708e63b70314619e098a64ff44c884dcb'),
           'shopping_sale_transfer': ('_ZN12HangarWindow11transactionEb', 212, 22, 'dbf868003146dbf8a8209bf81d310069fcf6bcee8246'),
           # The hangar list: merge, split and the committed cargo and stock.
           'shopping_combine': ('_ZN4Item8mixItemsEP5ArrayIPS_ES3_', 0, 602, 'sha256:37e985e9fb500e19b28f79dc3f806d396111f1a10db90dbff05b054007e16adc'),
           'shopping_split': ('_ZN4Item12extractItemsEP5ArrayIPS_Eb', 0, 182, 'sha256:cd1ee245e793b989bca822bd1df85458f76ef206156e1497255de45f91d56a05'),
           'shopping_list_commit': ('_ZN12HangarWindow11setSellModeEb', 478, 62, 'sha256:db95e6abce280ee9971649225aabaa16c3a2caa951587d0ad90ea023c3f89427'),
           'shopping_list_commit_tab': ('_ZN12HangarWindow12OnTouchBeginEii', 362, 64, 'sha256:8a20297935fe87383ec0d0010f7ca1cc51034cd950b2d7e4b350886f1080c4f5'),
           'shopping_cargo_setter': ('_ZN4Ship8setCargoEP5ArrayIP4ItemE', 0, 92, 'sha256:71a00bf8d9656ccfc6fe7984f4d7e5663bef8a101d0b3aa4cd3f566af6554bcf'),
           'shopping_stock_setter': ('_ZN7Station8setItemsEP5ArrayIP4ItemEb', 0, 140, 'sha256:8120ed5e0d56117bc3bd8b601abba8f7aac10839ba44932364fc104ec804340d'),
           # Held buttons repeat x5 after 4000 ms; overfilled ships cannot leave (Android text 204).
           'shopping_repeat_quantity': ('_ZN12HangarWindow6updateEi', 340, 162, 'sha256:cc85e9323f3674640d9d3863f61b180cf5027e06254fe2d2ea900eff01ae8fad'),
           'shopping_overfilled_departure': ('_ZN10ModStation12leaveStationEv', 0, 50, 'sha256:7663d67ae0024c5e09c7bcc485ad9de639dc7edde1b4e8c7879d443012645232'),
           'shopping_reseed': ('_ZN11AbyssEngine8AERandom5resetEv', 0, 36, 'sha256:48ebaf1bd886ac03af6b109e67b1a8da31eb13841bfed2bd2131cae029d88244'),
           # Blueprint shipping: pending units x 200 for the quote and the charge.
           'blueprint_shipping_quote': ('_ZN12HangarWindow12OnTouchBeginEii', 946, 10, 'f9f614ebc82100fb01f2'),
           'blueprint_shipping_commit': ('_ZN12HangarWindow10OnTouchEndEii', 2774, 12, 'f7f6f2eec821002d00fb01fa'),
           # BluePrint::getAutoCompletionPrice: item 210, + 2000000, x 1.25f truncated.
           'blueprint_autocomplete_price': ('_ZN9BluePrint22getAutoCompletionPriceEv', 0, 80, 'sha256:37fddd8d63715928ac26b794bf0feb99edd10c5fce6781136f8daaf1c75bfdee'),
           'blueprint_autocomplete_item': ('_ZN9BluePrint22getAutoCompletionPriceEv', 6, 4, 'e069d228'),
           'blueprint_autocomplete_add': ('_ZN9BluePrint22getAutoCompletionPriceEv', 18, 8, '00f5f41000f59060'),
           'blueprint_autocomplete_multiplier': ('_ZN9BluePrint22getAutoCompletionPriceEv', 48, 22, 'b7ee040a484301ee100ab8eec11a21ee000abdeec00a'),
           'blueprint_ingredient_value': ('_ZN9BluePrint19getIngredientsValueEv', 0, 116, 'sha256:ab6c187b2f75611b6bc65b83526a567fd0335544cf1a60ef38845c658d9800ad'),
           'blueprint_max_price': ('_ZN4Item11getMaxPriceEv', 0, 4, '406a7047'),
           'blueprint_single_price': ('_ZN4Item14getSinglePriceEv', 0, 4, '80697047'),
           'blueprint_base_quantity': ('_ZN9BluePrintC2Ei', 38, 22, '3046c4f6fee90121012808bf0a214ff0ff3021622061'),
           # The blueprint: emptiness, completion, the remaining fill and the reset after construction.
           'blueprint_empty': ('_ZN9BluePrint7isEmptyEv', 0, 12, '41680020002908bf01207047'),
           'blueprint_fill': ('_ZN9BluePrint8completeEv', 0, 28, 'sha256:2f97db3de25e8c4bb534cf34144bb5f27bafb382ebde995407a95cd408dadcd9'),
           'blueprint_completed': ('_ZN9BluePrint11isCompletedEv', 0, 32, 'sha256:c7f674d5f56ac8cfe3a04ff503000738de097514161bf91ce56192c378c292eb'),
           'blueprint_reset': ('_ZN9BluePrint5resetEv', 0, 100, 'sha256:87e91d3b125c3981bd9f22a5052af8737616b38aefcc9da859952e45dd79af8c'),
           # The ingredient list's last row carries button 23, labelled "Autocomplete".
           'blueprint_autocomplete_row': ('_ZN10HangarList19fillIngredientsListEP9BluePrintb', 304, 62, 'sha256:27f4116709d5613c68e7a54bb0315acc560fbd0c0ae9c218041e78a6273e242e'),
           'blueprint_autocomplete_label': ('_ZN12HangarWindow10initializeEv', 2134, 13, '4175746f636f6d706c65746500', 'literal', 0),
           'blueprint_autocomplete_label_button': ('_ZN12HangarWindow10initializeEv', 2128, 48, 'sha256:39a33c41972bb20ae2afcc7aac9d951dc2a11b4ab2cc1c323612ace6e7c876a8'),
           'blueprint_autocomplete_button': ('_ZN12HangarWindow6renderEv', 2456, 86, 'sha256:8ad8310c87e73e5de9627c625fcbaf38b09414690dc2ff276264a79bb31e1f21'),
           # HangarWindow::OnTouchEnd: the offer (text 195), the answer, the shortfall (text 203), the commit.
           'blueprint_autocomplete_offer': ('_ZN12HangarWindow10OnTouchEndEii', 940, 160, 'sha256:5e4ec29b3440cb94edd48957723a8e106463b9c142c680cd611c153163f5c667'),
           'blueprint_autocomplete_text': ('_ZN12HangarWindow10OnTouchEndEii', 994, 2, 'c321'),
           'blueprint_autocomplete_confirm': ('_ZN12HangarWindow10OnTouchEndEii', 84, 62, 'sha256:ccc4cb2bf893b62874f4b817e0ba780c45b50057f7523e9644c70b9411937676'),
           'blueprint_autocomplete_shortfall': ('_ZN12HangarWindow10OnTouchEndEii', 146, 212, 'sha256:ee43d87bfaaca0661f6b4dba1054cbfa3b952050371d0f2606fe5556fb7056d0'),
           'blueprint_autocomplete_shortfall_text': ('_ZN12HangarWindow10OnTouchEndEii', 162, 2, 'cb21'),
           'blueprint_autocomplete_commit': ('_ZN12HangarWindow10OnTouchEndEii', 1196, 140, 'sha256:7f0aaeee74f250d882740a8f884dfcada71a378fc61b71c38a65a611777c9026'),
           # setSellMode: the completed blueprint goes to the hold here or waits at its site, unshipped.
           'blueprint_completion': ('_ZN12HangarWindow11setSellModeEb', 686, 670, 'sha256:1b1389cff196ff467e1321dccab9a7a89acd947d0506cfcd3f0e862018d48a49')}
