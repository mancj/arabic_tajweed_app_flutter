import 'dart:math' as math;
import 'dart:ui';

/// Сигнатура формы линии: точки, пересчитанные так, что от них остаётся
/// только форма — ни места на холсте, ни размера, ни пропорций.
///
/// Линия пересэмплируется в фиксированное число точек по длине дуги,
/// вписывается в единичный квадрат и центрируется — как в распознавателе $1.
///
/// Сравниваются сигнатуры **по порядку точек**, и этим форма отличается от
/// расстояния до эталона, которым мы мерили раньше. Расстояние не чувствует
/// порядок: «W» на месте чаши каждой своей точкой лежит рядом с какой-нибудь
/// точкой чаши и потому проходит. По порядку она не проходит: на середине
/// пути перо должно быть внизу, а оно наверху.
///
/// Соответствие точек ищется динамическим выравниванием (DTW), а не строго
/// «i-я к i-й». Жёсткое соответствие требует, чтобы части буквы занимали ту
/// же долю длины, что и в эталоне: у س с более глубоким хвостом зубцы
/// оказываются «не на своём километре», и верная буква отвергается (0.123
/// против 0.061 у DTW). Выравнивание позволяет соответствию растягиваться
/// вдоль линии — но не дальше [alignmentBand], иначе лишняя петля просто
/// схлопнется в точку и неверная форма пройдёт.
class StrokeSignature {
  /// Сколько точек оставляем. Больше — точнее и медленнее; 64 хватает,
  /// чтобы различать зубцы ش.
  static const int sampleCount = 64;

  /// Выше этого отношения сторон нормируем равномерно: у ا соотношение
  /// около 1:10, и растяжение узкой оси превратило бы дрожание руки в мусор.
  static const double extremeAspect = 6;

  /// Насколько далеко соответствие может съезжать вдоль линии, в долях
  /// её длины (полоса Сакоэ–Чибы).
  static const double alignmentBand = 0.1;

  final List<Offset> points;

  /// Нормировали ли равномерно. Решает **эталон**: ввод обязан нормироваться
  /// так же, иначе растянутая форма перескочит границу [extremeAspect] и
  /// сравнение пойдёт по разным правилам.
  final bool uniform;

  const StrokeSignature(this.points, {required this.uniform});

  static StrokeSignature? ofPaths(List<Path> paths, {bool? uniform}) =>
      ofPolylines(polylinesOf(paths), uniform: uniform);

  /// Точки каждой линии отдельно: части из двух штрихов разбираются на
  /// куски, между которыми чернил нет.
  static List<List<Offset>> polylinesOf(List<Path> paths) {
    final lines = <List<Offset>>[];
    for (final path in paths) {
      for (final metric in path.computeMetrics()) {
        if (metric.length <= 0) continue;
        final step = metric.length / (sampleCount * 2);
        final line = <Offset>[];
        for (var d = 0.0; d <= metric.length; d += step) {
          final tangent = metric.getTangentForOffset(d);
          if (tangent != null) line.add(tangent.position);
        }
        if (line.length >= 2) lines.add(line);
      }
    }
    return lines;
  }

  /// Сигнатура части, собранной из нескольких отдельных линий.
  ///
  /// Между линиями чернил нет, и вести выборку сквозь разрыв нельзя: у
  /// соединённых форм ـحـ, ـضـ, ـطـ штрихи расходятся на 60–114 пикселей,
  /// и прямая через промежуток забирает пятую часть точек. Каждый кусок
  /// пересэмплируется отдельно, а точки делятся между кусками по длине.
  ///
  /// Это модель «перо отрывали». Модель «вели не отрываясь» — это
  /// [ofPoints] по склеенным точкам: там перемычка нарисована и в счёт
  /// идти должна.
  static StrokeSignature? ofPolylines(
    List<List<Offset>> lines, {
    bool? uniform,
  }) {
    final usable = [
      for (final line in lines)
        if (line.length >= 2) line,
    ];
    if (usable.isEmpty) return null;
    if (usable.length == 1) return ofPoints(usable.first, uniform: uniform);

    final lengths = [for (final line in usable) _lengthOf(line)];
    final total = lengths.fold(0.0, (sum, value) => sum + value);
    if (total <= 0) return null;

    // Доли округляются вниз, остаток достаётся самому длинному куску: он
    // несёт основную форму, и лишние точки полезнее всего там.
    final counts = [
      for (final length in lengths)
        math.max(2, (sampleCount * length / total).floor()),
    ];
    var longest = 0;
    for (var i = 1; i < lengths.length; i++) {
      if (lengths[i] > lengths[longest]) longest = i;
    }
    counts[longest] += sampleCount - counts.fold(0, (sum, n) => sum + n);
    if (counts[longest] < 2) return null;

    final points = <Offset>[];
    for (var i = 0; i < usable.length; i++) {
      final part = _resample(usable[i], counts[i]);
      if (part == null) return null;
      points.addAll(part);
    }
    return _normalize(points, uniform);
  }

  static double _lengthOf(List<Offset> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
    }
    return total;
  }

  static StrokeSignature? ofPoints(List<Offset> points, {bool? uniform}) {
    if (points.length < 2) return null;

    final resampled = _resample(points, sampleCount);
    if (resampled == null) return null;

    return _normalize(resampled, uniform);
  }

  /// Расхождение форм. Линию сравниваем и в обратном направлении: обводить
  /// справа налево или слева направо — одна и та же форма.
  double distanceTo(StrokeSignature other) {
    final last = points.length - 1;
    final backwards = [for (var i = last; i >= 0; i--) points[i]];

    return math.min(
      _align(points, other.points),
      _align(backwards, other.points),
    );
  }

  /// Среднее расстояние по лучшему соответствию точек в пределах полосы.
  static double _align(List<Offset> a, List<Offset> b) {
    final n = a.length;
    final m = b.length;
    final width = math.max(1, (math.max(n, m) * alignmentBand).round());

    var previous = List<double>.filled(m + 1, double.infinity);
    var current = List<double>.filled(m + 1, double.infinity);
    previous[0] = 0;

    for (var i = 1; i <= n; i++) {
      current.fillRange(0, m + 1, double.infinity);
      final from = math.max(1, i - width);
      final to = math.min(m, i + width);

      for (var j = from; j <= to; j++) {
        final cost = (a[i - 1] - b[j - 1]).distance;
        current[j] =
            cost +
            math.min(previous[j], math.min(current[j - 1], previous[j - 1]));
      }

      final swap = previous;
      previous = current;
      current = swap;
    }

    return previous[m] / math.max(n, m);
  }

  /// Равномерная выборка [count] точек по длине ломаной.
  static List<Offset>? _resample(List<Offset> points, int count) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
    }
    if (total <= 0) return null;

    final step = total / (count - 1);
    final result = <Offset>[points.first];

    var current = points.first;
    var index = 1;
    var walked = 0.0;

    while (result.length < count && index < points.length) {
      final segment = (points[index] - current).distance;
      if (walked + segment >= step) {
        final t = segment == 0 ? 0.0 : (step - walked) / segment;
        current = Offset.lerp(current, points[index], t)!;
        result.add(current);
        walked = 0;
      } else {
        walked += segment;
        current = points[index];
        index++;
      }
    }

    while (result.length < count) {
      result.add(points.last);
    }
    return result;
  }

  /// Вписывает в единичный квадрат и сносит центроид в ноль.
  static StrokeSignature _normalize(List<Offset> points, bool? forceUniform) {
    var left = points.first.dx;
    var right = left;
    var top = points.first.dy;
    var bottom = top;

    for (final point in points) {
      if (point.dx < left) left = point.dx;
      if (point.dx > right) right = point.dx;
      if (point.dy < top) top = point.dy;
      if (point.dy > bottom) bottom = point.dy;
    }

    final width = right - left;
    final height = bottom - top;
    final longest = math.max(width, height);
    if (longest <= 0) {
      return StrokeSignature(points, uniform: forceUniform ?? true);
    }

    final shortest = math.min(width, height);
    final uniform =
        forceUniform ?? (shortest <= 0 || longest / shortest > extremeAspect);

    final scaleX = uniform ? 1 / longest : (width > 0 ? 1 / width : 0.0);
    final scaleY = uniform ? 1 / longest : (height > 0 ? 1 / height : 0.0);

    final scaled = [
      for (final point in points) Offset(point.dx * scaleX, point.dy * scaleY),
    ];

    var centroid = Offset.zero;
    for (final point in scaled) {
      centroid += point;
    }
    centroid = centroid / scaled.length.toDouble();

    return StrokeSignature([
      for (final point in scaled) point - centroid,
    ], uniform: uniform);
  }
}
