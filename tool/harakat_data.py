"""Общие данные знаков и сочетаний блока кратких огласовок."""

HARAKAT_LETTERS = [
    ("ba", "ب", "ба"),
    ("ta", "ت", "та"),
    ("kaf", "ك", "кяф"),
    ("dal", "د", "даль"),
    ("ra", "ر", "ро"),
    ("sin", "س", "син"),
    ("mim", "م", "мим"),
    ("lam", "ل", "лям"),
    ("shin", "ش", "шин"),
    ("ayn", "ع", "айн"),
    ("jim", "ج", "джим"),
    ("hha", "ح", "ха"),
    ("fa", "ف", "фа"),
    ("nun", "ن", "нун"),
    ("alif", "ا", "алиф"),
    ("tha", "ث", "са"),
    ("kha", "خ", "хо"),
    ("dhal", "ذ", "заль"),
    ("zay", "ز", "зай"),
    ("sod", "ص", "сод"),
    ("dod", "ض", "дод"),
    ("to", "ط", "то"),
    ("zho", "ظ", "зо"),
    ("ghayn", "غ", "гойн"),
    ("qof", "ق", "коф"),
    ("ha", "ه", "хэ"),
    ("waw", "و", "вав"),
    ("ya", "ي", "йа"),
]

HARAKAT_LETTER_IDS = [letter_id for letter_id, _, _ in HARAKAT_LETTERS]
HARAKAT_NAMES = ["fatha", "kasra", "damma"]

# Все три знака вводятся на ба. Объёмные буквы и ро получают полный
# набор, чтобы объяснить особенности при разных гласных. У хо отдельно
# разбирается фатха. Касра на мим и айн нужна для первых коротких слов.
# На обычных буквах выбираем разные знаки, включая дамму, без тройного
# повторения каждого сочетания.
CORE_VOWELS = {
    "ba": ("fatha", "kasra", "damma"),
    "alif": ("fatha", "kasra", "damma"),
    **{letter_id: ("fatha", "kasra", "damma") for letter_id in
       ("ra", "sod", "dod", "to", "zho", "ghayn", "qof")},
    "kha": ("fatha",),
    "mim": ("fatha", "kasra"),
    "ayn": ("fatha", "kasra"),
    **{letter_id: ("damma",) for letter_id in
       ("dal", "lam", "fa", "tha", "dhal", "ha", "ya")},
    **{letter_id: ("kasra",) for letter_id in ("ta", "sin", "jim", "zay", "waw")},
}


def core_vowels(letter_id):
    return CORE_VOWELS.get(letter_id, ("fatha",))


CORE_SYLLABLE_IDS = [
    f"vowel.{letter_id}.{vowel}"
    for letter_id in HARAKAT_LETTER_IDS
    if letter_id != "ba"
    for vowel in core_vowels(letter_id)
]

# Сохраняем прежние атомы, заменённые при выравнивании огласовок, для
# чтения накопленного прогресса. В обязательные темы они больше не входят.
LEGACY_SYLLABLE_IDS = [
    "vowel.ta.fatha", "vowel.dal.fatha", "vowel.sin.fatha",
    "vowel.lam.fatha", "vowel.jim.fatha", "vowel.fa.fatha",
    "vowel.kha.kasra",
]

# Ба уже освоена вместе с самими знаками: второй обязательный набор
# vowel.ba.* дублировал первый урок, поэтому в переходах используются знаки.
HARAKA_SIGN_IDS = [f"haraka.{name}" for name in HARAKAT_NAMES]
REQUIRED_HARAKA_IDS = [*HARAKA_SIGN_IDS, *CORE_SYLLABLE_IDS]
