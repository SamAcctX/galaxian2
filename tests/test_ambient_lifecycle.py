"""Small traffic lifecycle recognition is optional, relocated and fail-closed."""
import copy
import unittest
from unittest.mock import patch
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from declaration_fixture import declaration_fixture
from gof2_content import ambient_lifecycle as reader


class AmbientLifecycleTests(unittest.TestCase):
    def test_relocated_and_independent_declarations(self):
        for shift in [0,0x900000]:
            mach,arrival,layouts=declaration_fixture({**reader.LAYOUTS,**reader.RECYCLING_LAYOUTS},shift)
            with patch.object(reader,'LAYOUTS',layouts), patch.object(reader,'RECYCLING_LAYOUTS',{}):
                result=reader.extract_ambient_lifecycle(mach,arrival,reader.COMBAT_VALUES)
                self.assertEqual({k:v for k,v in result.items() if k!='provenance'},{**reader.VALUES,'recycling':reader.RECYCLING})
                for key,span in result['provenance'].items():
                    self.assertEqual(span,{'offset':arrival['provenance']['actor']['offset']+layouts[key][0],'bytes':layouts[key][1]})
                result['initial_mode']=-1
                self.assertEqual(reader.extract_ambient_lifecycle(mach,arrival,reader.COMBAT_VALUES)['initial_mode'],4)

    def test_altered_or_truncated_source_is_unsupported(self):
        mach,arrival,layouts=declaration_fixture({**reader.LAYOUTS,**reader.RECYCLING_LAYOUTS})
        with patch.object(reader,'LAYOUTS',layouts), patch.object(reader,'RECYCLING_LAYOUTS',{}):
            for key,(delta,_,_,_) in layouts.items():
                changed=copy.copy(mach);data=bytearray(mach.data)
                data[arrival['provenance']['actor']['offset']-mach.slice_offset+delta]^=255
                changed.data=bytes(data)
                self.assertFalse(reader.extract_ambient_lifecycle(changed,arrival,reader.COMBAT_VALUES),key)
            for i in range(len(mach.sections)):
                changed=copy.deepcopy(mach);changed.sections[i]['length']-=1
                self.assertFalse(reader.extract_ambient_lifecycle(changed,arrival,reader.COMBAT_VALUES),i)

    def test_requires_source_combat_context(self):
        mach,arrival,layouts=declaration_fixture({**reader.LAYOUTS,**reader.RECYCLING_LAYOUTS})
        with patch.object(reader,'LAYOUTS',layouts), patch.object(reader,'RECYCLING_LAYOUTS',{}):
            for key in ['scope','freighter','campaign_cursor']:
                data=copy.deepcopy(reader.COMBAT_VALUES);data.pop(key)
                self.assertFalse(reader.extract_ambient_lifecycle(mach,arrival,data),key)
            changed=copy.copy(mach);changed.architecture='armv7'
            self.assertFalse(reader.extract_ambient_lifecycle(changed,arrival,reader.COMBAT_VALUES))
            self.assertFalse(reader.extract_ambient_lifecycle(mach,arrival,None))


class AmbientLifecycleAndroidTests(unittest.TestCase):
    def test_android_proofs(self):
        import android_fixture
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        staged={'scope':'rescue_choreography'}
        extract=lambda lib:reader.extract_ambient_lifecycle(lib,staged,reader.COMBAT_VALUES)
        expected={**reader.VALUES,'recycling':reader.RECYCLING}
        with patch.object(reader,'ANDROID_VTABLES',{}),patch.object(reader,'ANDROID_RESULT',expected,create=True):
            with patch.object(android_fixture,'library',roomy(android_fixture.library)):
                android_fixture.verify_android_proof(self,reader,extract,values='ANDROID_RESULT')
                image,layout,_=android_fixture.layout_library(reader.ANDROID)
            with patch.object(reader,'ANDROID',layout):
                lib=AndroidLibrary(image)
                self.assertTrue(extract(lib))
                # Requires the arrival staging, the combat and the vtable slot.
                self.assertEqual(reader.extract_ambient_lifecycle(lib,{},reader.COMBAT_VALUES),{})
                combat=copy.deepcopy(reader.COMBAT_VALUES);combat['initial_active']=False
                self.assertEqual(reader.extract_ambient_lifecycle(lib,staged,combat),{})
                self.assertEqual(reader.extract_ambient_lifecycle(lib,staged,None),{})
                slot={'ambient_lifecycle_freighter_reset_dispatch':{'offset':1,'bytes':4,'anchor':0}}
                with patch.object(reader,'vtable_proof',lambda lib,rows:slot):
                    self.assertEqual(extract(lib)['provenance']['ambient_lifecycle_freighter_reset_dispatch'],slot['ambient_lifecycle_freighter_reset_dispatch'])
                with patch.object(reader,'vtable_proof',lambda lib,rows:None):
                    self.assertEqual(extract(lib),{})

    def test_vtable_slot(self):
        from android_text_fixture import text_library
        names=['_ZN8KIPlayer6reviveEv','_ZN13PlayerFighter6reviveEv']
        lib,_=text_library({n:'bx lr' for n in names},{'_ZTV17PlayerFixedObject':[0,0]+[0]*6+[names[0],0]})
        proof=reader.vtable_proof(lib,reader.ANDROID_VTABLES)
        self.assertEqual({k:v['offset']-v['anchor'] for k,v in proof.items()},{'ambient_lifecycle_freighter_reset_dispatch':8+4*6})
        lib,_=text_library({n:'bx lr' for n in names},{'_ZTV17PlayerFixedObject':[0,0]+[0]*6+[names[1],0]})
        self.assertIsNone(reader.vtable_proof(lib,reader.ANDROID_VTABLES))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        layout={**reader.ANDROID,**{k:(t,8+4*first,4*len(n),'00') for k,(t,first,n) in reader.ANDROID_VTABLES.items()}}
        with patch.object(reader,'ANDROID',layout):
            assert_native_android(self,reader,'ambient_lifecycle_definitions.gd',values='VALUES')
