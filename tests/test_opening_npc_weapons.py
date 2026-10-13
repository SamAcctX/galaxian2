"""Independent relocated declaration fixtures; no original game resources."""
import copy
import struct
import unittest
from types import SimpleNamespace
from gof2_content import opening_npc_weapons as reader
from test_font_selection import expand as blank
from test_ship_models import branch
from test_materials import arm_wide
from test_surface_material import arm_modified


def expand(pattern, values):
    data, fields = blank(pattern)
    for key, raw in values.items():
        at, size = fields[key]
        assert len(raw) == size
        data[at:at+size] = raw
    return bytes(data)


def fixture(mac, shift=0):
    origin=0x100000+shift; offset=256; slice_offset=4096
    architecture='x86_64' if mac else 'armv7'
    layouts=reader.LAYOUTS[architecture]
    positions={'main':6000,'table':9000,'player_constructor':15000,'constructor':18000,
               'npc_owner':18200,'cursor':18400,'post_campaign':18600,'level_getter':18800,
               'level_scale':19000,'speed_value':19004,'item':19200,'fresh_level':22000}
    for key,(delta,_,_) in layouts.items(): positions[key]=positions['main']+delta
    if not mac:
        positions['table']=positions['main']+layouts['main'][1]
        positions['level_scale']=((positions['level_zero']+16)&~3)+0x368
    data=bytearray(30000)
    def write(at,raw): data[offset+at:offset+at+len(raw)]=raw
    def reference(at,key,pattern,destination):
        marker=reader.template(pattern).match(expand(pattern,{}))
        p=at+marker.start(key)
        return struct.pack('<i',destination-p-4) if mac else branch(origin+p,origin+destination)
    def block(key,pattern,values=None,links=None):
        at=positions[key]; values=dict(values or {})
        for field,destination in (links or {}).items():values[field]=reference(at,field,pattern,positions.get(destination,destination))
        raw=expand(pattern,values);write(at,raw);return raw
    values={True:{'capacity':struct.pack('<i',7),'interval':struct.pack('<i',711),'lifetime':struct.pack('<i',3201)},
            False:{'capacity':bytes([7,0x23]),'interval':arm_modified(768,2),'lifetime':arm_wide(3201,0)}}[mac]
    # 711 is not a Thumb modified immediate; use a representable interval.
    if not mac:values['interval']=arm_modified(768,2)
    links={'call_0':'post_campaign',('call_14' if mac else 'call_12'):'cursor',
           ('call_55' if mac else 'call_50'):'constructor',('call_62' if mac else 'call_60'):'npc_owner',
           ('call_77' if mac else 'call_78'):'item'}
    if mac:links['ref_a4']='table'
    block('main',layouts['main'][2],values,links)
    block('kind',layouts['kind'][2],{'kind':struct.pack('<i',1) if mac else bytes([1,0x22]),
          'item':struct.pack('<i',21) if mac else bytes([21,0x21]),'model':struct.pack('<i',9876) if mac else arm_wide(9876,10)},
          {'call_14' if mac else 'call_e':'item'})
    write(positions['table']+8*(4 if mac else 1),struct.pack('<i',positions['kind']-positions['table']) if mac else bytes([(positions['kind']-positions['table'])//2]))
    block('base_damage',layouts['base_damage'][2],{'damage':struct.pack('<i',5) if mac else bytes([5,0x22])})
    block('speed',layouts['speed'][2],{} if mac else {'speed':bytes.fromhex('83ef148f')},{'ref_0':'speed_value'} if mac else {})
    links={('call_a' if mac else 'call_6'):'level_getter',('call_31' if mac else 'call_30'):'level_getter'}
    if mac:links.update(ref_16='level_scale',ref_3d='level_scale')
    block('level_zero',layouts['level_zero'][2],links=links)
    write(positions['level_scale'],struct.pack('<f',0.75))
    if mac:write(positions['speed_value'],struct.pack('<f',22.0))
    block('fresh_level',reader.FRESH[architecture][1])
    setters={True:{'npc_owner':'554889e54088b7510100005dc3','cursor':'554889e58b87780200005dc3',
                   'post_campaign':'554889e583bf780200002c0f9fc05dc3','level_getter':'554889e58b87580200005dc3'},
             False:{'npc_owner':'80f8f9107047','cursor':'d0f8d4017047','post_campaign':'d0f8d41100202c29c8bf01207047','level_getter':'d0f8b4017047'}}[mac]
    for key,raw in setters.items():write(positions[key],bytes.fromhex(raw))
    cp=block('player_constructor',reader.MAC_CALL if mac else reader.ARM_CALL,links={'ctor':'constructor'})
    def extent(at,size):return {'offset':slice_offset+offset+at,'bytes':size}
    mach=SimpleNamespace(architecture=architecture,data=bytes(data),slice_offset=slice_offset,
          text={'offset':offset,'address':origin,'length':29000},
          sections=[{'name':b'__text','segment':b'__TEXT','offset':offset,'address':origin,'length':29000}])
    if mac:
        mach.sections.append({'name':b'__const','segment':b'__TEXT','offset':offset+19000,'address':origin+19000,'length':8})
        # Keep address(span) unambiguous for executable extents.
    actors={'npc_initialization':{'supported':True},'actors':[{'actor_id':i,'actor_kind':8,'hull_catalogue_id':[2,23,2][i]} for i in range(3)]}
    opening={'provenance':{'declaration':extent(positions['fresh_level']+(0x974 if mac else 0x734),1)}}
    weapon={'launch_modes':{'alternate_item_ids':[9,10,11,228], 'provenance':{'classification':extent(positions['item']+(17 if mac else 78),1)}},
            'projectile_capacity':{'provenance':{'constructor_call':extent(positions['player_constructor'],len(cp))}}}
    return mach,actors,opening,weapon,positions,offset


class OpeningNpcWeaponTests(unittest.TestCase):
    def test_relocated_values(self):
        for mac in [False,True]:
            for shift in [0,0x40000]:
                with self.subTest(mac=mac,shift=shift):
                    m,a,o,w,_,_=fixture(mac,shift)
                    result=reader.extract_opening_npc_weapon(m,a,o,w)
                    self.assertTrue(result)
                    self.assertEqual((result['damage'],result['projectile_capacity'],result['item_id'],result['model_resource_id']),(5,7,21,9876))
                    self.assertEqual(result['interval_ms'],711 if mac else 768)
                    self.assertEqual(result['speed_units_per_millisecond'],22 if mac else 20)
                    self.assertEqual(result['lifetime_ms'],3201)
                    self.assertTrue(all(x['offset']>=m.slice_offset for x in result['provenance'].values()))

    def test_missing_or_changed_scope(self):
        for mac in [False,True]:
            m,a,o,w,_,_=fixture(mac)
            for key in ['actor_kind','hull_catalogue_id','actor_id']:
                altered=copy.deepcopy(a);altered['actors'][2][key]=99
                self.assertEqual(reader.extract_opening_npc_weapon(m,altered,o,w),{})
            altered=copy.deepcopy(w);altered['launch_modes']['alternate_item_ids'].append(21)
            self.assertEqual(reader.extract_opening_npc_weapon(m,a,o,altered),{})
            self.assertEqual(reader.extract_opening_npc_weapon(m,a,{},w),{})

    def test_corruption_and_truncation(self):
        for mac in [False,True]:
            m,a,o,w,p,offset=fixture(mac)
            for key in ['main','kind','base_damage','fresh_level','npc_owner','level_getter','cursor','post_campaign','actor_kind']:
                raw=bytearray(m.data);pos=p['table']+8*(4 if mac else 1) if key=='actor_kind' else p[key]
                raw[offset+pos]^=0xff
                damaged=copy.copy(m);damaged.data=bytes(raw)
                self.assertEqual(reader.extract_opening_npc_weapon(damaged,a,o,w),{},key)
            for value in [float('nan'),-1.0,0.0]:
                raw=bytearray(m.data);struct.pack_into('<f',raw,offset+p['level_scale'],value)
                damaged=copy.copy(m);damaged.data=bytes(raw)
                self.assertEqual(reader.extract_opening_npc_weapon(damaged,a,o,w),{})
            m.data=m.data[:offset+p['main']+40]
            self.assertEqual(reader.extract_opening_npc_weapon(m,a,o,w),{})

if __name__=='__main__': unittest.main()


ANDROID_ACTORS = {'actors': [{'actor_id': i, 'actor_kind': 8, 'hull_catalogue_id': h} for i, h in enumerate((2, 23, 2))],
                  'npc_initialization': {'ordinary_half_extent': 1000}}
ANDROID_WEAPON = {'launch_modes': {'alternate_item_ids': [7]}, 'projectile_capacity': {'player': 9}}
ANDROID_HELPERS = {'post_campaign': '_ZN6Status7gameWonEv', 'cursor': '_ZN6Status25getCurrentCampaignMissionEv',
                   'level_getter': '_ZN6Status8getLevelEv', 'npc_owner': '_ZN3Gun12setFriendGunEb'}


def android_extract(actors=ANDROID_ACTORS, opening=None, weapon=ANDROID_WEAPON, order=('level', 'damage', 'gun'), between='nop',
                    cases=None, kind_setter='_ZN3Gun8setIndexEi', fresh='mov r8, r0', kind_last=False, **changes):
    """Synthetic Level::assignGuns, Status helpers and Status::resetGame in the Android shapes."""
    from android_text_fixture import fill, text_library
    values = dict(scale='0x3f800000', zero='0x0', speed='1.200000e+01', damage='5', capacity='6', interval='0x190',
                  lifetime='0x7d0', kinds='0xa', kind='1', item='0x15', model='0x1234', item_setter='_ZN3Gun8setIndexEi',
                  **{key: name for key, name in ANDROID_HELPERS.items()})
    values.update(changes.pop('values', {}))
    blocks = {'level': fill(reader.ANDROID_LEVEL, **values), 'damage': fill(reader.ANDROID_DAMAGE, **values),
              'gun': fill(reader.ANDROID_GUN, blank='#out', **values)}
    # The kind table follows the gun block, the kind 8 block the table (or all blocks).
    kind = '\n'.join(['kind:', fill(reader.ANDROID_KIND, **dict(values, item_setter=kind_setter))])
    blocks['gun'] += '\n'.join(['', '.cases ' + ', '.join(cases or ['out'] * 8 + ['kind', 'out', 'out']), '' if kind_last else kind])
    guns = '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', blocks[order[0]], between, blocks[order[1]], 'nop', blocks[order[2]],
                      kind if kind_last else '', 'out:', 'bx lr'])
    functions = {'_ZN5Level10assignGunsEv': guns,
                 '_ZN6Status9resetGameEv': '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, lr}', fresh, reader.ANDROID_FRESH, 'bx lr']),
                 **{name: reader.ANDROID_HELPERS[key] for key, name in ANDROID_HELPERS.items()}}
    functions.update(changes)
    from android_text_fixture import text_library
    lib, addresses = text_library({k: v for k, v in functions.items() if v is not None})
    return reader.extract_opening_npc_weapon(lib, actors, {'declaration': 1} if opening is None else opening, weapon), lib, addresses


class AndroidOpeningNpcWeapon(unittest.TestCase):
    def test_named_functions_give_weapon_and_spans(self):
        result, lib, addresses = android_extract()
        self.assertEqual({k: v for k, v in result.items() if k != 'provenance'},
                         {'actor_ids': [0, 1, 2], 'actor_kind': 8, 'item_id': 21, 'kind': 1, 'category': 0, 'model_resource_id': 0x1234,
                          'damage': 5, 'interval_ms': 400, 'lifetime_ms': 2000, 'speed_units_per_millisecond': 12.0,
                          'projectile_capacity': 6, 'local_muzzle': [0.0, 0.0, 0.0], 'launch_mode': 'ordinary'})
        p = result['provenance']
        guns = addresses['_ZN5Level10assignGunsEv']
        self.assertEqual({k: (p[k]['offset'] - guns, p[k]['bytes']) for k in ('level_zero', 'base_damage', 'main', 'actor_kind', 'kind')},
                         {'level_zero': (4, 224), 'base_damage': (230, 64), 'main': (296, 118), 'actor_kind': (422, 1), 'kind': (426, 16)})
        self.assertEqual(int.from_bytes(lib.data[p['level_scale']['offset']:][:4], 'little'), 0x3f800000)
        self.assertEqual((p['fresh_level']['offset'] - addresses['_ZN6Status9resetGameEv'], p['fresh_level']['bytes']), (6, 10))
        for key, name in ANDROID_HELPERS.items():
            self.assertEqual(p[key]['offset'], addresses[name], key)

    def test_each_broken_rule_is_unsupported(self):
        actors = copy.deepcopy(ANDROID_ACTORS)
        actors['actors'][2]['actor_kind'] = 9
        cases = {
            'no initialization': dict(actors={'actors': ANDROID_ACTORS['actors'], 'npc_initialization': {}}),
            'other actors': dict(actors=actors),
            'no loadout': dict(opening={}),
            'no launch modes': dict(weapon={'launch_modes': {}, 'projectile_capacity': {'player': 9}}),
            'no capacity': dict(weapon={'launch_modes': {'alternate_item_ids': [7]}, 'projectile_capacity': {}}),
            'alternate item': dict(weapon={'launch_modes': {'alternate_item_ids': [21]}, 'projectile_capacity': {'player': 9}}),
            'damage first': dict(order=('damage', 'level', 'gun')),
            'gun before damage': dict(order=('level', 'gun', 'damage'), kind_last=True),
            'bonus lost': dict(between='movs r4, #0'),
            'small table': dict(values=dict(kinds='7'), cases=['out'] * 8 + ['kind']),
            'kind elsewhere': dict(cases=['out'] * 7 + ['kind', 'out', 'out', 'out']),
            'other kind setter': dict(kind_setter='_ZN3Gun12setFriendGunEb'),
            'fresh this lost': dict(fresh='mov r8, r1'),
            'no fresh level': {'_ZN6Status9resetGameEv': 'bx lr'},
            **{'helper ' + key: {name: 'movs r0, #0\nbx lr'} for key, name in ANDROID_HELPERS.items()},
            'kind': dict(values=dict(kind='2')),
            'negative scale': dict(values=dict(scale='0xbf800000')),
            'level sum start': dict(values=dict(zero='0x3f800000')),
            'zero damage': dict(values=dict(damage='0')),
            'zero interval': dict(values=dict(interval='0')),
            'long interval': dict(values=dict(interval='0x20000')),
            'zero lifetime': dict(values=dict(lifetime='0')),
            'zero capacity': dict(values=dict(capacity='0')),
            'negative speed': dict(values=dict(speed='-1.200000e+01')),
        }
        for name, changes in cases.items():
            with self.subTest(name):
                self.assertEqual(android_extract(**changes)[0], {})
