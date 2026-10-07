"""Проверяет общий банк слов и обновляет таблицу для редактора и озвучки."""

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "assets/curriculum/words.json"
TABLE = ROOT / "docs/word-reading/WORDS.md"
MARKS = {"fatha": ("َ", "a"), "kasra": ("ِ", "i"), "damma": ("ُ", "u")}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate(bank, source_path=None):
    words = bank["words"]
    by_id = {word["id"]: word for word in words}
    require(len(by_id) == len(words), "Повтор ID слова")
    require(len({word["joined"] for word in words}) == len(words), "Повтор написания слова")
    stage1 = json.loads((ROOT / "assets/curriculum/stage1.json").read_text())
    forms = {row["atom"]["id"]: row["atom"] for row in stage1["nodes"]}
    letters = {
        atom["letterId"]: atom["display"] for atom in forms.values()
        if atom.get("form") == "isolated"
    }
    for word in words:
        word_id = word["id"]
        ids = word["syllableIds"]
        require(2 <= len(ids) <= 4, f"Нужны 2–4 кратких слога: {word_id}")
        glyphs, segments = [], []
        for syllable in ids:
            letter, mark = syllable.split(".")
            require(letter in letters and mark in MARKS, f"Неизвестный слог: {syllable}")
            glyph = letters[letter]
            if letter == "alif":
                glyph = "إ" if mark == "kasra" else "أ"
            glyphs.append(glyph + MARKS[mark][0])
            segments.append(f"{letter}_{MARKS[mark][1]}")
        require("".join(glyphs) == word["joined"], f"Слоги не совпадают с написанием: {word_id}")
        require("_".join(segments) == word_id, f"ID не соответствует слогам: {word_id}")
        require(word["audioFile"] == f"audio/words/{word_id}.mp3", f"Изменилось имя записи: {word_id}")
        require(isinstance(word.get("recorded", False), bool), f"recorded должен быть boolean: {word_id}")
        if word.get("recorded", False):
            require((ROOT / "assets" / word["audioFile"]).is_file(), f"Нет MP3: {word_id}")
        reference = word.get("quranReference")
        if word["origin"] == "quran":
            require(reference and reference["token"] == word["joined"], f"Нет точной ссылки на аят: {word_id}")
            require(reference["url"] == f"https://tanzil.net/#{reference['surah']}:{reference['ayah']}", f"Неверная ссылка на аят: {word_id}")
        else:
            source = word.get("source", {})
            require(source.get("name") and source.get("url"), f"Нет источника: {word_id}")
            if "://" not in source["url"]:
                require((ROOT / source["url"]).is_file(), f"Нет файла источника: {word_id}")

    for name, ids in bank["wordSets"].items():
        require(len(ids) == len(set(ids)), f"Повтор слова в подборке {name}")
        require(all(word_id in by_id for word_id in ids), f"Неизвестное слово в подборке {name}")
    for word_id in bank["wordSets"]["harakaIntroduction"]:
        ids = by_id[word_id]["syllableIds"]
        require(len(ids) <= 3, f"Вводное слово слишком длинное: {word_id}")
        require(all(f"{syllable.split('.')[0]}.initial" in forms for syllable in ids[:-1]), f"Разрыв во вводном слове: {word_id}")

    stage3 = json.loads((ROOT / "assets/curriculum/stage3.json").read_text())
    nodes = [row["atom"] for row in stage3["nodes"] if row["atom"]["kind"] == "word"]
    require([node["wordId"] for node in nodes] == bank["wordSets"]["wordReading"], "Граф слов не соответствует подборке; запустите tool/build_stage3.py")
    for node in nodes:
        word = by_id[node["wordId"]]
        require(node["id"] == word.get("atomId"), f"Изменился ID прогресса: {word['id']}")
        require("display" not in node and "audioAsset" not in node, f"Дублирование слова в графе: {node['id']}")

    if source_path is not None:
        raw = source_path.read_bytes()
        require(hashlib.sha256(raw).hexdigest() == bank["source"]["sha256"], "Не совпадает исходный Quran JSON")
        verses = {
            (chapter["id"], verse["id"]): verse["text"].split()
            for chapter in json.loads(raw) for verse in chapter["verses"]
        }
        for word in words:
            if word["origin"] != "quran":
                continue
            ref = word["quranReference"]
            token = verses[ref["surah"], ref["ayah"]][ref["wordIndex"] - 1]
            require(token == ref["token"] == word["joined"], f"Не совпадает текст аята: {word['id']}")


def render(bank):
    by_id = {word["id"]: word for word in bank["words"]}
    # Вводную подборку удобно видеть первой, остальные записи идут в порядке банка.
    ids = list(dict.fromkeys([*bank["wordSets"]["harakaIntroduction"], *by_id]))
    lines = [
        "# Слова для упражнений и озвучки", "",
        "Таблица создаётся из [общего банка](../../assets/curriculum/words.json).",
        "Редактировать JSON, затем выполнить `python3 tool/word_bank.py --write`.", "",
        "Одна строка — одна запись целого слова. Читать слитно, с последней краткой",
        "огласовкой. Раздельный показ ниже нужен только для разбора диктором.",
        "Отсутствие подборки означает запас для будущих упражнений.", "",
        "`harakaIntroduction` — вводные сборки; `wordReading` — текущие слова курса;",
        "`wordBuildDebug` — просмотр разных соединений в отладке.", "",
        "| № | Слово | Разбор | Источник | Файл в `assets/audio/words/` | Подборки |",
        "|---|---|---|---|---|---|",
    ]
    for number, word_id in enumerate(ids, start=1):
        word = by_id[word_id]
        ref = word.get("quranReference")
        if ref:
            source = f"[Коран {ref['surah']}:{ref['ayah']}]({ref['url']})"
        else:
            url = word["source"]["url"]
            if "://" not in url:
                url = f"../../{url}"
            source = f"[{word['source']['name']}]({url})"
        joined = word["joined"]
        separated = " ".join(joined[index:index + 2] for index in range(0, len(joined), 2))
        sets = ", ".join(f"`{name}`" for name, values in bank["wordSets"].items() if word_id in values)
        lines.append(f"| {number} | {joined} | {separated} | {source} | `{word_id}.mp3` | {sets} |")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Обновить таблицу WORDS.md")
    parser.add_argument("--source", type=Path, help="Сохранённый simple-min Quran JSON для сверки аятов")
    args = parser.parse_args()
    bank = json.loads(BANK.read_text())
    validate(bank, args.source)
    table = render(bank)
    if args.write:
        TABLE.write_text(table)
    else:
        require(TABLE.read_text() == table, "Таблица устарела: python3 tool/word_bank.py --write")
    print(json.dumps({
        "words": len(bank["words"]),
        "wordSets": {name: len(ids) for name, ids in bank["wordSets"].items()},
        "origins": dict(Counter(word["origin"] for word in bank["words"])),
        "sourceChecked": args.source is not None,
    }, ensure_ascii=False, indent=2))
