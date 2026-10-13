"""Android station exterior proofs: named spans, vtable slots and parent scope."""
import importlib.util
import unittest
from unittest.mock import patch
from gof2_content import station_exterior as reader

FLIGHT = {'scope': 'first_mining_flight_construction'}
ARRIVAL = {'scope': 'arrival'}


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidStationExterior(unittest.TestCase):
    def setUp(self):
        import android_fixture
        from test_weapon_audio import roomy
        self.enterContext(patch.object(android_fixture, 'library', roomy(android_fixture.library)))

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        # Synthetic layouts hold no vtables; their slots are tested below.
        with patch.object(reader, 'ANDROID_VTABLES', {}):
            verify_android_proof(self, reader, lambda lib: reader.extract_station_exterior(lib, ARRIVAL, FLIGHT))
            image, layout, _ = layout_library(reader.ANDROID)
            with patch.object(reader, 'ANDROID', layout):
                lib = AndroidLibrary(image)
                result = reader.extract_station_exterior(lib, ARRIVAL, FLIGHT)
                result['model_ids'].append(0)
                self.assertEqual(reader.ANDROID_VALUES['model_ids'], [21078, 21878, 22078])
                for arrival, flight in ((ARRIVAL, {'scope': 'other'}), (ARRIVAL, {}), ({}, FLIGHT)):
                    self.assertEqual(reader.extract_station_exterior(lib, arrival, flight), {}, (arrival, flight))
        # The code spans alone are not enough: the vtable slots must hold the point tests.
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertEqual(reader.extract_station_exterior(AndroidLibrary(image), ARRIVAL, FLIGHT), {})
        # Android derives mesh spheres from vertex bounds: only the sphere axes differ.
        self.assertEqual({k: v for k, v in reader.ANDROID_VALUES.items() if k != 'sphere_axis_map'},
                         {k: v for k, v in reader.VALUES.items() if k != 'sphere_axis_map'})
        self.assertEqual((reader.VALUES['sphere_axis_map'], reader.ANDROID_VALUES['sphere_axis_map']), ([1, 3, -2], [1, 2, 3]))

    def vtables(self, station=None, box=None, omit=()):
        from android_text_fixture import text_library
        names = [name for _, _, names in reader.ANDROID_VTABLES.values() for name in names]
        station = station or reader.ANDROID_VTABLES['station_vtable'][2]
        box = box or reader.ANDROID_VTABLES['box_vtable'][2]
        objects = {'_ZTV13PlayerStation': [0, 0] + [0] * 14 + list(station) + [0], '_ZTV11BoundingAAB': [0, 0, 0, 0, 0] + list(box)}
        lib, _ = text_library({name: 'bx lr' for name in names + ['_ZN1X1yEv']}, {k: v for k, v in objects.items() if k not in omit})
        return lib

    def test_vtable_slots(self):
        from gof2_content.android_shapes import objects
        from gof2_content.declaration_layouts import data_bytes
        lib = self.vtables()
        proof = reader.vtable_proof(lib, reader.ANDROID_VTABLES)
        for key, table, delta, size in (('station_vtable', '_ZTV13PlayerStation', 64, 12), ('box_vtable', '_ZTV11BoundingAAB', 20, 4)):
            anchor = data_bytes(lib, objects(lib)[table], 4)[1]
            self.assertEqual(proof[key], {'offset': anchor + delta, 'bytes': size, 'anchor': anchor}, key)
        self.assertEqual(reader.vtable_proof(lib, {}), {})
        names = reader.ANDROID_VTABLES['station_vtable'][2]
        for broken in (dict(station=[names[0], '_ZN1X1yEv', names[2]]), dict(box=['_ZN1X1yEv']), dict(station=names[1:] + [names[0]]),
                       dict(omit=('_ZTV11BoundingAAB',))):
            with self.subTest(broken):
                self.assertIsNone(reader.vtable_proof(self.vtables(**broken), reader.ANDROID_VTABLES))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        # The game's span table holds the vtable slots after the code spans.
        layout = {**reader.ANDROID, **{k: (t, 8 + 4 * first, 4 * len(n), '00') for k, (t, first, n) in reader.ANDROID_VTABLES.items()}}
        with patch.object(reader, 'ANDROID', layout):
            assert_native_android(self, reader, 'station_exterior_definitions.gd')
