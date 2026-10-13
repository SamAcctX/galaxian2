"""Static Mac declarations for physical player/scenery contacts.

The two recognized compiler layouts are read as bounded data. This reader does
not execute the source binary or emit any of its instructions into a pack.

Android: PlayerEgo::update moves the player, then PlayerEgo::calcCollision
tests landmarks (station first), enemies and asteroids through their vtable
slots: an asteroid hit (PlayerAsteroid::collide, a strict box around the intact
body) damages the asteroid 9999 and the player 20 and pushes along
PlayerAsteroid::getProjectionVector; a station hit (PlayerStation::outerCollide)
projects the player out of the volumes in two passes without damage.
PlayerEgo::stopMining finishes a mined asteroid; LevelScript toggles the
player's collide flag through the opening.
"""

import copy

from .declaration_layouts import recognize, recognize_symbols
from .station_exterior import declaration_bytes, vtable_proof


VALUES = {
    'scope': 'physical_scenery_contacts',
    'player_stage': 'after_motion_before_aim_recharge',
    'collision_gate': 'player_permission_and_active_statistics',
    'station_slot': 0,
    'station_contact': 'strict_authored_point_volume',
    'station_projection_passes': 2,
    'station_damage': 0,
    'asteroid_contact': 'strict_point_inside_intact_body_axis_box',
    'asteroid_damage': 9999,
    'player_damage': 20,
    'asteroid_impact': 'body_center_minus_player_center_normalized',
    'selected_mining_target_excluded': True,
    'mining_finish': 'inactive_negative_hull_without_combat_destruction',
    'opening_collision_initial_enabled': False,
    'opening_collision_enabled_phase': 4,
    'opening_collision_escape_phase': 5,
    'opening_collision_earned_escape_enabled': False,
    'opening_collision_sample': 'incoming_player_phase_before_controller',
}

# Layouts are relative to the already verified arrival actor. SHA-256 protects
# each complete route, including response geometry and the mining sentinel.
# The order is App Store Mac, then the older Mac source.
LAYOUTS = (
    {
        'player_sample': (571779, 52, '__text', 'sha256:e43364b1b218711b28814b560af59a8b342c147e960c3cf5628f6e15fdd1df13'),
        'player_motion': (576697, 142, '__text', 'sha256:31c1173b85f29179770f519832110c42703c75837aea26cb4faf40464ed2ccfd'),
        'collision_gate': (576839, 90, '__text', 'sha256:293bec3c26245ba45cb0f1f83c7007e8c0742edca43f97cd636ea4f9e039bf07'),
        'world_contact': (585516, 1666, '__text', 'sha256:6291961459685f1c54e878ed459442c56c2bb4e1e557f57861f3cffc0d7df75b'),
        'asteroid_active': (547365, 22, '__text', 'sha256:68f1f2cde96fa48a3e3e78f682a34986b35d17fd70e21eb0c9b0065a23137d1b'),
        'asteroid_normal': (550106, 158, '__text', 'sha256:9a2741c5a98ab7f493032d0db64741988815125b3c76c6b4bd055ad0a59a4661'),
        'asteroid_collider': (550264, 202, '__text', 'sha256:323b3f0aa70674d1cf6623bb81f2e31a5b5d787444fbce3174d66004f31eafe0'),
        'asteroid_vtable': (2376994, 72, '__const', 'sha256:4786838275210ca1cf9d9b6c1dad20b9e2907203b651b1c732377ad1eaeaf185'),
        'station_query': (650374, 232, '__text', 'sha256:fb5c26f9ca56ebe49f7b5725afc701ab8c33622a7a223bd23430c72546bb1b25'),
        'station_projection': (-713946, 190, '__text', 'sha256:f87b4e38414c5d4bce79fc21926ba8dbe8e8dfa53de88199f4849d111f1e9e59'),
        'station_response_vtable': (2378722, 24, '__const', 'sha256:140b9de14b108a9ded457c2e5eaa488e2065394f820a145a81f78c4307b33f20'),
        'box_projection': (-715776, 498, '__text', 'sha256:65462a43ad8150a0d241548447f875b21c9217184361f5a6d57a792bc0bfa323'),
        'sphere_projection': (-714814, 236, '__text', 'sha256:1e8711e9b6dfb1ad2d877e82172217b15753231f85996a22b5de806142679681'),
        'mining_finish': (602607, 61, '__text', 'sha256:22664bc5ac3d8d0148c7fcf21212078b47585079d01244ac1ab924b5a0643a4c'),
        'permission_setter': (560162, 14, '__text', 'sha256:72c854ab442e1d26da6d19e240e26911b289aa942d1d28ebd5fa79efb1dc85e2'),
        'opening_constructor_off': (122009, 18, '__text', 'sha256:6d9d874bc7a4286be626c884c4c1462d6ad8cbeb5ce523c992b52887deee397a'),
        'opening_release_on': (139783, 128, '__text', 'sha256:34d4f4a5ab2018215ae4197c1a9d7279c05103c687f3af5aa3c099075cf3ece7'),
        'opening_escape_off': (150612, 306, '__text', 'sha256:29aa6d80b917e302bbe916b75e96f74fd96996807e1949422eb6fcb8aa716861'),
        'opening_escape_guard': (150932, 250, '__text', 'sha256:1073984dc13794f28a8a9fd65528f7dfa5952f7dca68bfa745995b3ee55bc040'),
    },
    {
        'player_sample': (571243, 52, '__text', 'sha256:d30c0e56ca68e9763192db1db9d03c20a6790c33159343c950886b930376d91c'),
        'player_motion': (576161, 142, '__text', 'sha256:494a9a3967940c307708445641b658c3089efe1e856b3f1cf78668042ab58a57'),
        'collision_gate': (576303, 90, '__text', 'sha256:737ab42ce6d4158870418b9c89b9467b87af3b5a315c182fc242354623cc5469'),
        'world_contact': (584980, 1664, '__text', 'sha256:dba54a15b0187d1df48d2606405ccdb99b49380e238efca044a092c593bd024a'),
        'asteroid_active': (546829, 22, '__text', 'sha256:68f1f2cde96fa48a3e3e78f682a34986b35d17fd70e21eb0c9b0065a23137d1b'),
        'asteroid_normal': (549570, 158, '__text', 'sha256:5ff6dbf2a5bca2966f365ec228b780a40df56df2ed6552f0015b92ef8f31ab40'),
        'asteroid_collider': (549728, 202, '__text', 'sha256:c2e45edc38e4b96153881f0a328c82f0cef4f8bdadc10f13fdf754b75ed2afcd'),
        'asteroid_vtable': (2399562, 72, '__const', 'sha256:98ceb7da740629ba09baae43eac283fe612cc0fe8adcf5e2b9809611e1e383ee'),
        'station_query': (649826, 232, '__text', 'sha256:fb5c26f9ca56ebe49f7b5725afc701ab8c33622a7a223bd23430c72546bb1b25'),
        'station_projection': (-708050, 190, '__text', 'sha256:27c3fcc081133c72c85fcf7aa95d63f90eafaff322fd9553f1bb3c70c30df61b'),
        'station_response_vtable': (2401290, 24, '__const', 'sha256:cfd1fbfaedf52ae26138ab528022d02fd1a05d8e689829ccd2b7d962d975d363'),
        'box_projection': (-709880, 498, '__text', 'sha256:bdd49c9c468882734200b5c30f1c2ffe93f4a175356a1a85a79a7b0b490da03d'),
        'sphere_projection': (-708918, 236, '__text', 'sha256:146dc1e4b292e53be36ef132aafa7000fde518513f2dce1f9ff7930c706ca23d'),
        'mining_finish': (602059, 61, '__text', 'sha256:3f907355c0f646f4e39c4783753a35f84b0e4c34322999f7b5116f72a856c5c4'),
        'permission_setter': (559626, 14, '__text', 'sha256:72c854ab442e1d26da6d19e240e26911b289aa942d1d28ebd5fa79efb1dc85e2'),
        'opening_constructor_off': (122009, 18, '__text', 'sha256:bd8a2d1f69a8e7d58e1053130e20ceedf2f32704acd8a2fda7f4eb9a6a46982b'),
        'opening_release_on': (139783, 128, '__text', 'sha256:1c29ed2df466f05d3f090107ef2c00c54dc5815cd479848506eaa7972c01ce1b'),
        'opening_escape_off': (150612, 306, '__text', 'sha256:81bf5e61d073d8d88f9bbd3589bd0807ae686e10b2d094dbb030a6aef5149d64'),
        'opening_escape_guard': (150932, 250, '__text', 'sha256:1d44cf7c84cc588cb30af3fa872ac75866c64a8bf47b93774ae2a86cd6804a24'),
    },
)


def extract_physical_scenery_contacts(mach, arrival, scenery_resources, station_exterior, opening_staging):
    """Return a new optional capability only when one whole Mac layout matches."""
    if mach.architecture == 'android-armv7':
        return android_contacts(mach, arrival, scenery_resources, station_exterior, opening_staging)
    if mach.architecture != 'x86_64' or not scenery_resources or station_exterior.get('scope') != 'first_mining_station_exterior':
        return {}
    try:
        origin = arrival['provenance']['actor']
        if origin['bytes'] != 315:
            return {}
        initial = opening_staging['provenance']['initial']
        motion = opening_staging['player_motion']
        escape = opening_staging['escape']
        if (initial['bytes'] != 366 or motion['motion_before_controller'] is not True
                or motion['release_phase'] != VALUES['opening_collision_enabled_phase']
                or motion['release_after_event_finished'] != 8
                or escape['entry_phase'] != motion['release_phase']
                or escape['first_phase'] != VALUES['opening_collision_escape_phase']
                or escape['entry_after_event_finished'] != 10):
            return {}
        links = {
            'opening_constructor_off': initial['offset'] - 18,
            'opening_release_on': motion['provenance']['release']['offset'],
            'opening_escape_off': escape['provenance']['entry']['offset'],
        }
        layouts = [{key: (row[2], row[0], row[1], row[3])
                    for key, row in variant.items()} for variant in LAYOUTS]
        proof = recognize(mach, origin['offset'], layouts, links=links, reader=declaration_bytes)
        if not proof:
            return {}
        result = copy.deepcopy(VALUES)
        result['provenance'] = proof
        return result
    except (KeyError, TypeError, ValueError, IndexError, OverflowError):
        return {}


def android_contacts(lib, arrival, scenery_resources, station_exterior, opening_staging):
    try:
        motion, escape = opening_staging['player_motion'], opening_staging['escape']
        if (not arrival or not scenery_resources or station_exterior.get('scope') != 'first_mining_station_exterior'
                or motion['motion_before_controller'] is not True or motion['release_phase'] != VALUES['opening_collision_enabled_phase']
                or motion['release_after_event_finished'] != 8 or escape['entry_phase'] != motion['release_phase']
                or escape['first_phase'] != VALUES['opening_collision_escape_phase'] or escape['entry_after_event_finished'] != 10):
            return {}
        entry = escape['provenance']['entry']
    except (KeyError, TypeError, AttributeError):
        return {}
    proof = recognize_symbols(lib, ANDROID)
    vtables = vtable_proof(lib, ANDROID_VTABLES) if proof else None
    # The escape entry that switches contacts off is the escape's own.
    if vtables is None or proof['opening_escape_off'] != entry:
        return {}
    # Every value is a scalar: a shallow copy cannot share state.
    return dict(ANDROID_VALUES, provenance={**proof, **vtables})


# The values equal the Mac's.
ANDROID_VALUES = copy.deepcopy(VALUES)
ANDROID = {# PlayerEgo::update samples the incoming position, moves, then (collide flag and an active
           # player) runs PlayerEgo::calcCollision over the landmarks (station first), enemies and asteroids.
           'player_sample': ('_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi', 66, 24, '1eacd9f808102046c1f762ee09f5a47021460390bef782ef'),
           'player_motion': ('_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi', 3764, 112, 'sha256:648e3f520e6cdedb010fe24910b2007329f5023e53d5d48f2c3155598a8dbe9a'),
           'collision_gate': ('_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi', 3876, 72, 'sha256:26db1712313291e184709486be1b1355fe147b09ce30907cf61b4d6db8b448e4'),
           'active_getter': ('_ZN6Player8isActiveEv', 0, 6, '90f8c0007047'),
           'world_contact': ('_ZN9PlayerEgo13calcCollisionEP5ArrayIP8KIPlayerE', 0, 1112, 'sha256:79a5f8fc0b0aa59035d11e5caeebf7281059c6e2d5aa467e102db4dd4e377d52'),
           # Asteroids start active; their contact is a strict box around the intact body.
           'asteroid_active': ('_ZN14PlayerAsteroidC2EiP10AEGeometryiiRKN11AbyssEngine6AEMath6VectorEfi', 726, 14, '2e48012184f83810784484f84810'),
           'asteroid_normal': ('_ZN14PlayerAsteroid19getProjectionVectorERKN11AbyssEngine6AEMath6VectorE', 0, 124, 'sha256:c03acc54321fe38d7b50b67aa3fbeea284732f37c6efbd02f53db7ff667489f2'),
           'asteroid_collider': ('_ZN14PlayerAsteroid7collideEfff', 0, 224, 'sha256:eb331139811aaba26a1a206c05e5d551c1ad2a7833d91802607da9395917c8b4'),
           'asteroid_outer': ('_ZN14PlayerAsteroid12outerCollideEfff', 0, 10, 'd0f800c0dcf838c06047'),
           'point_outer': ('_ZN8KIPlayer12outerCollideERKN11AbyssEngine6AEMath6VectorE', 0, 26, 'sha256:f17e832adf701edfbae43085c2eee53d9a06a6a41bf0fb96dc70f9be22857316'),
           # The station: bounds, then volumes; projection over the volumes in two passes.
           'station_query': ('_ZN13PlayerStation12outerCollideEfff', 0, 204, 'sha256:20df89ebdb867e50a995c5c1ea3af55fcd22fc11ac77b8df797b95142917fb84'),
           'station_point_outer': ('_ZN13PlayerStation12outerCollideERKN11AbyssEngine6AEMath6VectorE', 0, 26, 'sha256:f17e832adf701edfbae43085c2eee53d9a06a6a41bf0fb96dc70f9be22857316'),
           'station_projection': ('_ZN13PlayerStation25projectCollisionOnSurfaceERKN11AbyssEngine6AEMath6VectorE', 0, 18, '80b56f46d1f82c3111461a4626f7b8eb80bd'),
           'volume_projection': ('_ZN14BoundingVolume31staticProjectCollisionOnSurfaceERKN11AbyssEngine6AEMath6VectorEP5ArrayIPS_E', 0, 160, 'sha256:9a4239c897e710b2db56fad340df278e018af39d184decb35bfc65ddad0b7435'),
           'box_projection': ('_ZN11BoundingAAB25projectCollisionOnSurfaceERKN11AbyssEngine6AEMath6VectorE', 0, 388, 'sha256:01de62f9d3b44a2e96b19d2c2d432c9d358264cef0ca37c84152cd05ba6c0af0'),
           'sphere_projection': ('_ZN14BoundingSphere25projectCollisionOnSurfaceERKN11AbyssEngine6AEMath6VectorE', 0, 180, 'sha256:923db3843dd59a6f60ac476a631fb61df227826859294a6496a809b902a73a69'),
           # PlayerEgo::stopMining: the target becomes inactive with hull -1.
           'mining_finish': ('_ZN9PlayerEgo10stopMiningEv', 406, 46, 'sha256:6e097dae2fd71b6347088edf4532b89febcf334bb1343816d3c7c510ff295c83'),
           'permission_setter': ('_ZN9PlayerEgo10setCollideEb', 0, 6, '80f844117047'),
           # Opening: off in LevelScript's constructor, on at the phase-4 release, off at the
           # escape entry; the guard re-enables only after the escape (cursor 2, 7001 ms).
           'opening_constructor_off': ('_ZN11LevelScriptC2EP5LevelP3HudP5RadarP18TargetFollowCamera', 248, 14, '50460cf708ea0021002610f7f0ec'),
           'opening_release_on': ('_ZN11LevelScript7processEi', 4350, 86, 'sha256:e6edef929d2d6c2e574532484ee73ab745229e91d922bff9f393eb7679609f5e'),
           'opening_escape_off': ('_ZN11LevelScript7processEi', 6540, 238, 'sha256:347cc489aaad4f32754a3e7a736da5e84d39a7c9bee5679014c545b728398655'),
           'opening_escape_guard': ('_ZN11LevelScript7processEi', 716, 198, 'sha256:42b5d6ba70177c0aafb8ff6cdbb8144a9c5eeabf9680fc2ffcff23b2b15af93a')}
# calcCollision's slots: outer test (16, through 15 and 14), position (10), projection (20, 22).
ANDROID_VTABLES = {'asteroid_vtable': ('_ZTV14PlayerAsteroid', 14, ['_ZN14PlayerAsteroid7collideEfff', '_ZN14PlayerAsteroid12outerCollideEfff',
                                                                    '_ZN8KIPlayer12outerCollideERKN11AbyssEngine6AEMath6VectorE',
                                                                    '_ZN14PlayerAsteroid11setPositionERKN11AbyssEngine6AEMath6VectorE',
                                                                    '_ZN8KIPlayer11setPositionEfff', '_ZN8KIPlayer8getSpeedEv',
                                                                    '_ZN14PlayerAsteroid19getProjectionVectorERKN11AbyssEngine6AEMath6VectorE',
                                                                    '_ZN8KIPlayer18getCollisionNormalERKN11AbyssEngine6AEMath6VectorE',
                                                                    '_ZN8KIPlayer25projectCollisionOnSurfaceERKN11AbyssEngine6AEMath6VectorE']),
                   'station_response_vtable': ('_ZTV13PlayerStation', 20, ['_ZN13PlayerStation19getProjectionVectorERKN11AbyssEngine6AEMath6VectorE',
                                                                           '_ZN8KIPlayer18getCollisionNormalERKN11AbyssEngine6AEMath6VectorE',
                                                                           '_ZN13PlayerStation25projectCollisionOnSurfaceERKN11AbyssEngine6AEMath6VectorE'])}
