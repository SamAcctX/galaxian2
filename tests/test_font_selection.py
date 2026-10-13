"""Synthetic font setup layouts with relocated references and changed font IDs."""
import importlib.util
import struct
from types import SimpleNamespace
import unittest
from gof2_content.font_selection import (MAC, MAC_ALTERNATE, ARM, MAC_REFS, MAC_CALLS, ARM_FIELDS,
                                         ARM_REFS, ARM_CALLS, extract_font_selection)
from gof2_content.font_bindings import MAC_RECORD, font_records
from test_materials import arm_wide
from test_ship_models import branch


def expand(spec):
    code = bytearray(); fields = {}
    for token in spec.split():
        if token.startswith('{'):
            name, size = token[1:-1].split(':'); size = int(size)
            fields[name] = (len(code), size); code.extend(bytes(size))
        else: code.extend(bytes.fromhex(token))
    return code, fields


def selection_fixture(mac, relocation=0, alternate=False):
    body, fields = expand((MAC_ALTERNATE if alternate else MAC) if mac else ARM)
    address = 0x100000 + relocation + 128
    def put(key, data):
        at, size = fields[key]
        assert len(data) == size
        body[at:at+size] = data
    font_keys = ['2e','90','e2','f7','111','14e','1d2','203'] if mac else ['1a','f2','110','12e','6e','94','1ce','1f8']
    if mac:
        for key, (at, size) in fields.items():
            if key.startswith('value_'): put(key, (1).to_bytes(size, 'little'))
        for index, key in enumerate(font_keys): put('value_'+key, (100+index).to_bytes(4, 'little'))
        for index, group in enumerate(MAC_REFS + MAC_CALLS):
            target = address + len(body) - 24 if group[0][0] == 'ref_10' else address + 1800 + index * 8
            for key, end in group: put(key, struct.pack('<i', target-address-end))
    else:
        values = {}
        for key, (mnemonic, register) in ARM_FIELDS.items(): values[key] = 1 if mnemonic in ['mvn','mvnne'] else 65534 if key in ['value_4e','value_15a'] else 0
        for index, key in enumerate(font_keys): values['value_'+key] = 100+index
        for index, group in enumerate(ARM_REFS):
            target = address + 1800 + index * 8
            for lo, hi, pc in group:
                delta = target-address-pc
                values[lo], values[hi] = delta & 65535, delta >> 16
        for key, (mnemonic, register) in ARM_FIELDS.items():
            reg = int(register[1:]); value = values[key]
            put(key, struct.pack('<HH',0xf06f,(reg<<8)|value) if mnemonic.startswith('mvn') else arm_wide(value,reg,top=mnemonic=='movt'))
        for index, group in enumerate(ARM_CALLS):
            for key, at, mnemonic in group:
                data = bytearray(branch(address+at,address+3000+index*8))
                if mnemonic=='b.w': data[3] &= ~0x40
                put(key,data)
    code = bytes(128)+body+bytes(4096-128-len(body))
    text = {'address':address-128,'offset':64,'length':len(code),'name':b'__text','segment':b'__TEXT'}
    return SimpleNamespace(data=bytes(64)+code,text=text,sections=[text],slice_offset=4096,architecture='x86_64' if mac else 'armv7'), fields


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'optional static-reader dependency')
class FontSelection(unittest.TestCase):
    def test_alternate_mac_alignment_retains_dispatch_links(self):
        for relocation in (0, 0x20000):
            mach, fields = selection_fixture(True, relocation, alternate=True)
            result = extract_font_selection(mach)
            self.assertEqual(result['source_bytes'], 576)
            self.assertEqual(result['default_font_id'], 105)
            data = bytearray(mach.data)
            data[192 + fields['ref_10'][0]] += 2
            mach.data = bytes(data)
            self.assertEqual(extract_font_selection(mach), {})

    def test_relocated_changed_parameters(self):
        for mac in [False,True]:
            for relocation in [0,0x20000]:
                mach, fields = selection_fixture(mac,relocation)
                result = extract_font_selection(mach)
                self.assertEqual(result['default_font_id'],105)
                self.assertEqual(result['secondary_font_id'],106)
                self.assertEqual(result['overrides'][1],{'language_id':10,'font_id':101})
                self.assertEqual(result['source_offset'],4288)
                self.assertEqual(result['spacing']['default'],[1]*4 if mac else [-2]*4)

    def test_rejects_layout_and_reference_corruption(self):
        for mac in [False,True]:
            for mutation in ['shape','reference','call','duplicate','truncated','font_id']:
                mach, fields = selection_fixture(mac)
                data = bytearray(mach.data)
                if mutation=='shape': data[192] ^= 1
                elif mutation=='reference':
                    key = 'ref_27' if mac else 'value_28'; data[192+fields[key][0]] ^= 1
                elif mutation=='call':
                    key = MAC_CALLS[0][0][0] if mac else ARM_CALLS[0][0][0]; data[192+fields[key][0]] ^= 1
                elif mutation=='duplicate':
                    n=578 if mac else 544;data[1024:1024+n]=data[192:192+n]
                elif mutation=='truncated': data=data[:600]
                elif mutation=='font_id':
                    key='value_14e' if mac else 'value_94';at,n=fields[key];data[192+at:192+at+n]=struct.pack('<I',65535) if mac else arm_wide(65535,1)
                mach.data=bytes(data)
                self.assertEqual(extract_font_selection(mach),{},(mac,mutation))
        mach, fields = selection_fixture(True)
        data=bytearray(mach.data);data[192+fields['ref_10'][0]] ^= 1;mach.data=bytes(data)
        self.assertEqual(extract_font_selection(mach),{},'Unlinked language switch table accepted')


class FontRecords(unittest.TestCase):
    def test_record_fields_and_allocation_link(self):
        code,fields=expand(MAC_RECORD)
        for key,value in [('id',401),('texture',777),('group',3)]:
            at,n=fields[key];code[at:at+n]=value.to_bytes(n,'little')
        for key in ['record_allocate','payload_allocate']:
            at,n=fields[key];code[at:at+n]=struct.pack('<i',512-at-4)
        text={'address':0x10000,'offset':64,'length':len(code),'name':b'__text','segment':b'__TEXT'}
        mach=SimpleNamespace(data=bytes(64)+code,text=text,sections=[text],slice_offset=4096,architecture='x86_64')
        result=font_records(mach)
        self.assertEqual([(r['id'],r['texture_id'],r['font_group']) for r in result],[(401,777,3)])
        code[fields['payload_allocate'][0]] ^= 1;mach.data=bytes(64)+code
        self.assertEqual(font_records(mach),[])



@unittest.skipUnless(importlib.util.find_spec('capstone'), 'optional static-reader dependency')
class FontAtlasBranches(unittest.TestCase):
    def fixture(self, mac):
        from gof2_content.font_bindings import MAC_GUARDS, ARM_GUARDS
        specs = MAC_GUARDS if mac else ARM_GUARDS
        base=0x10000; data=bytearray(8192); flags={'medium':base+9000,'large':base+9001}
        for index,(kind,start,other) in enumerate([('medium',128,1024 if mac else 1022),('large',1024,2048)]):
            body,fields=expand(specs[kind])
            if mac:
                at,n=fields['flag'];body[at:at+n]=struct.pack('<i',flags[kind]-base-start-7)
                at,n=fields['other'];body[at:at+n]=struct.pack('<i',other-start-len(body))
            else:
                ptr=base+4096+index*4;delta=ptr-base-start-12
                for key,value,top in [('low',delta&65535,False),('high',delta>>16,True)]:
                    at,n=fields[key];body[at:at+n]=arm_wide(value,0,top)
                struct.pack_into('<I',data,4096+index*4,flags[kind])
                # BEQ.W has S/J1/J2 all zero for this short forward branch.
                delta=other-(start+len(body))
                at,n=fields['other'];body[at:at+n]=struct.pack('<HH',0xf000 | ((delta>>12)&0x3f),0x8000|((delta>>1)&0x7ff))
                if kind=='large':
                    at,n=fields['allocate'];call=bytearray(branch(base+start+at,base+3500));call[3] &= ~0x10;body[at:at+n]=call
                    at,n=fields['record'];body[at:at+n]=struct.pack('<HH',0xf8ca,0x40)
            data[start:start+len(body)]=body
        text={'address':base,'offset':64,'length':4096,'name':b'__text','segment':b'__TEXT'}
        section={'address':base+4096,'offset':4160,'length':256,'name':b'__data','segment':b'__DATA'}
        mach=SimpleNamespace(data=bytes(64)+data,text=text,sections=[text,section],slice_offset=4096,architecture='x86_64' if mac else 'armv7')
        rows=[{'id':900,'kind':'texture','registration_type':2,'resource':'resources/data/'+name+'.aei','source_offset':4160+offset} for name,offset in [('unrelated_alpha',256),('unrelated_beta',1200),('unrelated_gamma',2300)]]
        return mach,rows,flags

    def test_choices_follow_source_branches(self):
        from gof2_content.font_bindings import font_texture_choices
        for mac in [False,True]:
            mach,rows,flags=self.fixture(mac)
            result=font_texture_choices(mach,[{'texture_id':900}],rows,flags)
            self.assertEqual(result['rows'][0]['variants'],{'medium':rows[0]['resource'],'large':rows[1]['resource'],'baseline':rows[2]['resource']})
            flags['medium']+=100
            self.assertEqual(font_texture_choices(mach,[{'texture_id':900}],rows,flags),{})

    def test_missing_or_conflicting_choices_rejected(self):
        from gof2_content.font_bindings import font_texture_choices
        for mac in [False,True]:
            mach,rows,flags=self.fixture(mac)
            self.assertEqual(font_texture_choices(mach,[{'texture_id':900}],rows[:2],flags),{})
            rows[1]['source_offset']=rows[0]['source_offset']
            self.assertEqual(font_texture_choices(mach,[{'texture_id':900}],rows,flags),{})

@unittest.skipUnless(importlib.util.find_spec('capstone'), 'optional static-reader dependency')
class FontLanguageDispatch(unittest.TestCase):
    def test_language_file_order_comes_from_dispatch(self):
        from gof2_content.font_bindings import MAC_LANGUAGE, MAC_LANGUAGE_ALTERNATE
        for spec in (MAC_LANGUAGE, MAC_LANGUAGE_ALTERNATE):
            self.check_language_dispatch(spec)

    def check_language_dispatch(self, spec):
        from gof2_content.font_bindings import language_files
        body,fields=expand(spec);data=bytearray(4096);start=128;table=512
        at,n=fields['table'];body[at:at+n]=struct.pack('<i',table-start-at-4)
        data[start:start+len(body)]=body
        for i in range(16):
            case=1024+i*32;string=2048+(15-i)*16
            struct.pack_into('<i',data,table+4*i,case-table)
            # Variable file order deliberately differs from cstring order.
            name=('a'+chr(97+15-i)+'.lang\0').encode();data[string:string+len(name)]=name
            block=bytes.fromhex('488d7dc031d2488d35')+struct.pack('<i',string-case-13)+b'\xe8'+struct.pack('<i',3000-case-18)
            data[case:case+len(block)]=block
        text={'address':0x10000,'offset':64,'length':2048,'name':b'__text','segment':b'__TEXT'}
        strings={'address':0x10800,'offset':2112,'length':256,'name':b'__cstring','segment':b'__TEXT'}
        mach=SimpleNamespace(data=bytes(64)+data,text=text,sections=[text,strings],slice_offset=4096,architecture='x86_64')
        result=language_files(mach)
        self.assertEqual([r['file'] for r in result['rows']],['a'+chr(97+15-i)+'.lang' for i in range(16)])
        data[table:table+4]=struct.pack('<i',2047-table);mach.data=bytes(64)+data
        self.assertEqual(language_files(mach),{})


LOAD_FONT, SET_LANGUAGE = '_ZN7Globals8loadFontEi', '_ZN8GameText11setLanguageEsi'
CREATE, SPACING, STRING = ('_ZN11AbyssEngine11PaintCanvas10FontCreateEtRjb', '_ZN11AbyssEngine11PaintCanvas14FontSetSpacingEjs',
                           '_ZN11AbyssEngine6StringC1EPKcb')
ROLES = dict(zip(['canvas', 'font', 'iPadHD', 'retinaDisplay', 'n9', 'fontAlien', 'fontLangSelect'], range(0x9000, 0x901c, 4)))
# Synthetic fonts 500-507; spacing from -10: default [-3, -5, -5, -8], CJK [-4, -7, -4, -10], Japanese [-6, -9, -6, -13].
FONTS = {'standard': 500, 'secondary': 501, 'language': 502, 'arabic': 503, 'simplified': 504, 'traditional': 505, 'korean': 506, 'japanese': 507}
SPACING_HOLES = {'base': 0xfff6, 'standard_baseline': 7, 'standard_medium': 5, 'standard_large': 2, 'japanese_baseline': 4,
                 'japanese_medium': 1, 'japanese_large': 3, **{f'{n}_{m}': d for n in ('arabic', 'simplified', 'traditional', 'korean')
                                                                for m, d in (('baseline', 6), ('medium', 3))}}
# Font id, texture, group; two atlases.
RECORDS = [(500 + i, 40 if i < 2 else 41, 1 if i == 1 else 0) for i in range(8)]
FILES = ['a%s.lang' % chr(97 + i) for i in range(16)]
FILES[10] = FILES[11] = FILES[0]


def android_fonts(selection=None, cases=None, roles=None, records=RECORDS, files=FILES, wide=(1, 3, 5), flags=None,
                  guards=('medium', 'large'), atlases=None, other=0, omit=(), unsealed=()):
    """loadFont, setLanguage and BuildResourceList in the Android shapes, with synthetic
    values, between stub callees; the last font record follows the atlases. `unsealed`
    font ids store 0 for the record's -1, `other` moves the medium guard's target.
    Returns (library, {region or 'records': address(es)})."""
    from android_fixture import TEXT, Thumb, library, registration, stub
    from thumb_shapes import assemble
    from gof2_content.android_library import AndroidLibrary
    from gof2_content.font_selection import ANDROID
    from gof2_content.font_bindings import BUILD, LANGUAGE_CASE, LANGUAGE_DISPATCH, TEXTURE_GUARDS
    calls = {CREATE: TEXT, SPACING: TEXT + 0x10, STRING: TEXT + 0x20, '_Znwj': stub('_Znwj')}
    functions = [(name, b'\x70\x47\x00\xbf', address) for name, address in calls.items() if name != '_Znwj']
    at = {LOAD_FONT: TEXT + 0x100, SET_LANGUAGE: TEXT + 0x600, BUILD: TEXT + 0x900}
    roles = roles or ROLES
    shape = ANDROID
    for role, address in roles.items():
        if role not in ROLES:  # a second slot for one load of a role
            shape = shape.replace('{&%s}' % role[:-1], '{&%s}' % role, 1)
    values = {**FONTS, **SPACING_HOLES, **(selection or {}), 'tail': TEXT + 0x80}
    tables = {'cases': cases or ['arabic', 'simplified', 'traditional', 'other', 'other', 'korean']}
    code, _, _ = assemble(shape, at[LOAD_FONT], values, roles, calls, tables)
    functions.append((LOAD_FONT, code, at[LOAD_FONT]))
    # setLanguage: dispatch, then one String-building case per language.
    strings = {0x8000 + 16 * i: name for i, name in enumerate(files)}
    refs = {'file%d' % i: 0x8000 + 16 * (files.index(name) if name == files[0] else i) for i, name in enumerate(files)}
    text = LANGUAGE_DISPATCH + ''.join('case%d: ' % i + LANGUAGE_CASE.strip().replace('{&file}', '{&file%d}' % i)
                                       .replace('{ldr|ldr.w} r1', 'ldr.w r1' if i in wide else 'ldr r1') + '\n' for i in range(16))
    code, _, _ = assemble(text, at[SET_LANGUAGE], {'default': at[SET_LANGUAGE]}, refs, calls, {'cases': ['case%d' % i for i in range(16)]})
    functions.append((SET_LANGUAGE, code, at[SET_LANGUAGE]))
    # BuildResourceList: font records, then the atlases behind the iPadHD and retinaDisplay guards.
    flags = flags or {'medium': roles['iPadHD'], 'large': roles['retinaDisplay']}
    atlases = atlases or {mode: [(texture, 'data/textures/t%d_%s.aei' % (texture, mode)) for texture in (40, 41)]
                          for mode in ('medium', 'large', 'baseline')}
    layout = {'pool': 0, 'medium': 0, 'large': 0, 'baseline': 0}
    regions = ('before', 'medium', 'large', 'baseline')
    for _ in range(2):
        asm, pool = Thumb(at[BUILD]).push(), bytearray()
        layout['records'] = []

        def font(identifier, texture, group):
            asm.movs(0, 16)
            layout['records'].append(asm.here())
            asm.call(stub('_Znwj')).mov(5, 0).movs(0, 4).call(stub('_Znwj')).mov(6, 0)
            asm.movw(1, texture).strh(1, 6, 0).movs(1, group).strh(1, 6, 2).movw(0, identifier).strh(0, 5, 0).movs(0, 1)
            (asm.movs(1, 0) if identifier in unsealed else asm.minus_one(1)).adds(2, 5, 4).stm(2, 0, 1, 6)
        for row in records[:-1]:
            font(*row)
        for mode in regions:
            layout[mode] = asm.here()
            if mode in guards:
                target = layout['large' if mode == 'medium' else 'baseline'] + (other if mode == 'medium' else 0)
                body, _, _ = assemble(TEXTURE_GUARDS[mode], asm.here(), {'other': target}, {'flag': flags[mode]}, calls,
                                      pool=(layout['pool'], pool))
                asm.code += body
            for index, (texture, path) in enumerate(atlases.get(mode, [])):
                address = 0x8400 + 0x40 * (4 * index + regions.index(mode))
                strings[address] = path
                registration(asm, texture, 2, address, ('texture', 0))
            if mode in ('medium', 'large'):
                asm.jump('end')
        font(*records[-1])
        asm.label('end').pop()
        code = asm.finish()
        layout['pool'] = at[BUILD] + len(code)
    functions.append((BUILD, code + bytes(pool), at[BUILD]))
    functions = [row for row in functions if row[0] not in omit]
    return AndroidLibrary(library(functions, strings)), layout


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'optional static-reader dependency')
class AndroidFonts(unittest.TestCase):
    def bindings(self, lib):
        from gof2_content.android_library import android_records
        from gof2_content.font_bindings import extract_font_bindings
        return extract_font_bindings(lib, android_records(lib, lambda *_: None))

    def test_named_functions_give_fonts_languages_spacing_and_atlases(self):
        from android_fixture import TEXT
        lib, layout = android_fonts()
        result = self.bindings(lib)
        self.assertEqual(result['selection'], {
            'default_font_id': 500, 'secondary_font_id': 501, 'language_font_id': 502,
            'overrides': [{'language_id': 9, 'font_id': 503}, {'language_id': 10, 'font_id': 504}, {'language_id': 11, 'font_id': 505},
                          {'language_id': 14, 'font_id': 506}, {'language_id': 15, 'font_id': 507}],
            'spacing': {'default': [-3, -5, -5, -8], 'cjk': [-4, -7, -4, -10], 'japanese': [-6, -9, -6, -13]},
            'source_offset': TEXT + 0x100, 'source_bytes': 626})
        # Each record's provenance is its allocation call.
        self.assertEqual([(r['id'], r['texture_id'], r['font_group'], r['source_offset'], r['source_bytes']) for r in result['records']],
                         [row + (at, 4) for row, at in zip(RECORDS, layout['records'])])
        languages = result['languages']
        self.assertEqual([row['file'] for row in languages['rows']], FILES)
        self.assertEqual([row['source_bytes'] for row in languages['rows']], [14 if i in (1, 3, 5) else 12 for i in range(16)])
        self.assertEqual([row['string_offset'] for row in languages['rows'][9:12]], [0x8000 + 16 * 9, 0x8000, 0x8000])
        self.assertEqual(languages['provenance'], {'dispatch': {'offset': TEXT + 0x600, 'bytes': 10}, 'table': {'offset': TEXT + 0x60a, 'bytes': 32}})
        textures = result['textures']
        self.assertEqual([row['variants'] for row in textures['rows']],
                         [{mode: 'resources/data/textures/t%d_%s.aei' % (t, mode) for mode in ('medium', 'large', 'baseline')} for t in (40, 41)])
        self.assertEqual(textures['provenance'], {'medium': {'offset': layout['medium'], 'bytes': 16}, 'large': {'offset': layout['large'], 'bytes': 26}})
        for row in textures['rows']:
            self.assertLess(row['source_offsets']['medium'], row['source_offsets']['large'])
            self.assertLess(row['source_offsets']['large'], row['source_offsets']['baseline'])
        # The profile modes are the flags loadFont tests.
        from gof2_content.font_selection import extract_font_selection
        self.assertEqual(extract_font_selection(lib)['_profile_globals'],
                         {'medium': ROLES['iPadHD'], 'large': ROLES['retinaDisplay'], 'wide': ROLES['n9']})

    def test_each_atlas_follows_its_own_path_literal(self):
        # One path registered for two atlases in different branches.
        atlases = {'medium': [(40, 'data/textures/shared.aei'), (41, 'data/textures/m.aei')],
                   'large': [(40, 'data/textures/l.aei'), (41, 'data/textures/shared.aei')],
                   'baseline': [(40, 'data/textures/b0.aei'), (41, 'data/textures/b1.aei')]}
        rows = self.bindings(android_fonts(atlases=atlases)[0])['textures']['rows']
        self.assertEqual([{mode: path[len('resources/data/textures/'):] for mode, path in row['variants'].items()} for row in rows],
                         [{'medium': 'shared.aei', 'large': 'l.aei', 'baseline': 'b0.aei'}, {'medium': 'm.aei', 'large': 'shared.aei', 'baseline': 'b1.aei'}])

    def test_each_broken_declaration_is_unsupported(self):
        from gof2_content.font_bindings import BUILD
        cases = {
            'case table': dict(cases=['arabic', 'simplified', 'traditional', 'other', 'korean', 'korean']),
            'two slots for a role': dict(roles={**ROLES, 'canvas2': 0x9100}),
            'shared slot': dict(roles={**ROLES, 'n9': ROLES['iPadHD']}),
            'cjk copies differ': dict(selection={'korean_medium': 2}),
            'spacing range': dict(selection={'base': 26, 'standard_baseline': 7}),  # 33
            'record sentinel': dict(unsealed=(507,)),
            'unknown malformed record': dict(records=RECORDS[:4] + [(510, 40, 0)] + RECORDS[4:], unsealed=(510,)),
            'record group': dict(records=RECORDS[:7] + [(507, 41, 32)]),
            'record id': dict(records=RECORDS[:7] + [(0xffff, 41, 0)], selection={'japanese': 0xffff}),
            'record texture': dict(records=RECORDS[:7] + [(507, 0xffff, 0)],
                                   atlases={mode: [(t, 'data/textures/t%d_%s.aei' % (t, mode)) for t in (40, 41, 0xffff)] for mode in ('medium', 'large', 'baseline')}),
            'duplicate record': dict(records=RECORDS + [RECORDS[0]]),
            'missing font record': dict(records=RECORDS[:7]),
            'language name': dict(files=FILES[:4] + ['abcd.lang'] + FILES[5:]),
            'other repeat': dict(files=FILES[:4] + [FILES[3]] + FILES[5:]),
            'medium flag': dict(flags={'medium': ROLES['n9'], 'large': ROLES['retinaDisplay']}),
            'large flag': dict(flags={'medium': ROLES['iPadHD'], 'large': ROLES['n9']}),
            'no large guard': dict(guards=('medium',)),
            'guards apart': dict(other=2),
            'atlas before the guards': dict(atlases={'before': [(40, 'data/textures/a.aei')], 'medium': [(40, 'data/textures/b.aei'), (41, 'data/textures/c.aei')],
                                                     'large': [(40, 'data/textures/d.aei'), (41, 'data/textures/e.aei')], 'baseline': [(41, 'data/textures/f.aei')]}),
            'two medium atlases': dict(atlases={'medium': [(40, 'data/textures/a.aei'), (40, 'data/textures/b.aei'), (41, 'data/textures/c.aei')],
                                                'large': [(41, 'data/textures/d.aei')], 'baseline': [(40, 'data/textures/e.aei'), (41, 'data/textures/f.aei')]}),
            'missing atlas': dict(atlases={'medium': [(40, 'data/textures/a.aei'), (41, 'data/textures/c.aei')],
                                           'large': [(40, 'data/textures/d.aei')], 'baseline': [(40, 'data/textures/e.aei'), (41, 'data/textures/f.aei')]}),
        }
        for name, options in cases.items():
            self.assertEqual(self.bindings(android_fonts(**options)[0]), {}, name)
        for name in (LOAD_FONT, SET_LANGUAGE, BUILD):
            self.assertEqual(self.bindings(android_fonts(omit=(name,))[0]), {}, name)

if __name__=='__main__': unittest.main()
