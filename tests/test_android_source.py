"""Android release sources: XAPK streaming, the release .7z, the bundle view and cleanup."""
from contextlib import ExitStack
import io
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import warnings
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from gof2_content.android_source import AndroidRelease, PACKAGE, unpack_xapk
from gof2_content.bundle import ANDROID_LIBRARY, Bundle
from gof2_content.formats import ContentError
from gof2_content.game_install import missing_campaign, prepare, read_receipt, CAMPAIGN_GROUPS

OBB_NAME = f'main.47947006.{PACKAGE}.obb'
PREFIX = '47947_GOF2CONTENT_ETC/assets/'
SHIPS = b'original ships'.ljust(64 * 36, b'\0')


def zip_bytes(members, method=zipfile.ZIP_DEFLATED):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', method) as archive:
        for name, data in members.items():
            archive.writestr(name, data)
    return buffer.getvalue()


def obb(extra=None, prefix=PREFIX):
    members = {prefix + 'gb.lang': b'lang', prefix + 'data/audio/FMOD_GOF2.fev': b'events',
               prefix + 'data/bin/items.bin': b'android items', prefix + 'data/bin/ships.bin': b'android ships',
               prefix + 'data/bin/systems.bin': b'systems', prefix + 'data/bin/stations.bin': b'stations',
               prefix + 'data/assets/main/3d/meshes/ships/a.aem': b'mesh',
               prefix + 'data/assets/main/3d/textures/low/etc/ships/a.aei': b'texture',
               prefix + 'data/shader/Generic.frag': b'not selected'}
    members.update(extra or {})
    return zip_bytes(members)


def apk(economy=True):
    members = {ANDROID_LIBRARY: b'\x7fELF synthetic', 'AndroidManifest.xml': b'binary xml'}
    if economy:
        members.update({'assets/data/bin/items.bin': b'original items', 'assets/data/bin/ships.bin': SHIPS})
    return zip_bytes(members)


def xapk(members=None, method=zipfile.ZIP_DEFLATED):
    members = members if members is not None else {
        'Android/obb/' + PACKAGE + '/' + OBB_NAME: obb(), 'icon.png': b'png', 'manifest.json': b'{}',
        PACKAGE + '.apk': apk()}
    return zip_bytes(members, method)


class AndroidSourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.work = self.root / 'work'
        self.work.mkdir()

    def write(self, name, data):
        path = self.root / name
        path.write_bytes(data)
        return path

    def test_xapk_streams_only_the_obb_and_the_game_apk_and_cleans_up(self):
        for method in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
            source = self.write('release.xapk', xapk(method=method))
            with AndroidRelease(source, work=self.work) as stage:
                self.assertEqual(sorted(p.name for p in stage.iterdir()), ['game.apk', OBB_NAME])
                self.assertEqual((stage / 'game.apk').read_bytes(), apk())
                self.assertEqual((stage / OBB_NAME).read_bytes(), obb())
            self.assertEqual(list(self.work.iterdir()), [])

    def test_damaged_or_foreign_releases_are_refused_and_leave_nothing(self):
        good = xapk()
        damaged = bytearray(good)
        at = good.index(b'PK\x03\x04', 4)  # the second record's data follows the first's
        damaged[at - 8] ^= 0xff
        cases = {'damaged': bytes(damaged), 'truncated': good[:len(good) // 2],
                 'no obb': xapk({PACKAGE + '.apk': apk()}),
                 'no apk': xapk({'Android/obb/' + PACKAGE + '/' + OBB_NAME: obb()}),
                 'two obbs': xapk({'Android/obb/' + PACKAGE + '/' + OBB_NAME: obb(), PACKAGE + '.apk': apk(),
                                   'Android/obb/' + PACKAGE + '/' + OBB_NAME.replace('47947006', '1'): obb()}),
                 'other package': xapk({'Android/obb/other/main.1.other.obb': obb(), 'other.apk': apk()}),
                 'other folder': xapk({'Android/obb/other/' + OBB_NAME: obb(), PACKAGE + '.apk': apk()})}
        for name, data in cases.items():
            with self.subTest(name), self.assertRaises(ContentError):
                with AndroidRelease(self.write('release.xapk', data), work=self.work):
                    pass
            self.assertEqual(list(self.work.iterdir()), [], name)
        # Stored data: only the checksum sees a changed byte, only the size a wrong length.
        stored = xapk(method=zipfile.ZIP_STORED)
        changed = bytearray(stored)
        changed[30 + len('Android/obb/' + PACKAGE + '/' + OBB_NAME) + 10] ^= 0xff  # inside the first entry's data
        longer = bytearray(stored)
        struct.pack_into('<I', longer, 22, struct.unpack_from('<I', stored, 22)[0] + 1)
        for message, data in (('checksum', changed), ('checksum', longer)):
            with self.assertRaisesRegex(ContentError, message):
                unpack_xapk(io.BytesIO(bytes(data)), self.work, lambda *_: None)
            shutil.rmtree(self.work); self.work.mkdir()
        buffer = io.BytesIO()
        with warnings.catch_warnings(), zipfile.ZipFile(buffer, 'w') as archive:
            warnings.simplefilter('ignore')  # a duplicate member name, on purpose
            for name in ('Android/obb/' + PACKAGE + '/' + OBB_NAME, PACKAGE + '.apk', PACKAGE + '.apk'):
                archive.writestr(name, obb() if name.endswith('.obb') else apk())
        with self.assertRaisesRegex(ContentError, 'more than one'):
            unpack_xapk(io.BytesIO(buffer.getvalue()), self.work, lambda *_: None)
        encrypted = bytearray(good)
        struct.pack_into('<H', encrypted, 6, 1)
        with self.assertRaisesRegex(ContentError, 'encrypted'):
            unpack_xapk(io.BytesIO(bytes(encrypted)), self.work, lambda *_: None)
        for name in ('release.zip', 'release.obb'):
            with self.assertRaisesRegex(ContentError, 'Choose the Android release'):
                with AndroidRelease(self.write(name, good), work=self.work):
                    pass

    def test_cancellation_while_unpacking_removes_the_stage(self):
        def checkpoint(*_):
            raise InterruptedError('cancelled')
        with self.assertRaises(InterruptedError):
            with AndroidRelease(self.write('release.xapk', xapk()), checkpoint, work=self.work):
                pass
        self.assertEqual(list(self.work.iterdir()), [])

    @unittest.skipUnless(shutil.which('7zz') or shutil.which('7z'), '7-Zip not installed')
    def test_release_7z_is_streamed_through_7zip(self):
        tool = shutil.which('7zz') or shutil.which('7z')
        folder = self.root / 'release'
        folder.mkdir()
        (folder / 'GOF2_2.0.16_Default_Economy.xapk').write_bytes(xapk())
        (folder / 'Links.txt').write_text('links')
        archive = self.root / 'GOF2FHD_XAPK.7z'
        subprocess.run([tool, 'a', '-bd', str(archive), str(folder / '*')], check=True, capture_output=True)
        with AndroidRelease(archive, work=self.work) as stage:
            self.assertEqual((stage / OBB_NAME).read_bytes(), obb())
        self.assertEqual(list(self.work.iterdir()), [])
        (folder / 'second.xapk').write_bytes(xapk())
        archive.unlink()
        subprocess.run([tool, 'a', '-bd', str(archive), str(folder / '*')], check=True, capture_output=True)
        with self.assertRaisesRegex(ContentError, 'exactly one'):
            with AndroidRelease(archive, work=self.work):
                pass
        self.assertEqual(list(self.work.iterdir()), [])

    def stage(self, obb_data=None, apk_data=None):
        stage = self.root / 'stage' / 'android'
        shutil.rmtree(stage.parent, ignore_errors=True)
        stage.mkdir(parents=True)
        (stage / OBB_NAME).write_bytes(obb_data or obb())
        (stage / 'game.apk').write_bytes(apk_data or apk())
        return stage

    def test_bundle_maps_the_obb_to_the_mac_layout_with_the_original_economy(self):
        with Bundle(self.stage()) as bundle:
            self.assertEqual(bundle.profile, {'edition': 'android-hd', 'bundle_identifier': PACKAGE,
                                              'bundle_version': '47947006'})
            resources = bundle.resources()
            self.assertIn('FMOD_GOF2.fev', resources)
            self.assertNotIn('data/shader/Generic.frag', resources)
            self.assertEqual(bundle.read('data/bin/ships.bin', 4096), SHIPS)
            self.assertEqual(bundle.read('data/bin/items.bin', 64), b'original items')
            self.assertEqual(bundle.read('data/bin/systems.bin', 64), b'systems')
            self.assertEqual(bundle.read(bundle.executable(), 64), b'\x7fELF synthetic')

    def test_bundle_refuses_other_economies_layouts_and_stages(self):
        cases = [('free-to-play', None, apk(economy=False)), ('layout', obb(prefix='content/assets/'), None),
                 ('library', None, zip_bytes({'assets/data/bin/items.bin': b'i', 'assets/data/bin/ships.bin': b's'}))]
        for message, obb_data, apk_data in cases:
            with self.subTest(message), self.assertRaisesRegex(ContentError, message):
                Bundle(self.stage(obb_data, apk_data)).__enter__()
        stage = self.stage()
        (stage / 'extra.txt').write_text('x')
        with self.assertRaisesRegex(ContentError, 'stage'):
            Bundle(stage).__enter__()


class AndroidInstallTests(unittest.TestCase):
    """The installation transaction with an Android source and injected preparers."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'GOF2_2.0.16_Default_Economy.xapk'
        self.source.write_bytes(xapk())
        self.store = self.root / 'imports'

    def run_prepare(self, declarations, seen=None):
        def content(app, output, _checkpoint):
            seen.append(sorted(p.name for p in app.iterdir())) if seen is not None else None
            path = output / ('a' * 64); path.mkdir(parents=True)
            return path, {'content_id': 'a' * 64, 'profile': {'edition': 'android-hd'}, 'ship_table': {'records': 64}}

        def bindings(_source, _base, output, _checkpoint):
            path = output / ('b' * 64); path.mkdir(parents=True)
            (path / 'registrations.json').write_text(json.dumps(declarations))
            return path, {'binding_id': 'b' * 64}, {}

        def visuals(_base, output, **_kwargs):
            path = output / ('c' * 64); path.mkdir(parents=True)
            return path, {'pack_id': 'c' * 64}

        with ExitStack() as stack:
            stack.enter_context(patch('gof2_content.game_install.requirements'))
            stack.enter_context(patch('gof2_content.game_install.install', side_effect=content))
            stack.enter_context(patch('gof2_content.bindings.prepare', side_effect=bindings))
            stack.enter_context(patch('gof2_content.visuals.prepare', side_effect=visuals))
            return prepare(self.source, self.store)

    def complete(self):
        from gof2_content.game_install import CAMPAIGN_STAGES
        result = {group: {'scope': group} for group in CAMPAIGN_GROUPS}
        for group, stages in CAMPAIGN_STAGES.items():
            result[group] = {stage: {} for stage in stages}
        return result

    def test_finished_import_holds_only_the_installation(self):
        seen = []
        path, record = self.run_prepare(self.complete(), seen)
        self.assertEqual(seen, [['game.apk', OBB_NAME]])  # the importer saw the unpacked release
        self.assertEqual(record['format'], 'android-xapk')
        self.assertEqual(read_receipt(path), record)
        self.assertEqual([p.name for p in self.store.iterdir()], [path.parent.name])
        self.assertEqual(sorted(p.name for p in path.parent.iterdir()), ['bindings', 'content', 'installation.json', 'visuals'])
        self.assertEqual(self.source.read_bytes(), xapk())

    def test_incomplete_campaign_is_refused_without_leftovers(self):
        declarations = self.complete()
        declarations['opening_camera'] = {}
        del declarations['mido_travel']['kappa_return']
        self.assertEqual(missing_campaign(declarations), ['mido_travel.kappa_return', 'opening_camera'])
        with self.assertRaisesRegex(ContentError, 'not fully supported yet .2 campaign parts'):
            self.run_prepare(declarations)
        self.assertEqual(list(self.store.iterdir()), [])
        complete = self.complete()
        complete['desktop_text'] = {}  # a Mac-only capability
        self.assertEqual(missing_campaign(complete), [])


class AndroidContentTests(unittest.TestCase):
    def test_android_strings_are_stored_in_the_mac_numbering(self):
        from gof2_content.importer import install
        from test_content import fixture
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            resources = {n: d for n, d in fixture('ios').items() if n.startswith(('data/', 'FMOD'))}
            resources['gb.lang'] = b''.join(len(t).to_bytes(2, 'big') + t for t in (b's%d' % i for i in range(3401)))
            resources['data/audio/FMOD_GOF2.fev'] = resources.pop('FMOD_GOF2.fev')
            stage = root / 'android'
            stage.mkdir()
            (stage / OBB_NAME).write_bytes(zip_bytes({PREFIX + n: d for n, d in resources.items()}))
            (stage / 'game.apk').write_bytes(apk())
            base, manifest = install(stage, root / 'cache')
            self.assertEqual((manifest['profile']['edition'], manifest['languages']['gb']['records']), ('android-hd', 3401))
            strings = json.loads((base / 'definitions/languages/gb.json').read_text())['strings']
            self.assertEqual([strings[i] for i in (47, 48, 187, 188, 3384, 3385, 3386, 3400)],
                             ['s47', 's49', 's188', 's199', 's3395', 's48', 's189', 's3400'])
            self.assertEqual((base / 'resources/data/bin/ships.bin').read_bytes(), SHIPS)
            self.assertTrue((base / 'resources/FMOD_GOF2.fev').is_file())


class AndroidAudioTests(unittest.TestCase):
    def test_android_languages_without_banks_use_the_default_language(self):
        from gof2_content.bindings import check_banks
        def audio():  # German first, English default, as in the original event project
            return {'default_language': 1, 'banks': [{'name': 'VOICE', 'variants': [
                {'hash_prefix': '2' * 16, 'suffix': '_deu', 'resource': 'resources/VOICE_deu.fsb'},
                {'hash_prefix': '1' * 16, 'suffix': '_eng', 'resource': 'resources/VOICE_eng.fsb'}]}]}
        english = {'resources/VOICE_eng.fsb': {'kind': 'audio_bank'}}
        data = audio()
        check_banks(data, {'profile': {'edition': 'android-hd'}, 'files': english})
        self.assertEqual(data['banks'][0]['variants'], [audio()['banks'][0]['variants'][1]] * 2)
        for edition, files in (('mac-full-hd', english), ('android-hd', {'resources/VOICE_deu.fsb': {'kind': 'audio_bank'}}),
                               ('android-hd', {'resources/VOICE_eng.fsb': {'kind': 'other'}})):
            with self.assertRaisesRegex(ContentError, 'missing sound bank'):
                check_banks(audio(), {'profile': {'edition': edition}, 'files': files})
        data = audio()
        check_banks(data, {'profile': {'edition': 'android-hd'},
                           'files': dict(english, **{'resources/VOICE_deu.fsb': {'kind': 'audio_bank'}})})
        self.assertEqual(data, audio())


if __name__ == '__main__':
    unittest.main()
