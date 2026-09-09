# -*- coding: utf-8 -*-
"""Собирает assets/curriculum/stage1.json и stage2.json.

Контент курса — данные, а не код, но 28 букв × 4 формы руками не набрать
без опечаток. Скрипт держит буквы в одной таблице и раскладывает их
по узлам графа и темам.
"""
import json, os

OUT = 'assets/curriculum'

# id, глиф-изолированная, конечная, начальная, средняя, имя, похожие, объяснение
L = [
 ('alif','ا','ـا',None,None,'Алиф',[], 'Алиф — первая буква алфавита. Простая вертикальная черта, без точек.'),
 ('ba','ب','ـب','بـ','ـبـ','Ба',['ta','tha','nun'], 'Ба. Форма другая — чаша, лежащая на строке. И одна точка снизу.'),
 ('ta','ت','ـت','تـ','ـتـ','Та',['ba','tha','nun'], 'Та. Форма такая же, как у ба, но точек больше: две, и стоят сверху.'),
 ('tha','ث','ـث','ثـ','ـثـ','Са',['ba','ta','nun'], 'Са. Та же чаша, а точек на одну больше — три, тоже сверху.'),
 ('jim','ج','ـج','جـ','ـجـ','Джим',['hha','kha'], 'Джим. Крючок с животиком, который свисает ниже строки. Внутри одна точка.'),
 ('hha','ح','ـح','حـ','ـحـ','Ха',['jim','kha'], 'Ха. Тот же крючок, что у джима, но пустой — точек нет вовсе.'),
 ('kha','خ','ـخ','خـ','ـخـ','Хо',['jim','hha'], 'Хо. Тот же крючок, а точка одна и стоит сверху.'),
 ('dal','د','ـد',None,None,'Даль',['dhal'], 'Даль. Короткий уголок на строке, без точек. Слева ни с чем не соединяется.'),
 ('dhal','ذ','ـذ',None,None,'Заль',['dal'], 'Заль. Тот же уголок, что у даля, и одна точка сверху.'),
 ('ra','ر','ـر',None,None,'Ро',['zay'], 'Ро. Хвостик, уходящий под строку. Точек нет.'),
 ('zay','ز','ـز',None,None,'Зай',['ra'], 'Зай. Тот же хвостик, что у ро, с одной точкой сверху.'),
 ('sin','س','ـس','سـ','ـسـ','Син',['shin'], 'Син. Три зубчика на строке и чаша за ними. Точек нет.'),
 ('shin','ش','ـش','شـ','ـشـ','Шин',['sin'], 'Шин. Те же три зубчика, а сверху три точки.'),
 ('sod','ص','ـص','صـ','ـصـ','Сод',['dod'], 'Сод. Петля на строке и чаша за ней. Точек нет.'),
 ('dod','ض','ـض','ضـ','ـضـ','Дод',['sod'], 'Дод. Та же петля с чашей, и одна точка сверху.'),
 ('to','ط','ـط','طـ','ـطـ','То',['zho'], 'То. Петля на строке, а из неё вверх торчит прямая палочка.'),
 ('zho','ظ','ـظ','ظـ','ـظـ','Зо',['to'], 'Зо. Та же петля с палочкой, и одна точка сверху.'),
 ('ayn','ع','ـع','عـ','ـعـ','Айн',['ghayn'], 'Айн. Открытый крючок сверху и чаша снизу. Точек нет.'),
 ('ghayn','غ','ـغ','غـ','ـغـ','Гойн',['ayn'], 'Гойн. Тот же крючок с чашей, и одна точка сверху.'),
 ('fa','ف','ـف','فـ','ـفـ','Фа',['qof'], 'Фа. Кружок на строке с хвостом и одной точкой сверху.'),
 ('qof','ق','ـق','قـ','ـقـ','Коф',['fa'], 'Коф. Тот же кружок, но чаша уходит под строку, а точек сверху две.'),
 ('kaf','ك','ـك','كـ','ـكـ','Кяф',[], 'Кяф. Угловатая буква с маленькой чёрточкой внутри.'),
 ('lam','ل','ـل','لـ','ـلـ','Лям',[], 'Лям. Высокая палочка, которая внизу заворачивается в чашу.'),
 ('mim','م','ـم','مـ','ـمـ','Мим',[], 'Мим. Кружок на строке с хвостиком, уходящим вниз.'),
 ('nun','ن','ـن','نـ','ـنـ','Нун',['ba','ta','tha'], 'Нун. Глубокая чаша под строкой и одна точка сверху.'),
 ('ha','ه','ـه','هـ','ـهـ','Хэ',[], 'Хэ. Кружок; в разных местах слова он меняется сильнее всех букв.'),
 ('waw','و','ـو',None,None,'Вав',[], 'Вав. Кружок с хвостом, уходящим под строку. Слева не соединяется.'),
 ('ya','ي','ـي','يـ','ـيـ','Йа',['ba','ta','tha','nun'], 'Йа. Чаша под строкой и две точки снизу.'),
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

# Буквы, не соединяющиеся со следующей: у них нет начальной формы.
NOJOIN = {r[1] for r in L if r[3] is None}

# Что от буквы остаётся в начальной и средней форме и что возвращается
# в конечной. Отсюда собираются объяснения соединений: каждая форма
# показывается карточкой в тот момент, когда впервые встречается.
SHAPE = {
 'ba':   ('зубчик с точкой снизу',        'чаша с точкой снизу'),
 'ta':   ('зубчик с двумя точками',       'чаша с двумя точками'),
 'tha':  ('зубчик с тремя точками',       'чаша с тремя точками'),
 'jim':  ('крючок с точкой внутри',       'крючок с животиком под строкой'),
 'hha':  ('крючок без точек',             'крючок с животиком под строкой'),
 'kha':  ('крючок с точкой сверху',       'крючок с животиком под строкой'),
 'sin':  ('три зубчика',                  'три зубчика и чаша за ними'),
 'shin': ('три зубчика с точками сверху', 'три зубчика и чаша за ними'),
 'sod':  ('петля',                        'петля и чаша за ней'),
 'dod':  ('петля с точкой сверху',        'петля и чаша за ней'),
 'to':   ('петля с прямой палочкой',      'петля с палочкой'),
 'zho':  ('петля с палочкой и точкой',    'петля с палочкой'),
 'ayn':  ('открытый крючок',              'крючок и чаша под строкой'),
 'ghayn':('открытый крючок с точкой',     'крючок и чаша под строкой'),
 'fa':   ('кружок с точкой сверху',       'кружок и хвост на строке'),
 'qof':  ('кружок с двумя точками',       'кружок и чаша под строкой'),
 'kaf':  ('угловатая палочка',            'угол с чёрточкой внутри'),
 'lam':  ('высокая палочка',              'палочка и чаша под строкой'),
 'mim':  ('кружок на строке',             'кружок с хвостиком вниз'),
 'nun':  ('зубчик с точкой сверху',       'глубокая чаша с точкой'),
 'ha':   ('петелька',                     'кружок'),
 'ya':   ('зубчик с двумя точками снизу', 'чаша с двумя точками снизу'),
}


def form_note(lid, form):
    """Объяснение одной формы. Соединение — это не новая буква, а та же
    с обрезанным или возвращённым хвостом, и карточка говорит ровно это."""
    row = BY[lid]
    name = row[5]
    joins_left = row[3] is not None

    if form == 'finalForm' and not joins_left:
        return (f'{name} в конце слова. Слева она и так ни с чем '
                f'не соединяется, поэтому меняется только справа: появляется '
                f'связка с предыдущей буквой.')

    head, tail = SHAPE[lid]
    if form == 'finalForm':
        return (f'{name} в конце слова. Справа — связка с предыдущей буквой, '
                f'слева хвост возвращается: {tail}.')
    if form == 'initial':
        return (f'{name} в начале слова: остаётся {head}. Хвост убирается, '
                f'вместо него связка к следующей букве.')
    return (f'{name} в середине слова: {head} со связками с обеих сторон. '
            f'Это самая короткая её форма.')


# Осевой SVG формы. Список букв не хардкодим: они дорисовываются, и
# забытая правка здесь ломает урок тише всего — атом просто перестаёт
# спрашиваться обводкой.
SVG = 'assets/svg/alphabet'
TRACING_SUFFIX = {'isolated': 'base', 'initial': 'init',
                  'medial': 'mid', 'finalForm': 'end'}


def tracing_of(lid, form):
    name = f'{lid}_{TRACING_SUFFIX[form]}'
    return name if os.path.exists(f'{SVG}/{name}.svg') else None

# Слово-пример на соединённую форму: где буква встречается в таком виде.
# Индекс — позиция буквы в слове. Слова короткие и по возможности из букв,
# введённых раньше; где нельзя, берётся самое узнаваемое слово.
#
# Форма в слове должна быть именно той, что показываем: перед конечной и
# средней формой стоит буква, которая соединяется влево (после ا د ذ ر ز و
# буква рисуется как отдельная), а начальная и средняя не последние в слове.
WORDS = {
 'alif':  {'finalForm': ('بابا', 1)},
 'ba':    {'initial': ('بات', 0),  'medial': ('ثبت', 1),  'finalForm': ('كتب', 2)},
 'ta':    {'initial': ('تاب', 0),  'medial': ('كتاب', 1), 'finalForm': ('بنت', 2)},
 'tha':   {'initial': ('ثابت', 0), 'medial': ('مثل', 1),  'finalForm': ('ثلث', 2)},
 'jim':   {'initial': ('جبل', 0),  'medial': ('نجم', 1),  'finalForm': ('ثلج', 2)},
 'hha':   {'initial': ('حب', 0),   'medial': ('بحث', 1),  'finalForm': ('ربح', 2)},
 'kha':   {'initial': ('خبز', 0),  'medial': ('بخت', 1),  'finalForm': ('شيخ', 2)},
 'dal':   {'finalForm': ('جد', 1)},
 'dhal':  {'finalForm': ('خذ', 1)},
 'ra':    {'finalForm': ('بحر', 2)},
 'zay':   {'finalForm': ('خبز', 2)},
 'sin':   {'initial': ('سبت', 0),  'medial': ('جسر', 1),  'finalForm': ('شمس', 2)},
 'shin':  {'initial': ('شجر', 0),  'medial': ('بشر', 1),  'finalForm': ('عيش', 2)},
 'sod':   {'initial': ('صبر', 0),  'medial': ('بصر', 1),  'finalForm': ('نص', 1)},
 'dod':   {'initial': ('ضرب', 0),  'medial': ('خضر', 1),  'finalForm': ('بيض', 2)},
 'to':    {'initial': ('طبخ', 0),  'medial': ('خطر', 1),  'finalForm': ('خط', 1)},
 'zho':   {'initial': ('ظهر', 0),  'medial': ('حظر', 1),  'finalForm': ('حظ', 1)},
 'ayn':   {'initial': ('عرب', 0),  'medial': ('شعر', 1),  'finalForm': ('ربع', 2)},
 'ghayn': {'initial': ('غرب', 0),  'medial': ('بغداد', 1), 'finalForm': ('صبغ', 2)},
 'fa':    {'initial': ('فتح', 0),  'medial': ('سفر', 1),  'finalForm': ('صف', 1)},
 'qof':   {'initial': ('قصر', 0),  'medial': ('بقر', 1),  'finalForm': ('حق', 1)},
 'kaf':   {'initial': ('كتب', 0),  'medial': ('سكر', 1),  'finalForm': ('ضحك', 2)},
 'lam':   {'initial': ('لعب', 0),  'medial': ('بلد', 1),  'finalForm': ('جبل', 2)},
 'mim':   {'initial': ('مصر', 0),  'medial': ('شمس', 1),  'finalForm': ('علم', 2)},
 'nun':   {'initial': ('نجم', 0),  'medial': ('بنت', 1),  'finalForm': ('لبن', 2)},
 'ha':    {'initial': ('هلال', 0), 'medial': ('نهر', 1),  'finalForm': ('فقه', 2)},
 'waw':   {'finalForm': ('دلو', 2)},
 'ya':    {'initial': ('يد', 0),   'medial': ('بيت', 1),  'finalForm': ('كرسي', 3)},
}

FORMS = [('isolated', 1, ''), ('finalForm', 2, ' в конце'),
         ('initial', 3, ' в начале'), ('medial', 4, ' в середине')]

CONCEPTS = {
 'concept.letter': ('Буква, её имя и вид',
   'В арабском алфавите 28 букв. Пишут и читают справа налево, а одна и та же '
   'буква выглядит по-разному в зависимости от того, где она стоит в слове.'),
 'concept.forms': ('Разные формы одной буквы',
   'Одна буква пишется по-разному в зависимости от места в слове: отдельно, '
   'в начале, в середине и в конце. Это не разные буквы — это одна буква '
   'с разными хвостами.'),
 'concept.nojoin': ('Буквы, которые не соединяются слева',
   'Шесть букв — ا د ذ ر ز و — не соединяются со следующей. У них всего две '
   'формы вместо четырёх: отдельная и конечная.'),
 'concept.hamza': ('Хамза',
   'Хамза — не буква алфавита, а знак гортанной остановки. Пишут её пятью '
   'способами: отдельно или на подставке из алифа, вав или йа. Читается '
   'везде одинаково.'),
 'concept.join': ('Как буквы соединяются',
   'В слове буквы слипаются. Первая берёт начальную форму, последняя — '
   'конечную, а те, что между ними, — среднюю. Пока читаем молча: только '
   'смотрим, как буквы соединились.'),
 'concept.break': ('Разрыв в слове',
   'После ا د ذ ر ز و соединения нет. Следующая буква начинается заново — '
   'как будто с начала слова, хотя слово продолжается.'),
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
      concept='concept.letter', fconcept='concept.forms'),
 dict(letters=['jim','hha','kha'], tid='m.jim', title='Буквы ج ح خ',
      ftid='m.jim.forms', ftitle='ج ح خ в слове'),
 dict(letters=['dal','dhal','ra','zay'], tid='m.nojoin',
      title='Буквы, которые не соединяются: د ذ ر ز',
      ftid='m.nojoin.forms', ftitle='د ذ ر ز в конце слова',
      concept='concept.nojoin'),
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
ALWAYS = {'type': 'always'}


def concept_node(cid, requirement):
    title, note = CONCEPTS[cid]
    return {'atom': {'id': cid, 'kind': 'concept', 'display': title,
                     'label': title, 'note': note},
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
            'letterId': lid, 'form': form}
    if row[6]:
        atom['confusableWith'] = row[6]
    notation = LETTER_NOTATION.get(lid)
    atom['label'] = row[5] + (f' ({notation})' if notation else '') + suffix
    atom['note'] = row[7] if form == 'isolated' else form_note(lid, form)
    tracing = tracing_of(lid, form)
    if tracing:
        atom['tracing'] = tracing
    example = WORDS.get(lid, {}).get(form)
    if example:
        word, index = example
        assert word[index] == row[1], f'{lid}.{form}: в {word}[{index}] не {row[1]}'
        if form in ('finalForm', 'medial'):
            assert index > 0 and word[index - 1] not in NOJOIN, \
                f'{lid}.{form}: в {word} буква не соединена справа'
        if form in ('initial', 'medial'):
            assert index < len(word) - 1, f'{lid}.{form}: в {word} буква последняя'
        atom['example'] = {'word': word, 'index': index}
    return {'atom': atom, 'requirement': requirement}


def forms_of(lid):
    row = BY[lid]
    return [f for f, idx, _ in FORMS if row[idx] is not None]


def build_stage1():
    nodes, topics, previous = [], [], None

    for group in GROUPS:
        gate = ALWAYS if previous is None else intro(f'{previous}.isolated')

        if group.get('concept'):
            nodes.append(concept_node(group['concept'], gate))
        for lid in group['letters']:
            nodes.append(letter_node(lid, 'isolated', gate))

        if group.get('fconcept'):
            nodes.append(concept_node(group['fconcept'],
                                      intro(f"{group['letters'][1]}.isolated")))
        for lid in group['letters']:
            for form in forms_of(lid)[1:]:
                nodes.append(letter_node(lid, form, intro(f'{lid}.isolated')))

        topics.append({
            'id': group['tid'], 'stage': 1, 'title': group['title'],
            'requirement': ALWAYS,
            'counterOf': ([group['concept']] if group.get('concept') else [])
                         + [f'{l}.isolated' for l in group['letters']],
        })
        topics.append({
            'id': group['ftid'], 'stage': 1, 'title': group['ftitle'],
            'requirement': ALWAYS,
            'counterOf': ([group['fconcept']] if group.get('fconcept') else [])
                         + [f'{l}.{f}' for l in group['letters']
                            for f in forms_of(l)[1:]],
        })
        previous = group['letters'][-1]

    nodes.append(concept_node('concept.hamza', intro(f'{previous}.isolated')))
    for hid, glyph, label, carrier in HAMZA:
        nodes.append({'atom': {'id': hid, 'kind': 'sign', 'display': glyph,
                               'letterId': 'hamza', 'label': label},
                      'requirement': intro(f'{carrier}.isolated')})
    topics.append({'id': 'm.hamza', 'stage': 1, 'title': 'Хамза: ء أ إ ؤ ئ',
                   'requirement': ALWAYS,
                   'counterOf': ['concept.hamza'] + [h[0] for h in HAMZA]})

    return {'nodes': nodes, 'topics': topics}


def build_stage2():
    nodes, topics = [], []
    for cid, syllables, tid, title in [
        ('concept.join', SYLLABLES_JOIN, 'm.join', 'Как буквы соединяются'),
        ('concept.break', SYLLABLES_BREAK, 'm.break', 'Разрыв в слове'),
    ]:
        nodes.append(concept_node(cid, intro('ya.isolated')))
        for sid, glyph, label, parts in syllables:
            nodes.append({
                'atom': {'id': sid, 'kind': 'syllable', 'display': glyph,
                         'label': label},
                'requirement': {'type': 'allOf', 'parts':
                                [intro(f'{p}.isolated') for p in parts]},
            })
        topics.append({'id': tid, 'stage': 2, 'title': title,
                       'requirement': ALWAYS,
                       'counterOf': [cid] + [s[0] for s in syllables]})
    return {'nodes': nodes, 'topics': topics}


for name, data in [('stage1', build_stage1()), ('stage2', build_stage2())]:
    path = os.path.join(OUT, f'{name}.json')
    with open(path, 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f'{path}: {len(data["nodes"])} узлов, {len(data["topics"])} тем')
