"""Synthetic relocatable staging with changed coordinates and broken links."""
import importlib.util
import struct
from types import SimpleNamespace
import unittest
from gof2_content import opening_staging as reader
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def fixture(mac, relocation=0):
    base = 0x10000 + relocation
    names = ['MAC_INITIAL', 'MAC_FORMATION'] if mac else ['ARM_INITIAL', 'ARM_FORMATION', 'ARM_INITIAL_DISPATCH', 'ARM_UPDATE_DISPATCH']
    specs = [getattr(reader, n) for n in names]
    blocks = [expand(s) for s in specs]
    addresses = [base + i * 1024 for i in range(len(blocks))]
    helper_names = ['player', 'actors', 'events', 'cursor', 'visibility', 'finished', 'camera_vector', 'camera_components', 'position', 'orientation', 'other']
    helpers = {name: base + 8192 + i * 128 for i, name in enumerate(helper_names)}
    raw_helpers = {
        'player': '554889e5488b87680100005dc3' if mac else 'd0f8f0007047',
        'actors': '554889e5488b87780100005dc3' if mac else 'd0f8f8007047',
        'events': '554889e5488b87b00100005dc3' if mac else 'd0f814017047',
        'cursor': '554889e58b87780200005dc3' if mac else 'd0f8d4017047',
        'visibility': '554889e540887758408877595dc3' if mac else '80f8481080f849107047',
        'finished': '554889e58a473124015dc3' if mac else '90f821007047',
        'camera_vector': '554889e5f30f104608f30f1016f30f104e04f30f115710f30f114f14f30f1147185dc3' if mac else '91ed000ad1ed010b80ed020ac0ed030b7047',
        'camera_components': '554889e5f30f114710f30f114f14f30f1157185dc3' if mac else '00f1080989e80e007047'}
    links = [
        {'player': ['41','56','9e','be'], 'actors': ['103','118','133','14d'], 'cursor':['a'], 'visibility':['12b'], 'camera_vector':['96'], 'position':['b6'], 'orientation':['f9']},
        {'player':['10'], 'actors':['1c'], 'events':['4'], 'cursor':['2e'], 'finished':['43'], 'visibility':['1dc'], 'camera_components':['b5'], 'position':['94'], 'orientation':['1c5']}
    ] if mac else [
        {'player':['1a','30','8a','a8'], 'actors':['e2','fa','116','12a'], 'visibility':['10c'], 'camera_vector':['80'], 'position':['9e'], 'orientation':['d6']},
        {'finished':['18'], 'visibility':['19e'], 'camera_components':['82'], 'position':['62'], 'orientation':['186']},
        {'player':['a'], 'cursor':['30']},
        {'events':['3e'], 'player':['46'], 'actors':['4e'], 'cursor':['62']}
    ]
    const_values = {'ref_72':321.0,'ref_7a':-234.0,'ref_82':-456.0,'ref_ad':-234.0,'ref_9d':512.0,'ref_a5':-640.0,'ref_dd':-234.0,'ref_e5':512.0,'ref_ed':-640.0,'ref_fa':-789.0,'ref_102':896.0,'ref_13a':-789.0,'ref_11e':-896.0,'ref_126':1234.0,'ref_15c':-789.0,'ref_148':-2304.0,'ref_164':512.0}
    const = bytearray(); scalar_offsets = {}
    def put(index, key, raw):
        body, fields = blocks[index]; at, size = fields[key]
        assert len(raw) == size, (key,len(raw),size)
        body[at:at+size] = raw
    def cond(at, dest, kind):
        d = dest-at-4
        if kind == 'bne': return struct.pack('<H',0xd100|((d//2)&255))
        d &= 0x1fffff; condition = 0 if kind == 'beq.w' else 1
        return struct.pack('<2H',0xf000|((d>>20)<<10)|(condition<<6)|((d>>12)&63),0x8000|(((d>>18)&1)<<13)|(((d>>19)&1)<<11)|((d>>1)&2047))
    for index, (_, fields) in enumerate(blocks):
        address = addresses[index]
        for key, (offset, size) in fields.items():
            if key.startswith('call_'):
                name = next((name for name, keys in links[index].items() if key[5:] in keys), 'other')
                dest = helpers[name]
                if mac: raw = struct.pack('<i',dest-address-offset-4)
                else:
                    blx = index==3 and key=='call_b0'
                    raw = bytearray(branch(((address+offset+4)&~3)-4 if blx else address+offset,dest))
                    if blx: raw[3] &= ~0x10
                put(index,key,raw)
            elif key.startswith('jump_'):
                if mac:
                    dest = address + ({'jump_16c':0x100}.get(key,800) if index==0 else {'jump_1e7':0x17f,'jump_4e':800,'jump_56':800}.get(key,900))
                    put(index,key,int(dest-address-offset-size).to_bytes(size,'little',signed=True))
                else:
                    dest,kind = [(address+0xdc,'bne'),(address+0x14c if key=='jump_1a6' else address+800,'bne' if key=='jump_1a6' else 'bne.w'),(addresses[0],'beq.w'),(addresses[1],'beq.w')][index]
                    put(index,key,cond(address+offset,dest,kind))
            elif key.startswith('ref_'):
                value = -90.0 if index==0 else const_values.get(key,1.0)
                off = len(const);const.extend(struct.pack('<f',value));scalar_offsets[(index,key)] = 20000+off
                put(index,key,struct.pack('<i',base+0x10000+off-address-offset-4))
            elif key.startswith('pointer_'):
                put(index,key,arm_wide(12,0,key in ('pointer_1e','pointer_8e','pointer_2a','pointer_58','pointer_6c')))
            elif key.startswith('literal_'): put(index,key,bytes.fromhex('dff80010'))
    if mac:
        for axis,value in zip('xyz',[12.0,-34.0,-56.0]): put(0,'camera_'+axis,struct.pack('<f',value))
    else:
        values = [dict(camera_x=(12.0,0),camera_y=(-34.0,0),camera_z=(-56.0,0),player_z=(-90.0,3)),
                  dict(player_x=(321.0,1),player_y=(-234.0,5),player_z=(-456.0,3),camera_y=(512.0,2),camera_z=(-640.0,6),actor_x=(-789.0,5),actor0_y=(896.0,2),actor1_y=(-896.0,2),actor1_z=(1234.0,3),actor2_y=(-2304.0,2))]
        for index,mapping in enumerate(values):
            for name,(value,reg) in mapping.items():
                bits=struct.unpack('<I',struct.pack('<f',value))[0]
                for top in [False,True]:
                    key=name+('_high' if top else '_low');size=blocks[index][1][key][1]
                    val=bits>>16 if top else bits&65535
                    put(index,key,arm_wide(val,reg,top) if size==4 else struct.pack('<H',0x2000|(reg<<8)|val))
    data=bytearray(24000)
    for address,(body,_) in zip(addresses,blocks):data[address-base+256:address-base+256+len(body)]=body
    for name,raw in raw_helpers.items():
        off=helpers[name]-base+256;data[off:off+len(bytes.fromhex(raw))]=bytes.fromhex(raw)
    data[20000:20000+len(const)]=const
    text={'name':b'__text','segment':b'__TEXT','address':base,'offset':256,'length':16000}
    section={'name':b'__const','segment':b'__TEXT','address':base+0x10000,'offset':20000,'length':len(const)}
    mach=SimpleNamespace(data=bytes(data),text=text,sections=[text,section],slice_offset=32768,architecture='x86_64' if mac else 'armv7')
    return mach,blocks,scalar_offsets,helpers


@unittest.skipUnless(importlib.util.find_spec('capstone'),'optional static-reader dependency')
class OpeningStaging(unittest.TestCase):
    def test_relocated_changed_coordinates(self):
        for mac in [True,False]:
            for relocation in [0,0x40000]:
                with self.subTest(mac=mac,relocation=relocation):
                    m,*_=fixture(mac,relocation);out=reader.extract_opening_staging(m)
                    self.assertEqual(out['initial']['player_position'],[0,0,-90])
                    self.assertEqual(out['initial']['camera_position_parameter'],[12,-34,-56])
                    self.assertEqual(out['formation']['player_position'],[321,-234,-456])
                    self.assertEqual(out['formation']['camera_position_parameter'],[-234,512,-640])
                    self.assertEqual([r['position'] for r in out['formation']['actors']],[[-789,896,0],[-789,-896,1234],[-789,-2304,512]])
                    self.assertEqual(out['formation']['after_event_finished'],2)
                    self.assertEqual(out['provenance']['initial']['offset'],33024)

    def test_arm_import_stub_is_bounded(self):
        for length in [16, 15]:
            m, blocks, _, _ = fixture(False)
            address = m.text['address'] + 0x20000
            at, size = blocks[3][1]['call_b0']; site = m.text['address'] + 3072 + at
            raw = bytearray(branch(((site+4)&~3)-4, address)); raw[3] &= ~0x10
            data = bytearray(m.data); data[256+3072+at:256+3072+at+size] = raw
            m.data = bytes(data)
            m.sections.append({'name': b'__picsymbolstub4', 'segment': b'__TEXT', 'address': address, 'offset': 22000, 'length': length})
            self.assertEqual(bool(reader.extract_opening_staging(m)), length == 16)

    def test_broken_context_and_coordinates_rejected(self):
        for mac in [True,False]:
            for bad in ['cursor','finished','visibility','camera','loop','dispatch','pose_link','unbacked_call','nan','truncated','duplicate','gate']:
                with self.subTest(mac=mac,bad=bad):
                    m,blocks,scalars,helpers=fixture(mac);data=bytearray(m.data)
                    if bad in ['cursor','finished','visibility','camera']:
                        name='camera_components' if bad=='camera' else bad
                        data[helpers[name]-m.text['address']+256]^=1
                    elif bad=='truncated':data=data[:300]
                    elif bad=='duplicate':data[256+4096:256+4096+len(blocks[0][0])]=blocks[0][0]
                    elif bad=='nan':
                        if mac:struct.pack_into('<f',data,scalars[(0,'ref_a3')],float('nan'))
                        else:
                            off=256+blocks[0][1]['player_z_high'][0];data[off:off+4]=arm_wide(0x7fc0,3,True)
                    elif bad=='gate':
                        # The fixed zero-phase/event-completed grammar must fail.
                        off=256+1024+(0x3f if mac else 0x12);data[off]^=1
                    else:
                        index=0;key={'loop':'jump_16c' if mac else 'jump_13e','dispatch':'jump_11' if mac else 'jump_36','pose_link':'call_b6' if mac else 'call_9e','unbacked_call':'call_4e' if mac else 'call_26'}[bad]
                        if not mac and bad=='dispatch':index=2
                        at,size=blocks[index][1][key];off=256+1024*index+at
                        if bad=='unbacked_call':data[off:off+size]=struct.pack('<i',0x70000000) if mac else branch(m.text['address']+1024*index+at,m.text['address']+0x100000)
                        elif mac and bad=='dispatch':data[off:off+size]=int(4-at-size).to_bytes(size,'little',signed=True)
                        else:data[off]^=0x10
                    m.data=bytes(data)
                    self.assertEqual(reader.extract_opening_staging(m),{})

if __name__=='__main__':unittest.main()


def halves(value):
    word, = struct.unpack('<I', struct.pack('<f', value))
    return word & 0xffff, word >> 16


def word_float(word):
    return struct.unpack('<f', struct.pack('<I', word))[0]


# Low halves differ wherever the code builds a float from two halves (movs takes 8 bits).
ANDROID_POSES = dict(camera=(word_float(0xc4960001), word_float(0xc3c80002), -30000.0), player_z=-50000.0, player=(16000.0, -11000.0, -35000.0),
                     camera_y=1500.0, camera_z=-400.0, actor_x=-9000.0, actor_y=(600.0, -250.0, -100.0), actor1_z=-1600.0)
STAGING_CALLEES = ['_ZN5Level9getPlayerEv', '_ZN5Level10getEnemiesEv', '_ZN5Level11getMessagesEv',
                   '_ZN6Status25getCurrentCampaignMissionEv', '_ZN9PlayerEgo10setCollideEb', '_ZN9PlayerEgo21setComputerControlledEb',
                   '_ZN6Player13setVulnerableEb', '_ZN18TargetFollowCamera12setLookAtCamEb',
                   '_ZN18TargetFollowCamera11setPositionERKN11AbyssEngine6AEMath6VectorE', '_ZN9PlayerEgo11setPositionEfff',
                   '_ZN10AEGeometry12setDirectionERKN11AbyssEngine6AEMath6VectorES4_', '_ZN8KIPlayer10setToSleepEv',
                   '_ZN10AEGeometry10setVisibleEb', '_ZN12RadioMessage6isOverEv', '_ZN18TargetFollowCamera11setPositionEfff',
                   '_ZN11AbyssEngine11PaintCanvas16CameraGetCurrentEv', '_ZN11AbyssEngine11PaintCanvas14CameraGetLocalEj',
                   '_ZN11AbyssEngine6AEMath20MatrixSetTranslationERNS0_6MatrixEfff']


def android(cursors=(0, 0), dispatches=(1, 1), hidden=3, shown=3, message=8, loop_back=True, shown_by='_ZN10AEGeometry10setVisibleEb',
            gap=False, tail=None, extra=(), omit=None, **poses):
    """LevelScript's constructor and process in the Android compiler's shape. Returns (library, function addresses).

    `tail(asm, labels, call)` emits the code the formation gate skips to (default: return); `extra`
    functions join the library, replacing stubs of the same name.
    """
    from android_fixture import TEXT, Thumb
    from gof2_content.android_library import AndroidLibrary
    from test_steering import add_imm, add_pc, adds8, assemble, b_to, blx_reg, cmp_imm, ldr_reg, ldr_w, roomy_library, strb_w
    p = dict(ANDROID_POSES, **poses)
    at = {name: TEXT + 0x40 * i for i, name in enumerate(STAGING_CALLEES)}
    stubs = dict(at)
    at.update({name: address for name, _, address in extra})
    constructor, process = TEXT + 0x800, TEXT + 0xc00

    def call(asm, name): return asm.call(at[name])

    def pair(asm, register, value, low='movw'):
        lo, hi = halves(value)
        return (asm.movs(register, lo) if low == 'movs' else asm.movw(register, lo)), hi

    def status(asm, cursor):
        add_pc(ldr_w(asm, 0, 15, 0x40), 0).ldr(0, 0, 0).ldr(0, 0, 0)
        return cmp_imm(call(asm, '_ZN6Status25getCurrentCampaignMissionEv'), 0, cursor)

    def enemy(asm, register=4):
        return ldr_reg(call(asm.mov(0, 10), '_ZN5Level10getEnemiesEv').ldr(0, 0, 4), 0, 0, register, 2)

    def emit_constructor(asm, L):
        asm.push()
        for _ in range(dispatches[0]):
            call(asm.movs(1, 0).movs(6, 0), '_ZN9PlayerEgo10setCollideEb')
            b_to(status(asm, cursors[0]).str_sp(4, 0x44), L.get('initial', asm.here() + 4), 'eq')
        asm.pop().label('initial')
        if gap:
            asm.nop()
        strb_w(ldr_w(asm.strd(6, 6, 4, 0).ldr_sp(0, 0x4c).strb(6, 0, 1).mov(0, 10), 9, 13, 0x48), 6, 9, 0x48)
        call(call(asm, '_ZN5Level9getPlayerEv').movs(1, 1).movs(4, 1), '_ZN9PlayerEgo21setComputerControlledEb')
        call(call(asm.mov(0, 10), '_ZN5Level9getPlayerEv').ldr(0, 0, 0).movs(1, 1), '_ZN6Player13setVulnerableEb')
        call(strb_w(asm.mov(0, 11).movs(1, 1), 4, 8, 0x21), '_ZN18TargetFollowCamera12setLookAtCamEb')
        x, y, z = p['camera']
        asm, high = pair(asm, 0, x, 'movs')
        asm.add_sp(1, 0x98).movt(0, high).str_sp(0, 0x98)
        asm, high = pair(asm, 0, y, 'movs')
        asm, high2 = pair(asm.movt(0, high).str_sp(0, 0x9c), 0, z)
        asm.movt(0, high2).str_sp(0, 0xa0).mov(0, 11)
        call(asm, '_ZN18TargetFollowCamera11setPositionERKN11AbyssEngine6AEMath6VectorE')
        call(asm.mov(0, 10), '_ZN5Level9getPlayerEv')
        asm, high = pair(asm, 3, p['player_z'])
        call(asm.movs(1, 0).movt(3, high).movs(2, 0), '_ZN9PlayerEgo11setPositionEfff')
        call(asm.mov(0, 10), '_ZN5Level9getPlayerEv').ldr(0, 0, 8).mov_imm(1, 0x3f800000).strd(6, 6, 13, 0x98).add_sp(2, 0x5c)
        asm.str_sp(1, 0xa0).strd(6, 1, 13, 0x5c).add_sp(1, 0x98).str_sp(6, 0x64)
        call(asm, '_ZN10AEGeometry12setDirectionERKN11AbyssEngine6AEMath6VectorES4_').movs(4, 0).label('loop')
        call(enemy(asm), '_ZN8KIPlayer10setToSleepEv')
        call(ldr_reg(call(asm.mov(0, 10), '_ZN5Level10getEnemiesEv').ldr(0, 0, 4).movs(1, 0), 0, 0, 4, 2).ldr(0, 0, 8),
             '_ZN10AEGeometry10setVisibleEb')
        enemy(asm).str_w(6, 0, 0x124)
        adds8(enemy(asm), 4, 1)
        strb_w(cmp_imm(asm, 4, hidden).ldr(0, 0, 4), 6, 0, 0x5c)
        b_to(asm, L.get('loop' if loop_back else 'initial', asm.here() + 4), 'ne').pop()

    def actor(asm):
        return blx_reg(asm.ldr(1, 0, 0).ldr(4, 1, 0x48).mov(1, 5), 4)

    def emit_process(asm, L):
        asm.push()
        for _ in range(dispatches[1]):
            call(ldr_w(asm, 0, 10, 0x18), '_ZN5Level11getMessagesEv').mov(6, 0)
            call(ldr_w(asm, 0, 10, 0x18), '_ZN5Level9getPlayerEv').mov(8, 0)
            call(ldr_w(asm, 0, 10, 0x18), '_ZN5Level10getEnemiesEv').mov(11, 0)
            b_to(status(asm, cursors[1]).mov(0, 11).str_sp(0, 0x50).str_w(9, 13, 0x48), L.get('formation', asm.here() + 4), 'eq', True)
        asm.pop().label('formation')
        call(asm.ldr(0, 6, 4).ldr(0, 0, message), '_ZN12RadioMessage6isOverEv')
        ldr_w(asm, 1, 10, 0x1c)
        cmp_imm(cmp_imm(asm, 0, 1).strd(6, 8, 13, 0x40).it_eq(), 1, 0)
        b_to(asm, L.get('end', asm.here() + 4), 'ne', True)
        (px, ph), (py, pyh), (pz, pzh) = (halves(v) for v in p['player'])
        asm.movw(5, py).movw(1, px).movw(3, pz).movs(0, 1).movt(5, pyh).str_w(0, 10, 0x1c).movt(1, ph).movt(3, pzh)
        call(asm.mov(0, 8).mov(2, 5), '_ZN9PlayerEgo11setPositionEfff')
        (cy, cyh), (cz, czh) = halves(p['camera_y']), halves(p['camera_z'])
        ldr_w(asm.movw(9, cy).movs(4, cz), 0, 10, 0x14).movt(9, cyh).movt(4, czh).mov(1, 5).mov(2, 9).mov(3, 4)
        call(asm, '_ZN18TargetFollowCamera11setPositionEfff')
        add_pc(ldr_w(asm, 0, 15, 0x80), 0).ldr(0, 0, 0).ldr(6, 0, 0).mov(0, 6)
        call(call(asm, '_ZN11AbyssEngine11PaintCanvas16CameraGetCurrentEv').mov(1, 0).mov(0, 6), '_ZN11AbyssEngine11PaintCanvas14CameraGetLocalEj')
        add_imm(asm, 8, 13, 0x1e8).mov(1, 0).mov(2, 5).mov(3, 9).mov(0, 8).str_sp(4, 0)
        call(asm, '_ZN11AbyssEngine6AEMath20MatrixSetTranslationERNS0_6MatrixEfff')
        (ax, axh), (a0, a0h), (a1, a1h), (a2, a2h), (z1, z1h) = (halves(v) for v in (p['actor_x'], *p['actor_y'], p['actor1_z']))
        actor(ldr_w(asm, 0, 11, 4).movw(5, ax).movs(2, a0).movt(5, axh).movt(2, a0h).movs(3, 0).ldr(0, 0, 0).movs(6, 0))
        actor(ldr_w(asm, 0, 11, 4).movs(2, a1).movw(3, z1).movt(2, a1h).movt(3, z1h).ldr(0, 0, 4))
        actor(ldr_w(asm, 0, 11, 4).movs(2, a2).movt(2, a2h).mov(3, 9).ldr(0, 0, 8))
        add_imm(asm, 9, 13, 0x190).mov_imm(4, 0x3f800000).movs(5, 0).label('loop')
        ldr_reg(ldr_w(asm, 0, 11, 4).mov(1, 8).mov(2, 9), 0, 0, 5, 2).ldr(0, 0, 8)
        asm.strd(4, 6, 13, 0x1e8).str_sp(6, 0x1f0).strd(6, 4, 13, 0x190).str_sp(6, 0x198)
        call(asm, '_ZN10AEGeometry12setDirectionERKN11AbyssEngine6AEMath6VectorES4_')
        call(ldr_reg(ldr_w(asm, 0, 11, 4).movs(1, 1), 0, 0, 5, 2).ldr(0, 0, 8), shown_by)
        b_to(cmp_imm(adds8(asm, 5, 1), 5, shown), L.get('loop', asm.here() + 4), 'ne').label('end')
        tail(asm, L, call) if tail else asm.pop()

    replaced = {f[0] for f in extra}
    functions = [(name, Thumb(address).ret().finish(), address) for name, address in stubs.items() if name not in replaced] + list(extra)
    functions += [('_ZN11LevelScriptC2EP5LevelP3HudP5RadarP18TargetFollowCamera', assemble(constructor, emit_constructor).finish(), constructor),
                  ('_ZN11LevelScript7processEi', assemble(process, emit_process).finish(), process)]
    return AndroidLibrary(roomy_library([f for f in functions if f[0] != omit])), (constructor, process)


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidOpeningStaging(unittest.TestCase):
    def test_named_declarations_give_poses_and_spans(self):
        lib, (constructor, process) = android()
        result = reader.extract_opening_staging(lib)
        self.assertEqual(result['initial'], {'player_position': [0.0, 0.0, -50000.0], 'player_forward': [0, 0, 1], 'player_up': [0, 1, 0],
                                             'camera_position_parameter': list(ANDROID_POSES['camera']), 'hidden_actor_ids': [0, 1, 2]})
        self.assertEqual(result['formation'], {
            'after_event_finished': 2, 'player_position': [16000.0, -11000.0, -35000.0], 'camera_position_parameter': [-11000.0, 1500.0, -400.0],
            'actors': [{'actor_id': i, 'position': position, 'forward': [1, 0, 0], 'up': [0, 1, 0], 'visible': True}
                       for i, position in enumerate([[-9000.0, 600.0, 0.0], [-9000.0, -250.0, -1600.0], [-9000.0, -100.0, 1500.0]])]})
        self.assertEqual({k: (v['offset'] - (constructor if k.startswith('initial') else process), v['bytes'])
                          for k, v in result['provenance'].items()},
                         {'initial_dispatch': (2, 28), 'initial': (32, 222), 'update_dispatch': (2, 58), 'formation': (62, 278)})

    def test_each_broken_declaration_is_unsupported(self):
        cases = {'initial cursor': dict(cursors=(1, 0)), 'formation cursor': dict(cursors=(0, 1)), 'two initial dispatches': dict(dispatches=(2, 1)),
                 'two formation dispatches': dict(dispatches=(1, 2)), 'hidden count': dict(hidden=2), 'shown count': dict(shown=4),
                 'message': dict(message=0xc), 'loop target': dict(loop_back=False), 'shown by': dict(shown_by='_ZN8KIPlayer10setToSleepEv'),
                 'nan': dict(player=(float('nan'), -11000.0, -35000.0)), 'far': dict(camera=(-1200.0, -400.0, -3e7)), 'gap': dict(gap=True),
                 'infinite': dict(actor_x=float('-inf'))}
        cases.update({name: dict(omit=name) for name in ('_ZN11LevelScriptC2EP5LevelP3HudP5RadarP18TargetFollowCamera',
                                                         '_ZN11LevelScript7processEi', '_ZN12RadioMessage6isOverEv')})
        for name, options in cases.items():
            self.assertEqual(reader.extract_opening_staging(android(**options)[0]), {}, name)
