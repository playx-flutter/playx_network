class Weight {
  String? imperial;
  String? metric;

  Weight({this.imperial, this.metric});

  Weight.fromJson(dynamic json) {
    imperial = json['imperial'];
    metric = json['metric'];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['imperial'] = imperial;
    map['metric'] = metric;
    return map;
  }
}
