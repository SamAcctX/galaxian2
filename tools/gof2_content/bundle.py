"""Read-only IPA/app ZIP and extracted app access, with bounded streaming."""
from contextlib import contextmanager
from pathlib import Path, PurePosixPath
import os
import plistlib
import re
import stat
import zipfile

from .formats import ContentError

MAX_ENTRIES = 20000
MAX_RESOURCE = 256 * 1024 * 1024
MAX_TOTAL = 8 * 1024 * 1024 * 1024
CHUNK = 1024 * 1024
ANDROID_LIBRARY = 'lib/armeabi-v7a/libgof2hdaa.so'
LANGUAGES = {'de', 'es', 'fr', 'gb', 'it', 'ja', 'ko', 'pl', 'ptl', 'ru', 'zs', 'zt'}
CATALOGUES = {'agents', 'collision', 'collision_test', 'docks', 'docks_hd', 'items',
              'shipparts', 'ships', 'static_collisions', 'stationparts', 'stations',
              'systems', 'ticker', 'wanted', 'weapons_hd', 'weapons_sd', 'wreck_collisions',
              'names_bobolan_0', 'names_bobolan_1', 'names_cyborg_0', 'names_grey_0',
              'names_multipod_0', 'names_multipod_1', 'names_nivelian_0', 'names_nivelian_1',
              'names_terran_0_m', 'names_terran_0_w', 'names_terran_1', 'names_vossk_0', 'names_vossk_1'}


def archive_files(archive):
    """(name, info) of every regular member, refusing links, encryption and ambiguity."""
    infos = archive.infolist()
    if len(infos) > MAX_ENTRIES:
        raise ContentError('Too many archive entries')
    seen, files = set(), []
    for info in infos:
        name = safe_name(info.filename[:-1] if info.is_dir() else info.filename)
        if name.casefold() in seen:
            raise ContentError(f'Duplicate or ambiguous archive path: {name}')
        seen.add(name.casefold())
        mode = info.external_attr >> 16
        if stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR):
            raise ContentError(f'Unsupported archive link or special file: {name}')
        if info.flag_bits & 1:
            raise ContentError(f'Encrypted archive entry: {name}')
        if not info.is_dir():
            files.append((name, info))
    return files


def safe_name(name: str) -> str:
    parts = name.split('/')
    if (not name or len(name) > 1024 or '\\' in name or ':' in name
            or any(p in ('', '.', '..') for p in parts)
            or any(ord(c) < 32 for c in name)):
        raise ContentError(f'Unsafe resource path: {name!r}')
    return name


def selected(name: str) -> bool:
    p = PurePosixPath(name)
    if len(p.parts) == 1:
        return ((p.suffix == '.lang' and p.stem in LANGUAGES)
                or (p.name.startswith('FMOD_GOF2') and p.suffix in ('.fsb', '.fev')))
    if p.parent.as_posix() == 'data/bin':
        return p.suffix == '.bin' and p.stem in CATALOGUES
    if p.parent.as_posix() in ('data/meshes', 'data/textures'):
        return ((p.parent.name == 'meshes' and p.suffix == '.aem')
                or (p.parent.name == 'textures' and p.suffix == '.aei'))
    return (len(p.parts) >= 5 and p.parts[:2] == ('data', 'assets')
            and p.parts[2] in ('main', 'valkyrie', 'supernova') and p.suffix in ('.aem', '.aei'))


class Bundle:
    def __init__(self, source: Path, checkpoint=lambda *_: None):
        self.source = source.absolute()
        self.zip = None
        self.entries = {}
        self.root = ''
        self.profile = {}
        self.info_path = ''
        self.executable_name = None
        self.dmg = None
        self.archives = []
        self.owners = {}
        self.checkpoint = checkpoint

    def __enter__(self):
        try:
            self._discover()
            return self
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def __exit__(self, *_):
        for archive in self.archives:
            archive.close()
        if self.dmg:
            self.dmg.__exit__(None, None, None)

    def _discover(self):
        if self.source.is_symlink():
            raise ContentError('Choose a regular archive or extracted .app, not a symbolic link')
        if self.source.suffix.lower() == '.dmg':
            from .dmg import DmgApp
            self.dmg = DmgApp(self.source, self.checkpoint)
            self.source = self.dmg.__enter__()
            self._discover()
            if self.profile.get('edition') != 'mac-full-hd':
                raise ContentError('The DMG must contain Galaxy on Fire 2 Full HD for Mac')
            return
        if self.source.is_dir() and self.source.name == 'android':
            return self._android()
        if self.source.is_dir():
            if self.source.suffix.lower() != '.app':
                raise ContentError('Choose the extracted .app directory itself')
            seen = set()
            for base, dirs, files in os.walk(self.source, followlinks=False):
                for name in dirs + files:
                    path = Path(base) / name
                    rel = safe_name(path.relative_to(self.source).as_posix())
                    if rel.casefold() in seen:
                        raise ContentError(f'Ambiguous case-insensitive path: {rel}')
                    seen.add(rel.casefold())
                    if len(seen) > MAX_ENTRIES:
                        raise ContentError('Too many bundle entries')
                    mode = path.lstat().st_mode
                    if stat.S_ISLNK(mode) or not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)):
                        raise ContentError(f'Unsupported link or special file in app: {rel}')
                    if stat.S_ISREG(mode):
                        self.entries[rel] = (path.stat().st_size, path)
            candidates = [n for n in ('Info.plist', 'Contents/Info.plist') if n in self.entries]
        else:
            self.zip = self.archive(self.source, 'Choose a readable IPA or ZIP containing one .app')
            for name, info in archive_files(self.zip):
                self.entries[name] = (info.file_size, info)
            candidates = [n for n in self.entries if n.endswith('.app/Info.plist') or n.endswith('.app/Contents/Info.plist')]
        if len(candidates) != 1:
            raise ContentError('Expected exactly one application bundle with Info.plist')
        info_path = candidates[0]
        try:
            info = plistlib.loads(self.read(info_path, 1024 * 1024))
        except (plistlib.InvalidFileException, ValueError, TypeError) as error:
            raise ContentError('Invalid bundle Info.plist') from error
        if not isinstance(info, dict):
            raise ContentError('Bundle Info.plist must be a dictionary')
        bundle_id = info.get('CFBundleIdentifier')
        if bundle_id == 'www.fishlabs.net.gof2hd' and not info_path.endswith('Contents/Info.plist'):
            edition = 'ios-hd'
            self.root = info_path.removesuffix('Info.plist')
        elif bundle_id == 'www.fishlabs.net.gof2mac' and info_path.endswith('Contents/Info.plist'):
            edition = 'mac-full-hd'
            self.root = info_path.removesuffix('Info.plist') + 'Resources/'
        else:
            raise ContentError('Unsupported bundle identity or layout; expected GoF2 iOS HD or Mac Full HD')
        self.profile = {'edition': edition, 'bundle_identifier': bundle_id,
                        'bundle_version': str(info.get('CFBundleShortVersionString', info.get('CFBundleVersion', 'unknown')))}
        self.info_path = info_path
        self.executable_name = info.get('CFBundleExecutable')

    def archive(self, path, message):
        try:
            archive = zipfile.ZipFile(path)
        except (zipfile.BadZipFile, OSError) as error:
            raise ContentError(message) from error
        self.archives.append(archive)
        return archive

    def _android(self):
        """An unpacked Android release (android_source): the OBB holds the
        resources in the Mac layout (sound banks under data/audio), the game APK
        the library and the original (Default Economy) item and ship tables."""
        from .android_source import PACKAGE
        files = sorted(p.name for p in self.source.iterdir())
        obbs = [n for n in files if n.startswith('main.') and n.endswith('.' + PACKAGE + '.obb')]
        if len(files) != 2 or 'game.apk' not in files or len(obbs) != 1:
            raise ContentError('Unexpected Android release stage')
        obb = self.archive(self.source / obbs[0], 'The Android expansion file (OBB) is not a readable ZIP')
        apk = self.archive(self.source / 'game.apk', 'The Android game APK is not a readable ZIP')
        roots = {name.split('/', 1)[0] for name, _ in archive_files(obb)}
        if len(roots) != 1 or not re.fullmatch(r'[0-9]+_GOF2CONTENT_ETC', next(iter(roots))):
            raise ContentError('Unsupported Android expansion file layout')
        prefix = next(iter(roots)) + '/assets/'
        seen = set()
        for name, info in archive_files(obb):
            if not name.startswith(prefix):
                continue
            name = name[len(prefix):]
            if name.startswith('data/audio/FMOD_GOF2'):
                name = name.removeprefix('data/audio/')
            if name.casefold() in seen:
                raise ContentError(f'Duplicate or ambiguous Android resource: {name}')
            seen.add(name.casefold())
            self.entries[name] = (info.file_size, info)
        own = dict(archive_files(apk))
        tables = [f'data/bin/{table}.bin' for table in ('items', 'ships')]
        if any('assets/' + table not in own for table in tables):
            raise ContentError('This release uses the free-to-play Android economy; choose the Default Economy .xapk')
        for table in tables:
            self.entries[table] = (own['assets/' + table].file_size, own['assets/' + table])
        if ANDROID_LIBRARY not in own:
            raise ContentError('The Android game APK lacks its ARMv7 game library')
        self.entries[ANDROID_LIBRARY] = (own[ANDROID_LIBRARY].file_size, own[ANDROID_LIBRARY])
        self.owners = {id(info): archive for archive in (obb, apk) for info in archive.infolist()}
        self.profile = {'edition': 'android-hd', 'bundle_identifier': PACKAGE, 'bundle_version': obbs[0].split('.')[1]}
        self.info_path = obbs[0]

    def executable(self):
        """Locate optional import-time static input; never open or execute it here."""
        if self.profile.get('edition') == 'android-hd':
            return ANDROID_LIBRARY
        name = self.executable_name
        if not isinstance(name, str) or '/' in name:
            raise ContentError('Missing or invalid CFBundleExecutable for declaration extraction')
        safe_name(name)
        prefix = self.info_path.removesuffix('Info.plist')
        path = prefix + ('MacOS/' if self.profile['edition'] == 'mac-full-hd' else '') + name
        if path not in self.entries:
            raise ContentError('Bundle executable named by Info.plist is missing')
        return path

    def resources(self) -> dict[str, int]:
        resources = {n[len(self.root):]: v[0] for n, v in self.entries.items()
                     if n.startswith(self.root) and selected(n[len(self.root):])}
        if any(size <= 0 or size > MAX_RESOURCE for size in resources.values()):
            raise ContentError('Empty resource or resource exceeds the 256 MiB import limit')
        if sum(resources.values()) > MAX_TOTAL:
            raise ContentError('Resource set exceeds the 8 GiB import limit')
        required = {f'data/bin/{n}.bin' for n in ('ships', 'items', 'systems', 'stations')}
        required |= {'gb.lang'}
        missing = required - resources.keys()
        if missing:
            raise ContentError('Missing required resources: ' + ', '.join(sorted(missing)))
        for suffix in ('.aem', '.aei'):
            if not any(n.startswith('data/assets/main/') and n.endswith(suffix) for n in resources):
                raise ContentError(f'Missing main asset family: {suffix}')
        return dict(sorted(resources.items()))

    @contextmanager
    def open(self, name):
        size, entry = self.entries[name]
        if self.archives:
            with (self.owners[id(entry)] if self.owners else self.zip).open(entry) as stream:
                yield stream
        else:
            # Refuse a link substituted since discovery, including parent directories.
            path = entry
            while path != self.source.parent:
                if path.is_symlink():
                    raise ContentError(f'Bundle changed to a symbolic link: {name}')
                path = path.parent
            with entry.open('rb') as stream:
                if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                    raise ContentError(f'Not a regular resource: {name}')
                yield stream

    def read(self, name, limit):
        if self.entries[name][0] > limit:
            raise ContentError(f'Oversized metadata: {name}')
        with self.open(name) as stream:
            data = stream.read(limit + 1)
        if len(data) > limit or len(data) != self.entries[name][0]:
            raise ContentError(f'Resource size changed: {name}')
        return data
