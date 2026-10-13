"""Import resource IDs for the verified location reflection selector.

Static contexts link to the existing location predicate and sky getter. Only
numeric resource IDs and provenance leave this reader, never executable bytes.

Android: MGame::OnInitialize picks the special cube when Status::inAlienOrbit,
else the base plus SolarSystem::getTextureIndex of Status::getSystem, loads it
through PaintCanvas::TextureCreate (as the opening sky in Level::createSpace)
and binds it with PaintCanvas::ChangeCubeTexture.
"""
from .opening_loadout import template
from .ship_models import section_bytes


ANDROID_SELECT = r"""ldr r0, =\w+
adr r0, (?P<status>\w+)
ldr r0, \[r0\]
ldr r0, \[r0\]
call _ZN6Status12inAlienOrbitEv
ldr\.w (?P<canvas>\w+), \[(?P<game>\w+), #4\]
cmp r0, #1
bne #(?P<sky>\w+)
add r2, sp, #(?P<slot>\w+)
mov r0, (?P=canvas)
movw r1, #(?P<special_id>\w+)
b #(?P<load>\w+)
ldr r0, =\w+
adr r0, (?P=status)
ldr r0, \[r0\]
ldr r0, \[r0\]
call _ZN6Status9getSystemEv
call _ZN11SolarSystem15getTextureIndexEv
movw r1, #(?P<texture_base>\w+)
add r0, r1
add r2, sp, #(?P=slot)
uxth r1, r0
mov r0, (?P=canvas)
(?P<loader>movs r3, #0)
call _ZN11AbyssEngine11PaintCanvas13TextureCreateEtRjb
ldr r1, \[sp, #(?P=slot)\]
ldr\.w r0, \[(?P=game), #4\]
call _ZN11AbyssEngine11PaintCanvas17ChangeCubeTextureEj
"""
# Unit 7 (0x84c7) takes the cube (0x8513); unit 0 is restored.
ANDROID_BIND = r"""push {r4, r5, r7, lr}
add r7, sp, #8
mov r5, r0
ldr r0, =\w+
mov r4, r1
adr r0, \w+
ldr r0, \[r0\]
ldrb r0, \[r0\]
cbz r0, #\w+
ldr r0, \[r5, #0x10\]
cmp r0, r4
bls #\w+
ldr r0, \[r5, #0x14\]
ldr\.w r0, \[r0, r4, lsl #2\]
ldrb r1, \[r0, #0x10\]
cbz r1, #\w+
ldr r0, =\w+
adr r0, \w+
ldr r0, \[r0\]
str r4, \[r0\]
movw r0, #0x84c7
call glActiveTexture
ldr r0, \[r5, #0x14\]
ldr\.w r0, \[r0, r4, lsl #2\]
ldr r1, \[r0\]
movw r0, #0x8513
call glBindTexture
movw r0, #0x84c0
pop\.w {r4, r5, r7, lr}
b\.w #\w+
adds r0, #4
call _ZNK11AbyssEngine6String9GetAECharEv
cbz r0, #\w+
pop\.w {r4, r5, r7, lr}
b\.w #\w+
pop {r4, r5, r7, pc}
"""
# The fresh opening (campaign mission 0, world type 3) jumps to its sky texture load.
ANDROID_OPENING = r"""call _ZN6Status25getCurrentCampaignMissionEv
cbnz r0, #(?P<other>\w+)
ldr\.w r0, \[(?P<level>\w+), #0xc0\]
cmp r0, #3
bne #(?P=other)
ldr r0, =\w+
movw r1, #\w+
mov r2, \w+
movs r3, #0
adr r0, \w+
ldr (?P<canvas>\w+), \[r0\]
ldr r0, \[(?P=canvas)\]
call _ZN11AbyssEngine11PaintCanvas10MeshCreateEtRjb
ldr r0, \[(?P=canvas)\]
add\.w r2, (?P=level), #0x198
movw r1, #\w+
b #(?P<texture>\w+)
"""
ANDROID_LOAD = ['movs r3, #0', 'call _ZN11AbyssEngine11PaintCanvas13TextureCreateEtRjb']


def android_selection(lib, projection, sky):
    from .android_listing import Listing, number
    # The parents must have proven these contexts; on Android they are found here by name.
    contexts = sky.get('provenance', {})
    if not ('predicate' in projection.get('provenance', {}) and 'system' in contexts and 'texture' in contexts):
        return {}
    game, space = Listing(lib, '_ZN5MGame12OnInitializeEv'), Listing(lib, '_ZN5Level11createSpaceEv')
    selects, openings = game.find(ANDROID_SELECT), space.find(ANDROID_OPENING)
    if len(selects) != 1 or len(openings) != 1:
        return {}
    select = selects[0]
    if (number(select['sky']) != game.code[game.index(select, 'load') + 1].address
            or number(select['load']) != game.code[game.index(select, 'loader')].address):
        return {}
    load = space.at(number(openings[0]['texture']))
    bind = Listing(lib, '_ZN11AbyssEngine11PaintCanvas17ChangeCubeTextureEj')
    binds = bind.find(ANDROID_BIND)
    index = Listing(lib, '_ZN11SolarSystem15getTextureIndexEv')
    predicate, system = Listing(lib, '_ZN6Status12inAlienOrbitEv'), Listing(lib, '_ZN6Status9getSystemEv')
    if (load is None or space.lines[load:load + 2] != ANDROID_LOAD or len(binds) != 1 or bind.index(binds[0]) != 0
            or index.lines != ['ldr r0, [r0, #0x30]', 'bx lr'] or not predicate or not system):
        return {}
    values = {key: number(select[key]) for key in ['texture_base', 'special_id']}
    if not all(0 <= v <= 65533 for v in values.values()):
        return {}
    return dict(values, provenance={'select': game.match_span(select), 'bind': bind.match_span(binds[0]),
                                    'predicate': predicate.span(0, len(predicate.code) - 1),
                                    'system': system.span(0, len(system.code) - 1),
                                    'sky_index': index.span(0, 1), 'load_context': space.span(load, load + 1)})


def extract_reflection_selection(mach, projection, sky):
    if mach.architecture == 'android-armv7':
        return android_selection(mach, projection, sky) if projection and sky else {}
    if not projection or not sky or mach.architecture not in ['x86_64','armv7']: return {}
    import capstone
    mac=mach.architecture=='x86_64';prefix='MAC_' if mac else 'ARM_'
    text=mach.text;base=text['address'];file_base=mach.slice_offset+text['offset']
    code=mach.data[text['offset']:text['offset']+text['length']]
    decoder=capstone.Cs(capstone.CS_ARCH_ARM,capstone.CS_MODE_THUMB);decoder.detail=True
    provenance={}
    def require(value):
        if not value:raise ValueError('Unsupported reflection selector')
    def instruction(m,key):
        rows=list(decoder.disasm(m[key],base+m.start(key)))
        require(len(rows)==1 and rows[0].size==len(m[key]));return rows[0]
    def target(m,key):
        return base+m.end(key)+int.from_bytes(m[key],'little',signed=True) if mac else instruction(m,key).operands[0].imm
    def match(key,address=None):
        name=prefix+key.upper()
        pattern=template((MAC_BIND, MAC_BIND_ALTERNATE) if mac and key=='bind' else globals()[name])
        matches=([pattern.match(code,address-base)] if address is not None else [m for m in pattern.finditer(code) if mac or m.start()%2==0])
        require(len(matches)==1 and matches[0] is not None);m=matches[0]
        if not mac:
            for field,expected in ARM_FIELDS[name].items():
                i=instruction(m,field);require(i.mnemonic==expected['kind'])
                if 'register' in expected:require(i.reg_name(i.operands[0].reg)==expected['register'])
        for field in m.groupdict():
            if field.startswith('call_'):
                at=target(m,field)
                require(section_bytes(mach,at,2,b'__text') is not None or section_bytes(mach,at,6 if mac else 16,b'__stubs' if mac else b'__picsymbolstub4') is not None)
        provenance[key]={'offset':file_base+m.start(),'bytes':len(m[0])};return m
    def inherited(key,row):
        require(isinstance(row,dict) and row['bytes']>0)
        at=base+row['offset']-file_base
        require(section_bytes(mach,at,row['bytes'],b'__text') is not None)
        provenance[key]=dict(row);return at
    try:
        selection=match('select');binding=match('bind',target(selection,'call_59' if mac else 'call_5a'))
        require(target(selection,'call_a' if mac else 'call_14')==inherited('predicate',projection['provenance']['predicate']))
        require(target(selection,'call_2f' if mac else 'call_30')==inherited('system',sky['provenance']['system']))
        index=target(selection,'call_37' if mac else 'call_36')
        raw=bytes.fromhex('554889e58b473c5dc3' if mac else '006b7047')
        found=section_bytes(mach,index,len(raw),b'__text');require(found is not None and found[0]==raw)
        provenance['sky_index']={'offset':found[1],'bytes':len(raw)}
        context=inherited('load_context',sky['provenance']['texture'])
        raw=section_bytes(mach,context,7 if mac else 6,b'__text')[0]
        if mac:
            require(raw[:3]==bytes.fromhex('31c9e8'))
            loader=context+7+int.from_bytes(raw[3:],'little',signed=True)
            require(target(selection,'ref_0')==target(selection,'ref_25'))
            require(len({target(binding,k) for k in ['call_5e','call_8b','call_123']})==1)
            require(target(binding,'call_10d')==target(binding,'call_13f'))
        else:
            require(raw[:2]==bytes.fromhex('0023'))
            rows=list(decoder.disasm(raw[2:],context+2));require(len(rows)==1 and rows[0].mnemonic=='bl')
            loader=rows[0].operands[0].imm
            require(len({target(binding,k) for k in ['call_3c','call_50','call_c2']})==1)
            require(target(binding,'call_b8')==target(binding,'call_e8'))
        require(target(selection,'call_4d' if mac else 'call_4a')==loader)
        values={key:int.from_bytes(selection[key],'little') if mac else instruction(selection,key).operands[1].imm for key in ['texture_base','special_id']}
        require(all(0<=v<=65533 for v in values.values()))
        spans=sorted((r['offset'],r['offset']+r['bytes']) for r in provenance.values())
        require(all(a[1]<=b[0] for a,b in zip(spans,spans[1:])))
        return dict(values,provenance=provenance)
    except (ValueError,KeyError,IndexError,TypeError,OverflowError):return {}

MAC_SELECT = """
488d05
{ref_0:4}
488b38e8
{call_a:4}
498b5e0884c0740e488d55d44889dfbe
{special_id:4}
eb26488d05
{ref_25:4}
488b38e8
{call_2f:4}
4889c7e8
{call_37:4}
05
{texture_base:4}
488d55d40fb7f04889df31c9e8
{call_4d:4}
498b7e088b75d4e8
{call_59:4}
"""

MAC_BIND = """
554889e54883ec40488d05
{ref_8:4}
48897df88975f4488b7df8f6000148897dd80f8505000000e918010000817df4000000000f82100000008b45f4488b4dd83b41180f8205000000e9f6000000488b45d84805180000008b75f44889c7e8
{call_5e:4}
488b00f6401c010f857f000000488d3d
{ref_70:4}
488b45d84805180000008b75f448897dd04889c7e8
{call_8b:4}
488b004805080000004889c7e8
{call_9c:4}
488945e8488b75e88b55f4488b7dd0b000e8
{call_b2:4}
48817de8000000000f841d000000488b45e8483d00000000488945c80f8409000000488b7dc8e8
{call_dd:4}
48c745e800000000e955000000bfc0840000b813850000b9c7840000c605
{ref_fe:4}
01897dc489cf8945c0e8
{call_10d:4}
488b55d84881c2180000008b75f44889d7e8
{call_123:4}
488b000fb708894de48b75e48b7dc0e8
{call_137:4}
8b7dc4e8
{call_13f:4}
4883c4405dc3
"""

# Same linked texture selection with the newer compiler's binding helper.
MAC_BIND_ALTERNATE = """
554889e54883ec30488d05
{ref_8:4}
48897df88975f4488b7df8f6000148897dd80f8505000000e904010000817df4000000000f82100000008b45f4488b4dd83b41180f8205000000e9e2000000488b45d84805180000008b75f44889c7e8
{call_5e:4}
488b00f6401c010f8577000000488b45d84805180000008b75f44889c7e8
{call_8b:4}
488b004805080000004889c7e8
{call_9c:4}
488d3d
{ref_70:4}
488945e8488b75e88b55f4b000e8
{call_b2:4}
48817de8000000000f841d000000488b45e8483d00000000488945d00f8409000000488b7dd0e8
{call_dd:4}
48c745e800000000e949000000bfc78400008b45f48905
{ref_fe:4}
e8
{call_10d:4}
488b4dd84881c1180000008b75f44889cfe8
{call_123:4}
bf13850000488b000fb7308975e48b75e4e8
{call_137:4}
bfc0840000e8
{call_13f:4}
4883c4305dc3
"""

ARM_SELECT = """
{global_low:4}
4ff0ff36
{global_high:4}
7844056828680c96
{call_14:4}
d8f80440012805d10c9608aa2046
{special_id:4}
0de028680c96
{call_30:4}
0c96
{call_36:4}
{texture_base:4}
084408aa0c9681b220460023
{call_4a:4}
08994ff0ff36d8f804000c96
{call_5a:4}
"""

ARM_BIND = """
80b56f4688b0
{ref_6:4}
{ref_a:4}
7a441268079006910798117811f0010f039000d163e00698002804d3069803990a69904200d35ae0039810300699
{call_3c:4}
0068007c10f0010f2bd1039810300699
{call_50:4}
00680430
{call_58:4}
{ref_5c:4}
{ref_60:4}
794405900598069a029008460299
{call_72:4}
0020c0f20000059981420ad00020c0f2000005998142019102d00198
{call_92:4}
ffe70020c0f20000059024e048f2c740c0f20000
{ref_aa:4}
{ref_ae:4}
7944069a0a60
{call_b8:4}
039810300699
{call_c2:4}
48f21351c0f200010068006804900498009008460099
{call_dc:4}
48f2c040c0f20000
{call_e8:4}
08b080bd
"""

ARM_FIELDS = {'ARM_SELECT': {'global_low': {'kind': 'movw', 'register': 'r0'}, 'global_high': {'kind': 'movt', 'register': 'r0'}, 'call_14': {'kind': 'bl'}, 'special_id': {'kind': 'movw', 'register': 'r1'}, 'call_30': {'kind': 'bl'}, 'call_36': {'kind': 'bl'}, 'texture_base': {'kind': 'movw', 'register': 'r1'}, 'call_4a': {'kind': 'bl'}, 'call_5a': {'kind': 'bl'}}, 'ARM_BIND': {'ref_6': {'kind': 'movw', 'register': 'r2'}, 'ref_a': {'kind': 'movt', 'register': 'r2'}, 'call_3c': {'kind': 'blx'}, 'call_50': {'kind': 'blx'}, 'call_58': {'kind': 'bl'}, 'ref_5c': {'kind': 'movw', 'register': 'r1'}, 'ref_60': {'kind': 'movt', 'register': 'r1'}, 'call_72': {'kind': 'bl'}, 'call_92': {'kind': 'blx'}, 'ref_aa': {'kind': 'movw', 'register': 'r1'}, 'ref_ae': {'kind': 'movt', 'register': 'r1'}, 'call_b8': {'kind': 'blx'}, 'call_c2': {'kind': 'blx'}, 'call_dc': {'kind': 'blx'}, 'call_e8': {'kind': 'blx'}}}
