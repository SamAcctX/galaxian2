"""Both Mac station layouts: bounded pointers/header, hashes and source damage."""
import copy
import re
import struct
import unittest
from unittest.mock import patch
from declaration_fixture import declaration_fixture
from gof2_content import station_presentation as reader


def variants():
    return [('LAYOUTS',reader.LAYOUTS,reader.VALUES),
            ('MAC_ALTERNATE',reader.MAC_ALTERNATE,reader.MAC_VALUES)]


def extract(mach,arrival):
    return reader.extract_station_presentation(mach,arrival,{'scope':'first_station_entry'})


class StationPresentationTests(unittest.TestCase):
    def test_relocated_complete_layout_and_detachment(self):
        for name,rows,expected in variants():
            for shift in [0,0x2400000]:
                mach,arrival,proofs=declaration_fixture(rows,shift,'sha256:')
                with patch.object(reader,name,proofs):
                    result=extract(mach,arrival)
                    self.assertEqual({k:v for k,v in result.items() if k!='provenance'},expected)
                    self.assertEqual(set(result['provenance']),set(rows))
                    result['dialogue']['voice_event_ids'].clear()
                    self.assertEqual(extract(mach,arrival)['dialogue']['voice_event_ids'],expected['dialogue']['voice_event_ids'])

    def test_every_source_boundary_is_required(self):
        for name,rows,_ in variants():
            mach,arrival,proofs=declaration_fixture(rows,hash_prefix='sha256:')
            origin=arrival['provenance']['actor']['offset']-mach.slice_offset
            with patch.object(reader,name,proofs):
                self.assertTrue(extract(mach,arrival))
                for key,(delta,size,_,_) in rows.items():
                    for edge in [0,size-1]:
                        bad=copy.copy(mach);data=bytearray(mach.data);data[origin+delta+edge]^=255;bad.data=bytes(data)
                        self.assertEqual(extract(bad,arrival),{},(name,key,edge))

    def test_context_section_header_and_truncation(self):
        for name,rows,_ in variants():
            for case in ['architecture','origin','extent','station','section','header_bounds','truncated']:
                mach,arrival,proofs=declaration_fixture(rows,hash_prefix='sha256:')
                station={'scope':'first_station_entry'}
                if case=='architecture':mach.architecture='armv7'
                elif case=='origin':arrival['provenance']['actor']['offset']+=1
                elif case=='extent':arrival['provenance']['actor']['bytes']=314
                elif case=='station':station.clear()
                elif case=='section':mach.sections=[s for s in mach.sections if s['name']!=b'__data']
                elif case=='header_bounds':proofs['zero_fill_section'][0]+=4096
                else:mach.data=mach.data[:128]
                with patch.object(reader,name,proofs):
                    self.assertEqual(reader.extract_station_presentation(mach,arrival,station),{},(name,case))

def listing(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.address, i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


def as_float(word):
    return struct.unpack('<f', struct.pack('<I', word & 0xffffffff))[0]


def built_floats(hex_code):
    """Floats completed by movt (on a movw/movs low half) or loaded whole by mov.w, in order."""
    low, found = {}, []
    for _, mnemonic, operands in listing(hex_code):
        immediate = re.fullmatch(r'(\w+), #(-?(?:0x[0-9a-f]+|\d+))', operands)
        if not immediate or mnemonic not in ('movw', 'movs', 'movt', 'mov.w'):
            continue
        register, value = immediate[1], int(immediate[2], 0)
        if mnemonic in ('movw', 'movs'):
            low[register] = value
        elif mnemonic == 'movt' and register in low:
            found.append(as_float(value << 16 | low.pop(register)))
        elif mnemonic == 'mov.w' and value & 0xffff == 0 and value >> 16:
            found.append(as_float(value))
    return found


def immediates(hex_code, mnemonic, register):
    return [int(o.split('#')[1], 0) for _, m, o in listing(hex_code) if m == mnemonic and o.startswith(register + ', #')]


def pool(hex_code, address, fmt):
    """The PC-relative literal a vldr at `address` reads from the span itself."""
    line = next(o for a, m, o in listing(hex_code) if a == address and m == 'vldr')
    target = ((address + 4) & ~3) + int(line.split('#')[1].rstrip(']'), 0)
    return struct.unpack_from(fmt, bytes.fromhex(hex_code), target)[0]


class AndroidStationPresentationTests(unittest.TestCase):
    def extract(self, lib, station={'scope': 'first_station_entry'}):
        return reader.extract_station_presentation(lib, {}, station)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, reader, self.extract, values='MAC_VALUES')
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            data = self.extract(lib)
            data['camera']['position'][0] = 0
            self.assertEqual(reader.MAC_VALUES['camera']['position'][0], 1800)
            for name, station in {'other station': {'scope': 'full_hold_station_entry'}, 'no station': {}, 'none': None}.items():
                self.assertEqual(self.extract(lib, station), {}, name)

    def test_android_camera(self):
        camera, row = reader.MAC_VALUES['camera'], reader.MAC_VALUES['hangar_row']
        android = reader.ANDROID
        self.assertEqual(immediates(android['scene_kind'][3], 'movs', 'r1'), [23])
        self.assertEqual(built_floats(android['projection'][3]), camera['projection'][::-1])
        self.assertEqual(built_floats(android['initial_camera'][3])[0], reader.MAC_VALUES['light']['initial_camera_yaw'])
        positions = struct.unpack('<30i', bytes.fromhex(android['position_table'][3]))
        self.assertEqual(list(positions[3 * row:3 * row + 3]), camera['position'])
        pitch = struct.unpack('<10f', bytes.fromhex(android['pitch_table'][3]))[row]
        yaws = {struct.unpack('<10f', bytes.fromhex(android[key][3]))[row] for key in ('yaw_table', 'alternate_yaw_table')}
        roll = built_floats(android['camera_rotation'][3])
        self.assertEqual([pitch, *yaws, *roll], camera['angles'])
        # AEMath::MatrixSetRotation order 2: the rotation order in camera_rotation.
        self.assertIn(2, immediates(android['camera_rotation'][3], 'movs', 'r0'))
        self.assertEqual(camera['rotation_order'], 'YXZ')
        self.assertEqual(set(immediates(android['camera_jitter'][3], 'movs', 'r1')), {20, camera['initial_jitter_bound']})
        update = android['camera_update'][3]
        self.assertEqual(immediates(update, 'movs', 'r1'), camera['endpoint_range'])
        self.assertEqual([v for v in immediates(update, 'add.w', 'r2, r0')], camera['endpoint_min'])
        self.assertIn(('vmov.f32', 's16, #%.6e' % camera['endpoint_tolerance']), [(m, o) for _, m, o in listing(update)])
        self.assertEqual(set(immediates(android['frame_clock'][3], 'cmp', 'r0')), {0, camera['max_frame_ms']})
        self.assertEqual(immediates(android['dialogue_delay'][3], 'subs.w', 'r0, r0'), [reader.MAC_VALUES['dialogue']['start_delay_ms']])

    def test_android_tween(self):
        camera = reader.MAC_VALUES['camera']
        self.assertEqual(built_floats(reader.ANDROID['tween_construct'][3]), [camera['phase_start']])
        clock = reader.ANDROID['tween_clock'][3]
        self.assertEqual(pool(clock, 4, '<d') * pool(clock, 0x14, '<d'), camera['phase_rate'])
        self.assertEqual(pool(clock, 0x2c, '<d'), camera['phase_limit'])
        self.assertEqual(pool(reader.ANDROID['tween_sample'][3], 6, '<d'), camera['phase_limit'])

    def test_android_light(self):
        light = reader.MAC_VALUES['light']
        bias = struct.unpack('<2f', bytes.fromhex(reader.ANDROID['light_bias'][3]))
        self.assertEqual([bias[1], bias[0], 0], light['direction_bias'])
        lights = reader.ANDROID['station_lights'][3]
        floats = built_floats(lights)
        self.assertEqual(floats[0], light['material_ambient'])
        self.assertEqual(floats[1:4], light['diffuse'])
        self.assertEqual(floats[-4:], [*light['specular'], light['specular_power']])
        # ModStation::resetLight's tbb on race - 1: race 3 (row 3) takes the third case.
        code = listing(lights)
        tbb = next(a for a, m, _ in code if m == 'tbb')
        entry = bytes.fromhex(lights)[tbb + 4 + reader.MAC_VALUES['hangar_row'] - 1]
        start = tbb + 4 + 2 * entry
        end = next(a for a, m, _ in code if a >= start and m == 'b')
        self.assertEqual(built_floats(bytes.fromhex(lights)[start:end].hex()), light['ambient'][:1])
        # Its branch joins the shared green and blue loads before LightSetLightColorAmbient.
        join = int(next(o for a, m, o in code if a == end).lstrip('#'), 0)
        call = next(a for a, m, _ in code if a > join and m == 'blx')
        self.assertEqual(built_floats(bytes.fromhex(lights)[join:call].hex()), light['ambient'][1:])

    def test_android_dialogue(self):
        from gof2_content import station_entry
        from gof2_content.text_ids import canonical_id
        dialogue = reader.MAC_VALUES['dialogue']
        labels = [immediates(reader.ANDROID[key][3], 'movs', 'r1')[0] for key in ('next_label_and_voice_stop', 'final_label_and_voice_start')]
        self.assertEqual([canonical_id(label) for label in labels], [dialogue['next_text_id'], dialogue['final_text_id']])
        pairs = struct.unpack('<36i', bytes.fromhex(reader.ANDROID['voices'][3]))
        voices = {canonical_id(pairs[i]): pairs[i + 1] for i in range(0, 36, 2)}
        events = station_entry.MAC_VALUES['dialogue']['events']
        spoken = [voices[e['text_id']] for e in events if e['text_id'] in voices]
        self.assertEqual(spoken, dialogue['voice_event_ids'])
        self.assertEqual([e['text_id'] for e in events if e['text_id'] not in voices], [dialogue['silent_text_id']])
        self.assertEqual(immediates(reader.ANDROID['atmosphere_start'][3], 'movs', 'r1'), [0, dialogue['atmosphere_event_id'], 0, 0])
        self.assertEqual(listing(reader.ANDROID['voice_not_found'][3])[0][1:], ('mov.w', 'r0, #-1'))
        # Mission::Mission leaves the agent (+4) empty and Mission::getAgent reads it.
        self.assertEqual(listing(reader.ANDROID['mission_no_actor'][3])[-1][1:], ('str', 'r0, [r4, #4]'))
        self.assertEqual(listing(reader.ANDROID['mission_actor_getter'][3])[0][1:], ('ldr', 'r0, [r0, #4]'))

    def test_android_portraits(self):
        portraits = reader.MAC_VALUES['portraits']
        words = struct.unpack('<17I', bytes.fromhex(reader.ANDROID['portrait_pointers'][3]))
        base = words[2] - reader.ANDROID['portrait_gunant'][5]
        self.assertEqual(words[16] - base, reader.ANDROID['portrait_instruction'][5])
        for speaker, key in ((2, 'portrait_gunant'), (16, 'portrait_instruction')):
            family, *parts = struct.unpack('<5i', bytes.fromhex(reader.ANDROID[key][3]))
            self.assertEqual({'status': 'fixed', 'family': family, 'parts': parts}, portraits[str(speaker)])
        # Speaker 0 points into zero-initialised storage past the file's .data (0x259000 + 0x2944).
        self.assertGreater(words[0], 0x259000 + 0x2944)
        self.assertEqual(portraits['0'], {'status': 'fixed', 'family': 0, 'parts': [0, 0, 0, 0]})

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'station_presentation_definitions.gd', values='MAC_VALUES')
