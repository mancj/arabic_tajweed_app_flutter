"""Собирает обязательные слоги на 28 буквах и короткие слова в stage3.json."""

import json
from pathlib import Path

from harakat_data import (
    HARAKA_SIGN_IDS, HARAKAT_LETTERS, LEGACY_SYLLABLE_IDS, REQUIRED_HARAKA_IDS, core_vowels,
)


ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "assets/curriculum/stage3.json"

LETTERS = HARAKAT_LETTERS
VOWELS = [
    ("fatha", "َ", "фатхой"),
    ("kasra", "ِ", "касрой"),
    ("damma", "ُ", "даммой"),
]
# Прежние группы букв остаются темами. Большие группы имеют авторские
# части по целым буквам: не больше пяти новых слогов за занятие.
GROUP_LETTER_IDS = (
    ("ta", "kaf", "dal", "ra"),
    ("sin", "mim", "lam", "shin"),
    ("ayn", "jim", "hha", "fa"),
    ("nun", "alif", "tha"),
    ("kha", "dhal", "zay"),
    ("sod", "dod", "ha"),
    ("to", "zho", "waw"),
    ("ghayn", "qof", "ya"),
)
LETTER_BY_ID = {letter_id: letter for letter_id, *letter in LETTERS}
GROUPS = [
    [(letter_id, *LETTER_BY_ID[letter_id]) for letter_id in group]
    for group in GROUP_LETTER_IDS
]
WORDS = [
    ("kataba", "كَتَبَ"),
    ("darasa", "دَرَسَ"),
    ("rasama", "رَسَمَ"),
    ("shariba", "شَرِبَ"),
    ("samia", "سَمِعَ"),
    ("amila", "عَمِلَ"),
    ("fariha", "فَرِحَ"),
    ("laiba", "لَعِبَ"),
    ("najaha", "نَجَحَ"),
]


def known(atom_id):
    return {"type": "atomKnown", "atomId": atom_id}


def introduced(atom_id):
    return {"type": "atomIntroduced", "atomId": atom_id}


def completed(atom_id):
    return introduced(atom_id) if atom_id.startswith("concept.") else known(atom_id)


def all_of(requirements):
    return {"type": "allOf", "parts": list(requirements)}


def topic(topic_id, title, requirement, ids, stage=2, lesson_blocks=None):
    result = {
        "id": topic_id,
        "stage": stage,
        "title": title,
        "requirement": requirement,
        "counterOf": ids,
    }
    if lesson_blocks is not None:
        result["lessonBlocks"] = lesson_blocks
    return result


def node(atom, requirement):
    return {"atom": atom, "requirement": requirement}


def spoken_atom(
    atom_id, kind, display, label, letter_id=None, audio_asset=None,
    tracing=None,
):
    atom = {
        "id": atom_id,
        "kind": kind,
        "display": display,
        "label": label,
        "explanationAsset": f"assets/explanations/ru/{atom_id}.yaml",
        "audioAsset": audio_asset or f"tts:{display}",
    }
    if letter_id is not None:
        atom["letterId"] = letter_id
    if tracing is not None:
        atom["tracing"] = tracing
    return atom


def harakat_asset(letter_id, vowel):
    relative = f"audio/harakat/{letter_id}_{vowel}.mp3"
    if not (ROOT / "assets" / relative).is_file():
        raise FileNotFoundError(f"Нет записи огласовки: assets/{relative}")
    return relative


def syllable_ids(letters):
    return [f"vowel.{letter_id}.{name}" for letter_id, _, _ in letters
            for name in core_vowels(letter_id)]


def build():
    topics = []
    nodes = []
    # Огласовки начинаются после всех отдельных и соединённых форм букв.
    # Многобуквенные связки идут позже отдельным этапом.
    stage1 = json.loads((ROOT / "assets/curriculum/stage1.json").read_text())
    stage1_ids = [atom_id for t in stage1["topics"] for atom_id in t["counterOf"]]
    prerequisite = all_of([
        {"type": "lettersKnown", "count": 28},
        *[known(atom_id) if not atom_id.startswith("concept.") else introduced(atom_id)
          for atom_id in stage1_ids],
    ])
    concept_id = "concept.haraka"
    topics.append(topic("m.haraka.intro", "Что такое огласовки", prerequisite, [concept_id]))
    nodes.append(node({
        "id": concept_id,
        "kind": "concept",
        "display": "огласовки",
        "label": "Краткие огласовки",
        "explanationAsset": f"assets/explanations/ru/{concept_id}.yaml",
    }, prerequisite))

    signs = HARAKA_SIGN_IDS
    topics.append(topic("m.haraka.signs", "Три огласовки на ب", introduced(concept_id), signs))
    for name, mark, title in VOWELS:
        display = f"ب{mark}"
        nodes.append(node(spoken_atom(
            f"haraka.{name}", "haraka", display,
            f"Ба с {title}",
            "ba",
            harakat_asset("ba", name),
            f"harakat/{name}",
        ), introduced(concept_id)))

    # Старые ID сохраняются для накопленного прогресса и отладочных заданий.
    # Отдельной обязательной темы ба больше нет: её уже проверили на знаках.
    for name, mark, title in VOWELS:
        display = f"ب{mark}"
        nodes.append(node(spoken_atom(
            f"vowel.ba.{name}", "syllable", display,
            f"Ба с {title}",
            "ba",
            harakat_asset("ba", name),
            f"harakat/{name}",
        ), all_of(map(known, signs))))

    previous = signs
    for index, group in enumerate(GROUPS, start=1):
        ids = syllable_ids(group)
        requirement = all_of(map(completed, previous))
        titles = " и ".join(glyph for _, glyph, _ in group)
        blocks = []
        for letter in group:
            letter_ids = syllable_ids([letter])
            if not blocks or len(blocks[-1]) + len(letter_ids) > 5:
                blocks.append([])
            blocks[-1].extend(letter_ids)
        topics.append(topic(
            f"m.haraka.group{index}", f"Огласовки на {titles}", requirement, ids,
            lesson_blocks=blocks if len(blocks) > 1 else None,
        ))
        for letter_id, glyph, letter_name in group:
            for name, mark, title in VOWELS:
                if name not in core_vowels(letter_id):
                    continue
                base = "إ" if letter_id == "alif" and name == "kasra" else (
                    "أ" if letter_id == "alif" else glyph)
                display = f"{base}{mark}"
                nodes.append(node(spoken_atom(
                    f"vowel.{letter_id}.{name}", "syllable", display,
                    f"{letter_name.capitalize()} с {title}",
                    letter_id,
                    harakat_asset(letter_id, name),
                    f"harakat/{name}",
                ), requirement))
        previous = ids

    # Исторические слоги сохраняют ID, запись и карточку, но не требуют
    # отдельного урока и не участвуют в условиях перехода.
    for atom_id in LEGACY_SYLLABLE_IDS:
        _, letter_id, vowel = atom_id.split(".")
        glyph, letter_name = LETTER_BY_ID[letter_id]
        _, mark, title = next(value for value in VOWELS if value[0] == vowel)
        nodes.append(node(spoken_atom(
            atom_id, "syllable", f"{glyph}{mark}",
            f"{letter_name.capitalize()} с {title}", letter_id,
            harakat_asset(letter_id, vowel), f"harakat/{vowel}",
        ), all_of(map(known, signs))))

    stage2 = json.loads((ROOT / "assets/curriculum/stage2.json").read_text())
    connection_ids = [
        atom_id for topic_data in stage2["topics"]
        for atom_id in topic_data["counterOf"]
    ]
    previous = [
        *REQUIRED_HARAKA_IDS,
        *connection_ids,
    ]
    for index in range(0, len(WORDS), 3):
        group = WORDS[index : index + 3]
        ids = [f"word.{word_id}" for word_id, _ in group]
        requirement = all_of(map(completed, previous))
        topics.append(topic(
            f"m.haraka.words{index // 3 + 1}",
            f"Читаем короткие слова {index // 3 + 1}",
            requirement,
            ids,
            stage=3,
        ))
        for word_id, display in group:
            nodes.append(node(spoken_atom(
                f"word.{word_id}", "word", display,
                "Короткое слово",
            ), requirement))
        previous = ids

    return {"topics": topics, "nodes": nodes}


if __name__ == "__main__":
    DESTINATION.write_text(json.dumps(build(), ensure_ascii=False, indent=2) + "\n")
