import 'package:playx_network/src/models/exceptions/message/exception_message.dart';

class DefaultArabicExceptionMessage extends ExceptionMessage {
  @override
  String get languageCode => 'ar';

  @override
  String get badRequest => "عذرًا ، الطلب غير صالح أو تم صياغته بشكل غير صحيح.";

  @override
  String get conflict => "عذرًا ، لم يكتمل الطلب بسبب وجود تعارض.";

  @override
  String get defaultError => "عذرا، هناك خطأ ما.";

  @override
  String get emptyResponse => "عذرا ، لا يمكن تلقي استجابة من الخادم.";

  @override
  String get formatException => "عذرًا ، الطلب لم يتم تنسيقه بشكل صحيح.";

  @override
  String get internalServerError => "عذرا ، هناك خطأ داخلي في الخادم";

  @override
  String get noInternetConnection => "عذرا ، لا يوجد اتصال بالإنترنت.";

  @override
  String get notAcceptable => "عذرا ، الطلب غير مقبول.";

  @override
  String get notFound => "عذرًا ، تعذر العثور على المورد المطلوب.";

  @override
  String get requestCancelled => "عذرا ، تم إلغاء الطلب.";

  @override
  String get requestTimeout => "عذرا ، لقد انقضت مهلة الطلب.";

  @override
  String get sendTimeout => "عذرًا ، لقد انقضت مهلة إرسال الطلب.";

  @override
  String get serviceUnavailable => "عذرا ، الخدمة غير متوفرة حالياً.";

  @override
  String get unableToProcess => "عذرا ، لا يمكن معالجة البيانات.";

  @override
  String get unauthorizedRequest => "عذرا ، الطلب غير مصرح به.";

  @override
  String get unexpectedError => "عذرا، هناك خطأ ما.";
}
