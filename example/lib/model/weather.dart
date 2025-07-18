class Weather {
  Weather({
    this.latitude,
    this.longitude,
    this.generationtimeMs,
    this.utcOffsetSeconds,
    this.timezone,
    this.timezoneAbbreviation,
    this.elevation,
    this.currentWeather,
  });

  num? latitude;
  num? longitude;
  num? generationtimeMs;
  num? utcOffsetSeconds;
  String? timezone;
  String? timezoneAbbreviation;
  num? elevation;
  CurrentWeather? currentWeather;

  factory Weather.fromJson(dynamic json) {
    return Weather(
      latitude: json['latitude'],
      longitude: json['longitude'],
      generationtimeMs: json['generationtime_ms'],
      utcOffsetSeconds: json['utc_offset_seconds'],
      timezone: json['timezone'],
      timezoneAbbreviation: json['timezone_abbreviation'],
      elevation: json['elevation'],
      currentWeather: json['current_weather'] != null
          ? CurrentWeather.fromJson(json['current_weather'])
          : null,
    );
  }

  static Future<Weather> fromJsonAsync(dynamic json) async {
    await Future.delayed(const Duration(seconds: 3));
    return Weather(
      latitude: json['latitude'],
      longitude: json['longitude'],
      generationtimeMs: json['generationtime_ms'],
      utcOffsetSeconds: json['utc_offset_seconds'],
      timezone: json['timezone'],
      timezoneAbbreviation: json['timezone_abbreviation'],
      elevation: json['elevation'],
      currentWeather: json['current_weather'] != null
          ? CurrentWeather.fromJson(json['current_weather'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['latitude'] = latitude;
    map['longitude'] = longitude;
    map['generationtime_ms'] = generationtimeMs;
    map['utc_offset_seconds'] = utcOffsetSeconds;
    map['timezone'] = timezone;
    map['timezone_abbreviation'] = timezoneAbbreviation;
    map['elevation'] = elevation;
    if (currentWeather != null) {
      map['current_weather'] = currentWeather?.toJson();
    }

    return map;
  }
}

/// temperature : 14.9
/// windspeed : 10.5
/// winddirection : 262.0
/// weathercode : 0
/// is_day : 0
/// time : "2023-07-18T01:00"

class CurrentWeather {
  CurrentWeather({
    this.temperature,
    this.windspeed,
    this.winddirection,
    this.weathercode,
    this.isDay,
    this.time,
  });

  num? temperature;
  num? windspeed;
  num? winddirection;
  num? weathercode;
  num? isDay;
  String? time;

  factory CurrentWeather.fromJson(dynamic json) {
    return CurrentWeather(
      temperature: json['temperature'],
      windspeed: json['windspeed'],
      winddirection: json['winddirection'],
      weathercode: json['weathercode'],
      isDay: json['is_day'],
      time: json['time'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['temperature'] = temperature;
    map['windspeed'] = windspeed;
    map['winddirection'] = winddirection;
    map['weathercode'] = weathercode;
    map['is_day'] = isDay;
    map['time'] = time;

    return map;
  }
}
