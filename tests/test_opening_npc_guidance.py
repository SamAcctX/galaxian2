"""Synthetic section relocation and fail-closed guidance declaration checks."""
import copy
import struct
import unittest
from types import SimpleNamespace
from gof2_content import opening_npc_guidance as reader
from test_font_selection import expand


def fixture(mac,shift=0):
    origin=0x200000+shift;offset=256;bias=4096
    arch='x86_64' if mac else 'armv7'
    bases={'membership':1000,'constructor':4000,'factory':10000,'update':20000}
    data=bytearray(53000);positions={};literal_positions={}
    def write(at,raw):data[offset+at:offset+at+len(raw)]=raw
    def extent(at,n):return {'offset':bias+offset+at,'bytes':n}
    for key,(base,delta,size,pattern) in reader.LAYOUTS[arch].items():
        at=bases[base]+delta;positions[key]=at;raw,_=expand(pattern);write(at,raw)
    unique={};next_literal=50000
    for name,(register,expected) in reader.LITERALS[arch].items():
        block,field=name.split('.');at=positions[block]
        _,fields=expand(reader.LAYOUTS[arch][block][3]);p,n=fields[field]
        values=expected if isinstance(expected,list) else [expected]
        token=tuple(values)
        if token not in unique:
            if mac:target=next_literal;next_literal+=4*len(values)
            elif block=='boost_damage':target=((positions[block]+952)&~3)+4*len(unique)
            elif block=='boost_response':target=(positions['boost_damage']+980)&~3
            else:target=((positions['fire']-600)&~3)+4*(len(unique)-3)
            unique[token]=target
            write(target,struct.pack('<'+'f'*len(values),*values))
        target=unique[token];literal_positions[name]=target
        if mac:encoded=struct.pack('<i',target-at-p-n)
        elif field=='rates':
            # Thumb SUBW R0,PC,#imm12. Keep its literal pool within reach.
            delta=at+p+4-target
            first=0xf2af|(((delta>>11)&1)<<10)
            second=(((delta>>8)&7)<<12)|(delta&255)
            encoded=struct.pack('<HH',first,second)
        else:
            reg=int(register[1:]);delta=target-((at+p+4)&~3)
            assert delta%4==0 and abs(delta)<=1020,(name,delta)
            encoded=struct.pack('<HH',(0xed9f if delta>=0 else 0xed1f)|((reg&1)<<6),((reg//2)<<12)|0x0a00|(abs(delta)//4))
        write(at+p,encoded)
    slot=51000;write(slot,struct.pack('<Q' if mac else '<I',origin+bases['update']+(0 if mac else 1)))
    text={'name':b'__text','segment':b'__TEXT','offset':offset,'address':origin,'length':45000}
    m=SimpleNamespace(architecture=arch,data=bytes(data),slice_offset=bias,text=text,
        sections=[text,{'name':b'__const','segment':b'__TEXT','offset':offset+50000,'address':origin+50000,'length':500},
                  {'name':b'__const','segment':b'__DATA','offset':offset+51000,'address':origin+51000,'length':500}])
    initial={'provenance':{'factory_entry':extent(bases['factory'],4)},
             'flight':{'provenance':{'virtual_update':extent(slot,8 if mac else 4),'bank':extent(bases['constructor']+(2272 if mac else 1794),24 if mac else 52)}},
             'primary_weapon':{'provenance':{'fresh_level':extent(500,1)}}}
    actors={'npc_initialization':initial,'actors':[{'actor_id':i,'actor_kind':8,'hull_catalogue_id':[2,23,2][i]} for i in range(3)]}
    return m,actors,positions,literal_positions,offset


class GuidanceTests(unittest.TestCase):
    def test_independent_relocated_profiles(self):
        for mac in [False,True]:
            for shift in [0,0x600000]:
                m,a,_,_,_=fixture(mac,shift)
                result=reader.extract_opening_npc_guidance(m,a)
                self.assertTrue(result,(mac,shift))
                self.assertEqual({k:v for k,v in result.items() if k!='provenance'},reader.VALUES)
                self.assertEqual(len(result['provenance']),21 if mac else 20)

    def test_reject_changed_blocks_literals_and_targets(self):
        for mac in [False,True]:
            m,a,positions,literals,offset=fixture(mac)
            for key,at in {**positions,**literals,'virtual_update':51000}.items():
                altered=copy.copy(m);data=bytearray(m.data);data[offset+at]^=255;altered.data=bytes(data)
                self.assertFalse(reader.extract_opening_npc_guidance(altered,a),(mac,key))
            for key in ['actor_id','actor_kind','hull_catalogue_id']:
                altered=copy.deepcopy(a);altered['actors'][1][key]=99
                self.assertFalse(reader.extract_opening_npc_guidance(m,altered))
            for key in ['flight','primary_weapon']:
                altered=copy.deepcopy(a);altered['npc_initialization'][key]={}
                self.assertFalse(reader.extract_opening_npc_guidance(m,altered))

    def test_ambiguity_bounds_and_architecture(self):
        for mac in [False,True]:
            m,a,p,_,offset=fixture(mac)
            changed=copy.copy(m);changed.data=m.data[:offset+51002]
            self.assertFalse(reader.extract_opening_npc_guidance(changed,a))
            changed=copy.deepcopy(m);changed.sections[-1]['segment']=b'__TEXT'
            self.assertFalse(reader.extract_opening_npc_guidance(changed,a))
            changed=copy.copy(m);data=bytearray(m.data);n=reader.LAYOUTS[m.architecture]['membership'][2]
            data[offset+3000:offset+3000+n]=data[offset+p['membership']:offset+p['membership']+n];changed.data=bytes(data)
            self.assertFalse(reader.extract_opening_npc_guidance(changed,a))
            changed=copy.copy(m);changed.architecture='unsupported'
            self.assertFalse(reader.extract_opening_npc_guidance(changed,a))


if __name__=='__main__':unittest.main()


ANDROID_ACTORS = {'actors': [{'actor_id': i, 'actor_kind': 8, 'hull_catalogue_id': h} for i, h in enumerate((2, 23, 2))],
                  'npc_initialization': {'flight': {'pi': 3.14}, 'primary_weapon': {'damage': 3}}}


def android_extract(actors=ANDROID_ACTORS, slot=13, drop=(), other='mov.w r5, #0x1f40', rates='0x3f733333, 0x3f866666',
                    words=('0x42c80000', '0x42200000', '0x4708b800', '0xc708b800'), **links):
    """Synthetic PlayerFighter, Level::createShip and Level::connectPlayers in the Android shapes."""
    from android_text_fixture import fill, text_library
    t = lambda key, **values: '' if key in drop else fill(getattr(reader, 'ANDROID_' + key.upper()), **values)
    response = fill(reader.ANDROID_RESPONSE, tag='', rates='rates').strip().splitlines()
    if 'response' in drop:
        response = [line if line.endswith(':') else 'nop' for line in response]
    link = {**dict(response='#response', resume='#resume', done='#done', keep='#keep', later='#keep', miss='#miss', none='#none', count='#count'), **links}
    update = '\n'.join([
        'push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', 'pre:', t('selection', keep=link['keep'], later=link['later']), 'keep:', 'nop',
        t('boost', scale=words[0], percent=words[1], done=link['done'], response=link['response'], resume=link['resume']),
        t('near', blank='#out', other='#other'), 'back:', 'nop', t('fire', range=words[2], negative_range=words[3], miss=link['miss']), 'miss:', 'nop',
        'other:', other, 'response:', response[0], 'resume:', *response[1:], 'out:', 'bx lr', 'rates:', '.word ' + rates])
    membership = fill(reader.ANDROID_MEMBERSHIP, blank='#out', skip='#out').strip().splitlines()
    if 'membership' in drop:
        membership = [line if line.endswith(':') else 'nop' for line in membership]
    functions = {
        '_ZN13PlayerFighter6updateEi': update,
        '_ZN13PlayerFighterC1EiiP6PlayerP10AEGeometryfffb': '\n'.join([
            'push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', t('tuning'), t('speed_seed'), t('hull_seed'), 'bx lr']),
        '_ZN5Level10createShipEiiiP8Waypointbb': '\n'.join([
            'push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', t('hull_level'), t('hull_difficulty'), 'bx lr']),
        '_ZN5Level14connectPlayersEv': '\n'.join([
            'push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', 'none:', membership[0], 'count:', *membership[1:],
            t('player_first', none=link['none'], count=link['count']), 'out:', 'bx lr'])}
    table = [0, 0] + ['f%d' % i for i in range(14)]
    table[2 + slot] = '_ZN13PlayerFighter6updateEi'
    lib, addresses = text_library(functions, {'_ZTV13PlayerFighter': table})
    return reader.extract_opening_npc_guidance(lib, actors), lib, addresses


class AndroidOpeningNpcGuidance(unittest.TestCase):
    def test_named_functions_give_values_and_spans(self):
        result, lib, addresses = android_extract()
        self.assertEqual({k: v for k, v in result.items() if k != 'provenance'}, reader.VALUES)
        p = result['provenance']
        update, players = addresses['_ZN13PlayerFighter6updateEi'], addresses['_ZN5Level14connectPlayersEv']
        self.assertEqual([(p[k]['offset'] - update, p[k]['bytes']) for k in ('selection', 'boost', 'near', 'fire', 'boost_response')],
                         [(4, 92), (98, 244), (342, 44), (388, 164), (558, 106)])
        self.assertEqual([(p[k]['offset'] - players, p[k]['bytes']) for k in ('membership', 'player_first')], [(4, 70), (74, 22)])
        words = [int.from_bytes(lib.data[p['literal_%d' % i]['offset']:][:4], 'little') for i in range(4)]
        self.assertEqual(words, [0x42c80000, 0x42200000, 0x4708b800, 0xc708b800])
        self.assertEqual(lib.data[p['literal_4']['offset']:][:8], struct.pack('<2f', 0.95, 1.05))
        self.assertEqual(len(p), 18)

    def test_each_broken_rule_is_unsupported(self):
        actors = copy.deepcopy(ANDROID_ACTORS)
        actors['actors'][1]['hull_catalogue_id'] = 2
        cases = {
            'no flight': dict(actors={'actors': ANDROID_ACTORS['actors'], 'npc_initialization': {'primary_weapon': {'damage': 3}}}),
            'no weapon': dict(actors={'actors': ANDROID_ACTORS['actors'], 'npc_initialization': {'flight': {'pi': 3.14}}}),
            'other actors': dict(actors=actors),
            'other slot': dict(slot=12),
            **{'no ' + key: dict(drop=(key,)) for key in ('tuning', 'speed_seed', 'hull_seed', 'selection', 'boost', 'near', 'fire',
                                                           'hull_level', 'hull_difficulty', 'player_first', 'response', 'membership')},
            'response elsewhere': dict(response='#resume'),
            'resume elsewhere': dict(resume='#response'),
            'done elsewhere': dict(done='#out'),
            'membership elsewhere': dict(none='#count'),
            'count elsewhere': dict(count='#none'),
            'miss backwards': dict(miss='#back'),
            'keep backwards': dict(keep='#pre'),
            'later backwards': dict(later='#pre'),
            'other near range': dict(other='mov.w r5, #0x1f00'),
            'damage scale': dict(words=('0x42c00000', '0x42200000', '0x4708b800', '0xc708b800')),
            'damage percent': dict(words=('0x42c80000', '0x42400000', '0x4708b800', '0xc708b800')),
            'fire range': dict(words=('0x42c80000', '0x42200000', '0x4709b800', '0xc708b800')),
            'negative fire range': dict(words=('0x42c80000', '0x42200000', '0x4708b800', '0xc709b800')),
            'speed rates': dict(rates='0x3f733333, 0x3f800000'),
        }
        for name, changes in cases.items():
            with self.subTest(name):
                self.assertEqual(android_extract(**changes)[0], {})
