#!/usr/bin/env python3
"""Transliteration of did2.convert.resolveLawnPlateSubjects + jPatchLocalId,
driven with the literal MATLAB fixtures, so mutations can be shown to fail.

THIS IS A TRANSLITERATION, NOT A RUN. There is no MATLAB in this container.
What it proves is that the LOGIC is sensitive to each mutation -- i.e. that the
tests written beside it are not vacuous. It cannot prove MATLAB syntax.
"""
import math
import re
import sys

MUT = set(sys.argv[1:])

# ---------------- the pass, transliterated ----------------

TOK_PLATE = 'bacterialplateidentifier'
TOK_PATCH = 'bacterialpatchidentifier'
TOK_IMAGE = 'microscopyimageidentifier'
TOK_EXP = 'experimentsessionidentifier'
TOK_POURED = 'agarplatepouringtimestamp'
TOK_POURED_COLD = 'agarplatecoldstoragetimestamp'

PLATE_MEASURES = [
    ('bacterialod600measurement', 'concentration_observation'),
    ('bacterialod600targetatseeding', 'concentration_observation'),
    ('bacterialcolonyformingunitscfumeasurement', 'concentration_observation'),
    ('bacterialpatchvolume', 'volume_observation'),
]
LAWN_MEASURES = [
    ('bacterialpatchradius', 'length_observation'),
    ('bacterialpatchcircularity', 'score_observation'),
    ('bacterialpatchborderpeakfluorescenceintensity', 'intensity_observation'),
    ('bacterialpatchborderedgefluorescenceintensity', 'intensity_observation'),
    ('bacterialpatchborderfluorescenceamplitude', 'intensity_observation'),
    ('bacterialpatchmeanfluorescenceamplitude', 'intensity_observation'),
    ('bacterialpatchcenterfluorescenceamplitude', 'intensity_observation'),
    ('bacterialpatchbordertocenterfluorescenceratio', 'intensity_observation'),
]
KNOWN = {TOK_PLATE, TOK_PATCH, TOK_IMAGE, TOK_EXP, TOK_POURED, TOK_POURED_COLD}
KNOWN |= {t for t, _ in PLATE_MEASURES} | {t for t, _ in LAWN_MEASURES}


def normalise(s):
    if s is None:
        return ''
    return ''.join(c for c in str(s).lower() if c.isalnum() and c.isascii())


def extract_columns(block):
    """cols + (by_key, by_name)."""
    keys = [x.strip() for x in block['variable_names'].split(',')]
    names = [x.strip() for x in block['names'].split(',')]
    nodes = [x.strip() for x in block['ontology_nodes'].split(',')]
    data = block['data']
    cols, by_key, by_name = [], 0, 0
    for i, key in enumerate(keys):
        nm = names[i] if i < len(names) else ''
        nd = nodes[i] if i < len(nodes) else ''
        val = data.get(key)
        tk, tn = normalise(key), normalise(nm)
        token = tk
        if 'M_NO_NAME_CHANNEL' in MUT:
            if tk in KNOWN:
                by_key += 1
        else:
            if tk in KNOWN:
                by_key += 1
            elif tn in KNOWN:
                token, = (tn,)
                by_name += 1
        cols.append({'key': key, 'name': nm, 'node': nd, 'value': val,
                     'token': token})
    return cols, by_key, by_name


def col(cols, token):
    for c in cols:
        if c['token'] == token:
            return c
    return None


def col_val(cols, token):
    c = col(cols, token)
    if c is None:
        return ''
    v = c['value']
    if isinstance(v, str):
        return v
    if isinstance(v, bool):
        return ''
    if isinstance(v, (int, float)) and not math.isnan(v):
        return repr(v)
    return ''


def classify(cols):
    has_plate = col(cols, TOK_PLATE) is not None
    has_patch = col(cols, TOK_PATCH) is not None
    has_image = col(cols, TOK_IMAGE) is not None
    has_poured = (col(cols, TOK_POURED) is not None
                  or col(cols, TOK_POURED_COLD) is not None)
    if 'M_PLATE_NO_POURED_CLAUSE' in MUT:
        has_poured = True
    if has_image and has_patch and not has_plate:
        return 3
    if has_image and has_plate and not has_patch:
        return 2
    if has_plate and has_poured and not has_image:
        return 1
    return 0


def scalar_number(x):
    if x is None:
        return (False, None)
    if isinstance(x, bool):
        if 'M_ACCEPT_LOGICAL' in MUT:
            return (True, 1.0 if x else 0.0)
        return (False, None)
    if isinstance(x, (int, float)):
        if math.isnan(x) or math.isinf(x):
            return (False, None)
        return (True, float(x))
    if isinstance(x, str):
        try:
            v = float(x)
        except ValueError:
            return (False, None)
        if math.isnan(v) or math.isinf(v):
            return (False, None)
        return (True, v)
    return (False, None)


def row_has_any_value(cols, id_tokens):
    for c in cols:
        if c['token'] in id_tokens:
            continue
        v = c['value']
        if v is None or v == '':
            continue
        if isinstance(v, float) and math.isnan(v):
            continue
        return True
    return False


def join_key(session, local):
    if 'M_UNSCOPED_JOIN' in MUT:
        return str(local)
    return '%s|%s' % (session, local)


def plate_handle(exp, plate):
    return 'exp/%s/plate/%s' % (exp, plate)


def patch_handle(exp, plate, patch):
    if 'M_BARE_PATCH_HANDLE' in MUT:
        return str(patch)
    return 'exp/%s/plate/%s/patch/%s' % (exp, plate, patch)


def pair_handle(plate, patch):
    return 'plate/%s/patch/%s' % (plate, patch)


PAIR_RE = re.compile(r'^plate/([^/]+)/patch/([^/]+)$')


def j_patch_local_id(plate, patch, doc_id):
    """Pass 1's handle (ontology_table_row.m)."""
    if 'M_PASS1_BARE_PATCH' in MUT:
        return patch or doc_id
    li = ''
    if plate and patch:
        li = pair_handle(plate, patch)
    return li if li else doc_id


def blank_report():
    return dict(
        documents_inspected=0, ontology_table_rows_seen=0,
        plate_rows_seen=0, image_rows_seen=0, lawn_rows_seen=0,
        exp_id_source_rows_seen=0, sessions_with_lawn_plate_tables=0,
        unclassified_rows_in_those_sessions=0,
        columns_resolved_by_key=0, columns_resolved_by_term_name=0,
        plate_rows_with_measurements=0,
        plate_rows_with_values_but_none_emittable=0,
        plate_rows_with_no_values_at_all=0,
        plate_rows_refused_no_session_id=0, plate_rows_refused_no_plate_key=0,
        plate_rows_refused_no_exp_id=0,
        plate_subjects_minted=0, plate_observations_emitted=0,
        lawn_rows_with_measurements=0,
        lawn_rows_with_values_but_none_emittable=0,
        lawn_rows_with_no_values_at_all=0,
        lawn_rows_refused_no_session_id=0, lawn_rows_refused_no_identity_keys=0,
        lawn_subjects_minted=0, lawn_observations_emitted=0,
        chains_attempted=0, chains_resolved=0,
        refused_no_image_row=0, refused_image_row_ambiguous=0,
        refused_image_row_has_no_plate_key=0, refused_no_plate_row=0,
        refused_plate_row_ambiguous=0, refused_lawn_no_exp_id=0,
        member_of_relations_emitted=0,
        withheld_plate_tier_not_minted=0, withheld_lawn_tier_not_minted=0,
        celegans_patch_subjects_seen=0, celegans_patch_subjects_relabelled=0,
        celegans_patch_subjects_already_triple=0,
        celegans_patch_subjects_refused_no_exp_id=0,
        celegans_patch_subjects_refused_ambiguous_exp_id=0,
        celegans_patch_subjects_unparseable_handle=0,
        local_identifier_collisions_within_batch=0,
        source_rows_left_in_place=0, documents_appended=0,
    )


def run(batch):
    """batch: list of dicts, either {'kind':'row', ...} or {'kind':'subject',...}"""
    rep = blank_report()
    rep['documents_inspected'] = len(batch)
    rows = []
    for d in batch:
        if d['class'] != 'ontology_table_row':
            continue
        rep['ontology_table_rows_seen'] += 1
        cols, bk, bn = extract_columns(d['block'])
        rep['columns_resolved_by_key'] += bk
        rep['columns_resolved_by_term_name'] += bn
        rows.append({'doc': d, 'cols': cols, 'kind': classify(cols),
                     'session': d['session_id'],
                     'exp_src': col(cols, TOK_PLATE) is not None
                                and col(cols, TOK_EXP) is not None})
    rep['plate_rows_seen'] = sum(1 for r in rows if r['kind'] == 1)
    rep['image_rows_seen'] = sum(1 for r in rows if r['kind'] == 2)
    rep['lawn_rows_seen'] = sum(1 for r in rows if r['kind'] == 3)
    rep['exp_id_source_rows_seen'] = sum(1 for r in rows if r['exp_src'])
    rep['source_rows_left_in_place'] = (rep['plate_rows_seen']
                                        + rep['image_rows_seen']
                                        + rep['lawn_rows_seen'])
    live = {r['session'] for r in rows if r['kind'] > 0 and r['session']}
    rep['sessions_with_lawn_plate_tables'] = len(live)
    rep['unclassified_rows_in_those_sessions'] = sum(
        1 for r in rows if r['kind'] == 0 and r['session'] in live)

    if rep['plate_rows_seen'] == 0 and rep['lawn_rows_seen'] == 0:
        return rep, []

    image_plate, image_count = {}, {}
    for r in rows:
        if r['kind'] != 2 or not r['session']:
            continue
        iid = col_val(r['cols'], TOK_IMAGE)
        if not iid:
            continue
        k = join_key(r['session'], iid)
        if k in image_count:
            image_count[k] += 1
        else:
            image_count[k] = 1
            image_plate[k] = col_val(r['cols'], TOK_PLATE)

    plate_count = {}
    for r in rows:
        if r['kind'] != 1 or not r['session']:
            continue
        pid = col_val(r['cols'], TOK_PLATE)
        if not pid:
            continue
        k = join_key(r['session'], pid)
        plate_count[k] = plate_count.get(k, 0) + 1

    exp_by_plate, exp_ambiguous = {}, set()
    for r in rows:
        if not r['exp_src'] or not r['session']:
            continue
        pid = col_val(r['cols'], TOK_PLATE)
        eid = col_val(r['cols'], TOK_EXP)
        if not pid or not eid:
            continue
        k = join_key(r['session'], pid)
        if k in exp_by_plate:
            if exp_by_plate[k] != eid:
                exp_ambiguous.add(k)
        else:
            exp_by_plate[k] = eid

    def lookup_exp(k):
        if not k or k in exp_ambiguous:
            return ''
        return exp_by_plate.get(k, '')

    minted, handles = [], []
    for r in rows:
        kind = r['kind']
        if kind not in (1, 3):
            continue
        cols = r['cols']
        id_tokens = [TOK_PLATE] if kind == 1 else [TOK_IMAGE, TOK_PATCH]
        measures = PLATE_MEASURES if kind == 1 else LAWN_MEASURES
        obs = []
        for tok, leaf in measures:
            c = col(cols, tok)
            if c is None:
                continue
            ok, num = scalar_number(c['value'])
            if not ok:
                continue
            obs.append((leaf, num))
        if not obs:
            anyv = row_has_any_value(cols, id_tokens)
            if 'M_FUSE_THE_TWO_EMPTY_STATES' in MUT:
                anyv = False
            key = ('plate' if kind == 1 else 'lawn') + (
                '_rows_with_values_but_none_emittable' if anyv
                else '_rows_with_no_values_at_all')
            rep[key] += 1
            continue
        rep[('plate' if kind == 1 else 'lawn') + '_rows_with_measurements'] += 1

        if not r['session']:
            rep[('plate_rows_refused_no_session_id' if kind == 1
                 else 'lawn_rows_refused_no_session_id')] += 1
            continue
        idvals = [col_val(cols, t) for t in id_tokens]
        if not all(idvals):
            rep[('plate_rows_refused_no_plate_key' if kind == 1
                 else 'lawn_rows_refused_no_identity_keys')] += 1
            continue

        if kind == 1:
            pid = idvals[0]
            pkey = join_key(r['session'], pid)
            eid = lookup_exp(pkey)
            if not eid:
                rep['plate_rows_refused_no_exp_id'] += 1
                continue
            handle = plate_handle(eid, pid)
        else:
            rep['chains_attempted'] += 1
            ikey = join_key(r['session'], idvals[0])
            if ikey not in image_count:
                rep['refused_no_image_row'] += 1
                continue
            if image_count[ikey] > 1:
                rep['refused_image_row_ambiguous'] += 1
                continue
            pid = image_plate[ikey]
            if not pid:
                rep['refused_image_row_has_no_plate_key'] += 1
                continue
            pkey = join_key(r['session'], pid)
            if pkey not in plate_count:
                rep['refused_no_plate_row'] += 1
                continue
            if plate_count[pkey] > 1:
                rep['refused_plate_row_ambiguous'] += 1
                continue
            eid = lookup_exp(pkey)
            if not eid:
                if 'M_MINT_WITHOUT_EXP' not in MUT:
                    rep['refused_lawn_no_exp_id'] += 1
                    continue
                rep['chains_resolved'] += 1
                handle = pair_handle(pid, idvals[1])
                minted.append({'kind': 3, 'handle': handle,
                               'plate_key': pkey, 'obs': obs})
                handles.append(handle)
                continue
            rep['chains_resolved'] += 1
            handle = patch_handle(eid, pid, idvals[1])
        minted.append({'kind': kind, 'handle': handle, 'plate_key': pkey,
                       'obs': obs})
        handles.append(handle)

    rep['withheld_lawn_tier_not_minted'] = (
        rep['lawn_rows_with_values_but_none_emittable']
        + rep['lawn_rows_with_no_values_at_all'])

    # ---- the C. elegans relabel ----
    relabelled = []
    for d in batch:
        if d['class'] != 'subject':
            continue
        if d.get('description') != 'bacterial patch':
            continue
        rep['celegans_patch_subjects_seen'] += 1
        h = d['local_identifier']
        if h.startswith('exp/'):
            rep['celegans_patch_subjects_already_triple'] += 1
            continue
        m = PAIR_RE.match(h)
        if not m:
            rep['celegans_patch_subjects_unparseable_handle'] += 1
            continue
        k = join_key(d['session_id'], m.group(1))
        if k in exp_ambiguous:
            rep['celegans_patch_subjects_refused_ambiguous_exp_id'] += 1
            continue
        if not d['session_id'] or k not in exp_by_plate:
            rep['celegans_patch_subjects_refused_no_exp_id'] += 1
            continue
        nh = patch_handle(exp_by_plate[k], m.group(1), m.group(2))
        d['local_identifier'] = nh
        handles.append(nh)
        relabelled.append(nh)
        rep['celegans_patch_subjects_relabelled'] += 1

    seen = {}
    for h in handles:
        seen[h] = seen.get(h, 0) + 1
    rep['local_identifier_collisions_within_batch'] = sum(
        v - 1 for v in seen.values())

    plate_subject = {m['plate_key']: m for m in minted if m['kind'] == 1}
    appended = 0
    for m in minted:
        appended += 1
        rep[('plate' if m['kind'] == 1 else 'lawn')
            + '_subjects_minted'] += 1
        for _leaf, _num in m['obs']:
            appended += 1
            rep[('plate' if m['kind'] == 1 else 'lawn')
                + '_observations_emitted'] += 1
    for m in minted:
        if m['kind'] != 3:
            continue
        if m['plate_key'] not in plate_subject:
            if 'M_EMIT_DANGLING_MEMBER_OF' not in MUT:
                rep['withheld_plate_tier_not_minted'] += 1
                continue
            rep['member_of_relations_emitted'] += 1
            appended += 1
            continue
        rep['member_of_relations_emitted'] += 1
        appended += 1
    rep['documents_appended'] = appended
    return rep, minted


# ---------------- the fixtures, copied from the MATLAB file ----------------

def row(doc_id, session, keys, names, data):
    return {'class': 'ontology_table_row', 'id': doc_id, 'session_id': session,
            'block': {'variable_names': ','.join(keys),
                      'names': ','.join(names),
                      'ontology_nodes': ','.join(['EMPTY:0'] * len(keys)),
                      'data': dict(data)}}


def ecoli_plate():
    keys = ['ExperimentSessionIdentifier', 'BacterialPlateIdentifier',
            'BacterialOD600Label', 'BacterialPlatePeptoneInclusionFlag',
            'AgarPlatePouringTimestamp', 'AgarPlateColdStorageTimestamp',
            'BacterialStrainDocumentIdentifier', 'BacterialPlateSeedingTimestamp',
            'BacterialPlateColdStorageTimestamp',
            'BacterialPlateRoomTemperatureTimestamp',
            'BacterialOD600Measurement',
            'BacterialColonyFormingUnitsCFUMeasurement',
            'BacterialOD600TargetAtSeeding', 'BacterialPatchVolume']
    names = ['experiment session identifier', 'bacterial plate identifier',
             'bacterial OD600 label', 'bacterial plate peptone inclusion flag',
             'agar plate pouring timestamp', 'agar plate cold storage timestamp',
             'bacterial strain document identifier',
             'bacterial plate seeding timestamp',
             'bacterial plate cold storage timestamp',
             'bacterial plate room temperature timestamp',
             'bacterial OD600 measurement',
             'bacterial colony forming units (CFU) measurement',
             'bacterial OD600 (target) at seeding', 'bacterial patch volume']
    data = {'ExperimentSessionIdentifier': '0007',
            'BacterialPlateIdentifier': '0061',
            'BacterialOD600Label': '1.00',
            'BacterialPlatePeptoneInclusionFlag': True,
            'AgarPlatePouringTimestamp': '2024-05-01T09:00:00',
            'AgarPlateColdStorageTimestamp': '2024-05-01T13:00:00',
            'BacterialStrainDocumentIdentifier': 'strain_doc_1',
            'BacterialPlateSeedingTimestamp': '2024-05-02T09:00:00',
            'BacterialPlateColdStorageTimestamp': '2024-05-02T13:00:00',
            'BacterialPlateRoomTemperatureTimestamp': '2024-05-03T09:00:00',
            'BacterialOD600Measurement': 0.98,
            'BacterialColonyFormingUnitsCFUMeasurement': 1.96e9,
            'BacterialOD600TargetAtSeeding': 1.0,
            'BacterialPatchVolume': 0.5}
    return row('otr_ecoli_plate', 'sess_ecoli', keys, names, data)


def ecoli_image():
    keys = ['BacterialPlateIdentifier', 'MicroscopyImageIdentifier',
            'BacteriaGrowthDurationAfterSeeding', 'MicroscopyImageExposureTime']
    names = ['bacterial plate identifier', 'microscopy image identifier',
             'bacteria growth duration after seeding',
             'microscopy image exposure time']
    data = {'BacterialPlateIdentifier': '0061',
            'MicroscopyImageIdentifier': '0042',
            'BacteriaGrowthDurationAfterSeeding': 12,
            'MicroscopyImageExposureTime': 0.25}
    return row('otr_ecoli_image', 'sess_ecoli', keys, names, data)


def ecoli_lawn():
    keys = ['MicroscopyImageIdentifier', 'BacterialPatchIdentifier',
            'BacterialPatchRadius', 'BacterialPatchCircularity',
            'BacterialPatchBorderPeakFluorescenceIntensity',
            'BacterialPatchBorderEdgeFluorescenceIntensity',
            'BacterialPatchBorderFluorescenceAmplitude',
            'BacterialPatchMeanFluorescenceAmplitude',
            'BacterialPatchCenterFluorescenceAmplitude',
            'BacterialPatchBorderToCenterFluorescenceRatio']
    names = ['microscopy image identifier', 'bacterial patch identifier',
             'bacterial patch radius', 'bacterial patch circularity',
             'bacterial patch border peak fluorescence intensity',
             'bacterial patch border edge fluorescence intensity',
             'bacterial patch border fluorescence amplitude',
             'bacterial patch mean fluorescence amplitude',
             'bacterial patch center fluorescence amplitude',
             'bacterial patch border-to-center fluorescence ratio']
    data = {'MicroscopyImageIdentifier': '0042',
            'BacterialPatchIdentifier': '0003',
            'BacterialPatchRadius': 28.5125,
            'BacterialPatchCircularity': 0.9848,
            'BacterialPatchBorderPeakFluorescenceIntensity': 1204,
            'BacterialPatchBorderEdgeFluorescenceIntensity': 880,
            'BacterialPatchBorderFluorescenceAmplitude': 324,
            'BacterialPatchMeanFluorescenceAmplitude': 611,
            'BacterialPatchCenterFluorescenceAmplitude': 502,
            'BacterialPatchBorderToCenterFluorescenceRatio': 0.6456}
    return row('otr_ecoli_lawn', 'sess_ecoli', keys, names, data)


def celegans_behaviour_plate():
    keys = ['ExperimentSessionIdentifier', 'CElegansAssayPhase',
            'BacterialPlateIdentifier', 'BacterialOD600Label',
            'BacterialOD600Measurement',
            'BacterialColonyFormingUnitsCFUMeasurement',
            'AmbientTemperature', 'AmbientHumidity']
    names = ['experiment session identifier', 'C. elegans assay phase',
             'bacterial plate identifier', 'bacterial OD600 label',
             'bacterial OD600 measurement',
             'bacterial colony forming units (CFU) measurement',
             'ambient temperature', 'ambient humidity']
    data = {'ExperimentSessionIdentifier': '0001',
            'CElegansAssayPhase': 'behavior',
            'BacterialPlateIdentifier': '0017',
            'BacterialOD600Label': '1.00',
            'BacterialOD600Measurement': 0.98,
            'BacterialColonyFormingUnitsCFUMeasurement': 1.96e9,
            'AmbientTemperature': 20, 'AmbientHumidity': 45}
    return row('otr_celegans_plate', 'sess_celegans', keys, names, data)


def celegans_patch_subject():
    """What pass 1 mints from the geometry row (plateID 0017, patchID 0017)."""
    return {'class': 'subject', 'id': 'otr_patch', 'session_id': 'sess_celegans',
            'description': 'bacterial patch',
            'local_identifier': j_patch_local_id('0017', '0017', 'otr_patch')}


def drop(r, key):
    r = {'class': r['class'], 'id': r['id'], 'session_id': r['session_id'],
         'block': {k: v for k, v in r['block'].items()}}
    keys = r['block']['variable_names'].split(',')
    names = r['block']['names'].split(',')
    nodes = r['block']['ontology_nodes'].split(',')
    keep = [i for i, k in enumerate(keys) if k != key]
    r['block']['variable_names'] = ','.join(keys[i] for i in keep)
    r['block']['names'] = ','.join(names[i] for i in keep)
    r['block']['ontology_nodes'] = ','.join(nodes[i] for i in keep)
    r['block']['data'] = {k: v for k, v in r['block']['data'].items()
                          if k != key}
    return r


def scramble(r):
    r = {'class': r['class'], 'id': r['id'], 'session_id': r['session_id'],
         'block': dict(r['block'])}
    keys = r['block']['variable_names'].split(',')
    newkeys, data = [], {}
    for i, k in enumerate(keys):
        nk = 'opaque%d' % (i + 1)
        newkeys.append(nk)
        if k in r['block']['data']:
            data[nk] = r['block']['data'][k]
    r['block']['variable_names'] = ','.join(newkeys)
    r['block']['data'] = data
    return r


# ---------------- the assertions the MATLAB tests make ----------------

CHECKS = []


def check(name, fn):
    CHECKS.append((name, fn))


def c_token_rule():
    pairs = [('BacterialPatchIdentifier', 'bacterial patch identifier'),
             ('BacterialOD600TargetAtSeeding',
              'bacterial OD600 (target) at seeding'),
             ('BacterialPatchCenter_XCoordinate',
              'bacterial patch center: X coordinate'),
             ('BacterialColonyFormingUnitsCFUMeasurement',
              'bacterial colony forming units (CFU) measurement'),
             ('CElegansBehavioralAssay_EncounterIdentifier',
              'C. elegans behavioral assay: encounter identifier')]
    for a, b in pairs:
        assert normalise(a) == normalise(b), (a, normalise(a), normalise(b))
    assert normalise('BacterialPatchIdentifier') != normalise(
        'bacterial plate identifier')


def c_two_tiers():
    rep, _ = run([ecoli_plate(), ecoli_image(), ecoli_lawn()])
    assert rep['plate_rows_seen'] == 1, rep
    assert rep['image_rows_seen'] == 1, rep
    assert rep['lawn_rows_seen'] == 1, rep
    assert rep['plate_subjects_minted'] == 1, rep
    assert rep['lawn_subjects_minted'] == 1, rep
    assert rep['chains_resolved'] == 1, rep
    assert rep['member_of_relations_emitted'] == 1, rep
    assert rep['plate_observations_emitted'] == 4, rep
    assert rep['lawn_observations_emitted'] == 8, rep
    assert rep['documents_appended'] == 15, rep


def c_triple():
    _rep, minted = run([ecoli_plate(), ecoli_image(), ecoli_lawn()])
    hs = sorted(m['handle'] for m in minted)
    assert hs == ['exp/0007/plate/0061', 'exp/0007/plate/0061/patch/0003'], hs


def c_no_exp_no_mint():
    rep, minted = run([drop(ecoli_plate(), 'ExperimentSessionIdentifier'),
                       ecoli_image(), ecoli_lawn()])
    assert rep['chains_attempted'] == 1, rep
    assert rep['refused_lawn_no_exp_id'] == 1, rep
    assert rep['plate_rows_refused_no_exp_id'] == 1, rep
    assert rep['lawn_subjects_minted'] == 0, rep
    assert rep['plate_subjects_minted'] == 0, rep
    assert minted == [], minted


def c_plate_no_measures():
    p = ecoli_plate()
    for k in ('BacterialOD600Measurement', 'BacterialOD600TargetAtSeeding',
              'BacterialColonyFormingUnitsCFUMeasurement',
              'BacterialPatchVolume'):
        p = drop(p, k)
    rep, _ = run([p, ecoli_image(), ecoli_lawn()])
    assert rep['plate_rows_with_measurements'] == 0, rep
    assert rep['plate_rows_with_values_but_none_emittable'] == 1, rep
    assert rep['plate_rows_with_no_values_at_all'] == 0, rep
    assert rep['plate_subjects_minted'] == 0, rep
    assert rep['lawn_subjects_minted'] == 1, rep
    assert rep['member_of_relations_emitted'] == 0, rep
    assert rep['withheld_plate_tier_not_minted'] == 1, rep


def _bare_lawn():
    lw = ecoli_lawn()
    for _t, _leaf in LAWN_MEASURES:
        pass
    for k in ('BacterialPatchRadius', 'BacterialPatchCircularity',
              'BacterialPatchBorderPeakFluorescenceIntensity',
              'BacterialPatchBorderEdgeFluorescenceIntensity',
              'BacterialPatchBorderFluorescenceAmplitude',
              'BacterialPatchMeanFluorescenceAmplitude',
              'BacterialPatchCenterFluorescenceAmplitude',
              'BacterialPatchBorderToCenterFluorescenceRatio'):
        lw = drop(lw, k)
    return lw


def c_two_empty_states_apart():
    rep, _ = run([ecoli_plate(), ecoli_image(), _bare_lawn()])
    assert rep['lawn_rows_with_no_values_at_all'] == 1, rep
    assert rep['lawn_rows_with_values_but_none_emittable'] == 0, rep

    # THE LOGICAL GOES IN A MEASURE COLUMN. A flag parked in a column this tier
    # never looks at would exercise nothing: the value has to reach
    # scalarNumber for "a logical is not a number" to be under test at all.
    lw = _bare_lawn()
    lw['block']['variable_names'] += ',BacterialPatchCircularity'
    lw['block']['names'] += ',bacterial patch circularity'
    lw['block']['ontology_nodes'] += ',EMPTY:0'
    lw['block']['data']['BacterialPatchCircularity'] = True
    rep2, _ = run([ecoli_plate(), ecoli_image(), lw])
    assert rep2['lawn_rows_with_values_but_none_emittable'] == 1, rep2
    assert rep2['lawn_rows_with_no_values_at_all'] == 0, rep2
    assert rep2['lawn_subjects_minted'] == 0, rep2
    assert rep2['lawn_observations_emitted'] == 0, rep2


def c_session_scope():
    other = ecoli_plate()
    other = {'class': 'ontology_table_row', 'id': 'otr_plate_other',
             'session_id': 'sess_celegans', 'block': dict(other['block'])}
    other['block']['data'] = dict(other['block']['data'])
    other['block']['data']['ExperimentSessionIdentifier'] = '9999'
    rep, minted = run([other, ecoli_plate(), ecoli_image(), ecoli_lawn()])
    assert rep['plate_rows_seen'] == 2, rep
    assert rep['refused_plate_row_ambiguous'] == 0, rep
    assert rep['chains_resolved'] == 1, rep
    assert rep['lawn_subjects_minted'] == 1, rep
    lawn = [m for m in minted if m['kind'] == 3][0]
    assert lawn['handle'] == 'exp/0007/plate/0061/patch/0003', lawn['handle']


def c_celegans_relabel():
    batch = [celegans_patch_subject(), celegans_behaviour_plate(),
             ecoli_plate(), ecoli_image(), ecoli_lawn()]
    rep, _ = run(batch)
    assert rep['celegans_patch_subjects_seen'] == 1, rep
    assert rep['celegans_patch_subjects_relabelled'] == 1, rep
    assert batch[0]['local_identifier'] == 'exp/0001/plate/0017/patch/0017', \
        batch[0]['local_identifier']


def c_celegans_pair_stands():
    batch = [celegans_patch_subject(), ecoli_plate(), ecoli_image(),
             ecoli_lawn()]
    rep, _ = run(batch)
    assert rep['celegans_patch_subjects_refused_no_exp_id'] == 1, rep
    assert batch[0]['local_identifier'] == 'plate/0017/patch/0017', \
        batch[0]['local_identifier']


def c_never_bare_patch_number():
    batches = [[ecoli_plate(), ecoli_image(), ecoli_lawn()],
               [celegans_patch_subject(), celegans_behaviour_plate()],
               [celegans_patch_subject()],
               [ecoli_image(), ecoli_lawn()]]
    n = 0
    for b in batches:
        _rep, minted = run(b)
        handles = [m['handle'] for m in minted]
        handles += [d['local_identifier'] for d in b
                    if d['class'] == 'subject']
        for h in handles:
            n += 1
            assert h, 'empty local_identifier'
            assert not re.match(r'^\d+$', h), 'bare number handle: %r' % h
            assert not h.startswith('patch/'), 'patch-only handle: %r' % h
    assert n >= 4, n


def c_name_channel():
    rep, minted = run([ecoli_plate(), ecoli_image(), scramble(ecoli_lawn())])
    assert rep['lawn_rows_seen'] == 1, rep
    assert rep['lawn_subjects_minted'] == 1, rep
    assert rep['columns_resolved_by_term_name'] > 0, rep
    assert rep['columns_resolved_by_key'] > 0, rep


def c_canary():
    stray = celegans_behaviour_plate()
    stray = {'class': 'ontology_table_row', 'id': 'otr_stray',
             'session_id': 'sess_ecoli', 'block': stray['block']}
    rep, _ = run([ecoli_plate(), ecoli_image(), ecoli_lawn(), stray])
    assert rep['sessions_with_lawn_plate_tables'] == 1, rep
    assert rep['unclassified_rows_in_those_sessions'] == 1, rep
    assert rep['ontology_table_rows_seen'] == 4, rep


def c_celegans_plate_is_not_an_ecoli_plate():
    rep, _ = run([celegans_behaviour_plate()])
    assert rep['ontology_table_rows_seen'] == 1, rep
    assert rep['plate_rows_seen'] == 0, rep
    assert rep['sessions_with_lawn_plate_tables'] == 0, rep


def c_no_plate_row_refuses():
    rep, _ = run([ecoli_lawn(), ecoli_image()])
    assert rep['chains_attempted'] == 1, rep
    assert rep['refused_no_plate_row'] == 1, rep
    assert rep['lawn_subjects_minted'] == 0, rep


check('token rule (5 corpus-proven pairs)', c_token_rule)
check('two tiers + member_of', c_two_tiers)
check('the (exp, plate, patch) triple', c_triple)
check('no expID -> no mint', c_no_exp_no_mint)
check('plate with no measures -> no subject, member_of withheld',
      c_plate_no_measures)
check('"no values" and "untypable values" stay apart', c_two_empty_states_apart)
check('the join is session-scoped', c_session_scope)
check('C. elegans patch relabelled to the triple', c_celegans_relabel)
check('C. elegans pair stands when expID unreadable', c_celegans_pair_stands)
check('NO subject is labelled just a patch number', c_never_bare_patch_number)
check('a column resolves by term name', c_name_channel)
check('the spelling canary counts strays in a live session', c_canary)
check('a C. elegans plate is not an E. coli plate',
      c_celegans_plate_is_not_an_ecoli_plate)
check('no plate row -> refused, counted', c_no_plate_row_refuses)


if __name__ == '__main__':
    print('DENOMINATOR: %d check(s), mutations active: %s'
          % (len(CHECKS), ', '.join(sorted(MUT)) or '(none -- BASELINE)'))
    failed = 0
    for name, fn in CHECKS:
        try:
            fn()
            print('  PASS  %s' % name)
        except AssertionError as err:
            failed += 1
            print('  FAIL  %s\n          %s' % (name, err))
    print('%d/%d passed, %d failed' % (len(CHECKS) - failed, len(CHECKS), failed))
    sys.exit(1 if failed else 0)
