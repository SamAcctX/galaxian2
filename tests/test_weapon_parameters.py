"""Relocated synthetic declarations, altered bindings, and linked-scope failures."""
import struct
import unittest
from types import SimpleNamespace
from gof2_content import weapon_parameters as reader
from test_font_selection import expand
from test_ship_models import branch


def fixture(mac, shift=0):
    base=0x100000+shift;file_base=4352
    text={'name':b'__text','segment':b'__TEXT','address':base,'offset':256,'length':8000}
    const={'name':b'__const','segment':b'__TEXT','address':base+8000,'offset':8256,'length':1000}
    data=bytearray(9256)
    locations={'head':1000,'scale':1077 if mac else 1060,'tail':1224 if mac else 1240,
               'defaults':3000,'modifier':3400,'category_getter':5000,'id_getter':5020,
               'ship_getter':5040,'damage_getter':5060,'interval_getter':5080,
               'property_getter':5120,'type_getter':5200,'equipment_table':3800 if mac else 3320}
    if not mac: locations.update(defaults=3100,scale_tail=1170,constants=3240,scale_load=924)
    helper_specs={'category_getter':'554889e58b47045dc3' if mac else '40687047',
       'id_getter':'554889e58b075dc3' if mac else '00687047',
       'ship_getter':'554889e5488b87000200005dc3' if mac else 'd0f87c017047',
       'damage_getter':'554889e5f30f1047585dc3' if mac else '806d7047',
       'interval_getter':'554889e5f30f1047545dc3' if mac else '406d7047',
       'type_getter':'554889e58b47085dc3' if mac else '80687047',
       'property_getter':'554889e5488b4f388b3931d2eb044883c202b8257899c539fa730d488b410839349075ea8b4490045dc3' if mac else '026bd2f80090b9f1000f08d05268002352f82300884207d002334b45f8d347f62500ccf29950704702eb830040687047'}
    for key,raw in helper_specs.items(): data[256+locations[key]:256+locations[key]+len(bytes.fromhex(raw))]=bytes.fromhex(raw)
    expected={'damage_property':49,'interval_property':51,'lifetime_property':52,'speed_property':53,
              'interval_percent_property':79,'damage_percent_property':80,'low_damage_threshold':12}
    links= {'head':{'11':'property_getter','26':'property_getter','3c':'category_getter'},
            'tail':{'b':'id_getter','1b':'type_getter','30':'property_getter','45':'property_getter','73':'id_getter'},
            'modifier':{'11':'property_getter','5f':'property_getter'},
            'scale':{'a':'ship_getter','12':'damage_getter','40':'ship_getter','48':'interval_getter','6d':'ship_getter','75':'interval_getter'}} if mac else {
            'head':{'c':'property_getter','1e':'property_getter','2e':'category_getter'},
            'tail':{'a':'id_getter','1c':'type_getter','2c':'property_getter','3c':'property_getter','60':'id_getter'},
            'modifier':{'8':'property_getter','36':'property_getter'},
            'scale':{'a':'ship_getter','12':'damage_getter','36':'ship_getter','3e':'interval_getter'},
            'scale_tail':{'1a':'ship_getter','22':'interval_getter'}}
    jumps={'head':{'43':locations['scale'],'48':locations['tail']},
           'scale':{'1d':locations['scale']+0x24,'22':locations['scale']+0x60,'5e':locations['tail']},
           'modifier':{'43':locations['modifier']+0x48,'88':locations['modifier']+160,'8a':locations['modifier']+160,'94':locations['modifier']+160}} if mac else {
           'head':{'32':locations['scale'],'3a':locations['tail']},
           'scale':{'22':locations['scale_tail'],'28':locations['scale_tail'],'60':locations['scale_tail']+68},
           'modifier':{'5c':locations['modifier']+160}}
    # ARM literals must be within their PC-relative load's 1 KiB reach.
    values={'divisor':(8100 if mac else 3600,200.0),'default':(8104,1.0),
            'sentinel':(8108 if mac else 3604,-9999.0),'low':(8112 if mac else 1164,0.5),'unused':(3608,1000.0)}
    refs={'modifier':{'1a':'divisor','22':'default','31':'sentinel','6b':'divisor','73':'default','81':'sentinel'},'scale':{'82':'low'}} if mac else {'constants':{'4':'unused','8':'divisor','10':'sentinel'},'scale_load':{'0':'low'}}
    contexts={}
    for key in ['head','tail','modifier','defaults','scale']+([] if mac else ['constants','scale_tail','scale_load']):
        body,fields=expand(getattr(reader,('MAC_' if mac else 'ARM_')+key.upper()));at=locations[key]
        for field,(off,n) in fields.items():
            site=base+at+off
            if field in expected:
                value=expected[field]
                raw=value.to_bytes(n,'little',signed=True) if mac else struct.pack('<HH',0xf1bb,0x0f00|value) if field=='low_damage_threshold' else struct.pack('<H',0x2100|value)
            elif field.startswith('call_'):
                target=base+locations[links[key][field[5:]]]
                raw=struct.pack('<i',target-site-4) if mac else branch(site,target)
            elif field.startswith('jump_'):
                target=base+jumps[key][field[5:]]
                if mac: raw=(target-site-n).to_bytes(n,'little',signed=True)
                else:
                    delta=target-site-4
                    if key=='head' and field=='jump_32': raw=struct.pack('<H',0xb100|((delta&0x40)<<3)|((delta&0x3e)<<2))
                    else: raw=struct.pack('<H',(0xd500 if field=='jump_22' else 0xda00 if field=='jump_28' else 0xe000)|((delta//2)&(255 if field in ['jump_22','jump_28'] else 2047)))
            else:
                target=base+values[refs.get(key,{}).get(field[4:],'default')][0]
                if mac:raw=struct.pack('<i',target-site-4)
                else:
                    reg={'ref_4':16,'ref_8':20,'ref_10':24,'ref_0':16}[field]
                    delta=target-((site+4)&~3);raw=struct.pack('<HH',0xed9f|((reg&1)<<6),((reg//2)<<12)|0x0a00|(delta//4))
            body[off:off+n]=raw
        data[256+at:256+at+len(body)]=body;contexts[key]=(at,body,fields)
    for at,value in values.values():struct.pack_into('<f',data,256+at,value)
    table=locations['equipment_table'];rows=[table+120]*30;rows[26]=locations['modifier']
    raw=struct.pack('<30i',*(x-table for x in rows)) if mac else bytes((x-table)//2 for x in rows)
    data[256+table:256+table+len(raw)]=raw
    def extent(key,n=None):return {'offset':file_base+locations[key],'bytes':n if n is not None else len(bytes.fromhex(helper_specs[key]))}
    vehicle={'item_type_value_index':5,'provenance':{k:extent(k) for k in ['type_getter','property_getter']}}
    vehicle['provenance'].update(equipment_table=extent('equipment_table',120 if mac else 30),equipment_selector={'offset':file_base+(3120 if mac else 3310),'bytes':25 if mac else 14})
    opening={'item_category_value_index':3,'provenance':{'category_getter':extent('category_getter')}}
    mach=SimpleNamespace(data=bytes(data),text=text,sections=[text,const] if mac else [dict(text,length=9000)],slice_offset=4096,architecture='x86_64' if mac else 'armv7')
    return mach,vehicle,opening,contexts,expected


class WeaponParameters(unittest.TestCase):
    def test_item_specific_launch_modes(self):
        for mac in [True,False]:
            for shift in [0,0x400000]:
                mach,vehicle,opening,_,_=fixture(mac,shift)
                data=bytearray(mach.data);base=mach.text['address'];at=2000;selector=2200;target=2400 if mac else 2568
                body,fields=expand(reader.MAC_LAUNCH_MODE if mac else reader.ARM_LAUNCH_MODE)
                for name,(off,n) in fields.items():
                    if name=='single': raw=(128).to_bytes(n,'little') if mac else struct.pack('<H',0x2c80)
                    elif name=='first': raw=(-19).to_bytes(n,'little',signed=True) if mac else bytes.fromhex('a4f11300')
                    elif name=='count': raw=bytes([3]) if mac else bytes.fromhex('0328')
                    elif name=='getter': raw=struct.pack('<i',5120-at-off-4) if mac else branch(base+at+off,base+5120)
                    elif name=='address_low': raw=bytes.fromhex('40f20001')
                    elif name=='address_high': raw=bytes.fromhex('c0f20001')
                    else: raw=bytes(n)
                    body[off:off+n]=raw
                data[256+at:256+at+len(body)]=body
                gate=bytes.fromhex('41f68760010000010f85')+struct.pack('<i',target-selector-14) if mac else bytes.fromhex('93f80801002800f0b380d96b0868')
                data[256+selector:256+selector+len(gate)]=gate
                selected=bytes.fromhex('498b4f788339007e00') if mac else bytes.fromhex('98680028')
                data[256+target:256+target+len(selected)]=selected
                mach.data=bytes(data)
                result=reader.extract_weapon_parameters(mach,vehicle,opening)
                self.assertEqual(result['launch_modes']['alternate_item_ids'],[19,20,21,128])
                for corruption in ['declaration','selector','target','getter','duplicate','overlap']:
                    bad=bytearray(data)
                    if corruption=='declaration':bad[256+at+8]^=0x80
                    elif corruption=='selector':bad[256+selector]^=1
                    elif corruption=='target':bad[256+target]^=1
                    elif corruption=='getter':bad[256+at+fields['getter'][0]]^=4
                    elif corruption=='duplicate':bad[256+2700:256+2700+len(body)]=body
                    else:
                        off,n=fields['single'];bad[256+at+off:256+at+off+n]=(19).to_bytes(n,'little') if mac else struct.pack('<H',0x2c13)
                    mach.data=bytes(bad)
                    self.assertFalse(reader.extract_launch_modes(mach,result),(mac,shift,corruption))

    def test_relocated_changed_bindings(self):
        for mac in [True,False]:
            for shift in [0,0x400000]:
                mach,vehicle,opening,_,expected=fixture(mac,shift)
                result=reader.extract_weapon_parameters(mach,vehicle,opening)
                self.assertTrue(result,(mac,shift));self.assertEqual({key:result[key] for key in expected},expected)
                self.assertEqual(result['modifier_type'],26);self.assertEqual(result['percent_divisor'],200)
                self.assertEqual(result['low_damage_interval_scale'],0.5)

    def test_corrupt_or_unlinked_contexts(self):
        for mac in [True,False]:
            for bad in ['head','tail','scale','modifier','defaults','property_getter','category_getter','table','missing','duplicate','truncated','call','jump','nan']:
                with self.subTest(mac=mac,bad=bad):
                    mach,vehicle,opening,contexts,_=fixture(mac);data=bytearray(mach.data)
                    if bad in contexts:data[256+contexts[bad][0]]^=1
                    elif bad in ['property_getter','category_getter']:
                        row=vehicle['provenance'][bad] if bad=='property_getter' else opening['provenance'][bad];data[row['offset']-4096]^=1
                    elif bad=='table':data[vehicle['provenance']['equipment_table']['offset']-4096+(104 if mac else 26)]=0
                    elif bad=='missing':vehicle={}
                    elif bad=='duplicate':
                        at,body,_=contexts['head'];data[6256:6256+len(body)]=body
                    elif bad=='truncated':mach.text['length']=contexts['head'][0]+1
                    elif bad in ['call','jump']:
                        at,_,fields=contexts['head'];off,n=fields[('call_11' if mac else 'call_c') if bad=='call' else ('jump_43' if mac else 'jump_32')];data[256+at+off]^=2
                    elif bad=='nan':struct.pack_into('<f',data,256+(8100 if mac else 3600),float('nan'))
                    mach.data=bytes(data)
                    self.assertEqual(reader.extract_weapon_parameters(mach,vehicle,opening),{})


ATTRIBUTES = {'damage_property': 21, 'interval_property': 22, 'lifetime_property': 23, 'speed_property': 24,
              'interval_percent_property': 41, 'damage_percent_property': 42, 'primary_category': 0, 'low_damage_limit': 7}


def android_weapons(values=None, floats=None, modifier_cases=(26,), getter_prefix=None, omit=()):
    """Level::createPlayer, Ship::refreshValue and the item/ship getters in the Android
    shapes. Floats: scale, divisor, missing. Returns (library, vehicle, opening)."""
    from android_fixture import TEXT, library
    from thumb_shapes import assemble
    from gof2_content.android_library import AndroidLibrary
    from gof2_content.android_blocks import offset
    floats = {'low_scale': 0.5, 'divisor': 50.0, 'missing': -12345.0, 'value_scale': 1000.0, **(floats or {})}
    values = {**ATTRIBUTES, **(values or {})}
    getters = reader.ANDROID_GETTERS
    calls = {'_ZN5Level9createGunEiiiiiiii': TEXT}
    functions = [('_ZN5Level9createGunEiiiiiiii', b'\x70\x47\x00\xbf', TEXT)]
    for index, (key, (symbol, shape)) in enumerate(getters.items()):
        calls[symbol] = TEXT + 0x40 + 0x40 * index
    for key, (symbol, shape) in getters.items():
        text = (getter_prefix or {}).get(key, '') + shape
        functions.append((symbol, assemble(text, calls[symbol], calls=calls)[0], calls[symbol]))

    def with_pool(text, address, names):
        """Assemble with each `vldr sN, [pc, #{name}]` loading its float from a pool after the code."""
        tables = {'cases': [labels_for(i) for i in range(30)]}
        code, labels, at = assemble(text, address, {**values, **{n: 0 for n in names}, 'other': address}, {'status': 0x9000}, calls, tables)
        pool = (address + len(code) + 3) & ~3
        offsets = {n: pool + 4 * i - ((at[n] + 4) & ~3) for i, n in enumerate(names)}
        code, labels, at = assemble(text, address, {**values, **offsets, 'other': labels.get('other', address)}, {'status': 0x9000}, calls, tables)
        return code + bytes(pool - address - len(code)) + b''.join(struct.pack('<f', floats[n]) for n in names), labels
    labels_for = lambda i: 'modifier' if i in modifier_cases else 'other'
    create = 'push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}\n' + reader.ANDROID_SCALE_LOAD + reader.ANDROID_PLAYER + 'pop.w {r4, r5, r6, r7, r8, sb, sl, fp, pc}\n'
    code, create_labels = with_pool(create, TEXT + 0x400, ['low_scale'])
    functions.append(('_ZN5Level12createPlayerEv', code, TEXT + 0x400))
    refresh = ('push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}\n' + reader.ANDROID_DEFAULTS + reader.ANDROID_CONSTANTS + reader.ANDROID_SORTS
               + 'modifier: ' + reader.ANDROID_MODIFIER.strip() + '\nother: pop.w {r4, r5, r6, r7, r8, sb, sl, fp, pc}\n')
    code, refresh_labels = with_pool(refresh, TEXT + 0x800, ['value_scale', 'divisor', 'missing'])
    functions.append(('_ZN4Ship12refreshValueEv', code, TEXT + 0x800))
    functions = [row for row in functions if row[0] not in omit]
    lib = AndroidLibrary(library(functions, {}))
    span = lambda symbol: {'offset': offset(lib, calls[symbol]), 'bytes': lib.symbols[symbol][1]} if symbol in lib.symbols else None
    table = refresh_labels['modifier'] - 30  # the case table ends where the modifier starts
    vehicle = {'item_type_value_index': 5, 'provenance': {'property_getter': {**span('_ZN4Item12getAttributeEi'), 'bytes': 54} if span('_ZN4Item12getAttributeEi') else None,
                                                          'type_getter': span('_ZN4Item7getSortEv'), 'equipment_table': {'offset': table, 'bytes': 30}}}
    opening = {'item_category_value_index': 3, 'provenance': {'category_getter': span('_ZN4Item7getTypeEv')}}
    return lib, vehicle, opening


class AndroidWeaponParameters(unittest.TestCase):
    def test_named_functions_give_properties_factors_and_constants(self):
        from android_fixture import TEXT
        lib, vehicle, opening = android_weapons()
        result = reader.extract_weapon_parameters(lib, vehicle, opening)
        self.assertEqual({k: result[k] for k in ATTRIBUTES if k in result}, {k: v for k, v in ATTRIBUTES.items() if k != 'low_damage_limit'})
        self.assertEqual({k: result[k] for k in ('low_damage_threshold', 'modifier_type', 'percent_divisor', 'default_multiplier', 'missing_multiplier',
                                                 'low_damage_interval_scale', 'item_type_value_index', 'item_category_value_index')},
                         {'low_damage_threshold': 8, 'modifier_type': 26, 'percent_divisor': 50.0, 'default_multiplier': 1.0,
                          'missing_multiplier': -12345.0, 'low_damage_interval_scale': 0.5, 'item_type_value_index': 5, 'item_category_value_index': 3})
        provenance = result['provenance']
        self.assertEqual({k: v['bytes'] for k, v in provenance.items()},
                         {'head': 52, 'scale': 124, 'tail': 80, 'equipment_table': 30, 'scale_load': 14, 'defaults': 10, 'constants': 22,
                          'modifier': 92, 'category_getter': 4, 'id_getter': 4, 'ship_getter': 6, 'damage_getter': 4, 'interval_getter': 4,
                          'type_getter': 4, 'property_getter': 54})
        self.assertEqual(provenance['head']['offset'] + 52, provenance['scale']['offset'])
        self.assertEqual(provenance['scale']['offset'] + 124, provenance['tail']['offset'])
        self.assertEqual(set(result['value_sources']), {'percent_divisor', 'missing_multiplier', 'low_damage_interval_scale'})
        for key, value in (('percent_divisor', 50.0), ('missing_multiplier', -12345.0), ('low_damage_interval_scale', 0.5)):
            at = result['value_sources'][key]['offset']
            self.assertEqual(struct.unpack_from('<f', lib.data, at)[0], value, key)

    def test_each_broken_declaration_is_unsupported(self):
        cases = {'duplicate property': dict(values={'interval_property': 21}), 'no modifier case': dict(modifier_cases=()),
                 'two modifier cases': dict(modifier_cases=(26, 27)), 'divisor': dict(floats={'divisor': 20000.0}),
                 'zero divisor': dict(floats={'divisor': 0.0}), 'scale': dict(floats={'low_scale': 1.5}), 'sentinel': dict(floats={'missing': 3.0}),
                 'nan': dict(floats={'divisor': float('nan')}), 'infinite sentinel': dict(floats={'missing': float('-inf')}), 'secondary category': dict(values={'primary_category': 1}),
                 'getter after code': dict(getter_prefix={'damage_getter': 'nop\n'})}
        for name, options in cases.items():
            self.assertEqual(reader.extract_weapon_parameters(*android_weapons(**options)), {}, name)
        for symbol in ('_ZN5Level12createPlayerEv', '_ZN4Ship12refreshValueEv', '_ZN4Ship17getFireRateFactorEv'):
            lib, vehicle, opening = android_weapons(omit=(symbol,))
            self.assertEqual(reader.extract_weapon_parameters(lib, vehicle, opening), {}, symbol)
        lib, vehicle, opening = android_weapons()
        for key in ('property_getter', 'type_getter', 'equipment_table'):
            other = {**vehicle, 'provenance': {**vehicle['provenance'], key: {'offset': 4, 'bytes': 4}}}
            self.assertEqual(reader.extract_weapon_parameters(lib, other, opening), {}, key)
        self.assertEqual(reader.extract_weapon_parameters(lib, vehicle, {**opening, 'provenance': {'category_getter': {'offset': 4, 'bytes': 4}}}), {})
        self.assertEqual(reader.extract_weapon_parameters(lib, {**vehicle, 'item_type_value_index': 4}, opening), {})
        self.assertEqual(reader.extract_weapon_parameters(lib, vehicle, {**opening, 'item_category_value_index': 2}), {})


GUN_VALUES = {'single': '0x30', 'first': '5', 'count': '2', 'flag': '0x120', 'property': '0xb', 'additional': '0x70', 'slots': '0x10',
              'kinds': '4', 'missing_low': '0x7825', 'missing_high': '0xc599', 'damage': '0x60', 'bounds': '0x6c', 'target': '0x40', 'own': '0x104'}
GUN_NAMES = {'setter': '_ZN3Gun8setIndexEi', 'shooter': reader.ANDROID_SHOOT, 'getter': '_ZN4Item12getAttributeEi',
             'factory': '_ZN5Level9createGunEiiiiiiii', 'collision': '_ZN3Gun22calcCharacterCollisionEv',
             'constructor': '_ZN3GunC1EiiiiiifN11AbyssEngine6AEMath6VectorES2_', 'hit': '_ZN6Player6damageEibi'}


def android_guns(values=None, edits=(), omit=()):
    """Gun::setIndex, Gun::shootAt, Level::createGun, Gun::Gun and Gun::calcCharacterCollision in the
    Android shapes (alternate items 5, 6 and 0x30, 16 slots). `edits`: (key, old text, new text).
    Returns (library, {key: address}, weapon parameters with the parents' provenance)."""
    from android_text_fixture import fill, text_library
    from gof2_content import ordinary_hit_policy, weapon_capacity, weapon_collision_bounds
    v = {**GUN_VALUES, **(values or {})}
    push, pop = 'push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}\nadd r7, sp, #0xc\n', 'pop.w {r4, r5, r6, r7, r8, sb, sl, fp, pc}'
    texts = {
        'setter': push + fill(reader.ANDROID_CLASSIFICATION, blank='&_ZN7Globals5itemsE', **v) + fill(ordinary_hit_policy.ANDROID_STORE, **v) + pop,
        'shooter': '\n'.join([push + 'mov fp, r0', fill(reader.ANDROID_SELECTOR, **dict(v, flag='0xf9', ordinary='#out')), 'movs r5, #0',
                              fill(reader.ANDROID_SELECTOR, **dict(v, ordinary='#out')), reader.ANDROID_SELECTED, 'out:', pop]),
        'getter': 'ldr r2, [r0, #0x30]\nbx lr',
        'factory': '\n'.join([push + 'sub sp, #0x38', weapon_capacity.ANDROID_ENTRY, fill(weapon_capacity.ANDROID_KINDS, blank='#other', **v),
                              '.cases zero, other, other, other, other', 'zero:',
                              fill(weapon_capacity.ANDROID_RANGE.replace('blt.w {}', 'blt.w #other'), **dict(v, ordinary='#ordinary')),
                              'other:', 'movs r0, #0', 'b #done', 'ordinary:', weapon_capacity.ANDROID_CONSTRUCTOR, 'done:', 'add sp, #0x38', pop]),
        'constructor': push + 'mov r4, r0\nmov.w sl, #0\nstr.w sl, [r4, #4]\n' + fill(weapon_collision_bounds.ANDROID_DEFAULT, **dict(v, zero='sl', flag=v['bounds'])) + '\n' + pop,
        'collision': '\n'.join([push + 'vpush {d8, d9, d10, d11, d12, d13, d14, d15}', 'mov fp, r0', 'vmov.f32 s16, #3.000000e+00',
                                'vmov.f32 s18, #2.500000e-01', 'vldr s24, =0x3e4ccccd', 'ldr.w sb, [fp, #0xb4]',
                                fill(ordinary_hit_policy.ANDROID_GATE + ordinary_hit_policy.ANDROID_ROUTE, **v),
                                fill(weapon_collision_bounds.ANDROID_SELECTOR, **dict(v, flag=v['bounds'])),
                                'vpop {d8, d9, d10, d11, d12, d13, d14, d15}', pop]),
        'hit': push + 'mov r4, r0\n' + pop}
    for key, old, new in edits:
        assert old in texts[key], (key, old)
        texts[key] = texts[key].replace(old, new, 1)
    lib, addresses = text_library({GUN_NAMES[k]: t for k, t in texts.items() if k not in omit}, {'_ZN7Globals5itemsE': [0]})
    at = {k: addresses.get(n) for k, n in GUN_NAMES.items()}
    weapon = {'provenance': {'property_getter': {'offset': at['getter'] or 2, 'bytes': 54}, 'tail': {'offset': 6, 'bytes': 80}}}
    return lib, at, weapon


def android_weapon_chain(lib, weapon):
    """The weapon sub-readers in extract order, each given the earlier results."""
    from gof2_content.weapon_capacity import extract_weapon_capacity
    from gof2_content.ordinary_hit_policy import extract_ordinary_hit_policy
    from gof2_content.player_hit_policy import extract_player_hit_policy
    from gof2_content.weapon_collision_bounds import extract_weapon_collision_bounds
    weapon = dict(weapon)
    weapon['launch_modes'] = reader.extract_launch_modes(lib, weapon)
    weapon['projectile_capacity'] = extract_weapon_capacity(lib, weapon, 0)
    weapon['ordinary_hit_policy'] = extract_ordinary_hit_policy(lib, weapon)
    weapon['player_hit_policy'] = extract_player_hit_policy(lib, weapon)
    weapon['collision_bounds'] = extract_weapon_collision_bounds(lib, weapon)
    return weapon


@unittest.skipUnless(__import__('importlib').util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidLaunchModes(unittest.TestCase):
    def test_named_functions_give_alternate_items(self):
        lib, at, weapon = android_guns()
        result = reader.extract_launch_modes(lib, weapon)
        self.assertEqual(result['alternate_item_ids'], [5, 6, 0x30])
        p = result['provenance']
        # setIndex: push, add r7, then the classification; shootAt: the second flag test.
        self.assertEqual({k: (p[k]['offset'] - at[f], p[k]['bytes']) for k, f in (('classification', 'setter'), ('selector', 'shooter'), ('selected_path', 'shooter'))},
                         {'classification': (6, 48), 'selector': (20, 10), 'selected_path': (30, 8)})
        self.assertEqual(p['property_getter'], weapon['provenance']['property_getter'])

    def test_each_broken_rule_is_unsupported(self):
        cases = {'other flag': dict(edits=[('setter', 'strb.w r1, [r4, #0x120]', 'strb.w r1, [r4, #0x124]')]),
                 'two flag tests': dict(edits=[('shooter', 'movs r5, #0', fill_selector() + reader.ANDROID_SELECTED)]),
                 'path apart': dict(edits=[('shooter', 'ldr.w r1, [fp, #0x3c]', 'nop\nldr.w r1, [fp, #0x3c]')]),
                 'no alternate path': dict(edits=[('shooter', 'ldr.w r1, [fp, #0x3c]', 'ldr.w r1, [fp, #0x40]')]),
                 'branch outside': dict(edits=[('shooter', '[fp, #0x120]\ncmp r0, #0\nbeq.w #out', '[fp, #0x120]\ncmp r0, #0\nbeq.w #_ZN4Item12getAttributeEi')]),
                 'shooter this lost': dict(edits=[('shooter', 'mov fp, r0', 'movs r0, #0\nmov fp, r0')]),
                 'setter this lost': dict(edits=[('setter', 'mov r4, r0', 'movs r0, #0\nmov r4, r0')]),
                 'index not argument': dict(edits=[('setter', 'add r7, sp, #0xc', 'movs r1, #0')]),
                 'other catalogue': dict(edits=[('setter', '=&_ZN7Globals5itemsE', '=0x10')]),
                 'no items': dict(values=dict(count='0')), 'too many items': dict(values=dict(count='0x41', single='0xff')),
                 'single in range': dict(values=dict(single='6')), 'past the ids': dict(values=dict(first='0xff000'))}
        for name, options in cases.items():
            with self.subTest(name):
                lib, _, weapon = android_guns(**options)
                self.assertEqual(reader.extract_launch_modes(lib, weapon), {})
        for key in ('setter', 'shooter'):
            lib, _, weapon = android_guns(omit=(key,))
            self.assertEqual(reader.extract_launch_modes(lib, weapon), {}, key)
        lib, _, weapon = android_guns()
        weapon['provenance']['property_getter'] = {'offset': weapon['provenance']['property_getter']['offset'] + 2, 'bytes': 54}
        self.assertEqual(reader.extract_launch_modes(lib, weapon), {})
        self.assertEqual(reader.extract_launch_modes(lib, {'provenance': {}}), {})


def fill_selector():
    from android_text_fixture import fill
    return fill(reader.ANDROID_SELECTOR, **dict(GUN_VALUES, ordinary='#out'))
