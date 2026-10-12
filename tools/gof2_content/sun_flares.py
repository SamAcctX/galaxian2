"""Recover original flare resources and color declarations by static reading.

Bounded compiler contexts only identify constant tables and literal colors.
No source instructions are emitted or executed by the native game.

Android: LensFlare::LensFlare creates three consecutive flare images;
StarSystem::StarSystem(int) stores the flare type from a table at
SolarSystem::getIndex() (StarSystem+0x3c, LensFlare::render2D's int
argument); render2D picks red, green and blue from three tables for types
0-4, else 255, and passes them to PaintCanvas::SetColor in that order;
BuildResourceList declares each image's texture and region.
"""
import re
import struct
from .opening_loadout import template
from .opening_sky import android_getter
from .ship_models import section_bytes

ANDROID_RESOURCES = r"""movs r0, #0xc
mov r8, r1
call _Znaj
mov r2, r0
ldr r0, =\w+
str\.w r2, \[sb, #0x10\]
mov(?:\.w|w) r1, #(?P<first>\w+)
adr r0, \w+
ldr r0, \[r0\]
ldr r0, \[r0\]
call _ZN11AbyssEngine11PaintCanvas13Image2DCreateEtRj
ldr r0, =\w+
movs r6, #4
movw r5, #(?P<second>\w+)
adr r0, \w+
ldr r4, \[r0\]
(?P<loop>ldr\.w r1, \[sb, #0x10\]
)ldr r0, \[r4\]
adds r2, r1, r6
uxth r1, r5
call _ZN11AbyssEngine11PaintCanvas13Image2DCreateEtRj
adds r6, #4
adds r5, #1
cmp r6, #0xc
bne #(?P<back>\w+)
"""
ANDROID_SYSTEM_TYPE = r"""ldr r0, \[r4\]
call _ZN6Status9getSystemEv
call _ZN11SolarSystem8getIndexEv
ldr r1, =\w+
adr r1, (?P<table>\w+)
ldr\.w r0, \[r1, r0, lsl #2\]
str\.w r0, \[sb, #0x3c\]
"""
ANDROID_PALETTE = r"""ldr r5, \[r7, #0x18\]
vmov s0, r3
mov r4, r0
cmp r5, #4
bhi #(?P<fallback>\w+)
ldr r0, =\w+
ldr r3, =\w+
ldr r6, =\w+
adr r0, (?P<red>\w+)
adr r3, (?P<green>\w+)
adr r6, (?P<blue>\w+)
ldr\.w sb, \[r0, r5, lsl #2\]
ldr\.w sl, \[r3, r5, lsl #2\]
ldr\.w r8, \[r6, r5, lsl #2\]
b #(?P<join>\w+)
"""
ANDROID_FALLBACK = r"""(?P<b>mov\.w r8, #(?P<blue>\w+)
)(?P<g>mov\.w sl, #(?P<green>\w+)
)(?P<r>mov\.w sb, #(?P<red>\w+)
)"""
ANDROID_CHANNELS = r"""(?P<g>uxtb\.w r2, sl
)vldr s26, =0x42f00000
(?P<b>uxtb\.w r3, r8
)vsub\.f32 s0, s24, s0
ldr r0, =\w+
adr r0, \w+
ldr\.w fp, \[r0\]
vsub\.f32 s0, s26, s0
ldr\.w r0, \[fp\]
vcvt\.u32\.f32 s0, s0
vmov r1, s0
str r1, \[sp\]
(?P<r>uxtb\.w r1, sb
)str r1, \[sp, #0x24\]
str r2, \[sp, #0x20\]
str r3, \[sp, #0x1c\]
call _ZN11AbyssEngine11PaintCanvas8SetColorEhhhh
"""
# An image record (16 bytes: id, kind 3, -1, payload) and its payload (texture, region).
# Texture, kind and -1 registers may hold values set by the previous record.
ANDROID_IMAGE = r"""movs r0, #0x10
call _Znwj
mov r4, r0
movs r0, #4
call _Znwj
(?:movw r8, #\w+
)?movs r1, #(?P<region>\w+)
(?P<texture>strh\.w r8, \[r0\]
)(?:movs r6, #3
)?strh r1, \[r0, #2\]
mov(?:w|\.w) r1, #(?P<id>\w+)
(?:mov\.w r5, #-1
)?strh r1, \[r4\]
(?P<kind>strd r6, r5, \[r4, #4\]
)str r0, \[r4, #0xc\]
(?:movw|mov\.w) r0, #\w+
str\.w r4, \[sl, r0\]
"""


def android_images(lib, ids):
    """The three image records for ids in BuildResourceList, and one span over them and the values they use."""
    from .android_listing import Listing, number
    build = Listing(lib, '_Z17BuildResourceListPN11AbyssEngine6EngineE')
    images, lines = {}, []
    for m in build.find(ANDROID_IMAGE):
        image = number(m['id'])
        if image not in ids:
            continue
        sources = [build.definition(build.index(m, group), register) for group, register in (('texture', 'r8'), ('kind', 'r6'), ('kind', 'r5'))]
        values = [re.fullmatch(shape, build.lines[i]) if i is not None else None
                  for shape, i in zip((r'movw r8, #(\w+)', r'movs r6, #3', r'mov\.w r5, #-1'), sources)]
        if image in images or not all(values):
            return None
        images[image] = {'id': image, 'texture_id': number(values[0][1]), 'region': number(m['region'])}
        lines += sources + [build.index(m), build.last(m)]
    if len(images) != 3 or any(v['texture_id'] > 65533 for v in images.values()):
        return None
    return [images[i] for i in ids], build.span(min(lines), max(lines))


def android_flares(lib, sky):
    from .android_listing import Listing, number
    flare = Listing(lib, '_ZN9LensFlareC1EPN11AbyssEngine11PaintCanvasE')
    system = Listing(lib, '_ZN10StarSystemC1Ei')
    render = Listing(lib, '_ZN9LensFlare8render2DEfffi')
    resources, types, palette, channels = (listing.find(shape) for listing, shape in
                                           ((flare, ANDROID_RESOURCES), (system, ANDROID_SYSTEM_TYPE),
                                            (render, ANDROID_PALETTE), (render, ANDROID_CHANNELS)))
    if (not all(key in sky.get('provenance', {}) for key in ('system', 'system_id'))
            or len(resources) != 1 or len(types) != 1 or len(palette) != 1 or len(channels) != 1):
        return {}
    resources, types, palette, channels = resources[0], types[0], palette[0], channels[0]
    first = number(resources['first'])
    ids = [first, first + 1, first + 2]
    # The loop creates second and second + 1 (offsets 4 and 8 of a 12-byte array).
    if number(resources['second']) != first + 1 or flare.at(number(resources['back'])) != flare.index(resources, 'loop') or first > 65531:
        return {}
    fallback = [m for m in render.find(ANDROID_FALLBACK) if render.index(m) == render.at(number(palette['fallback']))]
    images = android_images(lib, ids)
    if not fallback or not images or render.at(number(palette['join'])) != render.last(fallback[0]) + 1:
        return {}
    fallback = fallback[0]
    # SetColor gets red, green and blue from the registers the palette or its fallback set.
    if any(render.definition(render.index(channels, group), register) != render.index(fallback, group)
           for group, register in (('r', 'sb'), ('g', 'sl'), ('b', 'r8'))):
        return {}
    provenance = {'system': android_getter(lib, '_ZN6Status9getSystemEv'), 'system_id': android_getter(lib, '_ZN11SolarSystem8getIndexEv'),
                  'resources': flare.match_span(resources), 'system_type': system.match_span(types), 'palette': render.match_span(palette),
                  'fallback': render.match_span(fallback), 'channels': render.match_span(channels), 'images': images[1]}
    tables = {}
    for key, address, count in (('system_types', number(types['table']), 34), ('red', number(palette['red']), 5),
                                ('green', number(palette['green']), 5), ('blue', number(palette['blue']), 5)):
        found = section_bytes(lib, address, count * 4, b'__const')
        if not found:
            return {}
        tables[key] = list(struct.unpack('<%dI' % count, found[0]))
        provenance[key] = {'offset': found[1], 'bytes': count * 4}
    colors = [list(row) for row in zip(tables['red'], tables['green'], tables['blue'])]
    colors.append([number(fallback[key]) for key in ('red', 'green', 'blue')])
    if (not all(provenance.values()) or max(tables['system_types']) > 5
            or max(max(row) for row in colors) > 255):
        return {}
    return {'scope': 'ordinary_sun_flares', 'image_ids': ids, 'images': images[0], 'system_types': tables['system_types'],
            'colors': colors, 'provenance': provenance}


def extract_sun_flares(mach, sky):
    if mach.architecture == 'android-armv7':
        return android_flares(mach, sky or {})
    if not sky or mach.architecture not in ['x86_64','armv7']:return {}
    import capstone
    mac=mach.architecture=='x86_64';prefix='MAC_' if mac else 'ARM_'
    sec=mach.text;base=sec['address'];file_base=mach.slice_offset+sec['offset']
    code=mach.data[sec['offset']:sec['offset']+sec['length']]
    md=capstone.Cs(capstone.CS_ARCH_ARM,capstone.CS_MODE_THUMB);md.detail=True
    provenance={}
    def require(ok):
        if not ok:raise ValueError('Unsupported sun flare declarations')
    def instruction(m,key):
        rows=list(md.disasm(m[key],base+m.start(key)))
        require(len(rows)==1 and rows[0].size==len(m[key]));return rows[0]
    def match(key,at=None):
        name=prefix+key.upper()
        pattern=template(globals()[name])
        rows=[m for m in ([pattern.match(code,at)] if at is not None else pattern.finditer(code)) if m is not None and (mac or m.start()%2==0)]
        require(len(rows)==1);m=rows[0]
        if not mac:
            for field,(kind,register) in ARM_FIELDS[name].items():
                i=instruction(m,field);require(i.mnemonic==kind)
                if register:require(i.reg_name(i.operands[0].reg)==register)
        provenance[key]={'offset':file_base+m.start(),'bytes':len(m[0])};return m
    def target(m,key):
        return base+m.end(key)+int.from_bytes(m[key],'little',signed=True) if mac else instruction(m,key).operands[0].imm
    def value(m,key):
        return int.from_bytes(m[key],'little') if mac else instruction(m,key).operands[-1].imm
    def table(m,low,high,pc):
        return (base+m.start()+pc+value(m,low)+(value(m,high)<<16))&0xffffffff
    def words(key,address,count,section=b'__const'):
        found=section_bytes(mach,address,count*4,section);require(found is not None)
        provenance[key]={'offset':found[1],'bytes':count*4}
        return list(struct.unpack('<'+str(count)+'I',found[0]))
    try:
        resources=match('resources');system=match('system_type');palette=match('palette')
        for name,field,raw in [('system','call_6' if mac else 'bl_4','554889e5488b87280200005dc3' if mac else 'd0f890017047'),
                               ('system_id','call_e' if mac else 'bl_a','554889e58b47205dc3' if mac else '40697047')]:
            address=target(system,field);raw=bytes.fromhex(raw)
            require(address==base+sky['provenance'][name]['offset']-file_base)
            found=section_bytes(mach,address,len(raw),b'__text')
            require(found is not None and found[0]==raw)
            provenance[name]={'offset':found[1],'bytes':len(raw)}
        types=words('system_types',target(system,'ref_13') if mac else table(system,'movw_e','movt_12',0x1a),34)
        require(all(v<=5 for v in types))
        first=value(resources,'id_17' if mac else 'add_w_12');require(0<=first<=65531)
        ids=list(range(first,first+3))
        images={}
        for record in template(MAC_IMAGE if mac else ARM_IMAGE).finditer(code):
            if not mac and record.start()%2:continue
            if mac:
                image_id=value(record,'value_22')
                if image_id not in ids:continue
                require(target(record,'call_5')==target(record,'call_12'))
                texture=value(record,'value_17');region=value(record,'value_1c')
            else:
                image=instruction(record,'number_14')
                if image.mnemonic not in ['mov.w','movw'] or image.reg_name(image.operands[0].reg)!='r3':continue
                image_id=image.operands[1].imm
                if image_id not in ids:continue
                for field,kind in [('number_8','movw'),('number_10','movt')]:
                    i=instruction(record,field);require(i.mnemonic==kind and i.reg_name(i.operands[0].reg)=='r2')
                require(instruction(record,'blx_2').mnemonic=='blx')
                slot=None
                for field in ['ldr_w_1c','ldr_w_22','ldr_w_2a','ldr_w_34','ldr_w_3a']:
                    i=instruction(record,field);require(i.mnemonic=='ldr.w' and len(i.operands)==2)
                    require(i.reg_name(i.operands[0].reg)==('r1' if field=='ldr_w_1c' else 'r2'))
                    op=i.operands[1];require(op.type==3 and i.reg_name(op.mem.base)=='r5' and not op.mem.index and op.mem.disp%4==0)
                    if slot is None:slot=op.mem.disp
                    require(slot==op.mem.disp)
                texture=value(record,'number_8');region=value(record,'number_10')
            require(image_id not in images and 0<=texture<=65533 and 0<=region<65535)
            images[image_id]={'id':image_id,'texture_id':texture,'region':region}
            provenance['image_'+str(image_id-first)]={'offset':file_base+record.start(),'bytes':len(record[0])}
        require(len(images)==3)
        if mac:
            # The jump table selects one of five constant RGB records. Read
            # their literal operands, including both default paths.
            default=[value(palette,k) for k in ['value_0','value_c','value_12']]
            ordinary=[value(palette,k) for k in ['value_0','value_2a','value_30']]
            colors_by_offset={0x81:ordinary}
            for offset,fields in [(0x37,['value_3c','value_42','value_37']),
                                  (0x4a,['value_50','value_4a','value_56']),
                                  (0x5d,['value_63','value_5d','value_69']),
                                  (0x70,['value_75','value_7b','value_70'])]:
                colors_by_offset[offset]=[value(palette,k) for k in fields]
            ptr=target(palette,'ref_1c');relative=words('palette_selectors',ptr,5,b'__text')
            offsets=[ptr+struct.unpack('<i',struct.pack('<I',v))[0]-(base+palette.start()) for v in relative]
            require(all(v in colors_by_offset for v in offsets))
            colors=[colors_by_offset[v] for v in offsets]+[default]
        else:
            fallback=match('fallback',palette.start()+0x48)
            channels=[words(name,table(palette,lo,hi,pc),5) for name,lo,hi,pc in
                      [('red','movw_4','movt_8',0x20),('green','movw_c','movt_10',0x22),('blue','movw_14','movt_18',0x24)]]
            colors=[list(v) for v in zip(*channels)]+[[value(fallback,k) for k in ['mov_w_8','mov_w_4','mov_w_0']]]
        require(all(0<=v<=255 for row in colors for v in row))
        spans=sorted((p['offset'],p['offset']+p['bytes']) for p in provenance.values())
        require(all(left[1]<=right[0] for left,right in zip(spans,spans[1:])))
        return {'scope':'ordinary_sun_flares','image_ids':ids,'images':[images[i] for i in ids],'system_types':types,'colors':colors,'provenance':provenance}
    except (ValueError,KeyError,IndexError,TypeError,OverflowError,struct.error):return {}

MAC_RESOURCES = """
31db4c8d25
{ref_2:4}
eb04498b4718488d1498498b3c248d83
{id_17:4}
0fb7f0e8
{call_20:4}
48ffc380fb0375de4c89f7e8
{call_30:4}
418947104c89f7e8
{call_3c:4}
418947144d897708
"""

MAC_SYSTEM_TYPE = """
498b3e4d89e6e8
{call_6:4}
4889c7e8
{call_e:4}
488d0d
{ref_13:4}
4863c08b04814189465c
"""

MAC_PALETTE = """
41bd
{value_0:4}
4183fe04760d41bc
{value_c:4}
b9
{value_12:4}
eb684489f0488d0d
{ref_1c:4}
486304814801c841bc
{value_2a:4}
b9
{value_30:4}
ffe0b9
{value_37:4}
41bd
{value_3c:4}
41bc
{value_42:4}
eb3741bc
{value_4a:4}
41bd
{value_50:4}
b9
{value_56:4}
eb2441bc
{value_5d:4}
41bd
{value_63:4}
b9
{value_69:4}
eb11b9
{value_70:4}
41bd
{value_75:4}
41bc
{value_7b:4}
"""

ARM_RESOURCES = """
{movw_0:4}
{movt_4:4}
002679440d6800e02069
{add_w_12:4}
00eb8602286889b2
{bl_1e:4}
0136032ef3d14046
{bl_2a:4}
a0604046
{bl_32:4}
e060
"""

ARM_SYSTEM_TYPE = """
28686794
{bl_4:4}
6794
{bl_a:4}
{movw_e:4}
{movt_12:4}
794451f82000f063
"""

ARM_PALETTE = """
042d21d8
{movw_4:4}
{movt_8:4}
{movw_c:4}
{movt_10:4}
{movw_14:4}
{movt_18:4}
784479447a4450f825a051f8258052f825b0
"""

ARM_FALLBACK = """
{mov_w_0:4}
{mov_w_4:4}
{mov_w_8:4}
"""

ARM_FIELDS = {'ARM_RESOURCES': {'movw_0': ('movw', 'r1'), 'movt_4': ('movt', 'r1'), 'add_w_12': ('add.w', 'r1'), 'bl_1e': ('bl', None), 'bl_2a': ('bl', None), 'bl_32': ('bl', None)}, 'ARM_SYSTEM_TYPE': {'bl_4': ('bl', None), 'bl_a': ('bl', None), 'movw_e': ('movw', 'r1'), 'movt_12': ('movt', 'r1')}, 'ARM_PALETTE': {'movw_4': ('movw', 'r0'), 'movt_8': ('movt', 'r0'), 'movw_c': ('movw', 'r1'), 'movt_10': ('movt', 'r1'), 'movw_14': ('movw', 'r2'), 'movt_18': ('movt', 'r2')}, 'ARM_FALLBACK': {'mov_w_0': ('mov.w', 'fp'), 'mov_w_4': ('mov.w', 'r8'), 'mov_w_8': ('mov.w', 'sl')}}

MAC_IMAGE = """
bf18000000e8
{call_5:4}
4889c3bf04000000e8
{call_12:4}
66c700
{value_17:2}
66c74002
{value_1c:2}
66c703
{value_22:2}
c7430403000000c74308ffffffff4889431048899d
{slot_39:4}
"""

ARM_IMAGE = """
0420
{blx_2:4}
03ae
{number_8:4}
06f58151
{number_10:4}
{number_14:4}
13ae0d46
{ldr_w_1c:4}
0260
{ldr_w_22:4}
13800323
{ldr_w_2a:4}
53604ff0ff33
{ldr_w_34:4}
9360
{ldr_w_3a:4}
d060
"""
