"""Explicitly unregistered Vossk children, not a general missing-mesh fallback."""
import copy
from .station_exterior import hashed_variants

VALUES = {'scope': 'vossk_empty_lod_children', 'hull_catalogue_id': 13,
          'resource_ids': [17040, 17041]}


def extract_vossk_lod(mach, arrival):
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
