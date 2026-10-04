"""Проверяет конечный список слов и постепенное увеличение длины.

Защищает от появления искусственных сочетаний, появления длинных примеров
раньше коротких, потери огласовок и показа контрольного слова до проверки.
Курс и упражнения не меняет.
"""

import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "docs/word-reading"
MARKS = {"َ": "a", "ِ": "i", "ُ": "u"}
PHASES = ["two_letters", "three_letters", "occasional_four_letters"]
CONTEXT_FORMS = {"قُلِ", "خُذِ", "مِنَ", "لَمَنِ", "لِمَنِ"}


def validate(source_path=None):
    manifest = json.loads((CONTENT / "words.json").read_text())
    program = json.loads((CONTENT / "program.json").read_text())
    words = manifest["words"]
    by_id = {word["id"]: word for word in words}
    assert len(by_id) == len(words), "Повтор ID"
    assert len({word["joined"] for word in words}) == len(words), "Повтор записи"
    stage1 = json.loads((ROOT / "assets/curriculum/stage1.json").read_text())
    letters = {
        row["atom"]["display"]: row["atom"]["letterId"]
        for row in stage1["nodes"]
        if row["atom"].get("form") == "isolated"
    }
    letters.update({"أ": "alif", "إ": "alif"})
    core = [word_id for block in program["blocks"] for word_id in block["wordIds"]]
    reserved = set(program["reservedWordIds"])
    selection = program["selection"]
    assert len(core) == len(set(core)) == selection["coreWordCount"]
    assert reserved == {word_id for check in program["checks"] for word_id in check["wordIds"]}
    assert len(reserved) == 12 and not reserved.intersection(core)
    assert program["laterExercises"] == [1, 3]
    assert all(word_id in by_id for word_id in [*core, *reserved])
    assert all(word["origin"] == "quran" for word in words), "В банке допустимы только слова из Корана"
    assert {word["id"] for word in words if word["role"] == "core"} == set(core)
    assert {word["id"] for word in words if word["role"] == "check"} == reserved
    assert selection["practiceLimit"] == 0
    assert selection["quranOnly"]
    assert not selection["exhaustiveCoverageRequired"]
    assert not selection["requireMinimalPairsForEveryWord"]
    assert selection["fourLetterPolicy"] == "one_four_letter_word_among_five_three_letter_words"

    # Изменение таблицы для диктора должно проверяться вместе с JSON:
    # потерянная огласовка, строка или ссылка меняет будущую запись.
    table_rows = [
        line.split("|")[1:-1]
        for line in (CONTENT / "WORDS.md").read_text().splitlines()
        if re.match(r"\| \d+ \|", line)
    ]
    assert len(table_rows) == len(words)
    for number, (cells, word) in enumerate(zip(table_rows, words), start=1):
        cells = [cell.strip() for cell in cells]
        assert cells[0] == str(number)
        assert cells[1] == word["joined"] and cells[2] == word["separated"]
        assert cells[4] == f"`{word['id']}`"
        ref = word["quranReference"]
        assert cells[3] == f"[Коран {ref['surah']}:{ref['ayah']}]({ref['url']})"

    for word in words:
        glyph = word["joined"]
        assert re.fullmatch(r"(?:[بتثجحخدذرزسشصضطظعغفقكلمنهويأإ][َُِ]){2,4}", glyph), glyph
        syllables = [glyph[index:index + 2] for index in range(0, len(glyph), 2)]
        assert word["syllables"] == syllables and word["separated"] == " ".join(syllables)
        assert not any(part[0] in "أإ" for part in syllables[1:]), glyph
        assert not any(part in {"أِ", "إَ", "إُ"} for part in syllables), glyph
        expected_id = "_".join(letters[part[0]] + "_" + MARKS[part[1]] for part in syllables)
        assert word["id"] == expected_id
        assert word["audioFile"] == f"audio/words/{expected_id}.mp3"
        assert word["role"] in {"core", "check", "review"}
        # Связи для будущих ответов необязательны; если их добавят,
        # они не могут ссылаться на удалённый или контрольный пример.
        for kind in ["vowelContrastIds", "consonantContrastIds"]:
            assert all(alt in by_id and alt not in reserved for alt in word.get(kind, []))
        assert word["quranReference"]["token"] == glyph
        assert glyph not in CONTEXT_FORMS and not glyph.endswith(("هِمُ", "لَوِ", "يِ")), glyph

    phase_sequence = [block["phase"] for block in program["blocks"]]
    assert list(dict.fromkeys(phase_sequence)) == PHASES
    assert phase_sequence == sorted(phase_sequence, key=PHASES.index)
    short_lesson_count = 0
    introduced = set()
    for number, block in enumerate(program["blocks"], start=1):
        assert block["lesson"] == number
        examples = [by_id[word_id] for word_id in block["wordIds"]]
        lengths = [len(word["syllables"]) for word in examples]
        # Повторы используют уже введённые слова, не требуют новых MP3
        # и не могут случайно показать контрольный пример заранее.
        review_ids = block.get("reviewWordIds", [])
        assert len(review_ids) == len(set(review_ids))
        assert set(review_ids) <= introduced
        assert all(len(by_id[word_id]["syllables"]) in block["allowedLengths"] for word_id in review_ids)
        if block["phase"] == "two_letters":
            short_lesson_count += 1
            assert block["allowedLengths"] == [2] and set(lengths) == {2}
        elif block["phase"] == "three_letters":
            assert block["allowedLengths"] == [3] and set(lengths) == {3}
        else:
            assert block["allowedLengths"] == [3, 4]
            assert lengths.count(4) == 1 and lengths.count(3) == 5
        introduced.update(block["wordIds"])
    assert 2 <= short_lesson_count <= 3, "Начало должно содержать несколько коротких уроков"

    if source_path is not None:
        raw = Path(source_path).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == manifest["source"]["sha256"]
        corpus = json.loads(raw)
        verses = {
            (chapter["id"], verse["id"]): verse["text"].split()
            for chapter in corpus for verse in chapter["verses"]
        }
        for word in words:
            reference = word["quranReference"]
            token = verses[reference["surah"], reference["ayah"]][reference["wordIndex"] - 1]
            assert token == reference["token"] == word["joined"], reference
    return {
        "words": len(words), "core": len(core), "reserved": len(reserved),
        "review": sum(word["role"] == "review" for word in words),
        "origins": dict(Counter(word["origin"] for word in words)),
        "lengths": dict(Counter(len(word["syllables"]) for word in words)),
        "shortLessons": short_lesson_count, "sourceChecked": source_path is not None,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, help="Сохранённый simple-min Quran JSON для сверки аятов")
    args = parser.parse_args()
    print(json.dumps(validate(args.source), ensure_ascii=False, indent=2))
