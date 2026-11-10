class ApiMessage {
  List<Messages>? messages;

  ApiMessage({this.messages});

  ApiMessage.fromJson(dynamic json) {
    final list = json is Map ? json['messages'] : null;
    if (list is List) {
      messages = [for (final item in list) Messages.fromJson(item)];
    }
  }
}

class Messages {
  String? id;
  String? message;

  Messages({this.id, this.message});

  Messages.fromJson(dynamic json) {
    if (json is! Map) return;
    final rawId = json['id'];
    final rawMessage = json['message'];
    id = rawId is String ? rawId : null;
    message = rawMessage is String ? rawMessage : null;
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['message'] = message;
    return map;
  }
}
