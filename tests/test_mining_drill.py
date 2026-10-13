"""Android drill proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from unittest.mock import patch
from gof2_content import mining_drill as reader

FLIGHT = {'scope': 'first_mining_flight_construction'}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidMiningDrillTests(unittest.TestCase):
    def extract(self, lib, flight=FLIGHT):
        return reader.extract_mining_drill(lib, {}, flight)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        # Synthetic layouts hold no exported tables or resource records; both are tested below.
        tables = {k: {'offset': 0, 'bytes': v[1], 'anchor': 0} for k, v in reader.ANDROID_TABLES.items()}
        with patch.object(reader, 'table_proof', lambda lib, rows: tables), patch.object(reader, 'alias_records', lambda lib, proof: True):
            with roomy_layouts():
                verify_android_proof(self, reader, lambda lib: (lambda r: dict(r, provenance={k: v for k, v in r['provenance'].items() if k not in tables}) if r else r)(self.extract(lib)), values='VALUES')
                image, layout, _ = layout_library(reader.ANDROID)
            with patch.object(reader, 'ANDROID', layout):
                lib = AndroidLibrary(image)
                data = self.extract(lib)
                self.assertEqual({k: data['provenance'][k] for k in tables}, tables)
                data['diameters'][0].append(0)
                data['image_aliases']['1245']['region'] = 0
                self.assertEqual(len(reader.VALUES['diameters'][0]), 7)
                self.assertEqual(reader.VALUES['image_aliases']['1245']['region'], 144)
                for name, flight in {'other flight': {'scope': 'first_station_departure'}, 'no flight': {}, 'none': None}.items():
                    self.assertEqual(self.extract(lib, flight), {}, name)
                with patch.object(reader, 'table_proof', lambda lib, rows: None):
                    self.assertEqual(self.extract(lib), {})
                with patch.object(reader, 'alias_records', lambda lib, proof: False):
                    self.assertEqual(self.extract(lib), {})

    def tables_library(self, diameters=None, speeds=None, names=('LAYER_DIAMETERS', 'LAYER_SPEEDS')):
        from android_text_fixture import text_library
        rows = reader.ANDROID_TABLES
        words = lambda hex_code: list(struct.unpack('<%dI' % (len(hex_code) // 8), bytes.fromhex(hex_code)))
        objects = {'LAYER_DIAMETERS': diameters or words(rows['diameters'][2]), 'LAYER_SPEEDS': speeds or words(rows['spin_rates'][2]),
                   'OTHER': [0]}
        # The literal pair sits at the recorded delta of each reader (32 in isInCurrentLayer, 410 in update).
        pad = lambda n: '\n'.join(['nop'] * (n // 2))
        lib, _ = text_library({'_ZN10MiningGame16isInCurrentLayerEv': pad(32) + '\nldr.w ip, =&%s\nadd ip, pc\nbx lr' % names[0],
                               '_ZN10MiningGame6updateEi': pad(410) + '\nldr r0, =&%s\nadd r0, pc\nbx lr' % names[1]}, objects)
        return lib

    def test_layer_tables(self):
        from gof2_content.android_shapes import objects
        from gof2_content.declaration_layouts import data_bytes
        lib = self.tables_library()
        proof = reader.table_proof(lib, reader.ANDROID_TABLES)
        for key, name, size in (('diameters', 'LAYER_DIAMETERS', 112), ('spin_rates', 'LAYER_SPEEDS', 28)):
            offset = data_bytes(lib, objects(lib)[name], 4)[1]
            self.assertEqual(proof[key], {'offset': offset, 'bytes': size, 'anchor': offset}, key)
        self.assertEqual(reader.table_proof(lib, {}), {})
        # A table without its exported symbol.
        import gof2_content.android_shapes as shapes
        everything = shapes.objects(lib)
        with patch.object(shapes, 'objects', lambda lib: {k: v for k, v in everything.items() if k != 'LAYER_SPEEDS'}):
            self.assertIsNone(reader.table_proof(lib, reader.ANDROID_TABLES))
        for broken in (dict(diameters=[250] * 28), dict(speeds=[0] * 7), dict(names=('OTHER', 'LAYER_SPEEDS')), dict(names=('LAYER_DIAMETERS', 'OTHER'))):
            with self.subTest(broken):
                self.assertIsNone(reader.table_proof(self.tables_library(**broken), reader.ANDROID_TABLES))
        # The tables are the Mac's diameters and spin rates.
        diameters = struct.unpack('<28i', bytes.fromhex(reader.ANDROID_TABLES['diameters'][2]))
        self.assertEqual([list(diameters[i:i + 7]) for i in range(0, 28, 7)], reader.VALUES['diameters'])
        self.assertEqual(list(struct.unpack('<7f', bytes.fromhex(reader.ANDROID_TABLES['spin_rates'][2]))), reader.VALUES['spin_rates'])

    def test_alias_records(self):
        aliases = reader.VALUES['image_aliases']
        proof = {'image_alias_' + k: {'offset': 1000 + i} for i, k in enumerate(aliases)}
        rows = [{'id': int(k), 'texture_id': v['texture_id'], 'second': v['region'], 'source_offset': 1000 + i} for i, (k, v) in enumerate(aliases.items())]
        with patch('gof2_content.font_bindings.payload_records', lambda lib, kind: rows + [None] if kind == 3 else []):
            self.assertTrue(reader.alias_records(None, proof))
        for index, change in ((0, dict(id=1)), (3, dict(texture_id=10063)), (16, dict(second=0)), (5, dict(source_offset=1))):
            broken = [dict(r, **change) if i == index else r for i, r in enumerate(rows)]
            with patch('gof2_content.font_bindings.payload_records', lambda lib, kind: broken):
                self.assertFalse(reader.alias_records(None, proof), (index, change))

    def test_android_constants(self):
        rows, values = reader.ANDROID, reader.VALUES
        up = thumb(rows['input_up'][3])
        self.assertEqual((up[0][0], float(up[0][1].split('#')[1])), ('vmov.f32', values['input_gain']))
        self.assertEqual([up[3], thumb(rows['input_left'][3])[3]], [('vstr', 's0, [r0, #4]'), ('vstr', 's0, [r0]')])
        self.assertEqual(thumb(rows['won_getter'][3])[0], ('ldrb.w', 'r0, [r0, #0x81]'))
        self.assertEqual(thumb(rows['failed_getter'][3])[0], ('ldrb.w', 'r0, [r0, #0x82]'))
        self.assertEqual(thumb(rows['core_getter'][3])[0], ('ldrb.w', 'r0, [r0, #0x83]'))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        layout = {**reader.ANDROID, **{k: (name, 0, size, '00') for k, (name, size, _, _) in reader.ANDROID_TABLES.items()}}
        with patch.object(reader, 'ANDROID', layout):
            assert_native_android(self, reader, 'mining_drill_definitions.gd', values='VALUES')
