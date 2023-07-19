/// id : "3ho"
/// url : "https://cdn2.thecatapi.com/images/3ho.png"
/// width : 483
/// height : 322

class Cat {
  Cat({
    this.id,
    this.url,
    this.width,
    this.height,
  });

  Cat.fromJson(dynamic json) {
    id = json['id'];
    url = json['url'];
    width = json['width'];
    height = json['height'];
  }

  String? id;
  String? url;
  num? width;
  num? height;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['url'] = url;
    map['width'] = width;
    map['height'] = height;
    return map;
  }
}
