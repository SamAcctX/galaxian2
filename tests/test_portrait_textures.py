"""Synthetic texture records with relocated references and non-source names/IDs."""
MAC_RECORD = """
bf18000000e8
{call_6:4}
4989c6bf10000000e8
{call_13:4}
4989c7488d7da0488d35
{ref_21:4}
31d2e8
{call_28:4}
41b401488d7db0488d75a0488d55d0e8
{call_3c:4}
41b401488d7d90488d35
{ref_4a:4}
31d2e8
{call_51:4}
41b401488d7dc0488d75b0488d5590e8
{call_65:4}
41b401488d75c04c89ff0f57c0e8
{call_77:4}
6641c706
{id_7f:2}
41c746040200000041c74608ffffffff4d897e104530e44889df4c89f6e8
{call_9f:4}
4530e4488d7dc0e8
{call_ab:4}
4530e4488d7d90e8
{call_b7:4}
4530e4488d7db0e8
{call_c3:4}
488d7da0e8
{call_cc:4}
"""
MAC_CALLS = [('6', 0, 'call'), ('13', 0, 'call'), ('28', 1, 'call'), ('3c', 2, 'call'), ('51', 1, 'call'), ('65', 2, 'call'), ('77', 3, 'call'), ('9f', 4, 'call'), ('ab', 5, 'call'), ('b7', 5, 'call'), ('c3', 5, 'call'), ('cc', 5, 'call')]
MAC_REFS = [('21', 0), ('4a', 1)]
ARM_RECORD = """
0df5005e0120cef860011020
{call_c:4}
0df11c0e0ef598510df5005e08600220cef860010820
{call_26:4}
0df11c0e
{wide_2e:4}
0ef598520df5005e
{wide_3a:4}
506003207944cef860010df11c0e00220ef59750
{call_52:4}
0df5805e01208ef8dc070df5005e0420cef860010df1040e0ef598500df11c0e0ef597510df1140e0ef59852
{call_82:4}
0df5805e
{wide_8a:4}
0120
{wide_90:4}
8ef8e0070df5005e05207944cef860010df1140e00220ef59750
{call_ae:4}
0df5805e01208ef8e4070df5005e0620cef860010df10c0e0ef598500df1040e0ef598510df1140e0ef59752
{call_de:4}
0df11c0e01210ef598500df5805e40688ef8e8170df5005e0721cef860110df10c0e00220ef59851
{call_10a:4}
0df11c0e
{wide_112:4}
0ef598500df5805e03461968186802800222186842604ff0ff321868826018685a68c26000208ef8e8070df5005e0820cef860010498
{call_14c:4}
0df5805e00208ef8e4070df5005e0920cef860010df10c0e0ef59850
{call_16c:4}
0df5805e00208ef8e0070df5005e0a20cef860010df1140e0ef59750
{call_18c:4}
0df5805e00208ef8dc070df5005e0b20cef860010df1040e0ef59850
{call_1ac:4}
0df5005e0c20cef860010df11c0e0ef59750
{call_1c2:4}
"""
ARM_CALLS = [('c', 0, 'blx'), ('26', 0, 'blx'), ('52', 1, 'bl'), ('82', 2, 'bl'), ('ae', 1, 'bl'), ('de', 2, 'bl'), ('10a', 3, 'bl'), ('14c', 4, 'bl'), ('16c', 5, 'bl'), ('18c', 5, 'bl'), ('1ac', 5, 'bl'), ('1c2', 5, 'bl')]
ARM_WIDE = [('2e', 'movw', 'r1'), ('3a', 'movt', 'r1'), ('8a', 'movw', 'r1'), ('90', 'movt', 'r1'), ('112', 'movw', 'r2')]

import importlib.util
import struct
from types import SimpleNamespace
import unittest
from gof2_content.portrait_textures import mac_record, arm_record, source_string, extract_portrait_textures
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def fixture(mac, relocation=0):
    code, fields = expand(MAC_RECORD if mac else ARM_RECORD)
    start = 0x10000 + relocation
    string_address = start + 2048
    strings = b'data/textures/custom_portrait\0.aei\0'
    extension_address = string_address + strings.index(b'.aei')
    def put(key, raw):
        at, size = fields[key]; assert len(raw) == size
        code[at:at+size] = raw
    for offset, group, mnemonic in (MAC_CALLS if mac else ARM_CALLS):
        key = 'call_' + offset; at = int(offset, 16)
        target = start + 4096 + group * 16
        if mac: raw = struct.pack('<i', target - start - at - 4)
        else:
            raw = bytearray(branch(start + at if mnemonic == 'bl' else ((start + at + 4) & ~3) - 4, target))
            if mnemonic == 'blx': raw[3] &= ~0x10
        put(key, raw)
    if mac:
        for offset, group in MAC_REFS:
            target = extension_address if group else string_address
            put('ref_'+offset, struct.pack('<i', target-start-int(offset,16)-4))
        for key in fields:
            if key.startswith('id_'): put(key, struct.pack('<H', 713))
    else:
        # The two source string declarations have different ADD-PC sites.
        string_refs = {'2e': string_address, '3a': string_address, '8a': extension_address, '90': extension_address}
        pc_refs = {'2e': 0x46, '3a': 0x46, '8a': 0xa2, '90': 0xa2}
        for offset, mnemonic, register in ARM_WIDE:
            if register == 'r2': value = 713
            else:
                delta = string_refs[offset] - start - pc_refs[offset]
                value = delta >> 16 if mnemonic == 'movt' else delta & 65535
            put('wide_' + offset, arm_wide(value, int(register[1:]), mnemonic == 'movt'))
    payload = bytes(64) + bytes(code).ljust(2048, b'\0') + strings
    text = {'name': b'__text', 'segment': b'__TEXT', 'address': start, 'offset': 64, 'length': 2048}
    cstring = {'name': b'__cstring', 'segment': b'__TEXT', 'address': string_address, 'offset': 2112, 'length': len(strings)}
    return SimpleNamespace(data=payload, text=text, cstring=cstring, sections=[text,cstring], slice_offset=4096,
                           architecture='x86_64' if mac else 'armv7'), start, fields, len(code)


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'optional static-reader dependency')
class PortraitTextures(unittest.TestCase):
    def read(self, mac, mach, start):
        import capstone
        decoder = capstone.Cs(capstone.CS_ARCH_X86 if mac else capstone.CS_ARCH_ARM,
                              capstone.CS_MODE_64 if mac else capstone.CS_MODE_THUMB)
        decoder.detail = True
        return mac_record(mach,start,decoder,-48,{}) if mac else arm_record(mach,start,decoder,0,{})

    def test_independent_names_ids_and_relocation(self):
        for mac in [True,False]:
            for relocation in [0,0x12000]:
                mach,start,fields,size = fixture(mac,relocation)
                row,end = self.read(mac,mach,start)
                self.assertEqual((row['id'],row['stem']), (713,'data/textures/custom_portrait'))
                self.assertEqual(row['source_offset'],4160)
                self.assertEqual(row['stem_offset'],6208)
                self.assertEqual(end-start,size)

    def test_broken_payload_string_and_allocator_links(self):
        for mac in [True,False]:
            for kind in ['allocator','string','extension','record_type','pointer','truncated']:
                mach,start,fields,size = fixture(mac)
                data=bytearray(mach.data)
                if kind == 'allocator':
                    key='call_'+(MAC_CALLS if mac else ARM_CALLS)[1][0];at,n=fields[key];data[64+at]^=1
                elif kind == 'string':
                    key=('ref_'+MAC_REFS[0][0]) if mac else 'wide_2e';at,n=fields[key];data[64+at]^=1
                elif kind == 'extension': data[2112+len(b'data/textures/custom_portrait\0')]=ord('x')
                elif kind == 'record_type':
                    pattern=bytes.fromhex('41c7460402000000' if mac else '022218684260')
                    at=data.find(pattern);self.assertGreaterEqual(at,0)
                    data[at+(4 if mac else 0)]=4
                elif kind == 'pointer':
                    pattern=bytes.fromhex('488d55d0' if mac else '0ef59851')
                    at=data.find(pattern);self.assertGreaterEqual(at,0);data[at+len(pattern)-1]^=1
                elif kind == 'truncated':
                    mach.text['length']=size-1;data=data[:64+size-1]
                mach.data=bytes(data)
                with self.assertRaises((ValueError,StopIteration,IndexError),msg=(mac,kind)): self.read(mac,mach,start)

    def test_no_prefix_and_string_bounds(self):
        for mac in [True,False]:
            mach,start,fields,size = fixture(mac)
            self.assertEqual(extract_portrait_textures(mach),{})
            for address in [mach.cstring['address']-1,mach.cstring['address']+1,mach.cstring['address']+mach.cstring['length']]:
                with self.assertRaises(ValueError):source_string(mach,address)


PORTRAITS = '_Z13loadPortraitsPN11AbyssEngine6EngineE'
STRING, CONCAT, TEXTURE, ADD, FREE = ('_ZN11AbyssEngine6StringC1EPKcb', '_ZN11AbyssEngineplERKNS_6StringES2_',
                                      '_ZN11AbyssEngine15ResourceTextureC2ERKNS_6StringEf',
                                      '_ZN11AbyssEngine11PaintCanvas11AddResourceEPNS_8ResourceE', '_ZN11AbyssEngine6StringD1Ev')
SUFFIXES = {'baseline': '', 'expanded': '_x', 'medium': '_m', 'large': '_l'}


def android_portraits(count=3, flags=None, extension='.aei', stem_offset=0, omit=()):
    """loadFont and loadPortraits in the Android shapes: `count` portraits 700+i named
    data/t/pN, the second interrupted by a skipped literal pool. Returns (library, extents)."""
    from android_fixture import TEXT, library, stub
    from thumb_shapes import assemble
    from test_font_selection import CREATE, FONTS, ROLES, SPACING, SPACING_HOLES
    from gof2_content.android_library import AndroidLibrary
    from gof2_content.font_selection import ANDROID
    from gof2_content.portrait_textures import ANDROID_RECORD, ANDROID_SELECTION
    names = [CREATE, SPACING, STRING, CONCAT, TEXTURE, ADD, FREE]
    calls = {name: TEXT + 0x10 * i for i, name in enumerate(names)}
    functions = [(name, b'\x70\x47\x00\xbf', address) for name, address in calls.items()]
    calls['_Znwj'] = stub('_Znwj')
    font, _, _ = assemble(ANDROID, TEXT + 0x100, {**FONTS, **SPACING_HOLES, 'tail': TEXT + 0x80}, ROLES, calls,
                          {'cases': ['arabic', 'simplified', 'traditional', 'other', 'other', 'korean']})
    functions.append(('_ZN7Globals8loadFontEi', font, TEXT + 0x100))
    strings, refs, at = {}, {**ROLES, 'guard': 0x9100, 'iPadLarge': 0x9104, 'iPad': 0x9108, **(flags or {})}, 0x8000
    def string(value):
        nonlocal at
        strings[at] = value
        at += len(value) + 1
        return at - len(value) - 1
    for key, value in SUFFIXES.items():
        refs[key] = string(value)
    refs['extension'] = string(extension)
    text, values = ANDROID_SELECTION, {}
    for index in range(count):
        record = ANDROID_RECORD.replace('{&stem}', '{&stem%d}' % index).replace('{&extension}', '{&extension%d}' % index).replace('{id}', '{id%d}' % index)
        if index == 1:  # a literal pool skipped mid-record
            record = record.replace('add r0, sp, #0x14\n', 'b @skip\n...\nskip: add r0, sp, #0x14\n', 1)
        text += record
        refs['stem%d' % index], refs['extension%d' % index] = string('data/t/p%d' % index) + stem_offset, refs['extension']
        values['id%d' % index] = 700 + index
    code, labels, _ = assemble(text + 'pop.w {r4, r5, r6, r7, r8, pc}', TEXT + 0x600, values, refs, calls)
    functions.append((PORTRAITS, code, TEXT + 0x600))
    functions = [row for row in functions if row[0] not in omit]
    return AndroidLibrary(library(functions, strings)), {'suffix': labels['suffix'], 'skip': labels['skip']}


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'optional static-reader dependency')
class AndroidPortraitTextures(unittest.TestCase):
    def read(self, count=3, **options):
        from unittest.mock import patch
        from gof2_content import portrait_textures
        with patch.object(portrait_textures, 'PORTRAITS', count):
            return extract_portrait_textures(android_portraits(**options)[0])

    def test_named_function_gives_suffixes_ids_and_stems(self):
        from android_fixture import TEXT
        lib, extents = android_portraits()
        from unittest.mock import patch
        from gof2_content import portrait_textures
        with patch.object(portrait_textures, 'PORTRAITS', 3):
            result = extract_portrait_textures(lib)
        self.assertEqual({key: row['value'] for key, row in result['suffixes'].items()}, SUFFIXES)
        self.assertEqual([(row['id'], row['stem'], row['variants']['medium']) for row in result['rows']],
                         [(700 + i, 'data/t/p%d' % i, 'resources/data/t/p%d_m.aei' % i) for i in range(3)])
        # The selection ends with the suffix String; records (122 bytes with narrow
        # literal loads) follow each other, the second spanning its skip and 4-byte pool.
        start = extents['suffix'] + 8
        self.assertEqual(result['provenance']['selection'], {'offset': TEXT + 0x600, 'bytes': start - TEXT - 0x600})
        self.assertEqual([(row['source_offset'], row['source_bytes']) for row in result['rows']],
                         [(start, 122), (start + 122, 128), (start + 250, 122)])
        self.assertEqual(result['rows'][0]['stem_offset'], 0x8000 + sum(len(v) + 1 for v in SUFFIXES.values()) + 5)

    def test_each_broken_declaration_is_unsupported(self):
        from test_font_selection import ROLES
        cases = {'medium flag': dict(flags={'iPadHD': 0x9200}), 'wide flag': dict(flags={'n9': 0x9200}),
                 'shared flag': dict(flags={'iPad': 0x9104}), 'extension': dict(extension='.aem'),
                 'stem inside a string': dict(stem_offset=1), 'no portraits function': dict(omit=(PORTRAITS,))}
        for name, options in cases.items():
            self.assertEqual(self.read(**options), {}, name)
        self.assertEqual(self.read(count=4), {}, 'fewer records')
        self.assertTrue(self.read(count=3))

if __name__ == '__main__': unittest.main()
