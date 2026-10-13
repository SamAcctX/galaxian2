"""Recognize opening escape camera declarations; emit no executable content.

Android: TargetFollowCamera's constructor sets the defaults (active, target up,
no cockpit, no transient shake, rumble radius 5, roll 0, not locked);
TargetFollowCamera::update in look-at mode (setLookAtCam) needs an elapsed
millisecond, takes the target's up and position, and adds the rumble shake
(AERandom::nextInt(2 x radius) - radius per axis, x percentage, x 1.0 outside
the cockpit) to the look-at point; translate updates at once with 1000 ms.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols

VALUES = {'scope': 'fresh_opening_escape_fixed_camera',
 'look_shake_axes': [0, 1, 2],
 'random_bound_radius_multiplier': 2,
 'look_shake_scale': 1.0,
 'immediate_update_ms': 1000,
 'ordinary_minimum_ms': 1,
 'inherit_target_up': True,
 'transient_eye_shake': False,
 'extra_roll': 0.0,
 'cockpit': False}


def extract_opening_escape_camera(mach, staging):
    arch = mach.architecture
    if arch == 'android-armv7':
        try:
            if not staging['escape']: return {}
        except (KeyError, TypeError): return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(copy.deepcopy(ANDROID_VALUES), provenance=proof) if proof else {}
    if arch not in LAYOUTS: return {}
    try:
        if not staging['escape']: return {}
        origin = staging['provenance']['initial']
        if origin['bytes'] != (366 if arch == 'x86_64' else 320): return {}
        layouts=[LAYOUTS[arch]]+([MAC_ALTERNATE] if arch=='x86_64' else [])
        proof=recognize(mach,origin['offset'],layouts,constants=[k for k in LAYOUTS[arch] if k.endswith('_constant')])
        if not proof:return {}
        result = copy.deepcopy(VALUES); result['provenance'] = proof
        return result
    except (KeyError, TypeError, IndexError, ValueError, OverflowError): return {}

LAYOUTS = {'x86_64': {'defaults': [782030,
                         68,
                         'c6434c00c6434f00c6434d00c7435000000000c6434e01c6435400c683f800000000c6830801000000c6831401000001c7831801000000000000c7831c01000005000000'],
            'roll_defaults': [782172,
                              27,
                              'c7833801000000000000c7833c0100000000c842c6834001000000'],
            'ordinary_gate': [783860,
                              23,
                              'f6434e010f840e0d000083bd34fbffff000f8e010d0000'],
            'fixed_target': [783883,
                             468,
                             '488b7b08e85520e7ff488b4820488b5028488b70308b783889bd20ffffff4889b518ffffff48899510ffffff48898d08ffffff488b481848898d00ffffff488b481048898df8feffff488b08488b4008488985f0feffff48898de8fefffff6434d010f846c0100004c8d7b28f68314010000017470488b8508ffffff488b8d10ffffff488b9518ffffff8bb520ffffff89b5d0feffff488995c8feffff48898dc0feffff488985b8feffff488b8500ffffff488985b0feffff488b85f8feffff488985a8feffff488b85e8feffff488b8df0feffff48898da0feffff48898598feffffeb72c78598feffff0000803f48c785a4feffff0000000048c7859cfeffff00000000c785acfeffff0000803f48c785b8feffff0000000048c785b0feffff00000000c785c0feffff0000803fc785c4feffff00000000c785c8feffff0000803fc785ccfeffff0000803fc785d0feffff0000803f488dbd98feffffe8611c0500f30f118de0fefffff30f1185d8feffff660f70c001f30f1185dcfeffff488db5d8feffff4c89ffe865520200488dbde8feffffe8e91c0500488d7b1c488db588fefffff30f118d90fefffff30f118588feffff660f70c001f30f11858cfeffffe82c520200c6830801000000e989070000'],
            'cockpit_gate': [786280, 13, 'f683f8000000010f84d5000000'],
            'transient_gate': [786506, 10, 'f6434f010f84c4000000'],
            'look_shake': [786712,
                           282,
                           'f30f108b18010000f30f118d28fbffff660fefc00f2ec80f86e2000000f683f800000001410f94c54c8d25c05d1700498b3c24448bbb1c010000478d343f4489f6e8413d0300410fb6cd488d15266d0a00f30f100c8af30f118d34fbffff4429f8f30f2ac0f30f109528fbfffff30f59d0f30f59d1f30f58531cf30f11531cf30f108318010000f30f118528fbffff498b3c244489f6e8ec3c03004429f80f57c0f30f2ac0f30f598528fbfffff30f598534fbfffff30f584320f30f114320f30f108318010000f30f118528fbffff498b3c244489f6e8ac3c03004429f80f57c0f30f2ac0f30f598528fbfffff30f598534fbfffff30f584324f30f114324488d7310488d531c488d4b284c8dbdb8fbffff4c89ffe86d270500'],
            'scale_constant': [1470095, 8, 'a69bc43a0000803f'],
            'pan': [783223,
                    87,
                    '554889e5f30f105f10f30f58d8f30f115f10f30f105f14f30f58d9f30f115f14f30f105f18f30f58daf30f115f18f30f58471cf30f11471cf30f584f20f30f114f20f30f585724f30f115724bee80300005de901000000'],
            'cockpit_select': [787309,
                               84,
                               '554889e5534883ec184889fb4088b3f8000000c745e800000000c745ec00001643c745f0000048c4488dbbfc000000488d75e8e85a460200c7830c01000000000000c78310010000000000004883c4185b5dc390'],
            'fixed_select': [787893, 10, '554889e54088774d5dc3'],
            'random_bound': [999071,
                             171,
                             '554889e54883ec4048897df08975ec488b7df08b75ecb8000000002b45ec21f03b45ec48897dd80f852f000000be1f000000486345ec488b7dd8488945d0e83dffffff4863f8488b4dd0480faff948c1ff1f89f88945fce946000000be1f000000488b7dd8e816ffffff8945e88b75ec8945cc99f7fe8b45cc8955e48945c88b45e82b45e48b4dec81e90100000001c181f9000000000f8cc0ffffff8b45e48945fc8b45fc4883c4405dc3'],
            'random_bits': [998943,
                            96,
                            '554889e548897df88975f4488b7df848c745e8e6ecde05488b45e848c1e008480d6d000000488945e8488b07480faf45e848050b00000048b9ffffffffffff00004821c148890f488b07be300000002b75f489f148d3f889c689f05dc30f1f00']},
 'armv7': {'defaults': [722642,
                        504,
                        'f0b503af2de9000d2ded028ba8b00446c0ef500080ef1080b86825939346269004f134003e694ff00008fd684ff07e5ad7f81490ba692296cdf88c902795249284ed148bc4f8588040f98f0a04f1280040f98f0a04f1180040f98f0a04f1080040f98f0a0546039004f1b400c4f8b0a040f98f0a04f1c800c4f8c4a040f98f0a04f59e70c4f8d8a0c4f8dc80c4f8e0a0c4f8e4a0c4f8e8a0c4f8f080c4f8f480c4f8f880c4f838a140f98f0a04f5a870c4f84ca140f98f0a04f12c00c4f860a1c4f86481c4f868a1c4f86ca1c4f870a184e8020825a9f8f093f804f1380022a9f8f08ef81fa928468ded1f8bcdf88480f8f086f804f114061ca98ded1c8b3046cdf87880f8f07cf858462cf64dfb00f12c010dad61f98f0a05f12c010df1280b25aa41f98f0a00f1200161f98f0a05f1200141f98f0a00f1100161f98f0a05f1100141f98f0a294660f98f0a584645f98f0a11f12df830465946f8f051f807ae294622ad30462a4611f122f803983146f8f046f804f1200004a9cdf81080cdf814a0cdf81880f8f03bf8012084f8448084f847804ff0050984f84580c4f8488084f8460084f84c8084f8ec8084f8fc8084f808012846c4e94389f8f04ffb4df20a710022c4f8ac0049f6a630c3f6a331c3f6c430c4f2c822c4f82411c4f8280104f16c03c4f82c8104f17c00c4f8302104f1740284f83481'],
           'ordinary_gate': [724596,
                             18,
                             '94f84600002800f0f783baf1010fc0f2f383'],
           'fixed_target': [724614,
                            128,
                            '60682bf6f7ff00f1200160f98f0a61f98f2a00f110012c3061f98f4aeaa901f1200201f1100360f98f6a01f12c0041f98f0a40f98f6a42f98f2a43f98f4a94f84560002e43d094f8085104f12006002d69d060f98f6ac3a861f98f0a00f12c0140f98f0a41f98f6a00f12001103062f98f2a63f98f4a41f98f2a40f98f4a65e0'],
           'fixed_target_store': [724908,
                                  84,
                                  'c3a9c0ef50000a1d18314ff07e50c39042f98f0ac89041f98f0a0021cd90ce91cf90d090d190d2adc3a9284610f10bfc30462946f7f077fcc0adeaa9284610f132fc04f114002946f7f06dfc002084f8fc000de2'],
           'cockpit_gate': [726044, 6, '94f8ec0038b3'],
           'transient_gate': [726130, 8, '94f84700002855d0'],
           'look_shake': [726310,
                          228,
                          '94ed439ab5eec09af1ee10fa58dd4ff2501055a5c0f21c00d4f81061784494f8ec10d0f800804fea460a00295146d8f8000018bf0435fef0fdfa801b95ed008a94ed050a514640ec300bfbff200649ff300d48ff300d00ef200d84ed050ad8f8000094ed439a20ef1001fef0e3fa801b94ed060a514640ec300bfbff200649ff300d48ff300d00ef200d84ed060ad8f8000094ed439a20ef1001fef0cbfa801b94ed070a40ec300bfbff200649ff300d48ff300d00ef200d84ed070a20ef100127ae04f1080104f1140204f12003304611f1f6f9eaad314628460ff13ffc18aec0ef5000'],
           'scale_literal': [726670, 8, '0000803fa69bc43a'],
           'pan': [724294,
                   72,
                   '43ec113b42ec122b41ec101b00f10801f0ee420a61f98f0af0ee401a40efc00d41f98f0a4ff47a7190ed063a03ef022d80ed062a90ed072a02ef010d80ed070a20ef100100f000b8'],
           'cockpit_select': [726746,
                              54,
                              '90b501af83b00446002084f8ec10694600900020c4f2163001900020ccf24840029004f1f000f7f0e7f8c0ef1000c4ed400b03b090bd'],
           'fixed_select': [726990, 6, '80f845107047'],
           'random_bound': [1768282,
                            114,
                            '80b56f4687b00022c0f200020590049105980499049bd21a1140049a914201900ed104981f21019a00901046fff7a8ff009981fb0001c00f40ea4100069015e01f21c0f200010198fff79aff03900398049945f0deec029003980299401a0499013908440028ebdb02980690069807b080bd'],
           'random_bits': [1768154,
                           128,
                           '90b501af85b06c4624f00704a546049003910498002101914ef6e641c0f2de510091052101914ef26d61cdf6ec61009102684368a2fb019c02eb8202624403fb012119f10b0241f1000189b2026041600398c0f13003c0f1100021fa00f9c3f1200c01fa0cf122fa03f241ea02010028a8bf49460846a7f10404a54690bd00bf']}}


# Independently verified alternate Mac compiler layout.
MAC_ALTERNATE = {'defaults': [782662,
              68,
              'c6434c00c6434f00c6434d00c7435000000000c6434e01c6435400c683f800000000c6830801000000c6831401000001c7831801000000000000c7831c01000005000000'],
 'roll_defaults': [782804, 27, 'c7833801000000000000c7833c0100000000c842c6834001000000'],
 'ordinary_gate': [784492, 23, 'f6434e010f840e0d000083bd34fbffff000f8e010d0000'],
 'fixed_target': [784515,
                  468,
                  '488b7b08e8d506e7ff488b4820488b5028488b70308b783889bd20ffffff4889b518ffffff48899510ffffff48898d08ffffff488b481848898d00ffffff488b481048898df8feffff488b08488b4008488985f0feffff48898de8fefffff6434d010f846c0100004c8d7b28f68314010000017470488b8508ffffff488b8d10ffffff488b9518ffffff8bb520ffffff89b5d0feffff488995c8feffff48898dc0feffff488985b8feffff488b8500ffffff488985b0feffff488b85f8feffff488985a8feffff488b85e8feffff488b8df0feffff48898da0feffff48898598feffffeb72c78598feffff0000803f48c785a4feffff0000000048c7859cfeffff00000000c785acfeffff0000803f48c785b8feffff0000000048c785b0feffff00000000c785c0feffff0000803fc785c4feffff00000000c785c8feffff0000803fc785ccfeffff0000803fc785d0feffff0000803f488dbd98feffffe8c1fd0400f30f118de0fefffff30f1185d8feffff660f70c001f30f1185dcfeffff488db5d8feffff4c89ffe8c5520200488dbde8feffffe849fe0400488d7b1c488db588fefffff30f118d90fefffff30f118588feffff660f70c001f30f11858cfeffffe88c520200c6830801000000e989070000'],
 'cockpit_gate': [786912, 13, 'f683f8000000010f84d5000000'],
 'transient_gate': [787138, 10, 'f6434f010f84c4000000'],
 'look_shake': [787344,
                282,
                'f30f108b18010000f30f118d28fbffff660fefc00f2ec80f86e2000000f683f800000001410f94c54c8d2520031700498b3c24448bbb1c010000478d343f4489f6e8a1380300410fb6cd488d1566090a00f30f100c8af30f118d34fbffff4429f8f30f2ac0f30f109528fbfffff30f59d0f30f59d1f30f58531cf30f11531cf30f108318010000f30f118528fbffff498b3c244489f6e84c3803004429f80f57c0f30f2ac0f30f598528fbfffff30f598534fbfffff30f584320f30f114320f30f108318010000f30f118528fbffff498b3c244489f6e80c3803004429f80f57c0f30f2ac0f30f598528fbfffff30f598534fbfffff30f584324f30f114324488d7310488d531c488d4b284c8dbdb8fbffff4c89ffe8fd080500'],
 'scale_constant': [1445191, 8, 'a69bc43a0000803f'],
 'pan': [783855,
         87,
         '554889e5f30f105f10f30f58d8f30f115f10f30f105f14f30f58d9f30f115f14f30f105f18f30f58daf30f115f18f30f58471cf30f11471cf30f584f20f30f114f20f30f585724f30f115724bee80300005de901000000'],
 'cockpit_select': [787941,
                    84,
                    '554889e5534883ec184889fb4088b3f8000000c745e800000000c745ec00001643c745f0000048c4488dbbfc000000488d75e8e8ba460200c7830c01000000000000c78310010000000000004883c4185b5dc390'],
 'fixed_select': [788525, 10, '554889e54088774d5dc3'],
 'random_bound': [998519,
                  170,
                  '554889e54883ec4048897df08975ec488b7df08b75ecb8000000002b45ec21c63b75ec48897dd80f852f000000be1f000000486345ec488b7dd8488945d0e83dffffff4863f8488b4dd0480fafcf48c1f91f89c88945fce945000000be1f000000488b7dd8e816ffffff8945e88b75ec8945cc99f7fe8b45cc8955e48945c88b45e82b45e48b4dec81e90100000001c83d000000000f8cc1ffffff8b45e48945fc8b45fc4883c4405dc3'],
 'random_bits': [998391,
                 93,
                 '554889e548897df88975f4488b7df848c745e8e6ecde05488b45e848c1e008480d6d000000488945e8488b07480faf45e848050b00000048b9ffffffffffff00004821c8488907488b07be300000002b75f489f148d3f889c689f05dc3']}

# The values equal the Mac's.
ANDROID_VALUES = copy.deepcopy(VALUES)
ANDROID = {'lock_gate': ('_ZN18TargetFollowCamera6updateEi', 30, 6, '9bf83801d8b3'),
           'defaults': ('_ZN18TargetFollowCameraC2EjP10AEGeometryN11AbyssEngine6AEMath6VectorES4_', 30, 356, 'sha256:f8eaa7658138251681a61fcbbc2d93e3b1170ff3405112f4f8539e5c656d5db9'),
           'roll_defaults': ('_ZN18TargetFollowCameraC2EjP10AEGeometryN11AbyssEngine6AEMath6VectorES4_', 392, 38, 'sha256:c2d030c58d05162688736cdbadb594f0f173dabd7424b3a657e882af620754e8'),
           'roll_table': ('_ZN18TargetFollowCameraC2EjP10AEGeometryN11AbyssEngine6AEMath6VectorES4_', 544, 16, '0ad7a33ba69bc43b000000000000c842'),
           'pan': ('_ZN18TargetFollowCamera9translateEfff', 0, 64, 'sha256:b6142bfbe0be4a8120f2c41cfe71a2eaa8237f1567db29d0c7704a4c9e4b5d85'),
           'ordinary_gate': ('_ZN18TargetFollowCamera6updateEi', 156, 18, 'baf1010fc0f2c7819bf84600002800f0c281'),
           'fixed_target': ('_ZN18TargetFollowCamera6updateEi', 174, 330, 'sha256:0df4a3030438b7a508d3b4d38ac96c606e8e2ea0a20b21a93b410a331b91f491'),
           'cockpit_gate': ('_ZN18TargetFollowCamera6updateEi', 504, 86, 'sha256:9e3c6ffca3d2410a736af517d5ee9e737f76b65c47cc112f45e16d8769ba1fa5'),
           'transient_gate': ('_ZN18TargetFollowCamera6updateEi', 590, 172, 'sha256:3e697b2a4d5403fe53b50e2ceb3d8b6b30e996595c9d14bc7b3225e7cd212b28'),
           'look_shake': ('_ZN18TargetFollowCamera6updateEi', 762, 312, 'sha256:09aa50788af558cc05798fc5b11074e37f7efc2c66ae1a4b939efe05560a7356'),
           'cockpit_select': ('_ZN18TargetFollowCamera20enableFirstPersonCamEb', 0, 88, 'sha256:fb4ced13b02087e1395b8af7d7dc9c40a4b0b7a81fcf5ae0f8fbc3823e529c82'),
           'fixed_select': ('_ZN18TargetFollowCamera12setLookAtCamEb', 0, 6, '80f845107047'),
           'random_bound': ('_ZN11AbyssEngine8AERandom7nextIntEi', 0, 152, 'sha256:dbdc6d398b2d2ed41a342376d8af938c332ab948c9bb120d02b25f85d1d46e1f'),
           'random_bits': ('_ZN11AbyssEngine8AERandom4nextEi', 0, 74, 'sha256:efa02bb1694a213294840e3db81115ff5ce9736c60ce155175a5c3d752360e7f'),
           'transient_scale_constant': ('_ZN18TargetFollowCamera6updateEi', 1560, 4, '6f12833a'),
           'scale_constant': ('_ZN18TargetFollowCamera6updateEi', 1564, 4, 'a69bc43a')}
