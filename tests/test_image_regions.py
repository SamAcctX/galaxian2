"""Synthetic image aliases, with independently relocated declarations."""
import importlib.util
import struct
from types import SimpleNamespace
import unittest
from gof2_content.image_regions import extract_image_bindings, MAC_RECORD, MAC_STACK_RECORD, MAC_RANGE, ARM_RANGE
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch

ARM_RECORD = """
1020c4f87055
{call_6:4}
c4f8f401
{value_e:4}
c4f870050420
{call_18:4}
0bae
{value_1e:4}
06f58041
{value_26:4}
{value_2a:4}
4ff0ff350c46d4f8f4110260d4f8f42113800323d4f8f4215360d4f8f4219560d4f8f421d060c4f870550798
{call_5a:4}
"""


def fixture(mac, sequence=False, relocation=0, stacked=False):
    start=0x10000+relocation
    spec=(MAC_RANGE if mac else ARM_RANGE) if sequence else (MAC_RECORD if mac else ARM_RECORD)
    if stacked:spec=MAC_STACK_RECORD
    code,fields=expand(spec)
    for key,(at,n) in fields.items():
        if key.startswith('call') or key in ['allocate','payload','insert']:
            target=start+512
            if mac: raw=struct.pack('<i',target-start-at-4)
            else:
                blx=key!=('call_74' if sequence else 'call_5a')
                raw=bytearray(branch(((start+at+4)&~3)-4 if blx else start+at,target))
                if blx:raw[3]&=~0x10
        elif key.startswith('outside'):raw=struct.pack('<i',start+600-start-at-4)
        elif key.startswith('value'):
            value,reg,top=({'value_16':5,'value_28':900,'value_30':42}[key],{'value_16':0,'value_28':2,'value_30':3}[key],False) if sequence else ({'value_e':5,'value_1e':900,'value_26':7,'value_2a':42}[key],{'value_e':0,'value_1e':2,'value_26':2,'value_2a':3}[key],key=='value_26')
            raw=arm_wide(value,reg,top)
        elif key=='stack':raw=struct.pack('<i',-0x2c00)
        else:
            value=({'count_d':2,'count_7c':3,'base_31':900,'base_41':42}[key] if sequence else {'texture':900,'region':7,'id':42}[key])
            raw=value.to_bytes(n,'little')
        assert len(raw)==n;code[at:at+n]=raw
    data=bytes(64)+code+bytes(1024-len(code))
    text={'name':b'__text','segment':b'__TEXT','address':start,'offset':64,'length':1024}
    return SimpleNamespace(data=data,text=text,sections=[text],slice_offset=4096,architecture='x86_64' if mac else 'armv7'),fields,len(code)


@unittest.skipUnless(importlib.util.find_spec('capstone'),'optional static-reader dependency')
class ImageRegions(unittest.TestCase):
    def test_records_and_ranges_survive_relocation(self):
        for mac in [True,False]:
            for sequence in [False,True]:
                for relocation in [0,0x23000]:
                    mach,_,size=fixture(mac,sequence,relocation);data=extract_image_bindings(mach)
                    self.assertTrue(data,(mac,sequence))
                    row=data['ranges' if sequence else 'records'][0]
                    self.assertEqual(row['source_offset'],4160)
                    self.assertEqual(row['source_bytes'],size)
                    if sequence:self.assertEqual([row[k] for k in ['first_id','first_texture_id','count','region']],[42,900,3,0])
                    else:self.assertEqual([row[k] for k in ['id','texture_id','region']],[42,900,7])

    def test_invalid_allocation_copy_and_range_bounds(self):
        for mac in [True,False]:
            for sequence in [False,True]:
                for bad in ['allocate','copy','truncated','range']:
                    if bad=='range' and not sequence:continue
                    with self.subTest(mac=mac,sequence=sequence,bad=bad):
                        mach,fields,size=fixture(mac,sequence);data=bytearray(mach.data)
                        if bad=='allocate':
                            key=('call_2a' if mac else 'call_20') if sequence else ('payload' if mac else 'call_18')
                            at,n=fields[key];data[64+at]^=1
                        elif bad=='copy':
                            if sequence:data[64+size-1]^=1
                            else:
                                pattern=bytes.fromhex('48894310' if mac else 'd060')
                                at=data.find(pattern,64,64+size);self.assertGreaterEqual(at,0);data[at]^=1
                        elif bad=='truncated':mach.text['length']=size-1
                        else:
                            key='count_d' if mac else 'count_7c';at,n=fields[key]
                            data[64+at:64+at+n]=(-1 if mac else 0).to_bytes(n,'little',signed=mac)
                        mach.data=bytes(data)
                        self.assertEqual(extract_image_bindings(mach),{})

    def test_conflicting_record_alternatives_are_retained(self):
        for mac in [True,False]:
            mach,fields,size=fixture(mac);data=bytearray(mach.data);second=bytearray(data[64:64+size])
            if mac:
                at,n=fields['region'];second[at:at+n]=(8).to_bytes(n,'little')
            else:
                at,n=fields['value_26'];second[at:at+n]=arm_wide(8,2,True)
            data[320:320+size]=second;mach.data=bytes(data)
            rows=extract_image_bindings(mach)['records']
            self.assertEqual([(r['id'],r['region']) for r in rows],[(42,7),(42,8)])



def android_images(range_values=None, with_range=True, extra=()):
    """BuildResourceList in the Android shape: three type-3 records (two alternatives for
    id 30), one font record, `extra` records as (id, kind, texture, second, sealed), and
    the range loop. Returns (library, record allocation addresses, range start)."""
    from android_fixture import TEXT, Thumb, library, stub
    from thumb_shapes import assemble
    from gof2_content.android_library import AndroidLibrary
    from gof2_content.image_regions import ANDROID_RANGE
    add = '_ZN11AbyssEngine11PaintCanvas11AddResourceEPNS_8ResourceE'
    rows = [(30, 3, 600, 4, True), (30, 3, 601, 9, True), (31, 3, 601, 2, True), (40, 1, 602, 0, True), *extra]
    asm, allocations = Thumb(TEXT + 0x100).push(), []
    for identifier, kind, texture, second, sealed in rows:
        asm.movs(0, 16)
        allocations.append(asm.here())
        asm.call(stub('_Znwj')).mov(5, 0).movs(0, 4).call(stub('_Znwj')).mov(6, 0)
        asm.movw(1, texture).strh(1, 6, 0).movs(1, second).strh(1, 6, 2).movw(0, identifier).strh(0, 5, 0).movs(0, kind)
        (asm.minus_one(1) if sealed else asm.movs(1, 0)).adds(2, 5, 4).stm(2, 0, 1, 6)
    start = asm.here()
    if with_range:
        asm.code += assemble(ANDROID_RANGE, start, {'first_id': 5000, 'first_texture_id': 900, 'count': 12, **(range_values or {})},
                             calls={'_Znwj': stub('_Znwj'), add: TEXT})[0]
    code = asm.pop().finish()
    functions = [(add, b'\x70\x47\x00\xbf', TEXT), ('_Z17BuildResourceListPN11AbyssEngine6EngineE', code, TEXT + 0x100)]
    return AndroidLibrary(library(functions, {})), allocations, start


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'optional static-reader dependency')
class AndroidImageRegions(unittest.TestCase):
    def test_records_alternatives_and_range(self):
        lib, allocations, start = android_images()
        result = extract_image_bindings(lib)
        # Type-3 records only, alternatives kept; provenance is each allocation call.
        self.assertEqual(result['records'], [
            {'id': 30, 'texture_id': 600, 'region': 4, 'source_offset': allocations[0], 'source_bytes': 4},
            {'id': 30, 'texture_id': 601, 'region': 9, 'source_offset': allocations[1], 'source_bytes': 4},
            {'id': 31, 'texture_id': 601, 'region': 2, 'source_offset': allocations[2], 'source_bytes': 4}])
        self.assertEqual(result['ranges'], [{'first_id': 5000, 'first_texture_id': 900, 'count': 12, 'region': 0,
                                             'source_offset': start, 'source_bytes': 82}])
        # A record without constant fields is left out, not the declarations around it.
        self.assertEqual(extract_image_bindings(android_images(extra=[(32, 3, 603, 1, False)])[0])['records'], result['records'])

    def test_unsupported_ranges(self):
        for name, options in {'no loop': dict(with_range=False), 'empty': dict(range_values={'count': 0}),
                              'id overflow': dict(range_values={'first_id': 65530}),
                              'texture overflow': dict(range_values={'first_texture_id': 65530})}.items():
            self.assertEqual(extract_image_bindings(android_images(**options)[0])['ranges'], [], name)

if __name__=='__main__': unittest.main()
