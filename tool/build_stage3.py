"""Собирает блок огласовок на 28 буквах и коротких слов в stage3.json.

Три огласовки сначала показываются на ба, затем на остальных отдельных
буквах. Следующая группа открывается после освоения предыдущей.
"""

import json
from pathlib import Path

from harakat_data import HARAKAT_LETTERS, HARAKAT_NAMES


ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "assets/curriculum/stage3.json"

LETTERS = HARAKAT_LETTERS
VOWELS = [
    ("fatha", "َ", "фатхой", "а"),
    ("kasra", "ِ", "касрой", "и"),
    ("damma", "ُ", "даммой", "у"),
]
VOWEL_NAMES = {"fatha": "Фатха", "kasra": "Касра", "damma": "Дамма"}
# Не меняем семь уже выпущенных групп. Новые буквы идут после них парами.
GROUPS = (
    [LETTERS[i : i + 2] for i in range(1, 13, 2)]
    + [LETTERS[13:14]]
    + [LETTERS[i : i + 2] for i in range(14, len(LETTERS), 2)]
)
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


def topic(topic_id, title, requirement, ids, stage=2):
    return {
        "id": topic_id,
        "stage": stage,
        "title": title,
        "requirement": requirement,
        "counterOf": ids,
    }


def node(atom, requirement):
    return {"atom": atom, "requirement": requirement}


def spoken_atom(
    atom_id, kind, display, label, note, letter_id=None, audio_asset=None,
    tracing=None,
):
    atom = {
        "id": atom_id,
        "kind": kind,
        "display": display,
        "label": label,
        "note": note,
        "audioAsset": audio_asset or f"tts:{display}",
    }
    if letter_id is not None:
        atom["letterId"] = letter_id
    if tracing is not None:
        atom["tracing"] = tracing
    return atom


def harakat_asset(letter_id, vowel):
    relative = f"audio/harakat/{letter_id}_{vowel}.mp3"
    return relative if (ROOT / "assets" / relative).exists() else None


def syllable_ids(letters):
    return [f"vowel.{letter_id}.{name}" for letter_id, _, _ in letters for name, _, _, _ in VOWELS]


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
        "note": "Знак над или под буквой меняет её звучание. Сначала послушаем три знака на отдельной букве ب.",
    }, prerequisite))

    signs = [f"haraka.{name}" for name, _, _, _ in VOWELS]
    topics.append(topic("m.haraka.signs", "Три огласовки на ب", introduced(concept_id), signs))
    for name, mark, title, sound in VOWELS:
        display = f"ب{mark}"
        nodes.append(node(spoken_atom(
            f"haraka.{name}", "haraka", display,
            f"Ба с {title}",
            f"{VOWEL_NAMES[name]} даёт краткий звук «{sound}». Послушайте, как звучит {display}.",
            "ba",
            harakat_asset("ba", name),
            f"harakat/{name}",
        ), introduced(concept_id)))

    ba_ids = syllable_ids(LETTERS[:1])
    topics.append(topic("m.haraka.ba", "Читаем ب с огласовками", all_of(map(known, signs)), ba_ids))
    for name, mark, title, sound in VOWELS:
        display = f"ب{mark}"
        nodes.append(node(spoken_atom(
            f"vowel.ba.{name}", "syllable", display,
            f"Ба с {title}",
            f"Послушайте и прочитайте: {display} — краткий звук «{sound}».",
            "ba",
            harakat_asset("ba", name),
            f"harakat/{name}",
        ), all_of(map(known, signs))))

    previous = ba_ids
    for index, group in enumerate(GROUPS, start=1):
        ids = syllable_ids(group)
        requirement = all_of(map(completed, previous))
        titles = " и ".join(glyph for _, glyph, _ in group)
        topics.append(topic(f"m.haraka.group{index}", f"Огласовки на {titles}", requirement, ids))
        for letter_id, glyph, letter_name in group:
            for name, mark, title, sound in VOWELS:
                display = f"{glyph}{mark}"
                nodes.append(node(spoken_atom(
                    f"vowel.{letter_id}.{name}", "syllable", display,
                    f"{letter_name.capitalize()} с {title}",
                    f"Та же огласовка на другой отдельной букве: {display}. Звук «{sound}» краткий.",
                    letter_id,
                    harakat_asset(letter_id, name),
                    f"harakat/{name}",
                ), requirement))
        previous = ids

    stage2 = json.loads((ROOT / "assets/curriculum/stage2.json").read_text())
    connection_ids = [
        atom_id for topic_data in stage2["topics"]
        for atom_id in topic_data["counterOf"]
    ]
    previous = [
        *syllable_ids(LETTERS),
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
                "Прочитайте буквы с огласовками по порядку, затем произнесите слово целиком. Перевод появится позже.",
            ), requirement))
        previous = ids

    return {"topics": topics, "nodes": nodes}


if __name__ == "__main__":
    DESTINATION.write_text(json.dumps(build(), ensure_ascii=False, indent=2) + "\n")
