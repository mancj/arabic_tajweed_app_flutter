// Защищает формат авторских файлов: новые типы блоков и правки загрузчика
// не должны терять порядок, скрывать ошибки содержимого или ломать старый JSON.
import 'dart:io';

import 'package:arabic_tajweed_app/data/explanation_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/explanation_document.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/text_asset_bundle.dart';

void main() {
  const asset = 'assets/explanations/ru/ba.yaml';
  final source = File(asset).readAsStringSync();

  test('карточка читается без курса и сохраняет порядок блоков', () {
    final content = ExplanationLoader.parse(source);
    expect(content.document.title, 'Буква Ба');
    expect(content.document.blocks.map((block) => block.runtimeType), [
      ExplanationText,
      ExplanationLetter,
      ExplanationWriting,
      ExplanationMakhraj,
      ExplanationSifat,
      ExplanationText,
      ExplanationForms,
      ExplanationWord,
      ExplanationText,
      ExplanationExamples,
      ExplanationSound,
    ]);
    final forms = (content.document.blocks[6] as ExplanationForms).forms;
    expect(forms.map((form) => form.position), LetterForm.values);
    expect(forms[1].example?.text, 'بات');
    expect(forms[1].example?.highlight, 0);
    final word = (content.document.blocks[7] as ExplanationWord).word;
    expect(word.text, 'بات');
    expect(word.form, LetterForm.initial);
    final examples =
        (content.document.blocks[9] as ExplanationExamples).examples;
    expect(examples.map((example) => example.glyph), ['بَ', 'بِ', 'بُ']);
    for (final audio in [
      (content.document.blocks[1] as ExplanationLetter).letter.audio!,
      ...examples.map((example) => example.audio!),
      (content.document.blocks.last as ExplanationSound).sound.audio,
    ]) {
      expect(File('assets/$audio').existsSync(), isTrue, reason: audio);
    }
    final text = (content.document.blocks.first as ExplanationText).text;
    expect(text, contains('**одна точка снизу**'));
    expect(text, contains('\n\n'));
    expect(
      (content.document.blocks[3] as ExplanationMakhraj).makhraj,
      contains('Сомкните губы'),
    );
    expect(
      (content.document.blocks[4] as ExplanationSifat).sifat,
      contains('с голосом'),
    );
    expect(
      (content.document.blocks[2] as ExplanationWriting).writing,
      contains('**ب** похожа на неглубокую чашу'),
    );
    final again = ExplanationDocument.fromJson(content.document.toJson());
    expect(again.toJson(), content.document.toJson());
  });

  // Правка отдельной карточки не должна потерять образец, звук или
  // офлайн-иллюстрацию. Махрадж и сыфат есть только там, где нужны автору.
  test('карточки всех букв сохраняют образец, разделы и ссылки на ассеты', () {
    for (final name in [
      'alif',
      'ba',
      'ta',
      'tha',
      'jim',
      'hha',
      'kha',
      'dal',
      'dhal',
      'ra',
      'zay',
      'sin',
      'shin',
      'sod',
      'dod',
      'to',
      'zho',
      'ayn',
      'ghayn',
      'fa',
      'qof',
      'kaf',
      'lam',
      'mim',
      'nun',
      'ha',
      'waw',
      'ya',
    ]) {
      final path = 'assets/explanations/ru/$name.isolated.yaml';
      final blocks = ExplanationLoader.parse(
        File(path).readAsStringSync(),
        sourceName: path,
      ).document.blocks;
      final types = blocks.map((block) => block.runtimeType).toList();
      expect(types.where((type) => type == ExplanationLetter), hasLength(1));
      expect(types.first, ExplanationLetter, reason: path);
      final letter = (blocks.first as ExplanationLetter).letter;
      expect(File('assets/${letter.audio}').existsSync(), isTrue, reason: path);
      final makhrajIndex = types.indexOf(ExplanationMakhraj);
      final sifatIndex = types.indexOf(ExplanationSifat);
      final writingIndex = types.indexOf(ExplanationWriting);
      expect(
        types.where((type) => type == ExplanationWriting),
        hasLength(1),
        reason: path,
      );
      expect(
        writingIndex,
        greaterThan(types.indexOf(ExplanationText)),
        reason: path,
      );
      for (final type in [ExplanationMakhraj, ExplanationSifat]) {
        expect(
          types.where((value) => value == type).length,
          lessThanOrEqualTo(1),
        );
      }
      if (makhrajIndex >= 0 && sifatIndex >= 0) {
        expect(makhrajIndex, lessThan(sifatIndex), reason: path);
      }
      for (final index in [
        makhrajIndex,
        sifatIndex,
      ].where((value) => value >= 0)) {
        expect(writingIndex, lessThan(index), reason: path);
      }
      for (final block in blocks) {
        final markdown = switch (block) {
          ExplanationText(:final text) => text,
          ExplanationWriting(:final writing) => writing,
          ExplanationMakhraj(:final makhraj) => makhraj,
          ExplanationSifat(:final sifat) => sifat,
          _ => '',
        };
        expect(markdown, isNot(contains('## Как пишется')), reason: path);
        for (final image in RegExp(
          r'!\[[^\]]*\]\(([^)]+)\)',
        ).allMatches(markdown)) {
          final target = image.group(1)!;
          expect(target, startsWith('resource:assets/img/'), reason: path);
          expect(
            File(target.substring('resource:'.length)).existsSync(),
            isTrue,
            reason: '$path: $target',
          );
        }
      }
    }
  });

  for (final entry in {
    'неизвестный тип': 'unknown: ba',
    'два типа сразу': 'text: текст, letter: ba.isolated',
    'нестроковый текст': 'text: 42',
    'пустой текст': 'text: " "',
    'пустое написание': 'writing: " "',
    'нестроковое написание': 'writing: 42',
    'написание без текста': 'writing: null',
    'пустой махрадж': 'makhraj: " "',
    'пустой сыфат': 'sifat: " "',
    'нестроковый махрадж': 'makhraj: 42',
    'старый ID вместо буквы': 'letter: ba.isolated',
    'пустая буква': 'letter: {glyph: ""}',
    'путь вне аудио': 'letter: {glyph: ب, audio: ../outside.wav}',
    'нет форм': 'forms: []',
    'повтор формы':
        'forms: [{position: isolated, glyph: ب}, {position: isolated, glyph: ب}]',
    'пустая форма': 'forms: [{position: initial, glyph: ""}]',
    'неизвестное положение': 'forms: [{position: another, glyph: ب}]',
    'ошибка в слове формы':
        'forms: [{position: initial, glyph: ب, example: {text: بات, highlight: 3}}]',
    'нет слова-примера': 'word: ba.initial',
    'подсветка за концом слова': 'word: {text: بات, highlight: 3}',
    'пустые примеры': 'examples: []',
    'ошибка в одном из примеров': 'examples: [{glyph: ب}, {glyph: ""}]',
    'пустая подпись звука': 'sound: {label: "", audio: audio/alphabet/ba.wav}',
    'неверный путь звука': 'sound: {label: Ба, audio: /tmp/ba.wav}',
  }.entries) {
    test('${entry.key}: ошибка называет файл и блок', () {
      expect(
        () => ExplanationLoader.parse(
          'title: Проверка\nblocks:\n  - {${entry.value}}',
          sourceName: asset,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'файл и блок',
            allOf(contains(asset), contains('blocks[0]')),
          ),
        ),
      );
    });
  }

  for (final invalid in [
    '[]',
    'title: Заголовок\nblocks: []',
    'title: ""\nblocks: [{text: Текст}]',
    'title: Заголовок\nbloks: [{text: Текст}]',
    'title: Заголовок\nblocks: [{text: Текст}]\nextra: true',
    'title: Первый\ntitle: Второй\nblocks: [{text: Текст}]',
  ]) {
    test('ошибочная структура не превращается в пустую карточку: $invalid', () {
      expect(() => ExplanationLoader.parse(invalid), throwsFormatException);
    });
  }

  test('одновременные запросы одного файла используют одну загрузку', () async {
    final bundle = TextAssetBundle({asset: source});
    final loader = ExplanationLoader(bundle: bundle);
    final cards = await Future.wait([loader.load(asset), loader.load(asset)]);
    expect(cards.first, same(cards.last));
    expect(await loader.load(asset), same(cards.first));
    expect(bundle.loads, [asset]);
  });

  test('ошибка загрузки не мешает прочитать исправленный файл', () async {
    final bundle = TextAssetBundle({});
    final loader = ExplanationLoader(bundle: bundle);
    await expectLater(loader.load(asset), throwsFormatException);
    bundle.sources[asset] = source;
    expect((await loader.load(asset)).document.title, 'Буква Ба');
    expect(bundle.loads, [asset, asset]);
  });

  test('ссылка на карточку необязательна и переживает сериализацию атома', () {
    const old = Atom(
      id: 'concept.example',
      kind: AtomKind.concept,
      display: 'Пример',
    );
    expect(old.toJson(), isNot(contains('explanationAsset')));
    final withCard = Atom.fromJson({
      ...old.toJson(),
      'explanationAsset': asset,
    });
    expect(withCard.note, old.note);
    expect(Atom.fromJson(withCard.toJson()).explanationAsset, asset);
  });
}
