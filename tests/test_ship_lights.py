"""Synthetic indexed light layers: masks, sentinels, relocations and call identity."""
import importlib.util
import struct
from types import SimpleNamespace
import unittest
from test_materials import arm_wide
from test_ship_models import branch
from gof2_content.ship_lights import extract_ship_lights


def fixture(mac):
    count = 61 if mac else 64
    base = 0x100002000 if mac else 0x2000
    address = base + 8192
    hulls = list(range(1000, 1000 + count))
    layers = [[10000 + i if i % 3 == 0 else 65535 for i in range(count)],
              [12000 + i if i % 2 == 0 else 65535 for i in range(count)]]
    layers[1][6] = layers[0][6]
    code = bytearray(1024)
    def call(at, target=800):
        return b'\xe8' + struct.pack('<i', target - at - 5) if mac else branch(base + at, base + target)
    def pc_pair(at, target, reg=0, gap=b'', after=0):
        disp = target - base - at - 8 - len(gap) - after - 4
        return arm_wide(disp & 65535, reg) + gap + arm_wide(disp >> 16, reg, True)
    root_at = 64
    if mac:
        root = bytes.fromhex('4d63f4488d05') + struct.pack('<i', address - base - root_at - 10) + bytes.fromhex('420fb73470488b15') + bytes(4) + bytes.fromhex('4c89ffb901000000') + call(root_at + 30)
    else:
        root = pc_pair(root_at, address, 1, bytes.fromhex('0623'), 8) + bytes(8) + bytes.fromhex('79447a44499031f81610499812684b9301230596') + call(root_at + 38)
    code[root_at:root_at + len(root)] = root
    sites = []
    for layer in range(2):
        at = root_at + len(root) + 16 + layer * 160
        target = address + count * 2 * (layer + 1)
        if mac:
            mask = sum(1 << i for i, id in enumerate(layers[layer]) if id != 65535)
            b = bytearray(bytes.fromhex('48b8') + struct.pack('<Q', mask) + bytes.fromhex('4c0fa3f073') + bytes([103 if layer == 0 else 75]))
            if layer == 0:
                b += bytes.fromhex('488d05') + struct.pack('<i', target - base - at - len(b) - 7)
                b += bytes.fromhex('420fb73470488b3d') + bytes(4) + bytes.fromhex('488d95d0feffffb901000000'); b += call(at + len(b))
                b += bytes.fromhex('488b3d') + bytes(4) + bytes.fromhex('488db5d4feffff'); b += call(at + len(b))
                b += bytes.fromhex('8b95d0feffff8bb5d4feffff488b3d') + bytes(4); b += call(at + len(b))
                b += bytes.fromhex('8bb5d4feffff4c89ff'); sites.append(256 + at + len(b)); b += call(at + len(b))
                b += bytes.fromhex('8b85d0feffff41894728')
            else:
                b += bytes.fromhex('c785c8feffffffffffff488b3d') + bytes(4) + bytes.fromhex('488db5c8feffff'); b += call(at + len(b))
                b += bytes.fromhex('488d05') + struct.pack('<i', target - base - at - len(b) - 7)
                b += bytes.fromhex('420fb714708bb5c8feffff488b3d') + bytes(4) + bytes.fromhex('31c9'); b += call(at + len(b))
                b += bytes.fromhex('8bb5c8feffff4c89ff'); sites.append(256 + at + len(b)); b += call(at + len(b))
        else:
            b = bytearray(pc_pair(at, target, after=2 if layer == 0 else 0))
            if layer == 0:
                b += bytes.fromhex('059a784430f812104ff0ff30924610900f904ff6ff70814221d0499c') + bytes(8) + bytes.fromhex('0faa78444ff0ff350123064630684b95'); b += call(at + len(b))
                b += bytes.fromhex('306810a94b95'); b += call(at + len(b))
                b += bytes.fromhex('30680f9a10994b95'); b += call(at + len(b))
                b += bytes.fromhex('109920464b95'); sites.append(256 + at + len(b)); b += call(at + len(b))
                b += bytes.fromhex('0f9849990862')
            else:
                b += bytes.fromhex('784430f81a404ff6ff7084421bd04ff0ff36ddf824810d96') + bytes(8) + bytes.fromhex('0da97844054628684b96'); b += call(at + len(b))
                b += bytes.fromhex('286822460d9900234b96'); b += call(at + len(b))
                b += bytes.fromhex('0d9940464b96'); sites.append(256 + at + len(b)); b += call(at + len(b))
        code[at:at + len(b)] = b
    constants = struct.pack('<' + str(count * 3) + 'H', *(hulls + layers[0] + layers[1]))
    text = {'offset': 256, 'length': len(code), 'address': base, 'segment': b'__TEXT', 'name': b'__text'}
    const = {'offset': 1280, 'length': len(constants), 'address': address, 'segment': b'__TEXT', 'name': b'__const'}
    mach = SimpleNamespace(data=bytes(256) + code + constants, text=text, sections=[text, const], slice_offset=0, architecture='x86_64' if mac else 'armv7')
    return mach, {'resource_ids': hulls, 'table_offsets': [1280]}, list(map(list, zip(*layers))), sites


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class LightTests(unittest.TestCase):
    def test_both_architectures_preserve_empty_and_duplicate_layers(self):
        for mac in (True, False):
            mach, models, expected, _ = fixture(mac)
            result = extract_ship_lights(mach, models)
            self.assertEqual(result['resource_ids'], expected)
            self.assertEqual(result['resource_ids'][6], [10006, 10006])
            self.assertEqual(result['provenance'][0]['offset'], 320)

    def test_wrong_hull_reference_calls_and_table_extent_fail(self):
        for mac in (True, False):
            for corruption in ('hull', 'offset', 'extent', 'attach', 'selection'):
                mach, models, _, sites = fixture(mac)
                data = bytearray(mach.data)
                if corruption == 'hull': models['resource_ids'][0] = 3000
                elif corruption == 'offset': models['table_offsets'] = [1282]
                elif corruption == 'extent': mach.sections[-1]['length'] -= 1
                elif corruption == 'attach': data[sites[1] + 2] ^= 1
                elif corruption == 'selection':
                    # An altered x86 mask or ARM sentinel-test branch must not
                    # silently change the interpretation of the same tables.
                    at = 256 + 64 + (35 if mac else 42) + 16
                    data[at + (2 if mac else 33)] ^= 1
                mach.data = bytes(data)
                self.assertEqual(extract_ship_lights(mach, models), {}, (mac, corruption))


GROUP = '_ZN7Globals12getShipGroupEiib'
CANVAS = 'PaintCanvas'


def android(name=GROUP, index=(9, 9, 9), geometry=(11, 11, 11), skips=('skip1', 'skip2'), order=('first', 'second'),
            seconds=1, none=0xffff, refill=False, table2=0x40):
    """getShipGroup's hull and two light layers in the Android compiler's shape."""
    from android_fixture import RODATA, TEXT
    from android_thumb import Asm, build
    paint = '_ZN11AbyssEngine11PaintCanvas'
    asm = Asm(TEXT + 0x100).push()

    def root(n=0):
        asm.ldr_address(1, RODATA).mov(11, 0).ldr_address(0, 0x9000).add_pc(1).add_pc(0)
        asm.ldrh_index(1, 1, index[0]).ldr(0, 0, 0).ldr(2, 0, 0).mov(0, geometry[0]).movs(3, 1)
        asm.call_to('_ZN10AEGeometryC1EtPN11AbyssEngine11PaintCanvasEb')

    def first(n):
        asm.ldr_address(0, RODATA + 0x20).movw(6, none).add_pc(0).ldrh_index(1, 0, index[1]).minus_one(0).str_sp(0, 0x30).str_sp(0, 0x70)
        asm.cmp_reg(1, 6).branch('eq', '%s_%d' % (skips[0], n)).ldr_address(0, 0x9000).add_sp(2, 0x70).movs(3, 1).add_pc(0).ldr(4, 0, 0)
        asm.ldr(0, 4, 0).call_to(paint + '10MeshCreateEtRjb').ldr(0, 4, 0).add_sp(1, 0x30).call_to(paint + '15TransformCreateERj')
        asm.ldr(0, 4, 0).ldr_sp(2, 0x70).ldr_sp(1, 0x30).call_to(paint + '18TransformAddMeshIdEjj').ldr_sp(1, 0x30).mov(0, geometry[1])
        asm.call_to('_ZN10AEGeometry8addChildEj').ldr_sp(0, 0x70).str_w(0, geometry[1], 0x20).label('skip1_%d' % n)
        asm.nop().label('other1_%d' % n)

    def second(n):
        if refill:
            asm.movw(6, 0xffff)
        asm.ldr_address(0, RODATA + table2).add_pc(0).ldrh_index(4, 0, index[2]).cmp_reg(4, 6).branch('eq', skips[1])
        asm.ldr_address(0, 0x9000).add_sp(1, 0x78).add_pc(0).ldr(5, 0, 0).minus_one(0).str_sp(0, 0x78).ldr(0, 5, 0)
        asm.call_to(paint + '15TransformCreateERj').ldr(0, 5, 0).mov(2, 4).ldr_sp(1, 0x78).movs(3, 0)
        asm.call_to(paint + '16TransformAddMeshEjtb').ldr_sp(1, 0x78).mov(0, geometry[2]).call_to('_ZN10AEGeometry8addChildEj')
        asm.ldr_sp(1, 0x28).label('skip2' + '_1' * n).nop()
    for part in order if 'root' in order else ('root',) + order:
        for n in range(seconds if part == 'second' else 1):
            {'root': root, 'first': first, 'second': second}[part](n)
    hull, lights = [100, 101, 102, 103], ([65535, 300, 65535, 302], [400, 65535, 65535, 403])
    data = {RODATA: struct.pack('<4H', *hull), RODATA + 0x20: struct.pack('<4H', *lights[0]), RODATA + 0x40: struct.pack('<4H', *lights[1])}
    return build({name: asm.pop()}, data), {'resource_ids': hull, 'table_offsets': [RODATA]}


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidLightTests(unittest.TestCase):
    def test_layers_pair_with_the_hull(self):
        from android_fixture import RODATA
        lib, models = android()
        value = extract_ship_lights(lib, models)
        self.assertEqual(value['resource_ids'], [[65535, 400], [300, 65535], [65535, 65535], [302, 403]])
        code = lib.symbols[GROUP][0]
        self.assertEqual([(p['offset'] - (code if p['offset'] < RODATA else 0), p['bytes']) for p in value['provenance']],
                         [(8, 20), (RODATA + 0x20, 8), (30, 70), (RODATA + 0x40, 8), (104, 52)])

    def test_each_broken_shape_is_unsupported(self):
        cases = {'name': dict(name='_ZN7Globals8getShipEi'), 'first index': dict(index=(9, 8, 9)), 'second index': dict(index=(9, 9, 8)),
                 'first geometry': dict(geometry=(11, 10, 11)), 'second geometry': dict(geometry=(11, 11, 10)),
                 'first skip': dict(skips=('other1', 'skip2')), 'second skip': dict(skips=('skip1', 'skip1_0')),
                 'order': dict(order=('second', 'first')), 'two seconds': dict(seconds=2), 'none': dict(none=0xfffe),
                 'root last': dict(order=('first', 'second', 'root')), 'table outside': dict(table2=0x2000),
                 'refilled none': dict(refill=True)}
        for name, options in cases.items():
            lib, models = android(**options)
            self.assertEqual(extract_ship_lights(lib, models), {}, name)
        lib, models = android()
        self.assertEqual(extract_ship_lights(lib, dict(models, table_offsets=[0x8010])), {})
        self.assertEqual(extract_ship_lights(lib, dict(models, resource_ids=[100, 101, 102, 104])), {})
