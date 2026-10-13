"""The first local journey read from the Android library (Mido core)."""
import copy
from pathlib import Path
import struct
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from gof2_content import mido_travel as reader

GROUPS = ('ANDROID', 'ANDROID_ARRIVAL_BRIEFING', 'ANDROID_NAVIGATION')
STATION = {'scope': 'first_station_entry'}
TRAINING = {'scope': 'combat_training_encounter_construction'}


ARRIVAL = {'scope': 'rescue_choreography', 'provenance': {'actor': {'offset': 5, 'bytes': 24, 'anchor': 1}}}


def extract(lib, arrival=ARRIVAL):
    return reader.extract_mido_travel(lib, arrival, STATION, TRAINING)


def roomy(original):
    """android_fixture.library with .dynsym and .dynstr moved to the image's end (their fixed slots hold ~50 names)."""
    def build(functions, strings, **options):
        from android_fixture import IMPORTS
        image = bytearray(original(functions, strings, **options))
        names, symbols = bytearray(b'\0'), [bytes(16)]
        for label, code, address in [(n, None, None) for n in IMPORTS] + list(functions):
            symbols.append(struct.pack('<IIIBBH', len(names), 0 if code is None else address | 1, 0 if code is None else len(code),
                                       0x12, 0, 0 if code is None else 5))
            names += label.encode() + b'\0'
        table, = struct.unpack_from('<I', image, 32)
        at = (len(image) + 15) & ~15
        image += bytes(at - len(image)) + b''.join(symbols)
        struct.pack_into('<III', image, table + 40 + 12, at, at, 16 * len(symbols))  # .dynsym address, offset, size
        struct.pack_into('<III', image, table + 80 + 12, len(image), len(image), len(names))  # .dynstr
        return bytes(image + names)
    return build


class MidoTravelAndroidTests(unittest.TestCase):
    def synthetic(self, shift=0):
        import android_fixture
        merged = {k: v for group in GROUPS for k, v in getattr(reader, group).items()}
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            image, patched, _ = android_fixture.layout_library(merged, shift)
        return image, {group: {k: patched[k] for k in getattr(reader, group)} for group in GROUPS}

    def expected(self):
        result = copy.deepcopy(reader.ANDROID_VALUES)
        result.update(continuation=reader.MAC_CONTINUATION, return_visit=reader.ANDROID_RETURN_VISIT,
                      arrival_briefing=reader.MAC_ARRIVAL_BRIEFING, contract_navigation=reader.CONTRACT_NAVIGATION)
        return result

    def test_android_proofs_and_relocation(self):
        from gof2_content.android_library import AndroidLibrary
        for shift in (0, 0x1000):
            image, layouts = self.synthetic(shift)
            with patch.multiple(reader, **layouts):
                result = extract(AndroidLibrary(image))
                proof = result.pop('provenance')
                self.assertEqual(result, self.expected())
                merged = {k: v for layout in layouts.values() for k, v in layout.items()}
                self.assertEqual(set(proof), set(merged))
                for key, span in proof.items():
                    self.assertEqual(span['offset'] - span['anchor'], merged[key][5] if len(merged[key]) == 6 else merged[key][1], key)
                # The result is a copy of the module's values.
                result['travel']['target_window_divisor'] = 0
                result['return_visit']['contract_gate']['additional_completions'] = 0
                self.assertEqual(extract(AndroidLibrary(image)).get('return_visit'), reader.ANDROID_RETURN_VISIT)
                self.assertEqual(reader.ANDROID_VALUES['travel']['target_window_divisor'], 16)

    def test_every_proven_byte_gates_its_capability(self):
        from gof2_content.android_library import AndroidLibrary
        image, layouts = self.synthetic()
        with patch.multiple(reader, **layouts):
            proof = extract(AndroidLibrary(image))['provenance']
            core = [(proof[k]['offset'], proof[k]['offset'] + proof[k]['bytes']) for k in layouts['ANDROID']]
            for group, lost in (('ANDROID', None), ('ANDROID_ARRIVAL_BRIEFING', 'arrival_briefing'), ('ANDROID_NAVIGATION', 'contract_navigation')):
                for key in layouts[group]:
                    span = proof[key]
                    for at in {span['offset'], span['offset'] + span['bytes'] - 1}:
                        raw = bytearray(image)
                        raw[at] ^= 0xff
                        broken = extract(AndroidLibrary(bytes(raw)))
                        if lost is None or any(a <= at < b for a, b in core):
                            self.assertEqual(broken, {}, (key, at))
                        else:
                            self.assertNotIn(lost, broken, key)
                            self.assertEqual(broken['conversations'], reader.ANDROID_VALUES['conversations'], key)

    def test_android_requires_its_parents(self):
        from gof2_content.android_library import AndroidLibrary
        image, layouts = self.synthetic()
        with patch.multiple(reader, **layouts):
            lib = AndroidLibrary(image)
            self.assertTrue(extract(lib))
            self.assertEqual(extract(lib, {}), {})
            self.assertEqual(extract(lib, {'provenance': ARRIVAL['provenance']}), {})
            self.assertEqual(extract(lib, {'scope': 'rescue_choreography', 'provenance': {}}), {})
            self.assertEqual(reader.extract_mido_travel(lib, ARRIVAL, {}, TRAINING), {})
            self.assertEqual(reader.extract_mido_travel(lib, ARRIVAL, STATION, {}), {})

    def test_android_values_differ_only_where_the_library_does(self):
        values = copy.deepcopy(reader.ANDROID_VALUES)
        # Radar::Radar keeps Globals::w / 16 as the planet window (the Mac: / 18).
        self.assertEqual(values['travel'].pop('target_window_divisor'), 16)
        mac = copy.deepcopy(reader.MAC_VALUES)
        mac['travel'].pop('target_window_divisor')
        self.assertEqual(values, mac)
        # Cursor 12 asks for one more completed contract (the Mac: four).
        visit = copy.deepcopy(reader.ANDROID_RETURN_VISIT)
        self.assertEqual(visit['contract_gate'].pop('additional_completions'), 1)
        mac = copy.deepcopy(reader.MAC_RETURN_VISIT)
        mac['contract_gate'].pop('additional_completions')
        self.assertEqual(visit, mac)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'mido_travel_definitions.gd')
        assert_native_android(self, reader, 'mido_travel_definitions.gd', 'ANDROID_RETURN_VISIT', 'ANDROID_ARRIVAL_BRIEFING')
        assert_native_android(self, reader, 'mido_travel_definitions.gd', 'ANDROID_RETURN_VISIT', 'ANDROID_NAVIGATION')


if __name__ == '__main__':
    unittest.main()
