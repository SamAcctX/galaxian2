"""Synthetic compiler layouts with relocated tables and altered source values."""
import importlib.util
import struct
from types import SimpleNamespace
import unittest

from gof2_content.hangars import extract_hangars
from test_materials import arm_wide
from test_ship_models import branch


def fixture(mac):
    base = 0x100002000 if mac else 0x2000
    const = base + 4096
    code = bytearray(1024)
    root = 640
    ids = [4100, 4101, 4102]
    def put(at, data):
        code[at:at + len(data)] = data
    def call(at, target):
        return b'\xe8' + struct.pack('<i', target - at - 5)
    if mac:
        put(16, bytes.fromhex('554889e58b47105dc3'))
        put(32, bytes.fromhex('554889e58b47285dc3'))
        selector = 320
        data = bytearray(call(selector, 16) + b'\xb9' + struct.pack('<I', 8) + b'\x83\xf8\x05\x74\x3a')
        at = selector + len(data)
        data += bytes.fromhex('488d05') + bytes(4) + bytes.fromhex('488b38') + call(at + 10, 48) + bytes.fromhex('4889c7') + call(at + 18, 16)
        data += b'\xb9' + struct.pack('<I', 7) + bytes.fromhex('83f8047419')
        at = selector + len(data)
        data += bytes.fromhex('488d05') + bytes(4) + bytes.fromhex('488b38') + call(at + 10, 48) + bytes.fromhex('4889c7') + call(at + 18, 32) + bytes.fromhex('89c14189cc')
        put(selector, data)
        put(root - 40, bytes.fromhex('4489e3895db04c63f3'))
        put(root, bytes.fromhex('4c89f048c1e004488d0d') + struct.pack('<i', const - base - root - 14) + bytes.fromhex('4801c8428b1ca8'))
        put(root + 64, bytes.fromhex('c745c800000000c745cc') + struct.pack('<f', 1.25) + bytes.fromhex('c745d0000000004c89ef488d75c8') + call(root + 92, 48))
        at = root + 112
        put(at, bytes.fromhex('488d05') + struct.pack('<i', const + 160 - base - at - 7) + bytes.fromhex('468b3cb04531e4'))
        at = root + 144
        put(at, bytes.fromhex('488d05') + struct.pack('<i', const + 176 - base - at - 7) + bytes.fromhex('428b04b04401e00fb7f0'))
        corrupt_getter = 20
        corrupt_join = selector + 14
    else:
        put(16, bytes.fromhex('80687047'))
        put(32, bytes.fromhex('c0697047'))
        first, second = 128, 160
        fallback = bytes.fromhex('28680b954ff0ff352895') + branch(base + second + 20, base + 48) + bytes.fromhex('2895') + branch(base + second + 26, base + 32)
        join = second + 10 + len(fallback)
        for at, station, row, fall in [(first, 5, 8, second - 14), (second, 4, 7, second + 10)]:
            put(at - 4, branch(base + at - 4, base + 16))
            put(at, bytes([station, 0x28, (fall - at - 6) // 2, 0xd1, 0x0b, 0x95, row, 0x20]) + struct.pack('<H', 0xe000 | ((join - at - 12) // 2)))
        put(second + 10, fallback)
        put(join, bytes.fromhex('1090'))
        disp = const - base - root - 16
        put(root, arm_wide(disp & 65535, 0) + bytes.fromhex('0021') + arm_wide(disp >> 16, 0, True) + bytes.fromhex('109c784400eb04100a90'))
        put(root + 34, bytes.fromhex('0a9850f82150'))
        at = root + 64
        bits = struct.unpack('<I', struct.pack('<f', 1.25))[0]
        put(at, arm_wide(bits & 65535, 0) + bytes.fromhex('0025') + arm_wide(bits >> 16, 0, True) + bytes.fromhex('12a9129513904ff0ff3620461495'))
        at = root + 128
        disp = const + 176 - base - at - 14
        put(at, arm_wide(disp & 65535, 0) + bytes.fromhex('0025') + arm_wide(disp >> 16, 0, True) + bytes.fromhex('784450f82400'))
        at = root + 176
        disp = const + 160 - base - at - 14
        put(at, arm_wide(disp & 65535, 0) + arm_wide(disp >> 16, 0, True) + bytes.fromhex('119d7844013550f824008542'))
        corrupt_getter, corrupt_join = 16, first + 8
    table = ids + [-1] * 37
    table[7 * 4] = 4900
    table[8 * 4] = 4901
    constants = struct.pack('<40i4i4i', *table, 2, 0, 0, 0, 7000, -1, -1, -1)
    data = bytes(256) + code + constants
    text = {'offset': 256, 'address': base, 'length': len(code), 'segment': b'__TEXT', 'name': b'__text'}
    mach = SimpleNamespace(data=data, architecture='x86_64' if mac else 'armv7', slice_offset=0,
        text=text, sections=[text, {'offset': 1280, 'address': const, 'length': len(constants), 'segment': b'__TEXT', 'name': b'__const'}])
    rows = [{'id': id, 'resource': 'resources/data/assets/main/3d/meshes/hangars/hangar_terran' + suffix + '.aem',
             'kind': 'mesh', 'registration_type': 4} for id, suffix in zip(ids, ('', '_add', '_alpha'))]
    return mach, rows, (256 + corrupt_getter, 256 + corrupt_join)


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class HangarTests(unittest.TestCase):
    def test_relocated_editions_recover_constants_not_hardcoded_game_values(self):
        for mac in (True, False):
            mach, rows, _ = fixture(mac)
            value = extract_hangars(mach, rows)
            self.assertTrue(value, mac)
            self.assertEqual(value['rows'][0], {'resource_ids': [4100, 4101, 4102, -1], 'extra_resource_ids': [7000, 7001]})
            self.assertEqual(value['rotation_y'], 1.25)
            self.assertEqual(value['station_overrides'], [{'station_id': 5, 'row': 8}, {'station_id': 4, 'row': 7}])
            self.assertEqual(value['provenance'][0], {'offset': 1280, 'bytes': 160})

    def test_wrong_getters_joins_extents_and_anchors_fail_closed(self):
        for mac in (True, False):
            for corruption in ('getter', 'join', 'truncated', 'anchor', 'extra_count', 'extra_range', 'duplicate_anchor'):
                mach, rows, sites = fixture(mac)
                data = bytearray(mach.data)
                if corruption in ('getter', 'join'):
                    data[sites[0 if corruption == 'getter' else 1]] ^= 1
                elif corruption == 'truncated':
                    # The table read must respect the declared const section.
                    mach.sections[-1]['length'] = 159
                elif corruption == 'anchor':
                    rows.pop()
                elif corruption == 'duplicate_anchor':
                    rows.append(dict(rows[0], id=6000))
                elif corruption == 'extra_count':
                    struct.pack_into('<i', data, 1440, 129)
                elif corruption == 'extra_range':
                    struct.pack_into('<i', data, 1456, 65534)
                mach.data = bytes(data)
                self.assertEqual(extract_hangars(mach, rows), {}, (mac, corruption))


SCENE = '_ZN5Level11createSceneEv'
STATION, INDEX, SYSTEM, RACE = '_ZN6Status10getStationEv', '_ZN7Station8getIndexEv', '_ZN6Status9getSystemEv', '_ZN11SolarSystem7getRaceEv'
ROTATE, GEOMETRY, CHILD = ('_ZN10AEGeometry11setRotationERKN11AbyssEngine6AEMath6VectorE',
                           '_ZN10AEGeometryC1EtPN11AbyssEngine11PaintCanvasEb', '_ZN10AEGeometry8addChildEj')


def android_scene(name=SCENE, overrides=((101, 8), (100, 7)), chain=None, join='join', status=(0x9000,) * 3, race=RACE,
                  slots=None, bound=4, loop='loop', vector=0x4c, rotations=1, counter=None, skip='skip', column=8, fallbacks=1):
    """Level::createScene's hangar code in the Android compiler's shape; `slots` override
    the row slot reloads {'rows'|'counts'|'extras'|'column': offset}."""
    from android_fixture import RODATA, TEXT, stub
    from android_thumb import Asm
    slots = {'rows': 0x44, 'counts': 0x44, 'extras': 0x44, 'column': 0x38, **(slots or {})}
    asm = Asm(TEXT + 0x100).push()
    labels = chain or ['o%d' % (i + 2) for i in range(len(overrides) - 1)] + ['fb']
    for index, (station, row) in enumerate(overrides):
        asm.label('o%d' % (index + 1)).address_of(0, status[index]).ldr(0, 0, 0).ldr(0, 0, 0)
        asm.call_to(STATION).call_to(INDEX).cmp(0, station)
        asm.branch('ne', labels[index]).movs(0, row).branch(None, join)
    asm.label('fb').address_of(0, status[2]).ldr(0, 0, 0).ldr(0, 0, 0).call_to(SYSTEM).call_to(race)
    asm.label('join').str_sp(0, 0x44)
    asm.label('rows').ldr_sp(2, slots['rows']).address_of(0, RODATA).add_reg(0, 0, 2, 4).str_sp(0, 0x38)
    asm.label('loop').ldr_sp(0, slots['column']).ldr_index(4, 0, 8).cmp(4, 0).branch('lt', skip)
    for _ in range(rotations):
        asm.movw(0, 0).movs(4, 0).movt(0, 0x3fa0).add_sp(1, 0x48).str_sp(4, 0x48).strd(0, 4, 13, vector).mov(0, 5).call_to(ROTATE)
    asm.label('skip').add_imm(column, column, 1).cmp_w(column, bound).branch('lt', loop)
    (asm.address_of(7, RODATA + 0xa0) if counter is None else counter(asm)).ldr_sp(0, slots['extras']).address_of(1, RODATA + 0xb0)
    asm.ldr_index(10, 1, 0).label('extra').movs(0, 0xc0).call(stub('_Znwj')).mov(4, 0).add_reg(0, 10, 6).ldr_w(2, 11)
    asm.uxth(1, 0).mov(0, 4).movs(3, 0).call_to(GEOMETRY).ldr(1, 4, 0xc).mov(0, 5).call_to(CHILD)
    asm.ldr_sp(0, slots['counts']).adds8(6, 1).ldr_index(0, 7, 0).cmp_reg(6, 0).branch('lt', 'extra').pop()
    for _ in range(fallbacks - 1):
        asm.address_of(0, status[2]).ldr(0, 0, 0).ldr(0, 0, 0).call_to(SYSTEM).call_to(race).str_sp(0, 0x44)
    return asm


def android_hangars(ids=(4100, 4101, 4102), **options):
    from android_fixture import RODATA
    from android_thumb import build
    asm = android_scene(**options)
    table = list(ids) + [-1] * 37
    table[7 * 4], table[8 * 4] = 4900, 4901
    data = {RODATA: struct.pack('<40i', *table), RODATA + 0xa0: struct.pack('<4i', 2, 0, 0, 0),
            RODATA + 0xb0: struct.pack('<4i', 7000, -1, -1, -1)}
    return build({options.get('name', SCENE): asm}, data), [
        {'id': id, 'resource': 'resources/data/assets/main/3d/meshes/hangars/hangar_terran' + suffix + '.aem',
         'kind': 'mesh', 'registration_type': 4} for id, suffix in zip(ids, ('', '_add', '_alpha'))]


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidHangarTests(unittest.TestCase):
    def test_scene_gives_rows_rotation_overrides_and_spans(self):
        from android_fixture import RODATA, TEXT
        lib, rows = android_hangars()
        value = extract_hangars(lib, rows)
        self.assertEqual(value['rows'][0], {'resource_ids': [4100, 4101, 4102, -1], 'extra_resource_ids': [7000, 7001]})
        self.assertEqual([row['resource_ids'][0] for row in value['rows']], [4100] + [-1] * 6 + [4900, 4901, -1])
        self.assertEqual((value['rotation_y'], value['system_field']), (1.25, 2))
        self.assertEqual(value['station_overrides'], [{'station_id': 101, 'row': 8}, {'station_id': 100, 'row': 7}])
        # Tables, then the scene from the first selection block to the counted extras loop.
        code = lib.symbols[SCENE]
        self.assertEqual(value['provenance'], [{'offset': RODATA, 'bytes': 160}, {'offset': RODATA + 0xa0, 'bytes': 16},
                                               {'offset': RODATA + 0xb0, 'bytes': 16},
                                               {'offset': TEXT + 0x102, 'bytes': value['provenance'][3]['bytes']}])
        # Up to the counted loop's blt: pop, an alignment nop and six pool words follow.
        self.assertEqual(TEXT + 0x102 + value['provenance'][3]['bytes'], code[0] + code[1] - 4 - 4 * 6)

    def test_each_broken_shape_is_unsupported(self):
        cases = {'name': dict(name='_ZN5Level9createBoxEv'), 'one override': dict(overrides=((101, 8),)),
                 'chain': dict(chain=['fb', 'fb']), 'second chain': dict(chain=['o2', 'rows']), 'join': dict(join='rows'), 'status': dict(status=(0x9000, 0x9004, 0x9000)),
                 'race': dict(race='_ZN11SolarSystem8getIndexEv'), 'row slot': dict(slots={'rows': 0x40}),
                 'column slot': dict(slots={'column': 0x3c}), 'count slot': dict(slots={'counts': 0x40}),
                 'extra slot': dict(slots={'extras': 0x40}), 'bound': dict(bound=5), 'loop': dict(loop='skip'),
                 'vector': dict(vector=0x50), 'two rotations': dict(rotations=2), 'no rotation': dict(rotations=0),
                 'count table': dict(counter=lambda asm: asm.mov(7, 1)), 'repeated station': dict(overrides=((101, 8), (101, 7))),
                 'skip': dict(skip='extra'), 'column': dict(column=3), 'two fallbacks': dict(fallbacks=2)}
        for name, options in cases.items():
            lib, rows = android_hangars(**options)
            self.assertEqual(extract_hangars(lib, rows), {}, name)
        lib, rows = android_hangars(ids=(4100, 4101, 4103))
        rows[2]['id'] = 4102
        self.assertEqual(extract_hangars(lib, rows), {})
