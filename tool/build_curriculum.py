# -*- coding: utf-8 -*-
"""Собирает assets/curriculum/stage1.json и stage2.json.

Скрипт держит буквы в одной таблице и раскладывает их по узлам графа
и темам. Тексты объяснений и слова-примеры находятся в YAML-карточках.
"""
import json, os

from harakat_data import REQUIRED_HARAKA_IDS

OUT = 'assets/curriculum'

# id, отдельная, конечная, начальная, средняя формы, имя, похожие буквы
L = [
 ('alif', 'ا', 'ـا', None, None, 'Алиф', []),
 ('ba', 'ب', 'ـب', 'بـ', 'ـبـ', 'Ба', ['ta', 'tha', 'nun']),
 ('ta', 'ت', 'ـت', 'تـ', 'ـتـ', 'Та', ['ba', 'tha', 'nun']),
 ('tha', 'ث', 'ـث', 'ثـ', 'ـثـ', 'Са', ['ba', 'ta', 'nun']),
 ('jim', 'ج', 'ـج', 'جـ', 'ـجـ', 'Джим', ['hha', 'kha']),
 ('hha', 'ح', 'ـح', 'حـ', 'ـحـ', 'Ха', ['jim', 'kha']),
 ('kha', 'خ', 'ـخ', 'خـ', 'ـخـ', 'Хо', ['jim', 'hha']),
 ('dal', 'د', 'ـد', None, None, 'Даль', ['dhal']),
 ('dhal', 'ذ', 'ـذ', None, None, 'Заль', ['dal']),
 ('ra', 'ر', 'ـر', None, None, 'Ро', ['zay']),
 ('zay', 'ز', 'ـز', None, None, 'Зай', ['ra']),
 ('sin', 'س', 'ـس', 'سـ', 'ـسـ', 'Син', ['shin']),
 ('shin', 'ش', 'ـش', 'شـ', 'ـشـ', 'Шин', ['sin']),
 ('sod', 'ص', 'ـص', 'صـ', 'ـصـ', 'Сод', ['dod']),
 ('dod', 'ض', 'ـض', 'ضـ', 'ـضـ', 'Дод', ['sod']),
 ('to', 'ط', 'ـط', 'طـ', 'ـطـ', 'То', ['zho']),
 ('zho', 'ظ', 'ـظ', 'ظـ', 'ـظـ', 'Зо', ['to']),
 ('ayn', 'ع', 'ـع', 'عـ', 'ـعـ', 'Айн', ['ghayn']),
 ('ghayn', 'غ', 'ـغ', 'غـ', 'ـغـ', 'Гойн', ['ayn']),
 ('fa', 'ف', 'ـف', 'فـ', 'ـفـ', 'Фа', ['qof']),
 ('qof', 'ق', 'ـق', 'قـ', 'ـقـ', 'Коф', ['fa']),
 ('kaf', 'ك', 'ـك', 'كـ', 'ـكـ', 'Кяф', []),
 ('lam', 'ل', 'ـل', 'لـ', 'ـلـ', 'Лям', []),
 ('mim', 'م', 'ـم', 'مـ', 'ـمـ', 'Мим', []),
 ('nun', 'ن', 'ـن', 'نـ', 'ـنـ', 'Нун', ['ba', 'ta', 'tha']),
 ('ha', 'ه', 'ـه', 'هـ', 'ـهـ', 'Хэ', []),
 ('waw', 'و', 'ـو', None, None, 'Вав', []),
 ('ya', 'ي', 'ـي', 'يـ', 'ـيـ', 'Йа', ['ba', 'ta', 'tha', 'nun']),
]
BY = {r[0]: r for r in L}

# Различаем похожие звуки в подписях: «Са (th)», «Ха (ḥ)», «То (ṭ)».
# Обозначение одинаково для всех форм буквы; в текстах объяснений
# остаётся привычное русское имя.
LETTER_NOTATION = {
 'ta': 't', 'tha': 'th',
 'hha': 'ḥ', 'kha': 'kh', 'ha': 'h',
 'dal': 'd', 'dhal': 'dh', 'dod': 'ḍ',
 'zay': 'z', 'zho': 'ẓ',
 'sin': 's', 'shin': 'sh', 'sod': 'ṣ',
 'to': 'ṭ', 'ayn': 'ʿ', 'ghayn': 'gh',
 'qof': 'q', 'kaf': 'k',
}

# Осевой SVG формы. Атом без файла не спрашивается обводкой.
SVG = 'assets/svg/alphabet'
TRACING_SUFFIX = {'isolated': 'base', 'initial': 'init',
                  'medial': 'mid', 'finalForm': 'end'}


def tracing_of(lid, form):
    name = f'{lid}_{TRACING_SUFFIX[form]}'
    return name if os.path.exists(f'{SVG}/{name}.svg') else None

FORMS = [('isolated', 1, ''), ('finalForm', 2, ' в конце'),
         ('initial', 3, ' в начале'), ('medial', 4, ' в середине')]

CONCEPTS = {
 'concept.letter': 'Ассаляму алейкум!',
 'concept.makhraj': 'Махрадж и сыфат',
 'concept.forms': 'Разные формы одной буквы',
 'concept.nojoin': 'Буквы, которые не соединяются слева',
 'concept.hamza': 'Хамза',
 'concept.join': 'Как буквы соединяются',
 'concept.break': 'Разрыв в слове',
}

HAMZA = [
 ('hamza.alone','ء','Хамза отдельно','alif'),
 ('hamza.alif','أ','Хамза на алифе','alif'),
 ('hamza.alifBelow','إ','Хамза под алифом','alif'),
 ('hamza.waw','ؤ','Хамза на вав','waw'),
 ('hamza.ya','ئ','Хамза на йа','ya'),
]

GROUPS = [
 dict(letters=['alif','ba','ta','tha'], tid='m.first', title='Первые буквы: ا ب ت ث',
      ftid='m.forms', ftitle='Разные формы одной буквы',
      concepts=['concept.letter', 'concept.makhraj'], fconcept='concept.forms'),
 dict(letters=['jim','hha','kha'], tid='m.jim', title='Буквы ج ح خ',
      ftid='m.jim.forms', ftitle='ج ح خ в слове'),
 dict(letters=['dal','dhal','ra','zay'], tid='m.nojoin',
      title='Буквы, которые не соединяются: د ذ ر ز',
      ftid='m.nojoin.forms', ftitle='د ذ ر ز в конце слова',
      concepts=['concept.nojoin']),
 dict(letters=['sin','shin'], tid='m.sin', title='Буквы س ش',
      ftid='m.sin.forms', ftitle='س ش в слове'),
 dict(letters=['sod','dod'], tid='m.sod', title='Буквы ص ض',
      ftid='m.sod.forms', ftitle='ص ض в слове'),
 dict(letters=['to','zho'], tid='m.to', title='Буквы ط ظ',
      ftid='m.to.forms', ftitle='ط ظ в слове'),
 dict(letters=['ayn','ghayn'], tid='m.ayn', title='Буквы ع غ',
      ftid='m.ayn.forms', ftitle='ع غ в слове'),
 dict(letters=['fa','qof'], tid='m.fa', title='Буквы ف ق',
      ftid='m.fa.forms', ftitle='ف ق в слове'),
 dict(letters=['kaf','lam'], tid='m.kaf', title='Буквы ك ل',
      ftid='m.kaf.forms', ftitle='ك ل в слове'),
 dict(letters=['mim','nun'], tid='m.mim', title='Буквы م ن',
      ftid='m.mim.forms', ftitle='م ن в слове'),
 dict(letters=['ha','waw','ya'], tid='m.ha', title='Буквы ه و ي',
      ftid='m.ha.forms', ftitle='ه و ي в слове'),
]

SYLLABLES_JOIN = [
 ('syl.ba_ta','بت','Ба и та',['ba','ta']),
 ('syl.ta_ba','تب','Та и ба',['ta','ba']),
 ('syl.na_ba','نب','Нун и ба',['nun','ba']),
 ('syl.sa_ba','سب','Син и ба',['sin','ba']),
 ('syl.mi_na','من','Мим и нун',['mim','nun']),
 ('syl.la_ba','لب','Лям и ба',['lam','ba']),
]
SYLLABLES_BREAK = [
 ('syl.dal_ba','دب','Даль и ба',['dal','ba']),
 ('syl.ra_ba','رب','Ро и ба',['ra','ba']),
 ('syl.alif_ba','اب','Алиф и ба',['alif','ba']),
 ('syl.waw_ba','وب','Вав и ба',['waw','ba']),
]

intro = lambda a: {'type': 'atomIntroduced', 'atomId': a}
known = lambda a: {'type': 'atomKnown', 'atomId': a}
ALWAYS = {'type': 'always'}

def all_of(*requirements):
    return {'type': 'allOf', 'parts': list(requirements)}


def after_harakat(requirement):
    """Связки открываются после обязательных огласовок на всех буквах."""
    return all_of(
        *[known(atom_id) for atom_id in REQUIRED_HARAKA_IDS],
        requirement,
    )


def completed(atom_ids):
    return all_of(*[
        intro(atom_id) if atom_id.startswith('concept.') else known(atom_id)
        for atom_id in atom_ids
    ])


def concept_node(cid, requirement):
    title = CONCEPTS[cid]
    return {'atom': {'id': cid, 'kind': 'concept', 'display': title,
                     'label': title,
                     'explanationAsset': f'assets/explanations/ru/{cid}.yaml'},
            'requirement': requirement}


TATWEEL = 'ـ'


def letter_node(lid, form, requirement):
    row = BY[lid]
    glyph = {'isolated': row[1], 'finalForm': row[2],
             'initial': row[3], 'medial': row[4]}[form]
    suffix = dict((f, s) for f, _, s in FORMS)[form]
    # Соединительную черту удваиваем: с одной ـب и ب в вопросе и вариантах
    # на глаз почти не различаются.
    glyph = glyph.replace(TATWEEL, TATWEEL * 2)
    atom = {'id': f'{lid}.{form}', 'kind': 'letterForm', 'display': glyph,
            'letterId': lid, 'form': form,
            'explanationAsset': f'assets/explanations/ru/{lid}.{form}.yaml'}
    if form == 'isolated':
        atom['formsOverviewAsset'] = f'assets/explanations/ru/{lid}-forms.yaml'
    if row[6]:
        atom['confusableWith'] = row[6]
    notation = LETTER_NOTATION.get(lid)
    atom['label'] = row[5] + (f' ({notation})' if notation else '') + suffix
    tracing = tracing_of(lid, form)
    if tracing:
        atom['tracing'] = tracing
    return {'atom': atom, 'requirement': requirement}


def forms_of(lid):
    row = BY[lid]
    return [f for f, idx, _ in FORMS if row[idx] is not None]


def build_stage1():
    nodes, topics, previous = [], [], None
    previous_counter = None

    for group in GROUPS:
        gate = ALWAYS if previous is None else intro(f'{previous}.isolated')

        concepts = group.get('concepts', [])
        for concept in concepts:
            nodes.append(concept_node(concept, gate))
        for lid in group['letters']:
            nodes.append(letter_node(lid, 'isolated', gate))

        if group.get('fconcept'):
            nodes.append(concept_node(group['fconcept'],
                                      intro(f"{group['letters'][1]}.isolated")))
        for lid in group['letters']:
            for form in forms_of(lid)[1:]:
                nodes.append(letter_node(lid, form, intro(f'{lid}.isolated')))

        letter_counter = concepts + [f'{l}.isolated' for l in group['letters']]
        topics.append({
            'id': group['tid'], 'stage': 1, 'title': group['title'],
            'requirement': (ALWAYS if previous_counter is None
                            else completed(previous_counter)),
            'counterOf': letter_counter,
        })
        forms_counter = ([group['fconcept']] if group.get('fconcept') else []) \
                        + [f'{l}.{f}' for l in group['letters']
                           for f in forms_of(l)[1:]]
        topics.append({
            'id': group['ftid'], 'stage': 1, 'title': group['ftitle'],
            'requirement': completed(letter_counter),
            'counterOf': forms_counter,
        })
        previous = group['letters'][-1]
        previous_counter = forms_counter

    nodes.append(concept_node('concept.hamza', intro(f'{previous}.isolated')))
    for hid, glyph, label, carrier in HAMZA:
        nodes.append({'atom': {'id': hid, 'kind': 'sign', 'display': glyph,
                               'letterId': 'hamza', 'label': label,
                               'explanationAsset': f'assets/explanations/ru/{hid}.yaml'},
                      'requirement': intro(f'{carrier}.isolated')})
    topics.append({'id': 'm.hamza', 'stage': 1, 'title': 'Хамза: ء أ إ ؤ ئ',
                   'requirement': completed(previous_counter),
                   'counterOf': ['concept.hamza'] + [h[0] for h in HAMZA]})

    return {'nodes': nodes, 'topics': topics}


def build_stage2():
    nodes, topics = [], []

    def connected_requirement(parts):
        first, last = parts
        return all_of(
            known(f'{first}.isolated'),
            known(f'{last}.isolated'),
            known(f'{first}.initial'),
            known(f'{last}.finalForm'),
        )

    def broken_requirement(parts):
        first, last = parts
        return all_of(
            known(f'{first}.isolated'),
            known(f'{last}.isolated'),
            known(f'{first}.isolated'),
            known(f'{last}.isolated'),
        )

    join_concept_requirement = after_harakat(all_of(
        {'type': 'lettersKnown', 'count': 2},
        known('ba.initial'),
        known('ta.finalForm'),
        known('ta.initial'),
        known('ba.finalForm'),
    ))
    nodes.append(concept_node('concept.join', join_concept_requirement))

    node_requirements = {}
    for index, (sid, glyph, label, parts) in enumerate(SYLLABLES_JOIN):
        base_requirement = connected_requirement(parts)
        requirement = (
            after_harakat(base_requirement)
            if index < 2
            else all_of(intro('concept.join'), base_requirement)
        )
        node_requirements[sid] = requirement
        nodes.append({
            'atom': {'id': sid, 'kind': 'syllable', 'display': glyph,
                     'label': label,
                     'explanationAsset': f'assets/explanations/ru/{sid}.yaml'},
            'requirement': requirement,
        })

    break_concept_requirement = after_harakat(all_of(
        intro('concept.join'),
        known('alif.isolated'),
        known('ba.isolated'),
    ))
    nodes.append(concept_node('concept.break', break_concept_requirement))
    for index, (sid, glyph, label, parts) in enumerate(SYLLABLES_BREAK):
        base_requirement = broken_requirement(parts)
        requirement = all_of(
            intro('concept.join' if index == 2 else 'concept.break'),
            base_requirement,
        )
        node_requirements[sid] = requirement
        nodes.append({
            'atom': {'id': sid, 'kind': 'syllable', 'display': glyph,
                     'label': label,
                     'explanationAsset': f'assets/explanations/ru/{sid}.yaml'},
            'requirement': requirement,
        })

    topic_specs = [
        ('m.join', 'Как буквы соединяются',
         ['concept.join', 'syl.ba_ta', 'syl.ta_ba'],
         [join_concept_requirement]),
        ('m.break', 'Разрыв после алифа',
         ['concept.break', 'syl.alif_ba'],
         [break_concept_requirement]),
        ('m.join.nun', 'Соединение ن ب', ['syl.na_ba'],
         [node_requirements['syl.na_ba']]),
        ('m.join.sin', 'Соединение س ب', ['syl.sa_ba'],
         [node_requirements['syl.sa_ba']]),
        ('m.join.mim', 'Соединение م ن', ['syl.mi_na'],
         [node_requirements['syl.mi_na']]),
        ('m.join.lam', 'Соединение ل ب', ['syl.la_ba'],
         [node_requirements['syl.la_ba']]),
        ('m.break.dal', 'Разрыв после د', ['syl.dal_ba'],
         [node_requirements['syl.dal_ba']]),
        ('m.break.ra', 'Разрыв после ر', ['syl.ra_ba'],
         [node_requirements['syl.ra_ba']]),
        ('m.break.waw', 'Разрыв после و', ['syl.waw_ba'],
         [node_requirements['syl.waw_ba']]),
    ]
    for topic_id, title, counter, requirements in topic_specs:
        topics.append({
            'id': topic_id,
            'stage': 3,
            'title': title,
            'requirement': all_of(*requirements),
            'counterOf': counter,
        })
    return {'nodes': nodes, 'topics': topics}


for name, data in [('stage1', build_stage1()), ('stage2', build_stage2())]:
    path = os.path.join(OUT, f'{name}.json')
    with open(path, 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f'{path}: {len(data["nodes"])} узлов, {len(data["topics"])} тем')
