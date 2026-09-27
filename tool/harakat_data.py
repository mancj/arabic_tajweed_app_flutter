"""Общие данные обязательных сочетаний блока кратких огласовок."""

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

# Все три знака объясняются на ба. Для твёрдых букв и ро нужна отдельная
# проверка касры; первые короткие слова требуют также касру на мим и айн.
# Остальные буквы получают один обязательный слог, а не все три.
CORE_VOWELS = {
    "ba": ("fatha", "kasra", "damma"),
    "ra": ("fatha", "kasra"),
    "mim": ("fatha", "kasra"),
    "ayn": ("fatha", "kasra"),
    "alif": ("fatha", "kasra", "damma"),
    **{letter_id: ("fatha", "kasra") for letter_id in
       ("kha", "sod", "dod", "to", "zho", "ghayn", "qof")},
    **{letter_id: ("damma",) for letter_id in ("tha", "dhal", "ha", "ya")},
    **{letter_id: ("kasra",) for letter_id in ("zay", "waw")},
}


def core_vowels(letter_id):
    return CORE_VOWELS.get(letter_id, ("fatha",))


CORE_SYLLABLE_IDS = [
    f"vowel.{letter_id}.{vowel}"
    for letter_id in HARAKAT_LETTER_IDS
    for vowel in core_vowels(letter_id)
]
