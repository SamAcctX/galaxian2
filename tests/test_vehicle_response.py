"""Synthetic linked vehicle declarations with relocated and altered constants."""
import importlib.util
import struct
from types import SimpleNamespace
import unittest
from test_ship_models import branch
from gof2_content.vehicle_response import extract_vehicle_response


def fixture(mac, relocation=0):
    base = (0x100002000 if mac else 0x2000) + relocation
    code = bytearray(4096)
    def put(at, raw):
        code[at:at + len(raw)] = raw
    def hx(at, text): put(at, bytes.fromhex(text))
    def call(at, target):
        put(at, b'\xe8' + struct.pack('<i', target - at - 5) if mac else branch(base + at, base + target))
    def ref(at, target, reg=0):
        if mac: put(at, struct.pack('<i', target - at - 4))
        else:
            delta = target - ((at + 4) & ~3)
            assert delta % 4 == 0 and abs(delta) <= 1020
            put(at, bytes([0x9f if delta >= 0 else 0x1f, 0xed, abs(delta) // 4, reg // 2 * 16 + 0xa]))
    def val(at, value): put(at, struct.pack('<f', value))
    if mac:
        getter = bytearray.fromhex('554889e5488b8f880000000f57c94885c9742b8b010f57c985c07422488b49080f57c931d2f30f100500000000833c91077504f30f58c848ffc239c272eff30f104718f30f580500000000f30f5e0500000000f30f590500000000f30f580500000000f30f58c15dc3')
        put(512, getter)
        # Every reference is independently backed; no fixture uses original values.
        offsets = [getter.index(bytes.fromhex('f30f1005')) + 4]
        for opcode in ['f30f5805', 'f30f5e05', 'f30f5905']:
            offsets.append(getter.index(bytes.fromhex(opcode)) + 4)
        offsets.append(getter.rindex(bytes.fromhex('f30f5805')) + 4)
        for offset, target, value in zip(offsets, range(3000, 3020, 4), [0.25, -0.2, 2, 0.5, 0.8]):
            ref(512 + offset, target); val(target, value)
        hx(1024, 'e8000000000f57c0f30f2ac0f30f1183f0020000f30f5e0500000000f30f108ba4010000f30f59c1f30f58c1f30f590500000000f30f1183a4010000')
        call(1024, 2100); ref(1024 + code[1024:1084].index(bytes.fromhex('f30f5e05')) + 4, 3020); val(3020, 200)
        ref(1024 + code[1024:1084].index(bytes.fromhex('f30f5905')) + 4, 3024); val(3024, 30)
        call(880, 512); hx(885, 'f30f1183a4010000')
        hx(2100, '554889e58b47405dc3')
        hx(1800, '498b4770488b40084a8b3c30be21000000e80000000041894740')
        call(1817, 2200)
        hx(2200, '554889e5488b4f388b3931d2eb044883c202b8257899c539fa730d488b410839349075ea8b4490045dc3')
        hx(1600, 'e80000000083f81d0f870000000089c0486304834801d8ffe0'); call(1600, 2300)
        hx(2300, '554889e58b47085dc3')
        hx(1540, '488d1d00000000'); ref(1543, 2600)
        put(2600, struct.pack('<30i', *[(1800 if i == 12 else 2800) - 2600 for i in range(30)]))
        hx(2400, '554889e5488b47384885c0747d488b48088b4904890f488b48088b490c894f04488b48088b4914894f08')
    else:
        hx(512, '826f002a1cbfd2f80090b9f1000f02d1c0ef10000ee0c0ef1000526800000000002352f823100133072908bf40ef800d4b45f6d390ed060a00ef800d10ee100a7047')
        ref(540, 600); val(600, 0.25)
        # A structurally identical, unlinked getter must not cause ambiguity.
        put(640, code[512:578]); ref(668, 720); val(720, 0.75)
        hx(1024, '0000000040ec300bbbff2006c3ef1e2f80ee0a1a85ed940a95ed540a40ff110d40ef200d00ffb20d85ed540a')
        call(1024, 2100)
        ref(800, 1100, 20); val(1100, 200)
        call(880, 512); hx(884, 'c5f85001')
        hx(2100, '006c7047')
        hx(1800, 'e06e212140688059000000002064'); call(1808, 2200)
        hx(2200, '026bd2f80090b9f1000f08d05268002352f82300884207d002334b45f8d347f62500ccf29950704702eb830040687047')
        hx(1600, '000000001d2800f20000dfe800f0'); call(1600, 2300)
        put(1614, bytes([(1800 - 1614) // 2 if j == 12 else 0 for j in range(30)]))
        hx(2300, '80687047')
        hx(2400, '016b002908bf70474968c0ef50004a680260ca6842604a698260')
    text = dict(offset=256, address=base, length=len(code), segment=b'__TEXT', name=b'__text')
    return SimpleNamespace(data=bytes(256) + code, text=text, sections=[text],
                           architecture='x86_64' if mac else 'armv7', slice_offset=4096)


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class VehicleResponseTests(unittest.TestCase):
    def test_linked_readers_and_relocated_alternative_values(self):
        for mac in (True, False):
            for relocation in (0, 0x2400):
                m = fixture(mac, relocation)
                result = extract_vehicle_response(m, {'supported': True})
                self.assertEqual(result['upgrade_tag'], 7)
                self.assertEqual(result['upgrade_bonus'], 0.25)
                self.assertEqual(result['equipment_type'], 12)
                self.assertEqual(result['equipment_percent_property'], 33)
                self.assertEqual(result['item_type_value_index'], 5)
                self.assertEqual(result['percent_divisor'], 200)
                self.assertEqual(result['response_scale'], 30)
                self.assertEqual(result['equipment_rule'], 'last_matching')
                self.assertAlmostEqual(result['base_add'], -0.2 if mac else 0)
                self.assertEqual(result['base_divisor'], 2 if mac else 1)
                self.assertEqual(len(result['provenance']), 18 if mac else 14)
                self.assertEqual(result['provenance']['handling_getter']['offset'], 4096 + 256 + 512)
                self.assertEqual(extract_vehicle_response(m, {}), {})

    def test_corrupted_references_and_missing_content_are_rejected(self):
        for mac in (True, False):
            for case in ('handling_link', 'getter', 'equipment_getter', 'property_getter', 'type_getter', 'type_layout', 'table', 'bonus', 'divisor', 'extent', 'duplicate'):
                m=fixture(mac); data=bytearray(m.data)
                at={'handling_link':880, 'getter':512, 'equipment_getter':2100,
                    'property_getter':2200, 'type_getter':2300, 'type_layout':2400}.get(case)
                if at is not None: data[256 + at] ^= 1
                elif case == 'table':
                    at=2600 + 12 * 4 if mac else 1614 + 12
                    data[256+at] ^= 1
                elif case in ('bonus','divisor'):
                    at = (3000 if mac else 600) if case == 'bonus' else (3020 if mac else 1100)
                    struct.pack_into('<f',data,256+at,float('nan') if case=='bonus' else 0)
                elif case == 'extent': m.sections[0]['length']=2400
                elif case == 'duplicate':
                    size=60 if mac else 44
                    data[256+3200:256+3200+size]=data[256+1024:256+1024+size]
                m.data=bytes(data)
                self.assertEqual(extract_vehicle_response(m, {'supported':True}), {}, (mac,case))


def floats(*values):
    return [struct.unpack('<I', struct.pack('<f', v))[0] for v in values]


ANDROID_DEFAULTS = dict(upgrade=0.25, zeros=(0.0, 0.0), tag=4, base_field=0x18, loop='loop', agility_field=0x40, sort_field=8,
                        default=0x7825, item_sort=0x14, percent=50.0, scale=16.0, setups=('handling', 'response'),
                        setup_call='agility', percent_loads=('pc',), early_jump=False, property_id=0x1d, assignments=1,
                        assign_call='attribute', cases=(12,), cases_bound=0x1d, prefix=False, outside=None, omit=None)


def android(**options):
    """The Android vehicle declarations: PlayerEgo's constructor, Ship and Item helpers.

    `outside` names a pool float ('zero', 'upgrade', 'percent') loaded from just before its function.
    Returns (library, labels of the fixture's own landmarks).
    """
    o = dict(ANDROID_DEFAULTS, **options)
    from android_fixture import TEXT, library
    from gof2_content import vehicle_response as v
    from test_steering import (adds8, assemble, b_to, cbz, cmp_imm, cmp_reg, cmp_w, ldr_reg, ldr_w, pop_r7, push_r7,
                               tbb, vadd, vdiv, vldr_pc, vmov_from_core, vmov_imm, vmov_q8_zero, vmov_s, vpush_d8, vstr)
    at = {name: TEXT + 0x200 * i for i, name in enumerate(
        [v.ANDROID_CONSTRUCTOR, v.ANDROID_HANDLING, v.ANDROID_AGILITY, v.ANDROID_REFRESH, v.ANDROID_ATTRIBUTE, v.ANDROID_SORT,
         v.ANDROID_INIT], 1)}
    marks = {}

    def pool(name, function, word):
        return at[function] - 4 if o['outside'] == name else at[function] + 0x100 + 4 * word

    def handling(asm, L):
        table = at[v.ANDROID_HANDLING] + 0x100
        asm.ldr(2, 0, 0x78)
        cbz(vldr_pc(asm, 0, pool('zero', v.ANDROID_HANDLING, 0)), 2, L.get('base', asm.here() + 4))
        b_to(cmp_w(ldr_w(asm, 12, 2, 0), 12, 0), L.get('base', asm.here() + 4), 'eq').ldr(2, 2, 4).movs(3, 0)
        vldr_pc(vldr_pc(asm, 0, table + 4), 2, pool('upgrade', v.ANDROID_HANDLING, 2)).label('loop')
        cmp_imm(adds8(ldr_reg(vadd(asm, 4, 0, 2), 1, 2, 3, 2), 3, 1), 1, o['tag']).it_eq()
        b_to(cmp_reg(vmov_s(asm, 0, 4), 3, 12), L.get(o['loop'], asm.here() + 4), 'lo').label('base')
        vadd(asm.vldr(2, 0, o['base_field']), 0, 0, 2).vmov_core(0, 0).ret()
        while asm.here() < table:
            asm.nop()
        asm.data(*floats(*o['zeros'], o['upgrade']))

    def constructor(asm, L):
        table = at[v.ANDROID_CONSTRUCTOR] + 0x100
        vpush_d8(asm.push())
        if o['early_jump']:
            b_to(asm, L.get('after', asm.here() + 4)).label('after')
        for kind in o['percent_loads']:
            vldr_pc(asm, 16, pool('percent', v.ANDROID_CONSTRUCTOR, 0)) if kind == 'pc' else asm.vldr(16, 4, 8)
            asm.nop()
        for kind in o['setups']:
            marks[kind] = asm.here()
            if kind == 'handling':
                asm.call(at[v.ANDROID_HANDLING]).str_w(0, 4, 0x154)
            else:
                asm.call(at[v.ANDROID_AGILITY if o['setup_call'] == 'agility' else v.ANDROID_SORT])
                vdiv(vmov_imm(vmov_from_core(asm, 0, 0), 4, o['scale']).vcvt(0, 0), 2, 0, 16)
                vstr(asm, 0, 4, 0x254).vldr(0, 4, 0x154).vmul(2, 0, 2)
                vstr(vadd(asm, 0, 0, 2).vmul(0, 0, 4), 0, 4, 0x154)
        asm.pop()
        while asm.here() < table:
            asm.nop()
        asm.data(*floats(o['percent']))

    def refresh(asm, L):
        asm.push().call(at[v.ANDROID_SORT])
        tbb(b_to(cmp_imm(asm, 0, o['cases_bound']), L.get('end', asm.here() + 4), 'hi', True), 0)
        start = asm.here()
        rows = [(L.get('assign', start) if i in o['cases'] else L.get('end', start)) - start >> 1 for i in range(30)]
        asm.half(*(rows[i] | rows[i + 1] << 8 for i in range(0, 30, 2)))
        for _ in range(o['assignments']):
            asm.label('assign').ldr(0, 4, 0x6c).movs(1, o['property_id']).ldr(0, 0, 4)
            ldr_reg(asm, 0, 0, 5).call(at[v.ANDROID_ATTRIBUTE if o['assign_call'] == 'attribute' else v.ANDROID_SORT]).str(0, 4, 0x40)
            b_to(asm, L.get('end', asm.here() + 4))
        asm.label('end').pop()

    def attribute(asm, L):
        push_r7(asm).ldr(2, 0, 0x30).movw(0, o['default']).movt(0, 0xc599)
        pop_r7(cmp_w(ldr_w(asm, 12, 2, 0), 12, 0).it_eq())
        ldr_w(asm, 14, 2, 4).movs(2, 0).label('loop')
        b_to(cmp_reg(ldr_reg(asm, 3, 14, 2, 2), 3, 1), L.get('found', asm.here() + 4), 'eq')
        b_to(cmp_reg(adds8(asm, 2, 2), 2, 12), L['loop'] if 'loop' in L else asm.here() + 4, 'lo')
        from test_steering import add_lsr
        b_to(asm, L.get('done', asm.here() + 4)).label('found')
        add_lsr(asm, 0, 14, 2, 2, 0).ldr(0, 0, 4).label('done')
        pop_r7(asm)

    def item_init(asm, L):
        cbz(asm.ldr(1, 0, 0x30), 1, L.get('end', asm.here() + 4)).ldr(1, 1, 4)
        vmov_q8_zero(asm).ldr(2, 1, 4).str(2, 0, 0).ldr(2, 1, 0xc).str(2, 0, 4).ldr(2, 1, o['item_sort']).str(2, 0, 8)
        asm.label('end').ret()

    emitters = {v.ANDROID_CONSTRUCTOR: constructor, v.ANDROID_HANDLING: handling, v.ANDROID_REFRESH: refresh,
                v.ANDROID_ATTRIBUTE: attribute, v.ANDROID_INIT: item_init,
                v.ANDROID_AGILITY: lambda asm, L: (asm.nop() if o['prefix'] else asm).ldr(0, 0, o['agility_field']).ret(),
                v.ANDROID_SORT: lambda asm, L: asm.ldr(0, 0, o['sort_field']).ret()}
    functions = []
    for name, emit in emitters.items():
        asm = assemble(at[name], emit)
        marks.update({name + ':' + k: a for k, a in asm.labels.items()})
        functions.append((name, asm.finish(), at[name]))
    from gof2_content.android_library import AndroidLibrary
    return AndroidLibrary(library([f for f in functions if f[0] != o['omit']], {})), marks, at


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidVehicleResponseTests(unittest.TestCase):
    def test_named_declarations_give_values_and_spans(self):
        from gof2_content import vehicle_response as v
        lib, marks, at = android()
        result = extract_vehicle_response(lib, {'available': True})
        self.assertEqual({k: x for k, x in result.items() if k != 'provenance'},
                         {'base_add': 0.0, 'base_divisor': 1.0, 'base_scale': 1.0, 'base_offset': 0.0, 'upgrade_tag': 4,
                          'upgrade_bonus': 0.25, 'equipment_type': 12, 'item_type_value_index': 5, 'equipment_percent_property': 0x1d,
                          'percent_divisor': 50.0, 'response_scale': 16.0, 'equipment_rule': 'last_matching'})
        spans = {k: (p['offset'], p['bytes']) for k, p in result['provenance'].items()}
        c = at[v.ANDROID_CONSTRUCTOR]
        self.assertEqual(spans, {
            'handling_getter': (at[v.ANDROID_HANDLING], 66), 'upgrade_bonus': (at[v.ANDROID_HANDLING] + 0x108, 4),
            'equipment_getter': (at[v.ANDROID_AGILITY], 4), 'type_getter': (at[v.ANDROID_SORT], 4),
            'property_getter': (at[v.ANDROID_ATTRIBUTE], 54), 'item_type_layout': (at[v.ANDROID_INIT], 22),
            'percent_load': (c + 6, 4), 'percent_divisor': (c + 0x100, 4), 'handling_setup': (marks['handling'], 8),
            'response_setup': (marks['response'], 44), 'response_scale': (marks['response'] + 8, 4),
            'equipment_selector': (at[v.ANDROID_REFRESH] + 2, 14), 'equipment_table': (at[v.ANDROID_REFRESH] + 16, 30),
            'equipment_assignment': (marks[v.ANDROID_REFRESH + ':assign'], 14)})
        self.assertEqual(extract_vehicle_response(lib, {}), {})

    def test_each_broken_declaration_is_unsupported(self):
        from gof2_content import vehicle_response as v
        cases = {'base field': dict(base_field=0x1c), 'loop target': dict(loop='base'), 'agility field': dict(agility_field=0x44),
                 'sort field': dict(sort_field=4), 'attribute default': dict(default=0x7826), 'item sort': dict(item_sort=0x1c),
                 'initial sum': dict(zeros=(0.0, 0.5)), 'initial zero': dict(zeros=(0.5, 0.0)), 'zero outside': dict(outside='zero'),
                 'upgrade outside': dict(outside='upgrade'), 'percent outside': dict(outside='percent'),
                 'no handling setup': dict(setups=('response',)), 'two handling setups': dict(setups=('handling', 'handling', 'response')),
                 'no response setup': dict(setups=('handling',)), 'two response setups': dict(setups=('handling', 'response', 'response')),
                 'setup order': dict(setups=('response', 'handling')), 'setup callee': dict(setup_call='sort'),
                 'two percent loads': dict(percent_loads=('pc', 'pc')), 'percent from a field': dict(percent_loads=('field',)),
                 'redefined percent': dict(percent_loads=('pc', 'field')), 'jump before percent': dict(early_jump=True),
                 'no assignment': dict(assignments=0), 'two assignments': dict(assignments=2), 'assignment callee': dict(assign_call='sort'),
                 'no case': dict(cases=()), 'selector bound': dict(cases_bound=0x1e), 'getter prefix': dict(prefix=True), 'two cases': dict(cases=(12, 16)), 'upgrade range': dict(upgrade=11.0),
                 'upgrade sign': dict(upgrade=-0.25), 'percent range': dict(percent=20000.0), 'percent sign': dict(percent=-50.0),
                 'scale sign': dict(scale=-16.0)}
        cases.update({name: dict(omit=name) for name in (v.ANDROID_CONSTRUCTOR, v.ANDROID_HANDLING, v.ANDROID_AGILITY,
                                                         v.ANDROID_REFRESH, v.ANDROID_ATTRIBUTE, v.ANDROID_SORT, v.ANDROID_INIT)})
        for name, options in cases.items():
            self.assertEqual(extract_vehicle_response(android(**options)[0], {'available': True}), {}, name)
