"""Engine sound selection reads its own constants and keeps its motion owners."""
import copy
import struct
import unittest
from declaration_fixture import literal_fixture
from gof2_content import engine_audio as reader


def variants():
    return [('x86_64', reader.LAYOUTS['x86_64'], reader.DATA['x86_64']),
            ('armv7', reader.LAYOUTS['armv7'], reader.DATA['armv7']),
            ('x86_64', reader.MAC_ALTERNATE,
             {'threshold_high': [1010348, '__const'], 'threshold_middle': [1010352, '__const'],
              'threshold_low': [1005116, '__const'], 'horizontal_scale': [968076, '__const'],
              'horizontal_offset': [967080, '__const']})]


def fixture(arch, layout, data, shift=0):
    rows=copy.deepcopy(layout)
    values={'threshold_low': 2.0, 'threshold_middle': 4.0, 'threshold_high': 6.0,
            'horizontal_scale': 0.25, 'horizontal_offset': 0.5}
    for key,(delta,_) in data.items():rows[key]=[delta,4,struct.pack('<f',values[key]).hex()]
    constants=[key for key,(_,section) in data.items() if section=='__const']
    mach,origin,_,_=literal_fixture(arch,rows,shift,constants)
    def span(key):return {'offset':origin+layout[key][0], 'bytes':layout[key][1]}
    vehicle={'provenance':{'handling_setup':span('handling_setup')}}
    rotation={'provenance':[span('rotation_anchor')]}
    return mach,vehicle,rotation,origin


class EngineAudioTests(unittest.TestCase):
    def test_source_constants_and_relocation(self):
        for arch,layout,data in variants():
            for shift in [0,0x700000]:
                mach,vehicle,rotation,origin=fixture(arch,layout,data,shift)
                result=reader.extract_engine_audio(mach,vehicle,rotation)
                self.assertEqual(result['thresholds'],[2.0,4.0,6.0])
                self.assertEqual(result['horizontal_scale'],0.25)
                self.assertEqual({k:result[k] for k in reader.VALUES},reader.VALUES)
                for span in result['provenance'].values():self.assertEqual(set(span),{'offset','bytes'})
                raw=bytearray(mach.data)
                struct.pack_into('<f',raw,origin+data['threshold_low'][0]-mach.slice_offset,1.5)
                mach.data=bytes(raw)
                self.assertEqual(reader.extract_engine_audio(mach,vehicle,rotation)['thresholds'],[1.5,4.0,6.0])

    def test_all_proofs_and_invalid_constants(self):
        for arch,layout,data in variants():
            mach,vehicle,rotation,origin=fixture(arch,layout,data)
            for key,(delta,size,_) in layout.items():
                for endpoint in [0,size-1]:
                    bad=copy.copy(mach);raw=bytearray(mach.data)
                    raw[origin+delta+endpoint-mach.slice_offset]^=255;bad.data=bytes(raw)
                    self.assertFalse(reader.extract_engine_audio(bad,vehicle,rotation),(arch,key,endpoint))
            for key in data:
                invalid=[0,-1,100,float('nan'),float('inf')]
                if key=='threshold_low':invalid.append(4)
                if key=='horizontal_offset':invalid.append(0.25)
                for value in invalid:
                    bad=copy.copy(mach);raw=bytearray(mach.data)
                    struct.pack_into('<f',raw,origin+data[key][0]-mach.slice_offset,value);bad.data=bytes(raw)
                    self.assertFalse(reader.extract_engine_audio(bad,vehicle,rotation),(arch,key,value))

    def test_independent_owners_and_sections(self):
        for arch,layout,data in variants():
            for changed in ['handling','rotation','origin','section','truncation','arch']:
                mach,vehicle,rotation,origin=fixture(arch,layout,data)
                if changed=='handling':vehicle['provenance']['handling_setup']['bytes']+=2
                elif changed=='rotation':rotation['provenance'][0]['offset']+=2
                elif changed=='origin':vehicle['provenance']['handling_setup']['offset']+=2
                elif changed=='section':mach.sections[-1]['segment']=b'__DATA'
                elif changed=='truncation':mach.data=mach.data[:origin-mach.slice_offset]
                else:mach.architecture='unsupported'
                self.assertFalse(reader.extract_engine_audio(mach,vehicle,rotation),(arch,changed))


def android_parents(lib):
    """Parents whose handling setup and rotation step are this library's own spans (or absent)."""
    from gof2_content.declaration_layouts import recognize_symbols
    proof = recognize_symbols(lib, reader.ANDROID)
    if not proof:
        return {}, {}
    def extent(key): return {'offset': proof[key]['offset'], 'bytes': proof[key]['bytes']}
    return {'provenance': {'handling_setup': extent('handling_setup')}}, {'provenance': [extent('rotation_anchor')]}


class AndroidEngineAudioTests(unittest.TestCase):
    def test_android_proofs(self):
        from android_fixture import verify_android_proof
        verify_android_proof(self, reader, lambda lib: reader.extract_engine_audio(lib, *android_parents(lib)))

    def test_android_parents_must_own_the_linked_spans(self):
        from unittest.mock import patch
        from android_fixture import layout_library
        from gof2_content.android_library import AndroidLibrary
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            vehicle, rotation = android_parents(lib)
            self.assertTrue(reader.extract_engine_audio(lib, vehicle, rotation))
            for broken in ('vehicle', 'rotation', 'handling', 'step', 'handling size', 'step size', 'no step'):
                v, r = copy.deepcopy(vehicle), copy.deepcopy(rotation)
                if broken == 'vehicle': v = {}
                elif broken == 'rotation': r = {}
                elif broken == 'handling': v['provenance']['handling_setup']['offset'] += 2
                elif broken == 'step': r['provenance'][0]['offset'] += 2
                elif broken == 'handling size': v['provenance']['handling_setup']['bytes'] += 2
                elif broken == 'step size': r['provenance'][0]['bytes'] -= 2
                else: r['provenance'] = []
                self.assertEqual(reader.extract_engine_audio(lib, v, r), {}, broken)

    def test_android_values_are_the_proven_pool_floats(self):
        def value(key): return struct.unpack('<f', bytes.fromhex(reader.ANDROID[key][3]))[0]
        self.assertEqual(reader.ANDROID_VALUES['thresholds'], [value('threshold_low'), value('threshold_middle'), value('threshold_high')])
        self.assertEqual(reader.ANDROID_VALUES['horizontal_scale'], value('horizontal_scale'))
        self.assertEqual({k: reader.ANDROID_VALUES[k] for k in reader.VALUES}, reader.VALUES)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'engine_audio_definitions.gd')
