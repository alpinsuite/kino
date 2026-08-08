import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Who made a change.
///
/// `userId` is nullable on purpose and follows FluidPlan's convention: today
/// every reviewer is a local name typed into preferences, and there is no
/// account system to resolve. If an annotation set ever attaches to a FluidPlan
/// task, the field to fill is already there and no stored document has to be
/// migrated.
@immutable
class Actor {
  const Actor({required this.name, this.userId});

  final String name;
  final String? userId;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    if (userId != null) 'userId': userId,
  };

  static Actor fromJson(Map<String, Object?> json) => Actor(
    name: json['name'] as String? ?? '',
    userId: json['userId'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is Actor && other.name == name && other.userId == userId;

  @override
  int get hashCode => Object.hash(name, userId);
}

/// The colour of a category, named rather than valued.
///
/// A stored `0xFFE04A3F` is a colour that will be wrong in the other theme and
/// unthemeable forever after. The sidecar names a role and the interface
/// resolves it against the Slate palette, which is also what lets this library
/// stay free of `dart:ui`.
enum AnnotationColor { neutral, red, amber, green, blue, violet }

/// A user-defined bucket — "defect", "query", "sign-off".
@immutable
class AnnotationCategory {
  const AnnotationCategory({
    required this.id,
    required this.label,
    this.color = AnnotationColor.neutral,
  });

  final String id;
  final String label;
  final AnnotationColor color;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'color': color.name,
  };

  static AnnotationCategory fromJson(Map<String, Object?> json) =>
      AnnotationCategory(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        color: AnnotationColor.values.firstWhere(
          (value) => value.name == json['color'],
          orElse: () => AnnotationColor.neutral,
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is AnnotationCategory &&
      other.id == id &&
      other.label == label &&
      other.color == color;

  @override
  int get hashCode => Object.hash(id, label, color);
}

enum ShapeKind { arrow, rectangle, ellipse, freehand }

/// A point in frame space, normalised to 0..1 on both axes.
///
/// Normalised because the drawing has to land in the same place when the window
/// is resized, when the video is scaled, and in a PDF export at whatever size
/// that page happens to be.
@immutable
class ShapePoint {
  const ShapePoint(this.x, this.y);

  final double x;
  final double y;

  List<double> toJson() => <double>[x, y];

  static ShapePoint fromJson(List<Object?> json) =>
      ShapePoint((json[0] as num).toDouble(), (json[1] as num).toDouble());

  @override
  bool operator ==(Object other) =>
      other is ShapePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// A mark drawn over one frame, stored as vectors.
///
/// Never baked into a raster: the still is composited at export time, so the
/// drawing stays editable and a re-export at a different size stays sharp.
@immutable
class DrawingShape {
  const DrawingShape({
    required this.id,
    required this.kind,
    required this.points,
    this.color = AnnotationColor.red,
    this.strokeWidth = 0.004,
  });

  final String id;
  final ShapeKind kind;

  /// Two points for [ShapeKind.arrow], [ShapeKind.rectangle] and
  /// [ShapeKind.ellipse] — start and end of the defining diagonal. A polyline
  /// for [ShapeKind.freehand].
  final List<ShapePoint> points;

  final AnnotationColor color;

  /// Stroke width as a fraction of the frame's *width*, so it scales with the
  /// picture rather than with the window.
  final double strokeWidth;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    'points': points.map((point) => point.toJson()).toList(),
    'color': color.name,
    'strokeWidth': strokeWidth,
  };

  static DrawingShape fromJson(Map<String, Object?> json) => DrawingShape(
    id: json['id'] as String,
    kind: ShapeKind.values.firstWhere(
      (value) => value.name == json['kind'],
      orElse: () => ShapeKind.freehand,
    ),
    points: (json['points'] as List<Object?>)
        .map((point) => ShapePoint.fromJson(point as List<Object?>))
        .toList(growable: false),
    color: AnnotationColor.values.firstWhere(
      (value) => value.name == json['color'],
      orElse: () => AnnotationColor.red,
    ),
    strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 0.004,
  );

  @override
  bool operator ==(Object other) =>
      other is DrawingShape &&
      other.id == id &&
      other.kind == kind &&
      other.color == color &&
      other.strokeWidth == strokeWidth &&
      const ListEquality<ShapePoint>().equals(other.points, points);

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    color,
    strokeWidth,
    const ListEquality<ShapePoint>().hash(points),
  );
}

/// A note attached to one frame.
@immutable
class Annotation {
  const Annotation({
    required this.id,
    required this.frame,
    required this.note,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.shapes = const <DrawingShape>[],
  });

  final String id;

  /// The frame this note is about — an index, not a time. See the library
  /// documentation for why.
  final int frame;

  final String note;
  final Actor author;

  /// References an [AnnotationCategory.id] in the same document, or null for
  /// uncategorised. A dangling id renders as uncategorised rather than failing
  /// to load: a merged import must never lose someone's note.
  final String? categoryId;

  final List<DrawingShape> shapes;

  /// Both are UTC. Local times in a file that two people exchange are a bug.
  final DateTime createdAt;
  final DateTime updatedAt;

  Annotation copyWith({
    int? frame,
    String? note,
    String? categoryId,
    List<DrawingShape>? shapes,
    required DateTime updatedAt,
  }) => Annotation(
    id: id,
    frame: frame ?? this.frame,
    note: note ?? this.note,
    author: author,
    categoryId: categoryId ?? this.categoryId,
    shapes: shapes ?? this.shapes,
    createdAt: createdAt,
    updatedAt: updatedAt.toUtc(),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'frame': frame,
    'note': note,
    'author': author.toJson(),
    if (categoryId != null) 'categoryId': categoryId,
    if (shapes.isNotEmpty)
      'shapes': shapes.map((shape) => shape.toJson()).toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static Annotation fromJson(Map<String, Object?> json) {
    final created = DateTime.parse(json['createdAt'] as String).toUtc();
    return Annotation(
      id: json['id'] as String,
      frame: (json['frame'] as num).toInt(),
      note: json['note'] as String? ?? '',
      author: Actor.fromJson(
        json['author'] as Map<String, Object?>? ?? const {},
      ),
      categoryId: json['categoryId'] as String?,
      shapes: (json['shapes'] as List<Object?>? ?? const <Object?>[])
          .map((shape) => DrawingShape.fromJson(shape as Map<String, Object?>))
          .toList(growable: false),
      createdAt: created,
      updatedAt: json['updatedAt'] == null
          ? created
          : DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Annotation &&
      other.id == id &&
      other.frame == frame &&
      other.note == note &&
      other.author == author &&
      other.categoryId == categoryId &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      const ListEquality<DrawingShape>().equals(other.shapes, shapes);

  @override
  int get hashCode => Object.hash(
    id,
    frame,
    note,
    author,
    categoryId,
    createdAt,
    updatedAt,
    const ListEquality<DrawingShape>().hash(shapes),
  );
}
