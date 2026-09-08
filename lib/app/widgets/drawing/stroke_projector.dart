import 'dart:math' as math;
import 'dart:ui';

import 'drawing_stroke.dart';
import 'tracing_matcher.dart';

/// Укладывает нарисованные штрихи на линии фигуры — то, во что они
/// «вливаются» при слиянии после зачёта. Это картинка, а не проверка:
/// матчер решает, совпало ли, а сюда попадают уже засчитанные штрихи.
///
/// [tracks] — опорные точки фигуры по дорожкам, как их отдаёт
/// [TracingMatcher.tracks]: каждая линия части — своя дорожка с точками
/// по порядку вдоль неё.
class StrokeProjector {
  const StrokeProjector(this.tracks);

  final List<List<Offset>> tracks;

  /// Каждый штрих ложится на кусок своей дорожки между своими концами,
  /// толщина становится [strokeWidth] — толщиной фигуры.
  List<DrawingStroke> project(
    List<DrawingStroke> strokes, {
    TracingAlignment alignment = const TracingAlignment.identity(),
    required double strokeWidth,
  }) {
    if (tracks.isEmpty) return strokes;
    return [
      for (final stroke in alignment.applyTo(strokes))
        DrawingStroke(
          points: _projectOnTrack(
            stroke.points,
            _bestTrack(stroke.points, tracks),
          ),
          color: stroke.color,
          width: strokeWidth,
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
