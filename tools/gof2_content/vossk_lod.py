"""Explicitly unregistered Vossk children, not a general missing-mesh fallback.

Android: BuildResourceList, loadPortraits and loadLowTexturesAndMaterials are
the only functions that add resources (PaintCanvas::AddResource appends them);
PaintCanvas::MeshCreate finds a mesh by id among them or creates none, and
TransformAddMesh, called by AEGeometry::setLodChildMeshes, then skips the child.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

VALUES = {'scope': 'vossk_empty_lod_children', 'hull_catalogue_id': 13,
          'resource_ids': [17040, 17041]}
ANDROID_VALUES = copy.deepcopy(VALUES)


def extract_vossk_lod(mach, arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(ANDROID_VALUES), proof) if proof else ({}, {})
    _, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})


# Guard the complete three registry owners: absence cannot be established by
# recognizing only the successful filename-registration templates.
LAYOUTS = {
    'vossk_traffic_lod_registry_main': [-648475, 308015, '__text', '6d30afbacfbf568f7a725d2008eebda71f3433212cb6637fb341e0c975a0b0e5'],
    'vossk_traffic_lod_registry_audio': [-340460, 51233, '__text', 'c3cc438da1487c0c0dc5cd2ac75fe080336d5bc588a9e76cee63b0314cfd9916'],
    'vossk_traffic_lod_registry_quality': [-289227, 44631, '__text', '1edf66a77b3e32667f2fe9c22767023f2e9c8cbc24ddfe3d18ab492ec3bb4fca'],
    'vossk_traffic_lod_child_loader': [-722330, 268, '__text', '69964f362eeadb3a8123e36d6391ea5f8655ad46b944475b30ecb094048fcb09'],
    'vossk_traffic_lod_lookup': [1149162, 78, '__text', '58c408c99916d83a3a02ccc9ab4ecfba9b2199e8576d21e1368de9ce5210fdcc'],
    'vossk_traffic_lod_attach': [1162442, 108, '__text', 'd985e5c08da50c41f590d3685fdc51ee4c3142be22c042396ca67743a654f062'],
    'vossk_traffic_lod_append': [1132218, 42, '__text', '87fd1143545fdf543af4010087c928ad8961ad27e72d8229b6e8df7c622bef04'],
}
MAC_ALTERNATE = {
    'vossk_traffic_lod_registry_main': [-653836, 311889, '__text', 'd0e3aa3c45060154ff3d8e788919731970cf2050a768f79b3de84e75961f55b5'],
    'vossk_traffic_lod_registry_audio': [-341947, 51233, '__text', 'dd424837d98a65027c668b0bb6bbb715fafc8003f1259f13b1ec2f1a0fbd67b9'],
    'vossk_traffic_lod_registry_quality': [-290714, 44630, '__text', '340824640f033b6cf2745eb35434e5af283a127a4a59a49b58d0d72e310756c8'],
    'vossk_traffic_lod_child_loader': [-728226, 268, '__text', '9bf1b588ef63355d8914ba8cc1623616edefde20bdeea84628b3e574640ae67c'],
    'vossk_traffic_lod_lookup': [1147074, 78, '__text', '50fdf953edf26ec8a1336293d809cf117b03d8bafe851e806732a002c75a5f13'],
    'vossk_traffic_lod_attach': [1159762, 108, '__text', '3b28b7b63fee4e3181d41e796b4dea272b266c6204b1fa2d0951e5178a51c420'],
    'vossk_traffic_lod_append': [1131410, 42, '__text', 'fbfb083459f9826255e5b818e530ec6a87fc053be515f6496ccd304f1314869f'],
}
# The three registry owners whole, the child loader whole, the id lookup up to
# its not-found exit, the attach up to its skip, and the append whole.
ANDROID = {'vossk_traffic_lod_registry_main': ('_Z17BuildResourceListPN11AbyssEngine6EngineE', 0, 231004, 'sha256:5e204f2b362f1039d3bc29ae06cfb0dd2024bc268478843a4a6d0611053501e5'),
           'vossk_traffic_lod_registry_audio': ('_Z13loadPortraitsPN11AbyssEngine6EngineE', 0, 23388, 'sha256:c6e08516e51ac395909b454ce7eca0e4ad65da5e0ddccdbaf814581bee786bf1'),
           'vossk_traffic_lod_registry_quality': ('_Z27loadLowTexturesAndMaterialsPN11AbyssEngine6EngineE', 0, 19124, 'sha256:05aa89d980743e4f5062f991bf8211e40cf13e1fb637f5fd507aa3263956a0da'),
           'vossk_traffic_lod_child_loader': ('_ZN10AEGeometry17setLodChildMeshesEPt', 0, 168, 'sha256:b889c092ebeee029064a65ed0c2a01f92fa6e7c36e01b68ef48d6ed00b7f169f'),
           'vossk_traffic_lod_lookup': ('_ZN11AbyssEngine11PaintCanvas10MeshCreateEtRjb', 0, 56, 'sha256:931ddfd5e545336a954dd0077ce280fe2162e8365ca4e257661a9732ed34d85e'),
           'vossk_traffic_lod_attach': ('_ZN11AbyssEngine11PaintCanvas16TransformAddMeshEjtb', 0, 58, 'sha256:6d86aceb7582c93b9e4bae9b567cbfb89f98fa5eb818574e7f460a458ea874d2'),
           'vossk_traffic_lod_append': ('_ZN11AbyssEngine11PaintCanvas11AddResourceEPNS_8ResourceE', 0, 50, 'sha256:48a94a91e6eaf8da0ec99f540a6fe14296efc73d04c844ac26622217092f4286')}
