"""Import-only Fast Forward recognition and native declaration contract."""
import copy
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from gof2_content import fast_forward
from declaration_fixture import declaration_fixture


def fixture(rows, shift=0):
    mach, arrival, layouts = declaration_fixture(rows, shift, hash_prefix='sha256:')
    # Exercise the same section reader as initialized data and Objective-C metadata.
    for name, section in zip(rows, mach.sections):
        if section['name'] in (b'__data', b'__objc_const') or name == 'flight_vtable':
            section['segment'] = b'__DATA'
    return mach, arrival, layouts


class FastForwardTests(unittest.TestCase):
    def variants(self):
        return [('LAYOUTS', fast_forward.LAYOUTS), ('MAC_ALTERNATE', fast_forward.MAC_ALTERNATE)]

    def test_both_complete_layouts_and_relocated_virtual_addresses(self):
        for name, rows in self.variants():
            for relocation in (0, 0x800000):
                with self.subTest(layout=name, relocation=relocation):
                    mach, arrival, layouts = fixture(rows, relocation)
                    with patch.object(fast_forward, name, layouts):
                        result = fast_forward.extract_fast_forward(mach, arrival)
                    expected = copy.deepcopy(fast_forward.VALUES)
                    expected['provenance'] = {
                        key: {'offset': arrival['provenance']['actor']['offset'] + row[0], 'bytes': row[1]}
                        for key, row in layouts.items()}
                    self.assertEqual(result, expected)
                    self.assertEqual(len(result['provenance']), 82)

    def test_nested_output_is_detached(self):
        for name, rows in self.variants():
            mach, arrival, layouts = fixture(rows)
            with patch.object(fast_forward, name, layouts):
                first = fast_forward.extract_fast_forward(mach, arrival)
                first['activation']['navigation_any'].clear()
                first['camera']['initial_cached_handling'] = 1
                first['provenance']['arrival_actor']['offset'] = 0
                second = fast_forward.extract_fast_forward(mach, arrival)
                self.assertEqual(second['activation'], fast_forward.VALUES['activation'])
                self.assertEqual(second['camera'], fast_forward.VALUES['camera'])
                self.assertEqual(second['provenance']['arrival_actor'], arrival['provenance']['actor'])

    def test_optional_radar_uses_the_matching_core_layout(self):
        for core_name, radar_name in [('LAYOUTS', 'RADAR_LAYOUTS'),
                                      ('MAC_ALTERNATE', 'RADAR_MAC_ALTERNATE')]:
            core = getattr(fast_forward, core_name)
            radar = getattr(fast_forward, radar_name)
            combined = dict(core, **{'radar.' + key: row for key, row in radar.items()})
            for shift in (0, 0x800000):
                mach, arrival, rows = fixture(combined, shift)
                core_rows = {key: rows[key] for key in core}
                radar_rows = {key: rows['radar.' + key] for key in radar}
                with patch.object(fast_forward, core_name, core_rows), patch.object(fast_forward, radar_name, radar_rows):
                    result = fast_forward.extract_fast_forward(mach, arrival)
                    expected = copy.deepcopy(fast_forward.RADAR_VALUES)
                    expected['provenance'] = {key: {'offset': arrival['provenance']['actor']['offset'] + row[0], 'bytes': row[1]}
                                              for key, row in radar_rows.items()}
                    self.assertEqual(result.get('radar'), expected)
                    result['radar']['inactive_modes'].clear()
                    self.assertEqual(fast_forward.extract_fast_forward(mach, arrival)['radar'], expected)
                    origin = arrival['provenance']['actor']['offset'] - mach.slice_offset
                    for key, (delta, size, _, _) in radar_rows.items():
                        for endpoint in (0, size - 1):
                            with self.subTest(layout=core_name, guard=key, endpoint=endpoint):
                                changed = copy.copy(mach)
                                raw = bytearray(mach.data)
                                raw[origin + delta + endpoint] ^= 1
                                changed.data = bytes(raw)
                                self.assertNotIn('radar', fast_forward.extract_fast_forward(changed, arrival))
                    foreign = fast_forward.RADAR_MAC_ALTERNATE if radar_name == 'RADAR_LAYOUTS' else fast_forward.RADAR_LAYOUTS
                    with patch.object(fast_forward, radar_name, foreign):
                        self.assertNotIn('radar', fast_forward.extract_fast_forward(mach, arrival))

    def test_every_span_endpoint_must_match(self):
        for name, rows in self.variants():
            mach, arrival, layouts = fixture(rows)
            origin = arrival['provenance']['actor']['offset'] - mach.slice_offset
            with patch.object(fast_forward, name, layouts):
                for key, (delta, size, _, _) in layouts.items():
                    for endpoint in (0, size - 1):
                        with self.subTest(layout=name, span=key, endpoint=endpoint):
                            changed = copy.copy(mach)
                            raw = bytearray(mach.data)
                            raw[origin + delta + endpoint] ^= 1
                            changed.data = bytes(raw)
                            self.assertEqual(fast_forward.extract_fast_forward(changed, arrival), {})

    def test_no_foreign_hybrid_or_ambiguous_variant(self):
        for name, rows in self.variants():
            other_name = 'MAC_ALTERNATE' if name == 'LAYOUTS' else 'LAYOUTS'
            _, _, foreign = fixture(getattr(fast_forward, other_name))
            mach, arrival, layouts = fixture(rows)
            hybrid = copy.deepcopy(layouts)
            hybrid['frame_cancel_and_scale'] = foreign['frame_cancel_and_scale']
            for rejected in (foreign, hybrid):
                with self.subTest(layout=name, kind='foreign_or_hybrid'):
                    with patch.object(fast_forward, name, rejected):
                        self.assertEqual(fast_forward.extract_fast_forward(mach, arrival), {})
            with patch.object(fast_forward, name, layouts), patch.object(fast_forward, other_name, layouts):
                self.assertEqual(fast_forward.extract_fast_forward(mach, arrival), {})

    def test_validated_arrival_anchor_and_architecture_are_required(self):
        mach, arrival, layouts = fixture(fast_forward.LAYOUTS)
        invalid = [None, {}, {'provenance': None}, {'provenance': {}}, {'provenance': {'actor': {}}}]
        for field, bad_values in [('bytes', [314, 316, True, 315.0, '315']),
                                  ('offset', [None, True, -1, 0.0, '0', len(mach.data) + mach.slice_offset])]:
            for value in bad_values:
                item = copy.deepcopy(arrival)
                item['provenance']['actor'][field] = value
                invalid.append(item)
        shifted = copy.deepcopy(arrival)
        shifted['provenance']['actor']['offset'] += 1
        invalid.append(shifted)
        with patch.object(fast_forward, 'LAYOUTS', layouts):
            for item in invalid:
                with self.subTest(arrival=item):
                    self.assertEqual(fast_forward.extract_fast_forward(mach, item), {})
            for arch in ('armv7', 'arm64', '', None):
                changed = copy.copy(mach)
                changed.architecture = arch
                self.assertEqual(fast_forward.extract_fast_forward(changed, arrival), {})

    def test_actual_arrival_bytes_and_section_are_required(self):
        mach, arrival, layouts = fixture(fast_forward.LAYOUTS)
        with patch.object(fast_forward, 'LAYOUTS', layouts):
            changed = copy.deepcopy(mach)
            changed.sections[0]['name'] = b'__const'
            self.assertEqual(fast_forward.extract_fast_forward(changed, arrival), {})
            changed = copy.copy(mach)
            raw = bytearray(mach.data)
            offset = arrival['provenance']['actor']['offset'] - mach.slice_offset
            raw[offset:offset + 315] = bytes(315)
            changed.data = bytes(raw)
            self.assertEqual(fast_forward.extract_fast_forward(changed, arrival), {})

    def test_bounded_sections_truncation_and_file_offsets(self):
        mach, arrival, layouts = fixture(fast_forward.LAYOUTS)
        with patch.object(fast_forward, 'LAYOUTS', layouts):
            changed = copy.copy(mach)
            changed.data = mach.data[:-17]
            self.assertEqual(fast_forward.extract_fast_forward(changed, arrival), {})
            changed = copy.deepcopy(mach)
            changed.sections[0]['length'] -= 1
            self.assertEqual(fast_forward.extract_fast_forward(changed, arrival), {})
            changed = copy.deepcopy(mach)
            changed.sections[0]['offset'] += 1
            self.assertEqual(fast_forward.extract_fast_forward(changed, arrival), {})

    def test_unrelated_bytes_are_not_an_archive_fingerprint(self):
        mach, arrival, layouts = fixture(fast_forward.LAYOUTS)
        raw = bytearray(mach.data)
        raw[0] ^= 255
        mach.data = bytes(raw)
        with patch.object(fast_forward, 'LAYOUTS', layouts):
            self.assertTrue(fast_forward.extract_fast_forward(mach, arrival))

    def test_native_constants_and_span_variants_match_import_contract(self):
        path = Path(__file__).resolve().parents[1] / 'game/src/content/fast_forward_definitions.gd'
        text = path.read_text()
        decoder = json.JSONDecoder()
        for native_name, expected in [('VALUES', fast_forward.VALUES),
                                      ('SPANS', {key: row[:2] for key, row in fast_forward.LAYOUTS.items()}),
                                      ('MAC_ALTERNATE', {key: row[:2] for key, row in fast_forward.MAC_ALTERNATE.items()}),
                                      ('RADAR_VALUES', fast_forward.RADAR_VALUES),
                                      ('RADAR_SPANS', {key: row[:2] for key, row in fast_forward.RADAR_LAYOUTS.items()}),
                                      ('RADAR_MAC_ALTERNATE', {key: row[:2] for key, row in fast_forward.RADAR_MAC_ALTERNATE.items()})]:
            declared, _ = decoder.raw_decode(text.split('const ' + native_name + ' := ', 1)[1])
            self.assertEqual(declared, expected)

    def test_timing_edges_camera_cache_and_scope_are_explicit(self):
        values = fast_forward.VALUES
        self.assertEqual(values['input']['delivery'], 'hold_until_release')
        self.assertFalse(values['input']['automatic_reset_rearms_held_key'])
        self.assertEqual(values['timing']['simulation_frame_max_ms'], 750)
        self.assertEqual(values['timing']['real_frame_max_ms'], 150)
        self.assertEqual(values['timing']['simulation_passes'], 1)
        self.assertEqual(values['timing']['fast_camera_passes'], 5)
        self.assertFalse(values['activation']['training_waypoint_grants_eligibility'])
        self.assertEqual(values['cancellation']['near_target_sample'], 'previous_player_update')
        self.assertEqual(values['camera']['input_policy'], 'relative_mouse_capture')
        self.assertTrue(values['camera']['fixed_refresh_preserves_cache'])
        self.assertTrue(values['camera']['fast_suppresses_normal_refresh'])
        self.assertFalse(values['supported_scope']['later_approach'])
        self.assertFalse(values['supported_scope']['slow_motion_combination'])
        self.assertNotIn('provenance', values)
        self.assertNotIn('default_key', values['input'])


ARRIVAL = {'scope': 'rescue_choreography', 'provenance': {'actor': {'offset': 1, 'bytes': 2, 'anchor': 0}}}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidFastForwardTests(unittest.TestCase):
    def extract(self, lib, arrival=ARRIVAL):
        return fast_forward.extract_fast_forward(lib, arrival)

    def test_android_core_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with patch.object(fast_forward, 'ANDROID_VTABLES', {}), patch.object(fast_forward, 'RADAR_ANDROID', {}):
            with roomy_layouts():
                verify_android_proof(self, fast_forward, self.extract)
                image, layout, _ = layout_library(fast_forward.ANDROID)
            with patch.object(fast_forward, 'ANDROID', layout):
                lib = AndroidLibrary(image)
                data = self.extract(lib)
                self.assertNotIn('radar', data)
                data['timing']['fast_multiplier'] = 1
                self.assertEqual(fast_forward.ANDROID_VALUES['timing']['fast_multiplier'], 5.0)
                cases = {'other arrival': {'scope': 'x', 'provenance': {'actor': {}}}, 'no actor': dict(ARRIVAL, provenance={}),
                         'no provenance': {'scope': 'rescue_choreography'}, 'empty': {}, 'none': None}
                for name, arrival in cases.items():
                    self.assertEqual(self.extract(lib, arrival), {}, name)
                slot = {'flight_vtable': {'offset': 1, 'bytes': 44, 'anchor': 0}}
                with patch.object(fast_forward, 'vtable_proof', lambda lib, rows: slot if rows is fast_forward.ANDROID_VTABLES else {}):
                    self.assertEqual(self.extract(lib)['provenance']['flight_vtable'], slot['flight_vtable'])
        # The code spans alone are not enough: MGame's vtable must hold the handlers.
        with roomy_layouts():
            image, layout, _ = layout_library(fast_forward.ANDROID)
        with patch.object(fast_forward, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            self.assertTrue(fast_forward.recognize_symbols(lib, layout))
            self.assertEqual(self.extract(lib), {})

    def test_android_radar_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            _, radar, _ = layout_library(fast_forward.RADAR_ANDROID)
        # The core proof reuses one radar span, so it holds in the radar's own synthetic library.
        core = {'core': radar['junk_constructor']}
        with patch.object(fast_forward, 'ANDROID_VTABLES', {}), patch.object(fast_forward, 'RADAR_ANDROID_VTABLES', {}), \
                patch.object(fast_forward, 'ANDROID', core):
            with roomy_layouts():
                verify_android_proof(self, fast_forward, lambda lib: self.extract(lib).get('radar', {}),
                                     layout='RADAR_ANDROID', values='RADAR_ANDROID_VALUES')
            with patch.object(fast_forward, 'RADAR_ANDROID', radar):
                with roomy_layouts():
                    image, _, _ = layout_library(fast_forward.RADAR_ANDROID)
                lib = AndroidLibrary(image)
                data = self.extract(lib)
                self.assertEqual({k: v for k, v in data.items() if k not in ('provenance', 'radar')}, fast_forward.ANDROID_VALUES)
                data['radar']['inactive_modes'].append(5)
                self.assertEqual(fast_forward.RADAR_ANDROID_VALUES['inactive_modes'], [3, 4])
                radar_slot = {'flight_update_draw_vtable': {'offset': 1, 'bytes': 12, 'anchor': 0}}
                with patch.object(fast_forward, 'vtable_proof', lambda lib, rows: radar_slot if rows is fast_forward.RADAR_ANDROID_VTABLES else {}):
                    self.assertEqual(self.extract(lib)['radar']['provenance']['flight_update_draw_vtable'], radar_slot['flight_update_draw_vtable'])
                # Without its vtable slots the radar is absent while the core stays.
                with patch.object(fast_forward, 'vtable_proof', lambda lib, rows: None if rows is fast_forward.RADAR_ANDROID_VTABLES else {}):
                    data = self.extract(lib)
                    self.assertTrue(data)
                    self.assertNotIn('radar', data)

    def test_vtable_slots(self):
        from android_text_fixture import text_library
        names = fast_forward.ANDROID_VTABLES['flight_vtable'][2]
        functions = {name: 'bx lr' for name in names}
        lib, _ = text_library(functions, {'_ZTV5MGame': [0] * 6 + names + [0]})
        proof = fast_forward.vtable_proof(lib, fast_forward.ANDROID_VTABLES)
        self.assertEqual((proof['flight_vtable']['offset'] - proof['flight_vtable']['anchor'], proof['flight_vtable']['bytes']), (8 + 4 * 4, 44))
        radar = fast_forward.vtable_proof(lib, fast_forward.RADAR_ANDROID_VTABLES)['flight_update_draw_vtable']
        self.assertEqual((radar['offset'] - radar['anchor'], radar['bytes']), (8 + 4 * 12, 12))
        self.assertEqual(names[8:], fast_forward.RADAR_ANDROID_VTABLES['flight_update_draw_vtable'][2])
        lib, _ = text_library(functions, {'_ZTV5MGame': [0] * 6 + names[1:] + [names[0], 0]})
        self.assertIsNone(fast_forward.vtable_proof(lib, fast_forward.ANDROID_VTABLES))
        self.assertIsNone(fast_forward.vtable_proof(lib, fast_forward.RADAR_ANDROID_VTABLES))

    def test_android_constants(self):
        import struct
        rows, radar, values = fast_forward.ANDROID, fast_forward.RADAR_ANDROID, fast_forward.ANDROID_VALUES
        self.assertEqual(thumb(rows['default_multiplier'][3])[::3], [('mov.w', 'r2, #0x3f800000'), ('str.w', 'r2, [r4, #0x160]')])
        self.assertEqual(struct.unpack('<f', bytes.fromhex(rows['autopilot_gain'][3]))[0], values['navigation']['autopilot_gain_add'])
        self.assertEqual(rows['mining_gain'][3], rows['autopilot_gain'][3])
        self.assertEqual(thumb(rows['pause_gate'][3])[0], ('ldrb.w', 'r0, [fp, #0x5d]'))
        self.assertEqual(thumb(rows['slow_motion_gate'][3])[0], ('ldr.w', 'r1, [fp, #0x164]'))
        self.assertEqual(thumb(rows['near_target_reset'][3])[1:], [('strb.w', 'r0, [sb, #0x145]'), ('strb.w', 'r0, [sb, #0x330]')])
        self.assertEqual(thumb(rows['near_target_active'][3])[0], ('ldrb.w', 'r0, [r0, #0x330]'))
        # KIPlayer::isDying / isDead: modes 3 and 4 leave the battle count.
        modes = [int(thumb(rows[k][3])[2][1].split('#')[1]) for k in ('inactive_getter', 'destroyed_getter')]
        self.assertEqual(modes, fast_forward.RADAR_ANDROID_VALUES['inactive_modes'])
        self.assertEqual(thumb(rows['battle_flag_set'][3])[:2], [('ldr.w', 'r2, [r4, #0x1b8]'), ('cmp', 'r2, #1')])
        self.assertEqual(thumb(rows['battle_counter_reset'][3])[1], ('str.w', 'r0, [r4, #0x1b8]'))
        self.assertIn(('cmp', 'r1, #0x%x' % fast_forward.RADAR_ANDROID_VALUES['guarded_music_id']), thumb(radar['radar_music_publication_gate'][3]))
        self.assertIn(('movs', 'r1, #0x%x' % fast_forward.RADAR_ANDROID_VALUES['scanner_equipment_type']), thumb(radar['radar_scanner_lookup'][3]))
        self.assertEqual(thumb(radar['radar_entry_gate'][3])[0], ('ldrb.w', 'r1, [r0, #0x48]'))
        self.assertEqual(thumb(radar['small_ship_drop_flag'][3])[2], ('strb.w', 'r0, [r4, #0x48]'))
        self.assertIn(('strb.w', 'r1, [sl, #0x54]'), thumb(radar['radar_initial_counter_battle'][3]))
        self.assertIn(('movw', 'r1, #0x4215'), thumb(radar['junk_factory_link'][3]))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        def slots(tables):
            return {k: (t, 8 + 4 * first, 4 * len(n), '00') for k, (t, first, n) in tables.items()}
        with patch.object(fast_forward, 'ANDROID', {**fast_forward.ANDROID, **slots(fast_forward.ANDROID_VTABLES)}), \
                patch.object(fast_forward, 'RADAR_ANDROID', {**fast_forward.RADAR_ANDROID, **slots(fast_forward.RADAR_ANDROID_VTABLES)}):
            assert_native_android(self, fast_forward, 'fast_forward_definitions.gd')
            assert_native_android(self, fast_forward, 'fast_forward_definitions.gd', values='RADAR_ANDROID_VALUES', layout='RADAR_ANDROID')


if __name__ == '__main__':
    unittest.main()
