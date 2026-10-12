"""Relocated synthetic effect declarations and bounded layout rejection."""
import copy
import importlib.util
import struct
from types import SimpleNamespace
import unittest
from gof2_content import scenery_effects as reader
from test_font_selection import expand
from test_ship_models import branch
from test_materials import arm_wide


def fixture(mac, relocation=0):
    base = 0x4000 + relocation
    offset, slice_offset = 512, 4096 if mac else 0
    data = bytearray(24576)
    sites = {'outer': 2000, 'actor_wrapper': 4000, 'effect_wrapper': 4500,
             'constructor': 5000, 'actor': 8000, 'scale': 10000,
             'speed_setter': 11000, 'threshold': 20000, 'speed_scale': 20004}
    relative = {'switch': 1414, 'default': 1118, 'ordinary': 1230, 'void': 318, 'ice': 411, 'magma': 498} if mac else {'switch': 136, 'default': 290, 'ordinary': 390, 'void': 454, 'ice': 546, 'magma': 638}
    sites.update({key: sites['constructor'] + delta for key, delta in relative.items()})
    links = {
        'outer': {'call_39' if mac else 'bl_26': 'actor_wrapper'},
        'actor_wrapper': {'branch_5' if mac else 'bl_26': 'actor'},
        'actor': {'call_19b' if mac else 'bl_1ba': 'effect_wrapper', 'call_1b0' if mac else 'bl_1d0': 'scale'},
        'effect_wrapper': {'branch_5' if mac else 'bl_6': 'constructor'},
        'constructor': {'branch_94' if mac else 'branch_bhi_82': 'default', 'ref_9d': 'switch'},
        'default': {'branch_1b' if mac else 'branch_bne_22': 'ordinary'},
        'scale': {key: 'speed_setter' for key in (('call_d7', 'call_ff', 'call_136') if mac else ('bl_c4', 'bl_d8', 'bl_fc'))},
    }
    links['scale'].update({'ref_45': 'threshold', 'ref_53': 'threshold', 'ref_63': 'speed_scale', 'blx_110': 21000, 'blx_120': 21016})
    blocks = {}
    model_ids = [[600, 601], [600, 603], [604, 605], [606, 607]]
    for key in ('outer', 'actor_wrapper', 'actor', 'effect_wrapper', 'constructor', 'default', 'ordinary', 'void', 'ice', 'magma', 'scale', 'speed_setter'):
        at = sites[key]
        raw, fields = expand(getattr(reader, ('MAC_' if mac else 'ARM_') + key.upper()))
        for name, (position, size) in fields.items():
            site = base + at + position
            if name.startswith('model'):
                identifier = model_ids[('ordinary', 'void', 'ice', 'magma').index(key)][int(name[-1])]
                value = identifier.to_bytes(size, 'little') if mac else arm_wide(identifier, 1)
            elif name in ('threshold', 'speed_base', 'speed_scale'):
                value = bytes.fromhex({'threshold': '87ef108f', 'speed_base': 'c7ef100f', 'speed_scale': 'c0ef182f'}[name])
            elif name.startswith(('movw_', 'movt_')):
                mnemonic, register, _ = name.split('_')
                value = arm_wide(0, int(register[1:]), mnemonic == 'movt')
            else:
                dest = links.get(key, {}).get(name, 15000)
                dest = sites[dest] if isinstance(dest, str) else dest
                if key in ('ordinary', 'ice', 'magma') and mac and name.startswith('branch_'):
                    dest = sites['void'] + 80
                elif key in ('void', 'ice', 'magma') and not mac and name.startswith('branch_'):
                    dest = sites['ordinary'] + 58
                elif not mac and name.startswith('branch_') and key == 'ordinary':
                    dest = 6000
                if mac:
                    value = (base + dest - site - size).to_bytes(size, 'little', signed=True)
                elif name.startswith('branch_'):
                    kind = name[7:].rsplit('_', 1)[0]
                    delta = (base + dest - site - 4) // 2
                    if kind == 'b': value = struct.pack('<H', 0xe000 | (delta & 2047))
                    else: value = struct.pack('<H', 0xd000 | ({'bhi': 8, 'bne': 1}[kind] << 8) | (delta & 255))
                else:
                    blx = name.startswith('blx_')
                    value = bytearray(branch(((site + 4) & ~3) - 4 if blx else site, base + dest))
                    if blx: value[3] &= ~0x10
            raw[position:position + size] = value
        data[offset + at:offset + at + len(raw)] = raw
        blocks[key] = (at, raw, fields)
    targets = [sites['default'], sites['void'], sites['ice'], sites['magma']]
    table = [0] * 13
    for index, target in enumerate(targets, 2): table[index] = (target - sites['switch']) // (1 if mac else 2)
    struct.pack_into('<13i' if mac else '<13H', data, offset + sites['switch'], *table)
    struct.pack_into('<2f', data, offset + sites['threshold'], 1.0, 3.0)
    sections = [{'name': b'__text', 'segment': b'__TEXT', 'address': base, 'offset': offset, 'length': 18000},
                {'name': b'__const', 'segment': b'__TEXT', 'address': base + 20000, 'offset': offset + 20000, 'length': 8}]
    if not mac:
        # Only symbol-table metadata: no imported implementation is present.
        struct.pack_into('<7I', data, 0, 0xfeedface, 12, 0, 2, 3, 228, 0)
        struct.pack_into('<2I', data, 28, 1, 124)
        struct.pack_into('<I', data, 28 + 48, 1)
        section = 28 + 56
        struct.pack_into('<3I', data, section + 32, base + 21000, 32, offset + 21000)
        struct.pack_into('<3I', data, section + 56, 8, 0, 16)
        strings = b'\0___floatdisf\0___fixsfdi\0'
        struct.pack_into('<6I', data, 152, 2, 24, 23000, 2, 23100, len(strings))
        struct.pack_into('<2I', data, 176, 11, 80)
        struct.pack_into('<2I', data, 176 + 56, 23200, 2)
        struct.pack_into('<IB', data, 23000, 1, 1)
        struct.pack_into('<IB', data, 23012, 14, 1)
        data[23100:23100 + len(strings)] = strings
        struct.pack_into('<2I', data, 23200, 0, 1)
    mach = SimpleNamespace(data=bytes(data), architecture='x86_64' if mac else 'armv7', text=sections[0], sections=sections, slice_offset=slice_offset)
    resources = {'model_ids': [100, 200, 300, 400], 'provenance': {'models': {'offset': slice_offset + offset + 1000, 'bytes': 91 if mac else 36}}}
    return mach, resources, blocks


class SceneryEffects(unittest.TestCase):
    def test_relocated_variant_links_and_only_declarations(self):
        for mac in (True, False):
            for relocation in (0, 0x800000):
                mach, resources, _ = fixture(mac, relocation)
                result = reader.extract_scenery_effects(mach, resources)
                self.assertTrue(result, (mac, relocation))
                self.assertEqual([r['base_model_id'] for r in result['variants']], resources['model_ids'])
                self.assertEqual([r['effect_type'] for r in result['variants']], [2, 3, 4, 5])
                self.assertEqual([r['model_ids'] for r in result['variants']], [[600, 601], [600, 603], [604, 605], [606, 607]])
                self.assertEqual([result[k] for k in ('speed_threshold', 'speed_base', 'speed_scale')], [1.0, 1.0, 3.0])
                self.assertEqual(set(result), {'variants', 'speed_threshold', 'speed_base', 'speed_scale', 'provenance'})
                self.assertEqual(len(result['provenance']), 15 if mac else 13)

    def test_each_proof_region_rejects_changed_layout(self):
        for mac in (True, False):
            mach, resources, _ = fixture(mac)
            result = reader.extract_scenery_effects(mach, resources)
            self.assertTrue(result, mac)
            for key, span in result['provenance'].items():
                bad = copy.copy(mach)
                data = bytearray(mach.data)
                at = span['offset'] - mach.slice_offset
                if key == 'switch': at += 8 if mac else 4
                data[at] ^= 255
                bad.data = bytes(data)
                self.assertFalse(reader.extract_scenery_effects(bad, resources), (mac, key))

    def test_disconnected_calls_and_ambiguous_outer(self):
        for mac in (True, False):
            mach, resources, blocks = fixture(mac)
            for key, field in [('outer', 'call_39' if mac else 'bl_26'), ('actor_wrapper', 'branch_5' if mac else 'bl_26'), ('actor', 'call_19b' if mac else 'bl_1ba'), ('scale', 'call_ff' if mac else 'bl_d8'), ('ice', 'call_21' if mac else 'bl_2c')]:
                bad = copy.copy(mach)
                data = bytearray(mach.data)
                at, _, fields = blocks[key]
                p, size = fields[field]
                data[512 + at + p:512 + at + p + size] = bytes(size)
                bad.data = bytes(data)
                self.assertFalse(reader.extract_scenery_effects(bad, resources), (mac, key))
            bad = copy.copy(mach)
            data = bytearray(mach.data)
            raw = blocks['outer'][1]
            data[512 + 3000:512 + 3000 + len(raw)] = raw
            bad.data = bytes(data)
            self.assertFalse(reader.extract_scenery_effects(bad, resources))
            self.assertFalse(reader.extract_scenery_effects(mach, {}))
            for ids in ([100, 100, 300, 400], [1, 2, 3], [True, 2, 3, 4], [-1, 2, 3, 4]):
                malformed = copy.deepcopy(resources); malformed['model_ids'] = ids
                self.assertFalse(reader.extract_scenery_effects(mach, malformed))
            truncated = copy.copy(mach); truncated.data = mach.data[:8500]
            self.assertFalse(reader.extract_scenery_effects(truncated, resources))

    def test_arm_conversion_symbols_and_model_operands(self):
        mach, resources, blocks = fixture(False)
        for at in (23102, 23116, 23004, 23204, 28 + 56 + 64):
            bad = copy.copy(mach); data = bytearray(mach.data); data[at] ^= 255; bad.data = bytes(data)
            self.assertFalse(reader.extract_scenery_effects(bad, resources), at)
        at, _, fields = blocks['ordinary']; position, _ = fields['model0']
        bad = copy.copy(mach); data = bytearray(mach.data)
        data[512 + at + position:512 + at + position + 4] = arm_wide(600, 2)
        bad.data = bytes(data)
        self.assertFalse(reader.extract_scenery_effects(bad, resources))


SCENE, EXPLOSION, SCALE = '_ZN5Level15createAsteroidsEv', '_ZN9ExplosionC1Ei', '_ZN9Explosion10setScalingEf'
ACTOR = '_ZN14PlayerAsteroidC1EiP10AEGeometryiiRKN11AbyssEngine6AEMath6VectorEfi'
SETTER, GEOMETRY = '_ZN11AbyssEngine9Transform17SetAnimationSpeedEf', '_ZN10AEGeometryC1EtPN11AbyssEngine11PaintCanvasEb'
# Android compiler encodings: Explosion's prologue up to its bhi, and the whole setScaling (with its pool).
EXPLOSION_START = ('f0b503af81b0c0ef50200e4604460ff2c03004f1300160f9ef0a4ff07e500c2ee06241f98f2a04f14401206441f98f2a04f1540141'
                   'f98f0a606660624ff00000c4e90200c4e90060')
SCALE_BODY = ('2de9f04103af2ded048b0d468046c8f824502a46d8f804002b46 call:_ZN10AEGeometry10setScalingEfff d8f8080009ee105a20b1'
              '29462a462b46 call:_ZN10AEGeometry10setScalingEfff b7ee008ab4eec89af1ee10fa09d5b7ee000ab0ee081a30ee492a22ee011a'
              '31ee008ab6ee000ad8f800000b28a0f1080028ee000a08bfb0ee408a022812d82c483c21784400680068 '
              'call:_ZN11AbyssEngine8AERandom7nextIntEi 00ee100a9fed291ab8eec00a20ee010a9fed271a30ee018a2648d8f8041078440068c968'
              '0068 call:_ZN11AbyssEngine11PaintCanvas21TransformGetTransformEj 18ee105a2946 call:' + SETTER + ' d8f8080048b11e49'
              '79440a68c1681068 call:_ZN11AbyssEngine11PaintCanvas21TransformGetTransformEj 2946 call:' + SETTER + ' d8f80c00a8b1'
              '016899b11849002679440c68406850f82600c1682068 call:_ZN11AbyssEngine11PaintCanvas21TransformGetTransformEj 2946 '
              'call:' + SETTER + ' d8f80c00013601688e42efd3d8e90401 call:__aeabi_l2f 00ee100a80ee080a10ee100a call:__aeabi_f2lz '
              'c8e90401bdec048bbde8f08100bf48091b000ad7233c3333333f1c091b00fe081b00de081b00')
PAIRS = ((16915, 16913), (16915, 16925), (16909, 16908), (18841, 18840))


def ands(asm, rd, rm): return asm.half(0x4000 | rm << 3 | rd)  # ands rd, rm


def scene(kind_slot=0x44, model_slot=0x4c, outer_kind=0x44, outer_model=0x4c, sites=1, outers=1, stored=2):
    """createAsteroids: the model lookup storing kind and model, and the PlayerAsteroid construction."""
    from android_fixture import TEXT
    from android_thumb import Asm
    from test_scenery_resources import models
    asm = Asm(TEXT + 0x100).push()
    for _ in range(sites):
        ands(models(asm), 0, 4).str_sp(stored, kind_slot).add_sp(4, 0x68).str_sp(1, model_slot)
    for _ in range(outers):
        asm.mov_imm(0, 0x16c).call_to('_Znwj').mov(10, 0).add_sp(0, 0x68).ldr_sp(1, outer_model).ldr_sp(3, outer_kind).mov(2, 8)
        asm.str_sp(4, 0xc).vstr(24, 13, 8).str_sp(0, 4).ldr_sp(0, 0x50).str_sp(0, 0).mov(0, 10).call_to(ACTOR)
    return asm.pop()


def actor(start='2de9f04f03af', kind=3, frame=0x20, step=2, effects=1):
    """PlayerAsteroid: kind (r3) to r8, the scale float to s16, then Explosion(kind + step) and setScaling."""
    from android_fixture import TEXT
    from android_thumb import Asm
    from test_scenery_population import raw
    asm = raw(Asm(TEXT + 0x1000), start)
    if kind is not None:
        asm.mov(8, kind)
    if frame is not None:
        asm.vldr(16, 7, frame)
    for _ in range(effects):
        asm.movs(0, 0x68).call_to('_Znwj').mov(6, 0).add_imm(1, 8, step).mov(0, 6).call_to(EXPLOSION).vmov_core(5, 16)
        asm.str_w(6, 4, 0x128).mov(0, 6).mov(1, 5).call_to(SCALE)
    return raw(asm, 'bde8f08f')


def explosion(start=EXPLOSION_START, pairs=PAIRS, cases=None, special=0xd, joins=('join',) * 3, ordinary='ordinary', high='default',
              stores=(4, 8), entries=None):
    """Explosion(type): the bhi/tbh switch, the default block, three variant blocks and the ordinary pair."""
    from android_fixture import RODATA, TEXT
    from android_thumb import Asm
    from test_scenery_population import raw
    def geometry(asm, model): return asm.mov(0, 5).movw(1, model).movs(3, 0).call_to(GEOMETRY)
    def canvas(asm): return asm.ldr_address(0, RODATA).add_pc(0).ldr(0, 0, 0).ldr(2, 0, 0)
    def second(asm, model): return geometry(canvas(asm.movs(0, 0xc0).str(5, 4, stores[0]).call_to('_Znwj').mov(5, 0)), model)
    asm = raw(Asm(TEXT + 0x1400), start).branch('hi', high)
    table = raw(asm, 'dfe816f0').here()
    for entry in entries or [0] * 13:
        asm.half(entry)
    asm.label('other').pop()
    asm.label('default').movs(0, 0xc0).call_to('_Znwj').mov(5, 0).ldr_address(0, RODATA).cmp(6, special).add_pc(0)
    asm.ldr(0, 0, 0).ldr(2, 0, 0).branch('ne', ordinary, wide=True)
    for name, (first, last), join in zip(('void', 'ice', 'magma'), pairs[1:], joins):
        second(geometry(canvas(asm.label(name).movs(0, 0xc0).call_to('_Znwj').mov(5, 0)), first), last).branch(None, join)
    second(geometry(asm.label('ordinary'), pairs[0][0]), pairs[0][1]).label('join').str(5, 4, stores[1]).pop()
    if entries is None:  # second pass with the table pointing at the laid-out blocks
        targets = {2: 'default', 3: 'void', 4: 'ice', 5: 'magma', **(cases or {})}
        return explosion(start, pairs, cases, special, joins, ordinary, high, stores,
                         [(asm.labels[targets.get(i, 'other')] - table) // 2 for i in range(13)])
    return asm


def effects_library(scenes=None, actors=None, explosions=None, scale=SCALE_BODY, setter='c0f8f0107047', omit=()):
    from unittest import mock
    import android_thumb
    from android_fixture import TEXT
    from android_thumb import Asm, build
    from test_scenery_population import raw
    from test_scenery_resources import roomy
    functions = {SCENE: scene(**(scenes or {})), ACTOR: actor(**(actors or {})), EXPLOSION: explosion(**(explosions or {})),
                 SCALE: raw(Asm(TEXT + 0x1a00), scale), SETTER: raw(Asm(TEXT + 0x1c00), setter)}
    with mock.patch.object(android_thumb, 'library', roomy):
        return build({name: asm for name, asm in functions.items() if name not in omit})


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidSceneryEffects(unittest.TestCase):
    RESOURCES = {'model_ids': [16900, 16921, 16904, 18836]}

    def test_encodings_decode_as_intended(self):
        import capstone
        from android_thumb import Asm
        ins = next(capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB).disasm(ands(Asm(0), 0, 4).finish(), 0))
        self.assertEqual('%s %s' % (ins.mnemonic, ins.op_str), 'ands r0, r4')

    def test_variants_speed_rule_and_spans(self):
        from android_fixture import TEXT
        lib = effects_library()
        result = reader.extract_scenery_effects(lib, self.RESOURCES)
        self.assertEqual(result['variants'], [{'base_model_id': base, 'effect_type': index + 2, 'model_ids': list(pair)}
                                              for index, (base, pair) in enumerate(zip(self.RESOURCES['model_ids'], PAIRS))])
        self.assertEqual((result['speed_threshold'], result['speed_base'], result['speed_scale']), (1.0, 1.0, 3.0))
        self.assertEqual(result['provenance'], {
            'outer': {'offset': TEXT + 0x132, 'bytes': 36}, 'actor': {'offset': TEXT + 0x1000, 'bytes': 46},
            'constructor': {'offset': TEXT + 0x1400, 'bytes': 78}, 'switch': {'offset': TEXT + 0x144e, 'bytes': 26},
            'default': {'offset': TEXT + 0x146a, 'bytes': 22}, 'ordinary': {'offset': TEXT + 0x1534, 'bytes': 44},
            'void': {'offset': TEXT + 0x1480, 'bytes': 60}, 'ice': {'offset': TEXT + 0x14bc, 'bytes': 60},
            'magma': {'offset': TEXT + 0x14f8, 'bytes': 60}, 'scale': {'offset': TEXT + 0x1a00, 'bytes': 290},
            'speed_setter': {'offset': TEXT + 0x1c00, 'bytes': 6}})
        self.assertEqual(reader.extract_scenery_effects(lib, {'model_ids': [16900, 16921, 16904, 16904]}), {})
        self.assertEqual(reader.extract_scenery_effects(lib, {}), {})

    def test_each_broken_shape_is_unsupported(self):
        cases = {'two lookups': dict(scenes=dict(sites=2)), 'two asteroids': dict(scenes=dict(outers=2)),
                 'stored kind': dict(scenes=dict(stored=3)), 'no kind argument': dict(actors=dict(kind=None)),
                 'no scale argument': dict(actors=dict(frame=None)), 'bound target': dict(explosions=dict(high='other')),
                 'first geometry': dict(explosions=dict(stores=(0xc, 8))), 'second geometry': dict(explosions=dict(stores=(4, 0xc))),
                 'kind slot': dict(scenes=dict(outer_kind=0x48)), 'model slot': dict(scenes=dict(outer_model=0x48)),
                 'frame': dict(actors=dict(start='f0b503af')), 'kind argument': dict(actors=dict(kind=2)),
                 'scale argument': dict(actors=dict(frame=0x24)), 'effect type': dict(actors=dict(step=3)),
                 'two effects': dict(actors=dict(effects=2)), 'type bound': dict(explosions=dict(start=EXPLOSION_START.replace('0c2e', '0d2e'))),
                 'default case': dict(explosions=dict(cases={2: 'other'})), 'special type': dict(explosions=dict(special=0xc)),
                 'ordinary pair': dict(explosions=dict(ordinary='void')), 'void case': dict(explosions=dict(cases={3: 'other'})),
                 'join': dict(explosions=dict(joins=('join', 'other', 'join'))),
                 'same models': dict(explosions=dict(pairs=((16915, 16915),) + PAIRS[1:])),
                 'threshold': dict(scale=SCALE_BODY.replace('b7ee008a', 'b0ee008a')),
                 'base': dict(scale=SCALE_BODY.replace('b7ee000ab0ee081a', 'b0ee000ab0ee081a')),
                 'factor': dict(scale=SCALE_BODY.replace('b0ee081a', 'b1ee081a')), 'setter': dict(setter='c0f8f4107047')}
        for name in (ACTOR, EXPLOSION, SCALE, SETTER):
            cases['no ' + name] = dict(omit=(name,))
        for name, options in cases.items():
            self.assertEqual(reader.extract_scenery_effects(effects_library(**options), self.RESOURCES), {}, name)
