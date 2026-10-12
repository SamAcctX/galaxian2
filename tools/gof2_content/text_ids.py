"""Text ids of other editions, in the Mac 1.0.7 numbering the game is written against.

The Android string tables are the Mac 1.0.7 table (3,385 strings) plus insertions:
one credit line before Mac 48, ten Kaamo Club lines before Mac 188, five lines
appended. Imports keep the Mac numbering by reordering Android tables once; the
sixteen Android-only lines follow the Mac range in Android order.
"""
MAC_STRINGS = 3385
ANDROID_STRINGS = 3401
ANDROID_ONLY = (48, *range(189, 199), *range(3396, 3401))


def android_id(mac_id):
    """Android id of a Mac 1.0.7 text id."""
    return mac_id + (mac_id >= 48) + 10 * (mac_id >= 188)


ANDROID_ORDER = [android_id(i) for i in range(MAC_STRINGS)] + list(ANDROID_ONLY)
CANONICAL = {android: index for index, android in enumerate(ANDROID_ORDER)}


def canonical_id(android):
    """Mac 1.0.7 id (3385+ for Android-only lines) of an Android text id, or None."""
    return CANONICAL.get(android)


def canonical_strings(strings):
    """An Android string table in Mac 1.0.7 order."""
    if len(strings) != ANDROID_STRINGS:
        raise ValueError('Unsupported Android string table')
    return [strings[i] for i in ANDROID_ORDER]
