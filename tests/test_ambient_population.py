"""Population imports fail closed without distributing source game fixtures."""
import copy,unittest
from unittest.mock import patch
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from declaration_fixture import declaration_fixture
from gof2_content import ambient_population as reader


class AmbientPopulationTests(unittest.TestCase):
    def test_relocation_independent_copy_and_bounded_provenance(self):
        for shift in [0,0xA00000]:
            mach,arrival,layouts=declaration_fixture(reader.LAYOUTS,shift)
            with patch.object(reader,'LAYOUTS',layouts):
                result=reader.extract_ambient_population(mach,arrival,reader.TRAVEL_VALUES)
                self.assertEqual({key:value for key,value in result.items() if key!='provenance'},reader.VALUES)
                for key,span in result['provenance'].items():
                    self.assertEqual(span,{'offset':arrival['provenance']['actor']['offset']+layouts[key][0],'bytes':layouts[key][1]})
                result['contexts'][0]['station_id']=-1
                self.assertNotEqual(result['contexts'],reader.extract_ambient_population(mach,arrival,reader.TRAVEL_VALUES)['contexts'])

    def test_missing_or_modified_span_is_unsupported(self):
        mach,arrival,layouts=declaration_fixture(reader.LAYOUTS)
        with patch.object(reader,'LAYOUTS',layouts):
            for key,(delta,_,_,_) in layouts.items():
                changed=copy.copy(mach);data=bytearray(mach.data)
                data[arrival['provenance']['actor']['offset']-mach.slice_offset+delta]^=255
                changed.data=bytes(data)
                self.assertFalse(reader.extract_ambient_population(changed,arrival,reader.TRAVEL_VALUES),key)
            for index in range(len(mach.sections)):
                changed=copy.deepcopy(mach);changed.sections[index]['length']-=1
                self.assertFalse(reader.extract_ambient_population(changed,arrival,reader.TRAVEL_VALUES),index)

    def test_context_and_architecture_are_required(self):
        mach,arrival,layouts=declaration_fixture(reader.LAYOUTS)
        with patch.object(reader,'LAYOUTS',layouts):
            for key in ['scope','actor_kind','anchor','architecture']:
                m=copy.copy(mach);a=copy.deepcopy(arrival);travel=copy.deepcopy(reader.TRAVEL_VALUES)
                if key=='scope':travel['scope']='unknown'
                elif key=='actor_kind':travel['departure_traffic']['actor_kind']=0
                elif key=='anchor':a['provenance']['actor']['offset']+=1
                else:m.architecture='armv7'
                self.assertFalse(reader.extract_ambient_population(m,a,travel),key)
            self.assertFalse(reader.extract_ambient_population(mach,arrival,None))


class AmbientPopulationAndroidTests(unittest.TestCase):
    def test_android_proofs(self):
        import android_fixture
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        staged={'scope':'rescue_choreography'}
        with patch.object(android_fixture,'library',roomy(android_fixture.library)):
            android_fixture.verify_android_proof(self,reader,lambda lib:reader.extract_ambient_population(lib,staged,reader.TRAVEL_ANDROID_VALUES),values='VALUES')
            image,layout,_=android_fixture.layout_library(reader.ANDROID)
        with patch.object(reader,'ANDROID',layout):
            lib=AndroidLibrary(image)
            self.assertTrue(reader.extract_ambient_population(lib,staged,reader.TRAVEL_ANDROID_VALUES))
            # Requires the arrival staging and the Android local travel (its own planet window).
            self.assertEqual(reader.extract_ambient_population(lib,{},reader.TRAVEL_ANDROID_VALUES),{})
            self.assertEqual(reader.extract_ambient_population(lib,staged,reader.TRAVEL_MAC_VALUES),{})
            self.assertEqual(reader.extract_ambient_population(lib,staged,None),{})

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self,reader,'ambient_population_definitions.gd',values='VALUES')
