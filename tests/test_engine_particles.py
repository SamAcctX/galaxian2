"""Synthetic source extents only; no original executable or artwork fixtures."""
import copy,struct,unittest
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from declaration_fixture import declaration_fixture
from unittest.mock import patch
from gof2_content import engine_particles as reader


def fixture(shift=0):
    mach,arrival,layouts=declaration_fixture(reader.LAYOUTS,shift,'sha256:')
    damage={'scope':'damage_particle_sprite_presets','emitter_defaults':{}}
    return mach,arrival,damage,layouts


def opening_fixture(shift=0):
    combined={**reader.LAYOUTS,**reader.MAC_OPENING_SPANS}
    mach,arrival,layouts=declaration_fixture(combined,shift,'sha256:')
    damage={'scope':'damage_particle_sprite_presets','emitter_defaults':{}}
    base={key:layouts[key] for key in reader.LAYOUTS}
    opening={key:layouts[key] for key in reader.MAC_OPENING_SPANS}
    return mach,arrival,damage,base,opening


class EngineParticleTests(unittest.TestCase):
    def test_opening_hull_requires_complete_additional_source_proof(self):
        for shift in (0,0x700000):
            mach,arrival,damage,base,opening=opening_fixture(shift)
            with patch.multiple(reader,LAYOUTS=base,MAC_OPENING_SPANS=opening):
                result=reader.extract_engine_particles(mach,arrival,damage)
                self.assertEqual(result.get('opening_ship'),reader.OPENING_SHIP)
                self.assertEqual(set(result['provenance']),set(base)|set(opening))
                for key,(delta,size,_,_) in opening.items():
                    self.assertEqual(result['provenance'][key],{'offset':arrival['provenance']['actor']['offset']+delta,'bytes':size})
                    for endpoint in (0,size-1):
                        changed=copy.copy(mach);data=bytearray(mach.data)
                        data[arrival['provenance']['actor']['offset']-mach.slice_offset+delta+endpoint]^=255
                        changed.data=bytes(data)
                        unsupported=reader.extract_engine_particles(changed,arrival,damage)
                        self.assertNotIn('opening_ship',unsupported,(key,endpoint))
                result['opening_ship']['uv_rect'][0]=0
                self.assertEqual(reader.extract_engine_particles(mach,arrival,damage)['opening_ship'],reader.OPENING_SHIP)

    def test_relocated_source_and_detached_data_only_result(self):
        for shift in [0,0x700000]:
            mach,arrival,damage,layouts=fixture(shift)
            with patch.object(reader,'LAYOUTS',layouts):
                result=reader.extract_engine_particles(mach,arrival,damage)
                self.assertEqual({k:v for k,v in result.items() if k!='provenance'},reader.VALUES)
                for key,span in result['provenance'].items():
                    self.assertEqual(set(span),{'offset','bytes'})
                    self.assertEqual(span,{'offset':arrival['provenance']['actor']['offset']+layouts[key][0],'bytes':layouts[key][1]})
                result['preset']['uv_rect'][0]=0
                self.assertNotEqual(result['preset'],reader.extract_engine_particles(mach,arrival,damage)['preset'])

    def test_every_required_span_and_section_extent(self):
        mach,arrival,damage,layouts=fixture()
        with patch.object(reader,'LAYOUTS',layouts):
            for key,(delta,_,_,_) in layouts.items():
                changed=copy.copy(mach);data=bytearray(mach.data)
                at=arrival['provenance']['actor']['offset']-mach.slice_offset+delta
                data[at]^=255;changed.data=bytes(data)
                self.assertFalse(reader.extract_engine_particles(changed,arrival,damage),key)
            for index in range(len(mach.sections)):
                changed=copy.deepcopy(mach);changed.sections[index]['length']-=1
                self.assertFalse(reader.extract_engine_particles(changed,arrival,damage),index)

    def test_missing_context_and_unknown_architecture(self):
        mach,arrival,damage,layouts=fixture()
        with patch.object(reader,'LAYOUTS',layouts):
            for key in ['anchor','anchor_size','scope','defaults','architecture']:
                m=copy.copy(mach);a=copy.deepcopy(arrival);d=copy.deepcopy(damage)
                if key=='anchor':a['provenance']['actor']['offset']+=1
                elif key=='anchor_size':a['provenance']['actor']['bytes']=314
                elif key=='scope':d['scope']='unknown'
                elif key=='defaults':d.pop('emitter_defaults')
                else:m.architecture='unknown'
                self.assertFalse(reader.extract_engine_particles(m,a,d),key)

DAMAGE = {'scope': 'damage_particle_sprite_presets', 'emitter_defaults': {}}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidEngineParticleTests(unittest.TestCase):
    def extract(self, lib, damage=DAMAGE):
        return reader.extract_engine_particles(lib, {}, damage)

    def test_android_proofs(self):
        from unittest.mock import patch
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, reader, self.extract)
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            data = self.extract(lib)
            data['opening_ship']['ship_id'] = 1
            data['preset']['size'] = 1.0
            self.assertEqual((reader.OPENING_SHIP['ship_id'], reader.ANDROID_VALUES['opening_ship']['ship_id']), (10, 10))
            self.assertEqual((reader.VALUES['preset']['size'], reader.ANDROID_VALUES['preset']['size']), (250.0, 250.0))
            cases = {'other damage': dict(damage={'scope': 'x', 'emitter_defaults': {}}), 'no defaults': dict(damage={'scope': DAMAGE['scope']}),
                     'no damage': dict(damage={}), 'none': dict(damage=None)}
            for name, changes in cases.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_constants(self):
        rows, values = reader.ANDROID, reader.ANDROID_VALUES
        preset = values['preset']
        lifetime, size, _, velocity = struct.unpack('<dfId', bytes.fromhex(rows['nozzle_scales'][3]))
        self.assertEqual((lifetime, size, velocity), (preset['lifetime_ms'], preset['size'], preset['local_velocity_z']))
        sprites = struct.unpack('<24f', bytes.fromhex(rows['nozzle_sprites'][3]))
        families = struct.unpack('<11i', bytes.fromhex(rows['family_table'][3]))
        # The pool holds families 9, 8, 1, 2, 3 and the default (0, 4..7); initParticleSystems picks by family.
        by_family = {3: list(sprites[16:20]), 0: list(sprites[20:24])}
        self.assertEqual(by_family[families[values['ship_id']]], preset['uv_rect'])
        self.assertEqual(by_family[families[values['opening_ship']['ship_id']]], values['opening_ship']['uv_rect'])
        vectors = struct.unpack('<4i4i4f', bytes.fromhex(rows['basic_vectors'][3]))
        self.assertEqual(vectors[:3], (1, -1, 255))
        self.assertEqual(vectors[4], preset['size_growth_per_second'] // 2)
        self.assertEqual(vectors[7], preset['velocity_scatter'])
        self.assertEqual(thumb(rows['ship_id_getter'][3])[0], ('ldr', 'r0, [r0]'))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'engine_particle_definitions.gd', values='VALUES')
