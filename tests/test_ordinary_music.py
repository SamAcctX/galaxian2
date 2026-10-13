"""Optional ordinary music reader rejects shifted, mixed and damaged source spans."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from gof2_content import ordinary_music
from declaration_fixture import declaration_fixture


def audio_fixture():
    events = [{} for _ in range(2293)]
    for event_id in ordinary_music.selected_event_ids():
        events[event_id] = {'id': event_id, 'categories': ['music'], 'simple_flags': 1,
                            'properties': {'fade_out_ms': 800, 'max_playbacks': 1},
                            'sound': {'flags': 0}}
    return {'events': events}


def source_fixture(rows, shift=0):
    fixture_rows = {key: [row[1], row[2], row[0], row[3]] for key, row in rows.items()}
    mach, arrival, layout = declaration_fixture(fixture_rows, shift, hash_prefix='sha256:')
    origin = arrival['provenance']['actor']['offset']
    table = layout['faction_table']
    raw = bytearray(mach.data)
    at = origin - mach.slice_offset + table[0]
    raw[at:at+16] = struct.pack('<4i', *ordinary_music.VALUES['faction_event_ids'])
    mach.data = bytes(raw)
    table[3] = 'sha256:' + hashlib.sha256(raw[at:at+16]).hexdigest()
    layout = {key: [row[2], row[0], row[1], row[3]] for key, row in layout.items()}
    fast_forward = {'radar': {'provenance': {'radar_music_publication_gate':
                                           {'offset': origin, 'bytes': 22}}}}
    return mach, fast_forward, layout


class OrdinaryMusicReaderTests(unittest.TestCase):
    def test_complete_layouts_relocate_and_detach(self):
        for name in ('LEGACY', 'APPSTORE'):
            for shift in (0, 0x800000):
                mach, fast_forward, rows = source_fixture(getattr(ordinary_music, name), shift)
                with patch.object(ordinary_music, name, rows):
                    found = ordinary_music.extract_ordinary_music(mach, fast_forward, audio_fixture())
                    self.assertEqual({k: v for k, v in found.items() if k != 'provenance'}, ordinary_music.VALUES)
                    self.assertEqual(ordinary_music.extract_ordinary_music(mach, fast_forward), found)
                    self.assertEqual(set(found['provenance']), set(rows))
                    found['battle_event_ids'].clear()
                    self.assertEqual(ordinary_music.extract_ordinary_music(mach, fast_forward, audio_fixture())['battle_event_ids'], [140, 141, 142])
                    for key, (_, delta, size, _) in rows.items():
                        for endpoint in (0, size-1):
                            changed = copy.copy(mach)
                            raw = bytearray(mach.data)
                            raw[fast_forward['radar']['provenance']['radar_music_publication_gate']['offset'] - mach.slice_offset + delta + endpoint] ^= 1
                            changed.data = bytes(raw)
                            self.assertEqual(ordinary_music.extract_ordinary_music(changed, fast_forward, audio_fixture()), {}, (name, key, endpoint))

    def test_source_identity_and_event_loop_are_required(self):
        mach, fast_forward, rows = source_fixture(ordinary_music.APPSTORE)
        with patch.object(ordinary_music, 'APPSTORE', rows):
            self.assertTrue(ordinary_music.extract_ordinary_music(mach, fast_forward, audio_fixture()))
            altered = copy.deepcopy(audio_fixture())
            altered['events'][134]['sound']['flags'] = 1
            self.assertEqual(ordinary_music.extract_ordinary_music(mach, fast_forward, altered), {})
            altered['events'][134]['sound']['flags'] = 0
            altered['events'][152]['properties']['fade_out_ms'] = 1000
            self.assertEqual(ordinary_music.extract_ordinary_music(mach, fast_forward, altered), {})
            self.assertEqual(ordinary_music.extract_ordinary_music(mach, fast_forward, []), {})
            bad = copy.deepcopy(fast_forward)
            bad['radar']['provenance']['radar_music_publication_gate']['offset'] += 1
            self.assertEqual(ordinary_music.extract_ordinary_music(mach, bad, audio_fixture()), {})
            mach.architecture = 'armv7'
            self.assertEqual(ordinary_music.extract_ordinary_music(mach, fast_forward, audio_fixture()), {})


FAST_FORWARD = {'radar': {'provenance': {'radar_music_publication_gate': {'offset': 5, 'bytes': 18, 'anchor': 1}}}}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidOrdinaryMusicTests(unittest.TestCase):
    def extract(self, lib, fast_forward=FAST_FORWARD, audio=None):
        return ordinary_music.extract_ordinary_music(lib, fast_forward, audio)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, ordinary_music, self.extract)
            image, layout, _ = layout_library(ordinary_music.ANDROID)
        with patch.object(ordinary_music, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            data = self.extract(lib, audio=audio_fixture())
            self.assertEqual(data, self.extract(lib))
            data['battle_event_ids'].append(1)
            self.assertEqual(ordinary_music.ANDROID_VALUES['battle_event_ids'], [140, 141, 142])
            short = {'events': audio_fixture()['events'][:2292]}
            long = {'events': audio_fixture()['events'] + [{}]}
            changed = audio_fixture()
            changed['events'][151]['properties']['fade_out_ms'] = 0
            cases = {'no gate': dict(fast_forward={'radar': {'provenance': {}}}), 'no radar': dict(fast_forward={}),
                     'none': dict(fast_forward=None), 'short audio': dict(audio=short), 'long audio': dict(audio=long), 'other fade': dict(audio=changed),
                     'audio list': dict(audio=[]), 'empty audio': dict(audio={})}
            for name, changes in cases.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_constants(self):
        rows, values = ordinary_music.ANDROID, ordinary_music.ANDROID_VALUES
        self.assertEqual(struct.unpack('<4i', bytes.fromhex(rows['faction_table'][3])), tuple(values['faction_event_ids']))
        # Above four ships: kind 10 already chose 151; marked 150, else 142.
        self.assertEqual(thumb(rows['large_battle'][3])[5:7], [('movne', 'r1, #0x%x' % values['battle_event_ids'][2]),
                                                               ('moveq', 'r1, #0x%x' % values['marked_battle_event_ids'][1])])
        self.assertIn(('movs', 'r1, #0x%x' % values['battle_event_ids'][1]), thumb(rows['medium_battle'][3]))
        size = thumb(rows['marked_group_size'][3])
        self.assertEqual([op for m, op in size if m in ('movs', 'movne') and op.startswith('r4')], ['r4, #%d' % n for n in values['marked_world_roll']['extra_group_sizes']])
        self.assertEqual(thumb(rows['marked_actor_flag'][3])[-1], ('strb.w', 'sb, [r0, #0x3e]'))
        self.assertEqual(thumb(rows['stats_marker_getter'][3])[0], ('ldrb.w', 'r0, [r0, #0xec]'))
        self.assertEqual(thumb(rows['stats_marker_setter'][3])[0], ('strb.w', 'r1, [r0, #0xec]'))
        self.assertEqual(thumb(rows['station_getter'][3])[0], ('ldr', 'r0, [r0, #8]'))
        self.assertEqual(thumb(rows['faction_getter'][3])[0], ('ldr', 'r0, [r0, #0x1c]'))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, ordinary_music, 'ordinary_music_definitions.gd')


if __name__ == '__main__':
    unittest.main()
