import 'dart:math' as math;
import 'dart:ui';

import 'drawing_stroke.dart';
import 'stroke_signature.dart';
import 'tracing_shape.dart';

/// Запуск проверки, который [DrawingController] делегирует холсту.
typedef TracingChecker = TracingMatchResult Function();

/// Чем закончилась проверка.
enum TracingMatchStatus {
  /// Ввод сверили с фигурой — смотри метрики.
  checked,

  /// Пользователь ещё ничего не нарисовал.
  noInput,

  /// Холст не готов: у него нет фигуры-подсказки либо он ещё не разложен.
  /// Метрики в этом случае бессмысленны, а не равны нулю.
  noShape,
}

/// Насколько ввод пользователя совпал с фигурой.
class TracingMatchResult {
  /// Доля фигуры, которую пользователь обвёл (0..1).
  final double coverage;

  /// Доля точек пользователя, попавших в полосу фигуры (0..1).
  final double accuracy;

  /// Насколько сильно линия отходит от фигуры, в долях толщины линии
  /// (перцентиль, а не максимум — один дёрнувшийся палец роли не играет).
  final double deviation;

  /// Расхождение форм без учёта места, размера и пропорций. Ноль — та же
  /// форма. Считается только там, где сверяется форма (режим по памяти).
  final double shapeError;

  /// Все ли диакритические точки поставлены.
  final bool dotsTraced;

  final bool isMatch;

  final TracingMatchStatus status;

  const TracingMatchResult({
    required this.coverage,
    required this.accuracy,
    required this.deviation,
    required this.shapeError,
    required this.dotsTraced,
    required this.isMatch,
  }) : status = TracingMatchStatus.checked;

  const TracingMatchResult.empty(this.status)
    : coverage = 0,
      accuracy = 0,
      deviation = 0,
      shapeError = double.infinity,
      dotsTraced = false,
      isMatch = false;

  /// Проверка вообще состоялась (есть и фигура, и ввод).
  bool get isChecked => status == TracingMatchStatus.checked;

  @override
  String toString() => status == TracingMatchStatus.checked
      ? 'TracingMatchResult(coverage: ${(coverage * 100).round()}%, '
            'accuracy: ${(accuracy * 100).round()}%, '
            'deviation: ${deviation.toStringAsFixed(2)}, '
            'shape: ${shapeError.isFinite ? shapeError.toStringAsFixed(3) : '—'}, '
            'dotsTraced: $dotsTraced, isMatch: $isMatch)'
      : 'TracingMatchResult(${status.name})';
}

/// Приведение нарисованного к фигуре: сдвиг и равномерный масштаб.
///
/// Нужно, когда пользователь рисует по памяти — форма может быть верной,
/// но нарисованной в другом месте холста и другого размера.
class TracingAlignment {
  final double scale;
  final Offset inputCenter;
  final Offset targetCenter;

  const TracingAlignment({
    required this.scale,
    required this.inputCenter,
    required this.targetCenter,
  });

  const TracingAlignment.identity()
    : scale = 1,
      inputCenter = Offset.zero,
      targetCenter = Offset.zero;

  bool get isIdentity => scale == 1 && inputCenter == targetCenter;

  /// Обратное преобразование как пара «масштаб и сдвиг»: им фигуру переносят
  /// туда, где рисовал пользователь.
  double get inverseScale => 1 / scale;

  Offset get inverseOffset => inputCenter - targetCenter / scale;

  Offset apply(Offset point) => (point - inputCenter) * scale + targetCenter;

  List<DrawingStroke> applyTo(List<DrawingStroke> strokes) {
    if (isIdentity) return strokes;
    return [
      for (final stroke in strokes)
        stroke.copyWith(points: [for (final p in stroke.points) apply(p)]),
    ];
  }

  /// Вписывает габариты [from] в габариты [to]. Возвращает null, если
  /// нарисованное слишком мелкое или требует недопустимого масштаба.
  static TracingAlignment? fit({
    required Rect from,
    required Rect to,
    required double minScale,
    required double maxScale,
    double minSize = 24,
  }) {
    if (from.longestSide < minSize || to.longestSide < minSize) return null;

    final byWidth = from.width < 1 ? double.infinity : to.width / from.width;
    final byHeight = from.height < 1
        ? double.infinity
        : to.height / from.height;

    // Среднее геометрическое, а не «вписать внутрь»: пропорции нарисованного
    // могут отличаться от эталонных, и min() схлопнул бы широкую букву до
    // размера её узкой оси — при заливке это выглядело бы как рывок.
    final scale = byWidth.isFinite && byHeight.isFinite
        ? math.sqrt(byWidth * byHeight)
        : math.min(byWidth, byHeight);
    if (!scale.isFinite || scale < minScale || scale > maxScale) return null;

    return TracingAlignment(
      scale: scale,
      inputCenter: from.center,
      targetCenter: to.center,
    );
  }
}

/// Сравнивает нарисованные штрихи с фигурой-подсказкой.
///
/// Фигура разбирается на плотный набор опорных точек, после чего считаются
/// три метрики:
/// * покрытие — сколько опорных точек фигуры пользователь задел;
/// * точность — сколько его точек легло в полосу фигуры;
/// * отклонение — насколько далеко линия уходит от фигуры.
///
/// Ни одной из них по отдельности не хватает. Без точности зачлась бы любая
/// мазня поверх буквы. А покрытие с точностью не чувствуют порядок точек:
/// «W» на месте чаши обходит всю фигуру и каждой своей точкой лежит рядом
/// с какой-нибудь точкой фигуры — ловится только отклонением, у которого
/// от локального выброса распухает хвост распределения.
class TracingMatcher {
  /// Допуск в долях толщины линии фигуры.
  final double toleranceFactor;

  /// Шаг дискретизации фигуры в долях толщины линии.
  final double sampleStepFactor;

  final double minCoverage;
  final double minAccuracy;

  /// Требовать, чтобы пользователь поставил все точки буквы. В покрытии они
  /// весят один сэмпл на точку, то есть сами по себе почти ни на что не
  /// влияют, — а для арабского они смыслоразличительные (ب против ت).
  final bool requireDots;

  /// Во сколько раз разрешено «дотягивать» рисунок до фигуры при свободном
  /// размещении: 0.4 — пользователь нарисовал вдвое с лишним крупнее,
  /// 3.0 — втрое мельче. За пределами диапазона выравнивание не делается.
  final double minFitScale;
  final double maxFitScale;

  /// Максимальное отклонение линии от фигуры в долях толщины линии.
  /// Работает при обводке, где важно попасть по видимому контуру.
  final double maxDeviation;

  /// Максимальное расхождение форм в режиме по памяти. Законные варианты
  /// (дрожь, перекос, вдвое уже или шире, более глубокий хвост у س)
  /// укладываются в 0.063, ближайшая неверная форма — «W» вместо чаши —
  /// начинается с 0.087.
  final double maxShapeError;

  /// Какой перцентиль отклонений брать. Не максимум — иначе одна
  /// дёрнувшаяся точка забракует верную букву.
  final double deviationPercentile;

  /// Какую долю размера уже собранной части группе точек разрешено съехать
  /// от идеального места. Больше этого — уже другая позиция буквы, а не
  /// неточность руки.
  final double maxDotShiftFactor;

  /// В каких пределах группе точек разрешено отличаться размером от эталона.
  final double minDotScale;
  final double maxDotScale;

  /// Ниже этой точности штрих считается промахом и не накапливается:
  /// он явно нарисован не по этой части фигуры.
  final double keepAccuracy;

  const TracingMatcher({
    this.toleranceFactor = 0.75,
    this.sampleStepFactor = 0.25,
    this.minCoverage = 0.85,
    this.minAccuracy = 0.8,
    this.requireDots = true,
    this.minFitScale = 0.4,
    this.maxFitScale = 3.0,
    this.maxDeviation = 0.65,
    this.deviationPercentile = 0.9,
    this.maxShapeError = 0.08,
    this.maxDotShiftFactor = 0.35,
    this.minDotScale = 0.5,
    this.maxDotScale = 2.0,
    this.keepAccuracy = 0.5,
  });

  /// Подбирает сдвиг и масштаб, которыми нарисованное совмещается с частью
  /// фигуры. Форма при этом не меняется — значит кривая линия так и
  /// останется кривой.
  TracingAlignment align({
    required ResolvedTracingPart target,
    required List<DrawingStroke> strokes,
  }) {
    final points = [for (final stroke in strokes) ...stroke.points];
    final samples = sample(target);
    if (points.length < 2 || samples.length < 2) {
      return const TracingAlignment.identity();
    }

    return TracingAlignment.fit(
          from: _boundsOf(points),
          to: _boundsOf(samples),
          minScale: minFitScale,
          maxScale: maxFitScale,
        ) ??
        const TracingAlignment.identity();
  }

  /// Опорные точки части фигуры: линии + центры диакритических точек.
  List<Offset> sample(ResolvedTracingPart target) => [
    for (final track in tracks(target)) ...track,
  ];

  /// Опорные точки, разложенные по дорожкам: каждая линия части — своя
  /// дорожка с точками по порядку вдоль неё, каждая диакритическая точка —
  /// дорожка из одной точки.
  ///
  /// Порядок внутри дорожки — единственное, чем отличается линия от облака
  /// точек: по нему видно, где у линии начало, конец и что между ними.
  List<List<Offset>> tracks(ResolvedTracingPart target) {
    final step = math.max(1.0, target.strokeWidth * sampleStepFactor);
    final result = <List<Offset>>[];

    for (final path in target.paths) {
      for (final metric in path.computeMetrics()) {
        final track = <Offset>[];
        for (var distance = 0.0; distance < metric.length; distance += step) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) track.add(tangent.position);
        }
        final tail = metric.getTangentForOffset(metric.length);
        if (tail != null) track.add(tail.position);
        if (track.isNotEmpty) result.add(track);
      }
    }

    for (final dot in target.dots) {
      result.add([dot]);
    }

    return result;
  }

  /// Подбирает сдвиг и равномерный масштаб для группы точек: их проверяют по
  /// взаимному расположению, а не по попаданию в пиксель. Треугольник ش,
  /// нарисованный крупнее или мельче эталонного, — та же буква.
  ///
  /// Поворот не подбираем намеренно: перевёрнутый треугольник (одна точка
  /// снизу, две сверху) — это уже другая расстановка, а не наклон руки.
  ///
  /// Возвращает identity, если количество точек не совпало, группа уехала
  /// слишком далеко или отличается размером в разы.
  /// [reference] — габариты того, что уже собрано: относительно него и
  /// меряется допустимый сдвиг. Без него мерка одна — перо.
  TracingAlignment alignDots({
    required ResolvedTracingPart target,
    required List<DrawingStroke> strokes,
    double? penWidth,
    Rect? reference,
  }) {
    if (target.paths.isNotEmpty) return const TracingAlignment.identity();
    if (strokes.length != target.dots.length) {
      return const TracingAlignment.identity();
    }

    final points = [for (final stroke in strokes) ...stroke.points];
    if (points.isEmpty || target.dots.isEmpty) {
      return const TracingAlignment.identity();
    }

    final from = _centroid(points);
    final to = _centroid(target.dots);

    final limit = reference == null
        ? math.max(target.strokeWidth, penWidth ?? 0) * 3
        : reference.shortestSide * maxDotShiftFactor;

    if ((to - from).distance > limit) {
      return const TracingAlignment.identity();
    }

    // Масштаб — отношение разбросов вокруг центров. Оно не зависит от того,
    // какая точка какой соответствует, поэтому перебирать пары не нужно.
    final spreadFrom = _spread(points, from);
    final spreadTo = _spread(target.dots, to);

    var scale = 1.0;
    if (spreadFrom > 0 && spreadTo > 0) {
      scale = spreadTo / spreadFrom;
      if (scale < minDotScale || scale > maxDotScale) {
        return const TracingAlignment.identity();
      }
    }

    return TracingAlignment(scale: scale, inputCenter: from, targetCenter: to);
  }

  /// [penWidth] — толщина, которой рисует пользователь. Допуски считаются от
  /// большей из двух толщин: если перо толще линии буквы, центр штриха может
  /// законно отойти на половину пера и всё равно полностью накрывать букву.
  ///
  /// [structural] — сверять форму, а не место. При обводке важно попасть по
  /// видимому контуру, поэтому там мерка позиционная. По памяти человек пишет
  /// где хочет и каких угодно пропорций, и единственное осмысленное — та же
  /// ли это форма.
  TracingMatchResult match({
    required ResolvedTracingPart target,
    required List<DrawingStroke> strokes,
    TracingAlignment alignment = const TracingAlignment.identity(),
    double? penWidth,
    bool structural = false,
  }) {
    final samples = sample(target);
    final points = [
      for (final stroke in alignment.applyTo(strokes)) ...stroke.points,
    ];
    if (samples.isEmpty) {
      return const TracingMatchResult.empty(TracingMatchStatus.noShape);
    }
    if (points.isEmpty) {
      return const TracingMatchResult.empty(TracingMatchStatus.noInput);
    }

    final band = _bandFor(target, penWidth);
    final tolerance = band * toleranceFactor;
    final toleranceSq = tolerance * tolerance;

    var covered = 0;
    for (final sample in samples) {
      if (_nearestDistanceSq(sample, points) <= toleranceSq) covered++;
    }

    var accurate = 0;
    final deviations = <double>[];
    for (final point in points) {
      final distanceSq = _nearestDistanceSq(point, samples);
      if (distanceSq <= toleranceSq) accurate++;
      deviations.add(math.sqrt(distanceSq) / band);
    }
    deviations.sort();
    final deviation =
        deviations[((deviations.length - 1) * deviationPercentile).round()];

    // Допуск на попадание в точку зажат расстоянием до соседней целиком,
    // вместе с радиусом: иначе сумма перекроет соседнюю точку, и
    // перевёрнутый треугольник зачтётся как правильный.
    var dotTolerance = target.dotRadius + tolerance;
    final dotSpacing = _minSpacing(target.dots);
    if (dotSpacing.isFinite) {
      dotTolerance = math.min(dotTolerance, dotSpacing * 0.45);
    }
    final dotToleranceSq = dotTolerance * dotTolerance;
    final dotsTraced = target.dots.every(
      (dot) => _nearestDistanceSq(dot, points) <= dotToleranceSq,
    );

    final coverage = covered / samples.length;
    final accuracy = accurate / points.length;

    // Для частей без линий (одни точки) отклонение не считаем: там всё уже
    // решает dotsTraced, а радиус точки заметно меньше допуска по линии.
    final shapeHolds = target.paths.isEmpty || deviation <= maxDeviation;

    // Количество точек — смыслоразличительное: ب, ت и ث отличаются только им.
    final countHolds =
        target.paths.isNotEmpty || strokes.length == target.dots.length;

    final shapeError = structural && target.paths.isNotEmpty
        ? _shapeErrorOf(target, strokes)
        : double.infinity;

    final bool holds;
    if (target.paths.isEmpty) {
      // Части из точек: количество и взаимное расположение. Неточность руки
      // уже поглощена общей подгонкой группы в alignDots.
      holds =
          countHolds &&
          (dotsTraced || !requireDots) &&
          (structural || (coverage >= minCoverage && accuracy >= minAccuracy));
    } else if (structural) {
      // Форма и только форма — но не любого размера: буква впятеро мельче
      // эталона это каракуля, а не «другие пропорции».
      holds = shapeError <= maxShapeError && _sizeIsSane(target, points);
    } else {
      holds =
          coverage >= minCoverage &&
          accuracy >= minAccuracy &&
          shapeHolds &&
          (dotsTraced || !requireDots);
    }

    return TracingMatchResult(
      coverage: coverage,
      accuracy: accuracy,
      deviation: deviation,
      shapeError: shapeError,
      dotsTraced: dotsTraced,
      isMatch: holds,
    );
  }

  /// Проецирует штрихи на фигуру: штрих ложится на кусок линии между своими
  /// концами, толщина становится толщиной фигуры. Результат — то, во что
  /// штрихи «вливаются» при слиянии.
  List<DrawingStroke> project({
    required ResolvedTracingPart target,
    required List<DrawingStroke> strokes,
    TracingAlignment alignment = const TracingAlignment.identity(),
  }) {
    final tracks = this.tracks(target);
    if (tracks.isEmpty) return strokes;

    return [
      for (final stroke in alignment.applyTo(strokes))
        DrawingStroke(
          points: _projectOnTrack(
            stroke.points,
            _bestTrack(stroke.points, tracks),
          ),
          color: stroke.color,
          width: target.strokeWidth,
        ),
    ];
  }

  /// Дорожка, по которой штрих шёл: та, к которой он в сумме ближе всех.
  static List<Offset> _bestTrack(
    List<Offset> points,
    List<List<Offset>> tracks,
  ) {
    if (tracks.length == 1) return tracks.first;

    var best = tracks.first;
    var bestCost = double.infinity;
    for (final track in tracks) {
      var cost = 0.0;
      for (final point in points) {
        cost += _nearestDistanceSq(point, track);
      }
      if (cost < bestCost) {
        bestCost = cost;
        best = track;
      }
    }
    return best;
  }

  /// Растягивает штрих по куску дорожки между его концами.
  ///
  /// Каждую точку по отдельности в ближайшую опорную двигать нельзя:
  /// ближайшая точка не монотонна вдоль линии, и на острых зубцах (س, ش)
  /// середина штриха перескакивает через вершину на соседнюю ветку и
  /// возвращается обратно. Сплайн затягивает такой скачок хордой — поперёк
  /// зубца появляется прямая перемычка. Кусок дорожки же по построению
  /// повторяет саму линию буквы и изломов дать не может.
  static List<Offset> _projectOnTrack(List<Offset> points, List<Offset> track) {
    if (points.isEmpty) return points;
    if (track.length == 1) {
      return [for (var i = 0; i < points.length; i++) track.first];
    }

    // Концы штриха — самое надёжное, что в нём есть: середину неоднозначно
    // тянет к соседним веткам, а начало и конец лежат там, где человек
    // поставил и оторвал палец.
    final from = _nearestIndex(points.first, track);
    final to = _nearestIndex(points.last, track);
    if (from == to || points.length == 1) {
      return [for (var i = 0; i < points.length; i++) track[from]];
    }

    final span = (to - from).toDouble();
    final last = points.length - 1;

    return [
      for (var i = 0; i <= last; i++) _pointAt(track, from + span * i / last),
    ];
  }

  /// Точка дорожки по дробному индексу — между соседними опорными.
  static Offset _pointAt(List<Offset> track, double index) {
    final low = index.floor().clamp(0, track.length - 1);
    final high = math.min(low + 1, track.length - 1);
    return Offset.lerp(track[low], track[high], index - low) ?? track[low];
  }

  static int _nearestIndex(Offset point, List<Offset> track) {
    var best = 0;
    var bestDistanceSq = double.infinity;
    for (var i = 0; i < track.length; i++) {
      final dx = point.dx - track[i].dx;
      final dy = point.dy - track[i].dy;
      final distanceSq = dx * dx + dy * dy;
      if (distanceSq < bestDistanceSq) {
        bestDistanceSq = distanceSq;
        best = i;
      }
    }
    return best;
  }

  /// Размер нарисованного соизмерим с эталоном. Границы те же, что у
  /// свободного размещения: во сколько раз разрешено «дотягивать» рисунок
  /// до фигуры, во столько же он может от неё отличаться.
  bool _sizeIsSane(ResolvedTracingPart target, List<Offset> points) {
    final input = _boundsOf(points).longestSide;
    final reference = target.bounds.longestSide;
    if (input <= 0 || reference <= 0) return false;

    final fit = reference / input;
    return fit >= minFitScale && fit <= maxFitScale;
  }

  /// Расхождение формы с эталоном части.
  ///
  /// Штрихи склеиваются в одну линию: если частей несколько, перебираем
  /// порядок — человек мог нарисовать сначала правую половину, потом левую.
  double _shapeErrorOf(
    ResolvedTracingPart target,
    List<DrawingStroke> strokes,
  ) {
    final templates = target.signatures;
    if (templates.isEmpty) return double.infinity;

    // Штрихи — отдельные линии: между ними человек отрывал перо, и вести
    // сигнатуру через отрыв так же нельзя, как через разрыв в эталоне.
    // Способы провести часть перебирает эталон, здесь остаётся порядок,
    // в котором штрихи легли на холст.
    final uniform = templates.first.uniform;
    var best = double.infinity;
    for (final order in _orders(strokes)) {
      final signature = StrokeSignature.ofPolylines([
        for (final stroke in order) stroke.points,
      ], uniform: uniform);
      if (signature == null) continue;
      for (final template in templates) {
        best = math.min(best, signature.distanceTo(template));
      }
    }
    return best;
  }

  /// Порядки, в которых могли нарисовать штрихи. Перебираем только для двух
  /// и трёх: дальше перебор дороже пользы, а таких частей и не бывает.
  static List<List<DrawingStroke>> _orders(List<DrawingStroke> strokes) {
    switch (strokes.length) {
      case 0:
      case 1:
        return [strokes];
      case 2:
        return [strokes, strokes.reversed.toList()];
      case 3:
        final a = strokes[0], b = strokes[1], c = strokes[2];
        return [
          [a, b, c],
          [a, c, b],
          [b, a, c],
          [b, c, a],
          [c, a, b],
          [c, b, a],
        ];
      default:
        return [strokes];
    }
  }

  /// Допуск для части. Неточность руки при постановке точек поглощает общий
  /// сдвиг группы в [alignDots], поэтому здесь допуск не раздуваем — но и
  /// не даём ему дотянуться до соседней точки: иначе одним тапом закрывались
  /// бы обе, и ت стало бы неотличимо от ب.
  double _bandFor(ResolvedTracingPart target, double? penWidth) {
    final band = math.max(target.strokeWidth, penWidth ?? 0);
    if (target.paths.isNotEmpty) return band;

    final spacing = _minSpacing(target.dots);
    if (!spacing.isFinite) return band;

    return math.min(band, spacing * 0.45 / toleranceFactor);
  }

  static double _minSpacing(List<Offset> dots) {
    var best = double.infinity;
    for (var i = 0; i < dots.length; i++) {
      for (var j = i + 1; j < dots.length; j++) {
        final distance = (dots[i] - dots[j]).distance;
        if (distance < best) best = distance;
      }
    }
    return best;
  }

  /// Среднеквадратичный разброс точек вокруг центра.
  static double _spread(List<Offset> points, Offset center) {
    if (points.length < 2) return 0;
    var sum = 0.0;
    for (final point in points) {
      final delta = point - center;
      sum += delta.dx * delta.dx + delta.dy * delta.dy;
    }
    return math.sqrt(sum / points.length);
  }

  static Offset _centroid(List<Offset> points) {
    var sum = Offset.zero;
    for (final point in points) {
      sum += point;
    }
    return sum / points.length.toDouble();
  }

  static Rect _boundsOf(List<Offset> points) {
    var left = points.first.dx;
    var top = points.first.dy;
    var right = left;
    var bottom = top;
    for (final point in points) {
      if (point.dx < left) left = point.dx;
      if (point.dx > right) right = point.dx;
      if (point.dy < top) top = point.dy;
      if (point.dy > bottom) bottom = point.dy;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static double _nearestDistanceSq(Offset point, List<Offset> candidates) {
    var best = double.infinity;
    for (final candidate in candidates) {
      final dx = point.dx - candidate.dx;
      final dy = point.dy - candidate.dy;
      final distanceSq = dx * dx + dy * dy;
      if (distanceSq < best) best = distanceSq;
    }
    return best;
  }
}
