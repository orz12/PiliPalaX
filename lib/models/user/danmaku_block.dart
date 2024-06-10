class DanmakuBlockDataModel {
  List<Rule>? rule;
  String? toast;
  int? valid;
  int? ver;

  DanmakuBlockDataModel({this.rule, this.toast, this.valid, this.ver});

  DanmakuBlockDataModel.fromJson(Map<String, dynamic> json) {
    if (json['rule'] != null) {
      rule = <Rule>[];
      json['rule'].forEach((v) {
        rule!.add(Rule.fromJson(v));
      });
    }
    toast = json['toast'];
    valid = json['valid'];
    ver = json['ver'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (rule != null) {
      data['rule'] = rule!.map((v) => v.toJson()).toList();
    }
    data['toast'] = toast;
    data['valid'] = valid;
    data['ver'] = ver;
    return data;
  }
}

class Rule {
  int? id;
  int? mid;
  int? type;
  String? filter;
  String? comment;
  int? ctime;
  int? mtime;

  Rule(
      {this.id,
      this.mid,
      this.type,
      this.filter,
      this.comment,
      this.ctime,
      this.mtime});

  Rule.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    mid = json['mid'];
    type = json['type'];
    filter = json['filter'];
    comment = json['comment'];
    ctime = json['ctime'];
    mtime = json['mtime'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['mid'] = mid;
    data['type'] = type;
    data['filter'] = filter;
    data['comment'] = comment;
    data['ctime'] = ctime;
    data['mtime'] = mtime;
    return data;
  }
}

class SimpleRule {
  final int id;
  final int type;
  String filter;
  SimpleRule(this.id, this.type, this.filter);
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'filter': filter,
    };
  }

  factory SimpleRule.fromMap(Map<String, dynamic> map) {
    return SimpleRule(
      map['id'],
      map['type'],
      map['filter'],
    );
  }
}
