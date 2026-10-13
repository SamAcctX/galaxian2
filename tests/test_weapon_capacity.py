"""Relocated ordinary-capacity declarations with changed pool sizes and item IDs."""
import struct
import unittest
from types import SimpleNamespace
from gof2_content import weapon_capacity as reader
from test_font_selection import expand
from test_ship_models import branch


def fixture(mac,shift=0):
    base=0x100000+shift;offset=256;slice_offset=4096
    data=bytearray(9000);factory=1000;table=2900 if mac else factory+116
    begin=factory+(345 if mac else 166);single=factory+1272
    call=begin+253 if mac else single+188
    item=4000;ctor=3800
    declarations={}
    specs={'range':reader.MAC_RANGE if mac else reader.ARM_RANGE,'constructor_call':reader.MAC_CALL if mac else reader.ARM_CALL}
    if not mac:specs['single']=reader.ARM_SINGLE
    for key,spec in specs.items():
        at={'range':begin,'constructor_call':call,'single':single}[key];body,fields=expand(spec)
        for field,(p,n) in fields.items():
            if field=='first':raw=(-19).to_bytes(n,'little',signed=True) if mac else bytes.fromhex('a5f11301')
            elif field=='count':raw=bytes([3]) if mac else bytes.fromhex('0329')
            elif field=='single':raw=(128).to_bytes(n,'little') if mac else bytes.fromhex('8029')
            elif field=='slots':raw=(37).to_bytes(n,'little') if mac else bytes.fromhex('4ff0250a')
            elif field=='single_branch':raw=bytes.fromhex('80f02282')
            elif field=='join':raw=bytes.fromhex('24e2')
            else:
                dest=ctor if field=='ctor' else item-(17 if mac else 78)
                raw=struct.pack('<i',dest-at-p-4) if mac else branch(base+at+p,base+dest)
            body[p:p+n]=raw
        data[offset+at:offset+at+len(body)]=body;declarations[key]=(at,body,fields)
    data[offset+factory:offset+factory+4]=bytes.fromhex('554889e5' if mac else 'f0b503af')
    selector=factory+(57 if mac else 112)
    body=bytes.fromhex('4489f8488d0d')+struct.pack('<i',table-selector-10)+bytes.fromhex('486304814801c84531edffe0') if mac else bytes.fromhex('dfe813f0')
    data[offset+selector:offset+selector+len(body)]=body
    target=begin-(31 if mac else 26)
    table_bytes=struct.pack('<i',target-table) if mac else struct.pack('<H',(target-table)//2)
    data[offset+table:offset+table+len(table_bytes)]=table_bytes
    section={'name':b'__text','segment':b'__TEXT','address':base,'offset':offset,'length':len(data)-offset}
    mach=SimpleNamespace(data=bytes(data),text=section,sections=[section],slice_offset=slice_offset,architecture='x86_64' if mac else 'armv7')
    weapon={'launch_modes':{'alternate_item_ids':[19,20,21,128],'provenance':{'classification':{'offset':slice_offset+offset+item,'bytes':65 if mac else 56}}},'provenance':{'tail':{'offset':slice_offset+offset+3200,'bytes':120 if mac else 100}}}
    return mach,weapon,base+factory,declarations,selector,table


class WeaponCapacity(unittest.TestCase):
    def test_relocated_capacity(self):
        for mac in [True,False]:
            for shift in [0,0x500000]:
                m,w,f,_,_,_=fixture(mac,shift)
                result=reader.extract_weapon_capacity(m,w,f)
                self.assertEqual(result.get('slots'),37,(mac,shift,result))

    def test_disconnected_or_invalid(self):
        for mac in [True,False]:
            for corruption in ['range','constructor_call','selector','table','factory','duplicate','classification','zero_capacity','missing_modes','item_call']:
                m,w,f,contexts,selector,table=fixture(mac)
                data=bytearray(m.data)
                if corruption in contexts:data[256+contexts[corruption][0]]^=1
                elif corruption=='selector':data[256+selector]^=1
                elif corruption=='table':data[256+table]^=2
                elif corruption=='factory':f+=4
                elif corruption=='duplicate':
                    body=contexts['range'][1];data[256+5000:256+5000+len(body)]=body
                elif corruption=='classification':w['launch_modes']['alternate_item_ids'][0]=18
                elif corruption=='zero_capacity':
                    at,body,fields=contexts['range' if mac else 'single'];p,n=fields['slots'];data[256+at+p:256+at+p+n]=bytes(n) if mac else bytes.fromhex('4ff0000a')
                elif corruption=='missing_modes':w['launch_modes']={}
                elif corruption=='item_call':
                    at,body,fields=contexts['constructor_call'];data[256+at+fields['item'][0]]^=4
                m.data=bytes(data)
                self.assertFalse(reader.extract_weapon_capacity(m,w,f),(mac,corruption))


@unittest.skipUnless(__import__('importlib').util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidWeaponCapacity(unittest.TestCase):
    def test_kind_zero_constructor_gives_slots(self):
        from test_weapon_parameters import android_guns, android_weapon_chain
        lib, at, weapon = android_guns()
        weapon = android_weapon_chain(lib, weapon)
        result = weapon['projectile_capacity']
        self.assertEqual(result['slots'], 16)
        p = result['provenance']
        # push, add r7, sub sp; the dispatch; its five cases; the range; other (4 bytes) after it.
        self.assertEqual({k: (p[k]['offset'] - at['factory'], p[k]['bytes']) for k in ('factory_entry', 'type_selector', 'kind_zero', 'range', 'constructor_call')},
                         {'factory_entry': (8, 6), 'type_selector': (14, 14), 'kind_zero': (28, 2), 'range': (38, 66), 'constructor_call': (108, 54)})
        self.assertEqual(p['factory_call'], weapon['provenance']['tail'])
        self.assertEqual(p['item_classification'], weapon['launch_modes']['provenance']['classification'])

    def test_each_broken_rule_is_unsupported(self):
        from test_weapon_parameters import android_guns, android_weapon_chain
        cases = {'index rewritten': dict(edits=[('factory', 'sub sp, #0x38', 'sub sp, #0x38\nmovs r1, #0')]),
                 'kind rewritten': dict(edits=[('factory', 'cmp r6, #4', 'movs r6, #0\ncmp r6, #4')]),
                 'kind from elsewhere': dict(edits=[('factory', 'mov r6, r3', 'mov r6, r2')]),
                 'kind zero elsewhere': dict(edits=[('factory', '.cases zero, other', '.cases other, zero')]),
                 'other alternate count': dict(edits=[('factory', 'cmp r0, #2', 'cmp r0, #3')]),
                 'constructor elsewhere': dict(edits=[('factory', 'bne.w #ordinary', 'bne.w #other')]),
                 'no slots': dict(edits=[('factory', 'movs r4, #0x10', 'movs r4, #0')]),
                 'no entry': dict(edits=[('factory', 'strd r2, r1, [sp, #0x30]', 'strd r2, r1, [sp, #0x28]')]),
                 'no dispatch': dict(edits=[('factory', 'mov.w fp, #0\ntbh', 'mov.w fp, #1\ntbh')])}
        for name, options in cases.items():
            with self.subTest(name):
                lib, _, weapon = android_guns(**options)
                self.assertEqual(android_weapon_chain(lib, weapon)['projectile_capacity'], {})
        lib, _, weapon = android_guns()
        self.assertEqual(reader.extract_weapon_capacity(lib, {**weapon, 'launch_modes': {}}, 0), {})
