"""Android physical scenery contact proofs: named spans, vtable slots and the opening phases."""
import copy
import importlib.util
import unittest
from unittest.mock import patch
from gof2_content import physical_scenery_contacts as reader

ENTRY = {'offset': 900, 'bytes': 238, 'anchor': 100}
STAGING = {'player_motion': {'motion_before_controller': True, 'release_phase': 4, 'release_after_event_finished': 8},
           'escape': {'entry_phase': 4, 'first_phase': 5, 'entry_after_event_finished': 10, 'provenance': {'entry': ENTRY}}}
EXTERIOR = {'scope': 'first_mining_station_exterior'}


def parents(lib, **changes):
    """Arrival, scenery, exterior and staging whose escape entry is the library's own span."""
    from gof2_content.declaration_layouts import recognize_symbols
    staging = copy.deepcopy(STAGING)
    found = recognize_symbols(lib, {'entry': reader.ANDROID['opening_escape_off']})
    if found:
        staging['escape']['provenance']['entry'] = found['entry']
    values = {'arrival': {'scope': 'arrival'}, 'scenery': {'present': True}, 'exterior': EXTERIOR, 'staging': staging}
    for path, value in changes.items():
        *keys, last = path.split('.')
        target = values
        for key in keys:
            target = target[key]
        target[last] = value
    return values['arrival'], values['scenery'], values['exterior'], values['staging']


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidPhysicalSceneryContacts(unittest.TestCase):
    def setUp(self):
        import android_fixture
        from test_weapon_audio import roomy
        self.enterContext(patch.object(android_fixture, 'library', roomy(android_fixture.library)))

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        self.assertEqual(reader.ANDROID_VALUES, reader.VALUES)
        with patch.object(reader, 'ANDROID_VTABLES', {}):
            verify_android_proof(self, reader, lambda lib: reader.extract_physical_scenery_contacts(lib, *parents(lib)))
            image, layout, _ = layout_library(reader.ANDROID)
            with patch.object(reader, 'ANDROID', layout):
                lib = AndroidLibrary(image)
                result = reader.extract_physical_scenery_contacts(lib, *parents(lib))
                result['scope'] = 'changed'
                self.assertEqual(reader.ANDROID_VALUES['scope'], 'physical_scenery_contacts')
                for change in ({'arrival': {}}, {'scenery': {}}, {'exterior': {'scope': 'other'}}, {'exterior': {}},
                               {'staging.player_motion.motion_before_controller': False}, {'staging.player_motion.release_phase': 3},
                               {'staging.player_motion.release_phase': 3, 'staging.escape.entry_phase': 3},
                               {'staging.player_motion.release_after_event_finished': 9}, {'staging.escape.entry_phase': 5},
                               {'staging.escape.first_phase': 6}, {'staging.escape.entry_after_event_finished': 11},
                               {'staging.escape.provenance.entry': ENTRY}, {'staging.escape': {}}, {'staging': {}}):
                    self.assertEqual(reader.extract_physical_scenery_contacts(lib, *parents(lib, **change)), {}, change)
        # The code spans alone are not enough: the vtable slots must name the contact methods.
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            self.assertEqual(reader.extract_physical_scenery_contacts(lib, *parents(lib)), {})

    def test_vtable_slots(self):
        from android_text_fixture import text_library
        from gof2_content.android_shapes import objects
        from gof2_content.declaration_layouts import data_bytes
        from gof2_content.station_exterior import vtable_proof
        asteroid, station = (reader.ANDROID_VTABLES[k][2] for k in ('asteroid_vtable', 'station_response_vtable'))
        lib, _ = text_library({name: 'bx lr' for name in set(asteroid + station)},
                              {'_ZTV14PlayerAsteroid': [0, 0] + [0] * 14 + asteroid, '_ZTV13PlayerStation': [0, 0] + [0] * 20 + station})
        proof = vtable_proof(lib, reader.ANDROID_VTABLES)
        for key, table, delta, size in (('asteroid_vtable', '_ZTV14PlayerAsteroid', 64, 36), ('station_response_vtable', '_ZTV13PlayerStation', 88, 12)):
            anchor = data_bytes(lib, objects(lib)[table], 4)[1]
            self.assertEqual(proof[key], {'offset': anchor + delta, 'bytes': size, 'anchor': anchor}, key)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        layout = {**reader.ANDROID, **{k: (t, 8 + 4 * first, 4 * len(n), '00') for k, (t, first, n) in reader.ANDROID_VTABLES.items()}}
        with patch.object(reader, 'ANDROID', layout):
            assert_native_android(self, reader, 'physical_scenery_contact_definitions.gd')
