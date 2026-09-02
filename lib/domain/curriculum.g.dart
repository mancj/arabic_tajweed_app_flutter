// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curriculum.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Topic _$TopicFromJson(Map<String, dynamic> json) => Topic(
  id: json['id'] as String,
  stage: (json['stage'] as num).toInt(),
  title: json['title'] as String,
  requirement: Requirement.fromJson(
    json['requirement'] as Map<String, dynamic>,
  ),
  counterOf:
      (json['counterOf'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$TopicToJson(Topic instance) => <String, dynamic>{
  'id': instance.id,
  'stage': instance.stage,
  'title': instance.title,
  'requirement': _reqToJson(instance.requirement),
  'counterOf': instance.counterOf,
};

CurriculumNode _$CurriculumNodeFromJson(Map<String, dynamic> json) =>
    CurriculumNode(
      atom: Atom.fromJson(json['atom'] as Map<String, dynamic>),
      requirement: Requirement.fromJson(
        json['requirement'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$CurriculumNodeToJson(CurriculumNode instance) =>
    <String, dynamic>{
      'atom': instance.atom,
      'requirement': _reqToJson(instance.requirement),
    };

Curriculum _$CurriculumFromJson(Map<String, dynamic> json) => Curriculum(
  nodes: (json['nodes'] as List<dynamic>)
      .map((e) => CurriculumNode.fromJson(e as Map<String, dynamic>))
      .toList(),
  topics: (json['topics'] as List<dynamic>)
      .map((e) => Topic.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$CurriculumToJson(Curriculum instance) =>
    <String, dynamic>{'nodes': instance.nodes, 'topics': instance.topics};
