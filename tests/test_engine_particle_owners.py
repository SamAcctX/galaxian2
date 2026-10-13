"""Synthetic declaration boundaries; no original executable fixtures."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import engine_particle_owners as reader
from gof2_content.engine_particles import VALUES as NOZZLES, OPENING_SHIP, OPENING_SPANS


def fixture(layout, shift=0):
    mach, arrival, proofs = declaration_fixture(layout, shift, 'sha256:')
    engines = copy.deepcopy(NOZZLES)
    engines['provenance'] = {}
    return mach, arrival, engines, proofs


class EngineParticleOwnerTests(unittest.TestCase):
    def test_opening_owner_requires_proven_nozzle_capability(self):
        mach,arrival,engines,proofs=fixture(reader.LAYOUTS)
        with patch.object(reader,'LAYOUTS',proofs):
            engines['opening_ship']=copy.deepcopy(OPENING_SHIP)
            self.assertFalse(reader.extract_engine_particle_owners(mach,arrival,engines))
            engines['provenance']={key:{'offset':100+index,'bytes':row[1]}
                                   for index,(key,row) in enumerate(OPENING_SPANS.items())}
            owner=reader.extract_engine_particle_owners(mach,arrival,engines)
            self.assertEqual(owner['opening_ship'],{'ship_id':10,'nozzle_count':3,'first_preset':29})
            self.assertEqual(set(owner['provenance']),set(proofs))
            engines['opening_ship']['uv_rect'][0]=0
            self.assertFalse(reader.extract_engine_particle_owners(mach,arrival,engines))

    def test_both_complete_layouts_relocate_and_return_detached_data_only(self):
        for name in ('LAYOUTS', 'MAC_ALTERNATE'):
            for shift in (0, 0x700000):
                mach, arrival, engines, proofs = fixture(getattr(reader, name), shift)
                with patch.object(reader, name, proofs):
                    result = reader.extract_engine_particle_owners(mach, arrival, engines)
                    self.assertEqual({key: value for key, value in result.items() if key != 'provenance'}, reader.VALUES)
                    self.assertEqual(set(result['provenance']), set(proofs))
                    for key, span in result['provenance'].items():
                        self.assertEqual(span, {'offset': arrival['provenance']['actor']['offset'] + proofs[key][0], 'bytes': proofs[key][1]})
                    result['provenance'].clear()
                    result['boost_available'] = True
                    again = reader.extract_engine_particle_owners(mach, arrival, engines)
                    self.assertEqual(len(again['provenance']), len(proofs))
                    self.assertFalse(again['boost_available'])

    def test_every_span_endpoint_and_section_extent_is_required(self):
        for name in ('LAYOUTS', 'MAC_ALTERNATE'):
            mach, arrival, engines, proofs = fixture(getattr(reader, name))
            with patch.object(reader, name, proofs):
                for key, (delta, size, _, _) in proofs.items():
                    for endpoint in (0, size - 1):
                        changed = copy.copy(mach)
                        data = bytearray(mach.data)
                        data[arrival['provenance']['actor']['offset'] - mach.slice_offset + delta + endpoint] ^= 255
                        changed.data = bytes(data)
                        self.assertFalse(reader.extract_engine_particle_owners(changed, arrival, engines), (name, key, endpoint))
                for index in range(len(mach.sections)):
                    changed = copy.deepcopy(mach)
                    changed.sections[index]['length'] -= 1
                    self.assertFalse(reader.extract_engine_particle_owners(changed, arrival, engines), (name, index))

    def test_context_and_unchanged_nozzle_contract_are_required(self):
        mach, arrival, engines, proofs = fixture(reader.LAYOUTS)
        with patch.object(reader, 'LAYOUTS', proofs):
            for mutation in ('architecture', 'anchor', 'anchor_size', 'missing_nozzles', 'scope', 'preset', 'provenance'):
                changed = copy.copy(mach)
                a = copy.deepcopy(arrival)
                e = copy.deepcopy(engines)
                if mutation == 'architecture':
                    changed.architecture = 'armv7'
                elif mutation == 'anchor':
                    a['provenance']['actor']['offset'] += 1
                elif mutation == 'anchor_size':
                    a['provenance']['actor']['bytes'] = 314
                elif mutation == 'missing_nozzles':
                    e = {}
                elif mutation == 'scope':
                    e['scope'] = 'unknown'
                elif mutation == 'preset':
                    e['preset']['distance_spacing'] += 1
                else:
                    e['provenance'] = []
                self.assertFalse(reader.extract_engine_particle_owners(changed, a, e), mutation)

    def test_partial_or_ambiguous_layouts_do_not_combine(self):
        mach, arrival, engines, proofs = fixture(reader.LAYOUTS)
        keys = list(proofs)
        first = {key: copy.deepcopy(proofs[key]) for key in keys}
        second = copy.deepcopy(first)
        first[keys[0]][3] = 'sha256:' + '0' * 64
        second[keys[-1]][3] = 'sha256:' + '0' * 64
        with patch.multiple(reader, LAYOUTS=first, MAC_ALTERNATE=second):
            self.assertFalse(reader.extract_engine_particle_owners(mach, arrival, engines))
        with patch.multiple(reader, LAYOUTS=proofs, MAC_ALTERNATE=proofs):
            self.assertFalse(reader.extract_engine_particle_owners(mach, arrival, engines))


def android_thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidEngineParticleOwnerTests(unittest.TestCase):
    def engines(self):
        from gof2_content import engine_particles
        provenance = {key: {'offset': 1, 'bytes': 1, 'anchor': 0} for key in engine_particles.ANDROID}
        return dict(copy.deepcopy(engine_particles.ANDROID_VALUES), provenance=provenance)

    def extract(self, lib, engines=None):
        return reader.extract_engine_particle_owners(lib, {}, self.engines() if engines is None else engines)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, reader, self.extract)
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            data = self.extract(lib)
            data['opening_ship']['nozzle_count'] = 1
            self.assertEqual(reader.ANDROID_VALUES['opening_ship']['nozzle_count'], 3)
            engines = self.engines()
            without_opening = {k: v for k, v in engines.items() if k != 'opening_ship'}
            other_preset = copy.deepcopy(engines); other_preset['preset']['size'] = 1.0
            missing_span = copy.deepcopy(engines); del missing_span['provenance']['family_table']
            cases = {'no opening': without_opening, 'other preset': other_preset, 'missing span': missing_span,
                     'no provenance': {k: v for k, v in engines.items() if k != 'provenance'}, 'empty': {}, 'none': None,
                     'mac values': dict(copy.deepcopy(NOZZLES), provenance=engines['provenance'])}
            for name, value in cases.items():
                self.assertEqual(reader.extract_engine_particle_owners(lib, {}, value), {}, name)

    def test_android_switches(self):
        rows, values = reader.ANDROID, reader.ANDROID_VALUES
        def flag(key):
            return next(int(op.split('#')[1]) for m, op in android_thumb(rows[key][3]) if m == 'movs' and op.startswith('r1,'))
        self.assertEqual(bool(flag('entry_disable')), values['entry_engine_enabled'])
        self.assertEqual(bool(flag('mining_capture_disable')), values['mining_capture_engine_enabled'])
        for key in ['mining_cancel_enable', 'mining_release_enable0', 'mining_release_enable1', 'drill_stop_enable']:
            self.assertEqual(bool(flag(key)), values['mining_release_engine_enabled'], key)
        self.assertEqual(bool(flag('death_disable')), values['death_engine_enabled'])
        self.assertEqual(bool(flag('revive_enable')), values['revive_engine_enabled'])
        # The constructor stores 1 (r5) to the drawn, visible and engine flags and 0 (r6) to the hidden flag.
        stores = android_thumb(rows['player_initial_flags'][3])
        self.assertEqual(stores, [('strb.w', 'r5, [r4, #0x309]'), ('strb.w', 'r5, [r4, #0x32e]'), ('strb.w', 'r5, [r4, #0x32f]'), ('strb.w', 'r6, [r4, #0x32d]')])

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'engine_particle_owner_definitions.gd', values='VALUES')
