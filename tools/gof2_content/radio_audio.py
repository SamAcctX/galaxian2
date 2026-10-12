"""Bounded static declarations for verified radio voice ownership and language.

Only source-selected event IDs, language names and provenance enter the pack.
The source table has additional campaign rows; their owners are not implemented.

Android: Radio::update times the message and selects its voice through
Globals::getDialogueSoundId's text-to-voice table (Android text ids), Radio::draw
plays it once after the display delay, FModSound::setAudioLanguage and
FModSound::init pick "deutsch" for language 1 and "english" otherwise.
"""
import copy
import struct
from .declaration_layouts import recognize, recognize_symbols

VALUES = {'trigger': 'radio_display', 'repeat': 'once_per_event', 'spatial': False,
          'stop_on_radio_finish': False, 'default_language': 'english',
          'override_language': 'deutsch', 'override_language_id': 1,
          'override_text_language': 'de', 'category': 'voice',
          'category_max_playbacks': 2, 'category_overflow': 'stop_oldest_immediately'}


def constant_bytes(mach, address, count, name):
    """Read a bounded file-backed constant, including relocated DATA pointers."""
    matches = [s for s in mach.sections if s['name'] == name and
               s['segment'] in (b'__TEXT', b'__DATA') and
               s['address'] <= address and address + count <= s['address'] + s['length']]
    if len(matches) != 1:
        return None
    section = matches[0]
    offset = section['offset'] + address - section['address']
    return mach.data[offset:offset + count], mach.slice_offset + offset


def extract_radio_audio(mach, dialogue, fonts):
    arch = mach.architecture
    if arch == 'android-armv7':
        return android_radio_audio(mach, dialogue, fonts)
    if arch not in LAYOUTS:
        return {}
    try:
        if ((dialogue['campaign_cursor'], len(dialogue['events'])) not in ((0, 23), (1, 3)) or
                fonts['languages']['rows'][1]['file'] != 'de.lang' or
                fonts['languages']['rows'][1]['language_id'] != 1):
            return {}
        origin = dialogue['provenance']['display_delay']['offset']
        address = mach.text['address'] + origin - mach.slice_offset - mach.text['offset']
        layouts = [LAYOUTS[arch]] + ([MAC_ALTERNATE] if arch == 'x86_64' else [])
        proof = recognize(mach, origin, layouts)
        if not proof:
            return {}
        data = DATA[arch]
        if arch == 'x86_64' and proof['lookup']['offset'] == origin + MAC_ALTERNATE['lookup'][0]:
            data = MAC_DATA
        for key in ['duration', 'display_delay']:
            if proof[key] != dialogue['provenance'][key]:
                return {}
        values = {}
        for key, (delta, size) in data.items():
            found = constant_bytes(mach, address + delta, size,
                                   b'__cstring' if key.endswith('_name') else b'__const')
            if found is None or len(found[0]) != size:
                return {}
            values[key] = found[0]
            proof[key] = {'offset': found[1], 'bytes': size}
        pointers = struct.unpack('<2Q' if arch == 'x86_64' else '<2I', values['language_table'])
        for index, key in enumerate(['default_name', 'override_name']):
            if pointers[index] != address + data[key][0]:
                return {}
        names = [values[key].removesuffix(b'\0').decode('ascii') for key in ['default_name', 'override_name']]
        if names != [VALUES['default_language'], VALUES['override_language']]:
            return {}
        rows = list(struct.iter_unpack('<ii', values['lookup_table']))
        if len(rows) != 1504 or len({text for text, _ in rows}) != len(rows):
            return {}
        if any(not (0 <= text <= 65535 and -1 <= event <= 19999) for text, event in rows):
            return {}
        lookup = dict(rows)
        # Missing table entries enter a separate source actor-dependent fallback.
        # Do not invent that fallback or silently treat it as a missing recording.
        texts = [row['text_id'] for row in dialogue['events']]
        if any(text not in lookup for text in texts):
            return {}
        result = copy.deepcopy(VALUES)
        result.update(event_ids=[lookup[text] for text in texts], text_ids=texts, provenance=proof)
        return result
    except (KeyError, ValueError, TypeError, IndexError, OverflowError, struct.error):
        return {}


# Compiler signatures remain in the static importer, never in runtime packs.
LAYOUTS = {'x86_64': {'duration': [-352, 32, '488b45b049894528498b45106900d007000005dc0500004189453841c6453d01'],
            'selection': [-212,
                          44,
                          '498b4500488b40084a8b3ce0488d05c6cf1a00488b18e83a0500004889df89c64c89f2e8474bf2ff41894540'],
            'text_getter': [1153, 10, '554889e58b47105dc390'],
            'lookup': [-898405,
                       59,
                       '554889e5415741564154534989d689f331c0488d0df1161b00eb044883c0023dbf0b00007f15391c8175f0488d0dd8161b008b448104e9d5080000'],
            'lookup_return': [-896090, 14, 'b8ffffffff5b415c415e415f5dc3'],
            'display_delay': [0, 26, 'b8d0070000480343284839f0488975a80f8dff010000f6433d01'],
            'display': [22,
                        39,
                        'f6433d0174218b734085f6781a488d05cbd41a00488b3831d231c90f57c0e86277ebffc6433d00'],
            'finish': [443,
                       90,
                       'f6433d017404c6433d00488b034885c074488b0885c9744248635338488b7328488d9416d0070000483b55a87d2c488b7b08488b4008ffc94863c9483b3cc87504c6433c0148c7432800000000e8aa02000048c7430800000000'],
            'language': [-1347499,
                         52,
                         '554889e5488bbfd84700004885ff75025dc383fe010f94c00fb6c0488d0d4eb72e00488b34c1e87d9d210089c65de9bdf9ffff90'],
            'language_init': [-1349369, 16, 'e859411b000fbff04c89e7e83e070000'],
            'language_getter': [436837, 13, '554889e50fbf0585f113005dc3']},
 'armv7': {'duration': [-420, 32, '0e9a4ff4fa61109850610f98906190680068484300f2dc505062012082f82900'],
           'selection': [-308,
                         46,
                         '0e980c9900680968109140680d9950f821000721189100f076fa01460820169a1890109839f7f7f916990e9ad062'],
           'text_getter': [978, 4, '80687047'],
           'lookup': [-814366,
                      40,
                      'f0b503af4df8048d0c4646f6b221c0f2280115460020794451f82020a2423ad00230b0f53c6ff7db'],
           'lookup_found': [-814216, 8, '01eb8000406888e1'],
           'lookup_return': [-813426, 10, '4ff0ff305df8048bf0bd'],
           'display_delay': [0,
                             44,
                             '3346002253f8140f596810f5fa6041f10001a0424ff0000028bf01205145a8bf012208bf0246002a40f02d81'],
           'display': [44,
                       58,
                       '96f829000493cdf814a00028069414d0f16a002911db47f60e704ff0ff32c0f220000024784400230068006810920022009473f668fd86f82940'],
           'finish': [514,
                      132,
                      '94f82900002818bf84f829a0206806990028059addf810e01cbfd0f80090b9f1000f2fd0def80080def80430666a18eb060543ebe67315f5fa6c43f10003002693424ff00005a8bf01258c4528bf0126934218bf2e46aeb942680025606802eb890151f8041c884204bf012184f828104ff0ff31cef80050cef80450109100f0b5f86560'],
           'language': [-1624698,
                        52,
                        '80b542f2f4326f468058002808bf80bd45f666620129c0f2390218bf00217a4452f82110aff2fafb0146bde88040fff7c3bf00bf'],
           'language_init': [-1625040, 12, 'edf2b9fb0146404600f0a5f8'],
           'language_getter': [1444774, 16, '4df2f830c0f20c007844b0f900007047']}}

DATA = {'x86_64': {'lookup_table': [876965, 12032],
            'language_table': [1714117, 16],
            'default_name': [1007365, 8],
            'override_name': [1007373, 8]},
 'armv7': {'lookup_table': [1834414, 12032],
           'language_table': [2135054, 8],
           'default_name': [1578070, 8],
           'override_name': [1578078, 8]}}


# Independently verified complete alternate Mac compiler layout.
MAC_ALTERNATE = {'duration': [-352, 32, '488b45b049894528498b45106900d007000005dc0500004189453841c6453d01'],
 'selection': [-212,
               44,
               '498b4500488b40084a8b3ce0488d057a751a00488b18e83a0500004889df89c64c89f2e86745f2ff41894540'],
 'text_getter': [1153, 10, '554889e58b47105dc390'],
 'lookup': [-899909,
            59,
            '554889e5415741564154534989d689f331c0488d0d45b91a00eb044883c0023dbf0b00007f15391c8175f0488d0d2cb91a008b448104e9d5080000'],
 'lookup_return': [-897594, 14, 'b8ffffffff5b415c415e415f5dc3'],
 'display_delay': [0, 26, 'b8d0070000480343284839f0488975a80f8dff010000f6433d01'],
 'display': [22,
             39,
             'f6433d0174218b734085f6781a488d058f7a1a00488b3831d231c90f57c0e83e5eebffc6433d00'],
 'finish': [443,
            90,
            'f6433d017404c6433d00488b034885c074488b0885c9744248635338488b7328488d9416d0070000483b55a87d2c488b7b08488b4008ffc94863c9483b3cc87504c6433c0148c7432800000000e8aa02000048c7430800000000'],
 'language': [-1353935,
              52,
              '554889e5488bbfd84700004885ff75025dc383fe010f94c00fb6c0488d0d26762e00488b34c1e8c952210089c65de9bdf9ffff90'],
 'language_init': [-1355805, 16, 'e841561b000fbff04c89e7e83e070000'],
 'language_getter': [435753, 13, '554889e50fbf05759b13005dc3']}
MAC_DATA = {'lookup_table': [851481, 12032],
 'language_table': [1691001, 16],
 'default_name': [981897, 8],
 'override_name': [981905, 8]}


ANDROID = {'duration': ('_ZN5Radio6updateElP9PlayerEgoP11LevelScript', 564, 26, 'sha256:7c48954457c2443a42d1ee5611c66fb483a82c1ece6efbedc57ccd4ffc98ff23'),
           'selection': ('_ZN5Radio6updateElP9PlayerEgoP11LevelScript', 648, 36, 'sha256:c16511ca789ffc4be514656796127016aa5ec1696f73060f705d7d829db5f4e5'),
           'text_getter': ('_ZN12RadioMessage9getTextIDEv', 0, 4, '80687047'),
           'lookup': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 0, 34, 'sha256:9ba804c27b6b2b9e9d4cc439e029afb2dbdb3a6cd0280a652c0d70affd78edca'),
           'lookup_found': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 186, 14, 'dff80416794401eb80004068bde8'),
           'lookup_return': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 1054, 8, '4ff0ff30bde8f081'),
           'lookup_table': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 8, 12032, 'sha256:24201ffc5c374c33aeec4660c20bd8af5788878246a0e6f0b1cae22c09895b52', 'literal', 0),
           'display_delay': ('_ZN5Radio4drawExP9PlayerEgoP11LevelScript', 34, 30, 'sha256:c8f89ee6968974eb3641ce4af0ebb22e163bc88d8452d71f4cdb14e4022b12b1'),
           'display': ('_ZN5Radio4drawExP9PlayerEgoP11LevelScript', 66, 36, 'sha256:891779f0d440fd38d3b907d2d3fa74f2fa2629a8d56ae624349c7056cff7dc55'),
           'finish': ('_ZN5Radio4drawExP9PlayerEgoP11LevelScript', 416, 88, 'sha256:499edfa254143e67994f5b59831a9ed623ea3fd9845bc1c73607fd3222bc8aa6'),
           'language': ('_ZN9FModSound16setAudioLanguageEi', 0, 28, 'sha256:a0d1efd7bbe7122933abbe802ed56e2eaee909ff9f15fcfb4ed88b2c8ff1efb4'),
           # The two language-name pointers ("english", "deutsch").
           'language_table': ('_ZN9FModSound16setAudioLanguageEi', 8, 8, 'cb022100d3022100', 'literal', 0),
           'language_init': ('_ZN9FModSound4initEv', 70, 32, 'sha256:e3ea8760a14f2155ed8102b5aecc9b64a30c8766d4d49cfa46c109404be6572c'),
           'language_getter': ('_ZN8GameText11getLanguageEv', 0, 12, '024878440068b0f900007047')}
ANDROID_VALUES = copy.deepcopy(VALUES)


def android_radio_audio(lib, dialogue, fonts):
    from .text_ids import android_id
    try:
        if ((dialogue['campaign_cursor'], len(dialogue['events'])) not in ((0, 23), (1, 3)) or
                fonts['languages']['rows'][1]['file'] != 'de.lang' or fonts['languages']['rows'][1]['language_id'] != 1):
            return {}
    except (KeyError, TypeError, IndexError):
        return {}
    proof = recognize_symbols(lib, ANDROID)
    if not proof:
        return {}
    # The timing spans are the text owner's.
    if any({k: proof[key][k] for k in ('offset', 'bytes')} != dialogue['provenance'].get(key) for key in ('duration', 'display_delay')):
        return {}
    pointers = struct.unpack('<2I', lib.data[proof['language_table']['offset']:proof['language_table']['offset'] + 8])
    for key, pointer, expected in zip(('default_name', 'override_name'), pointers, (ANDROID_VALUES['default_language'], ANDROID_VALUES['override_language'])):
        found = constant_bytes(lib, pointer, len(expected) + 1, b'__cstring')
        if found is None or found[0] != expected.encode() + b'\0':
            return {}
        # A name is found through its table pointer: it anchors itself.
        proof[key] = {'offset': found[1], 'bytes': len(found[0]), 'anchor': found[1]}
    at = proof['lookup_table']['offset']
    lookup = dict(struct.iter_unpack('<ii', lib.data[at:at + 12032]))
    texts = [row['text_id'] for row in dialogue['events']]
    if any(android_id(text) not in lookup for text in texts):
        return {}
    result = copy.deepcopy(ANDROID_VALUES)
    result.update(event_ids=[lookup[android_id(text)] for text in texts], text_ids=texts, provenance=proof)
    return result
