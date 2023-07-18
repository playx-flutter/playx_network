import 'package:flutter/material.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network_example/model/Weather.dart';
import 'package:playx_network_example/model/exception/custom_exception_message.dart';

import 'model/Cat.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, });


  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

const String _baseUrl = 'https://api.open-meteo.com/v1/';
const String _forecastEndpoint = 'forecast';
const String _catsUrl = 'https://api.thecatapi.com/v1/images/search';

class _MyHomePageState extends State<MyHomePage> {
  String _weatherMsg = '';
  List<Cat> _cats =[];

  bool _isLoading = false;

  //you should create only one instance of this network client to be used for the app depending on your use case.
  late PlayxNetworkClient _client;

  @override
  void initState() {
    _client = PlayxNetworkClient(
      // customize your dio options.
      dio: Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
        ),
      ),
      //if you want to attach a token to the client.
      token: '',
      //attach logger to the client to print ongoing requests works only on debug mode.
      attachLoggerOnDebug: true,
      logSettings: const LoggerSettings(
        responseBody: true,
      ),
      //converts json to error message.
      errorMapper: (json) {
        if (json.containsKey('message')) {
          return json['message'];
        }
        return null;
      },
      shouldShowApiErrors: true,
      //creates custom exception messages to be displayed when error is received.
      exceptionMessages: const CustomExceptionMessage(),
    );
    super.initState();

    getWeatherFromApi();
    getCatsFromApi();

  }

  Future<void> getWeatherFromApi() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _client.get<Weather>(_forecastEndpoint,
        query: {
          'latitude': '30.04',
          'longitude': '31.23',
          'current_weather': 'true',
        },
        fromJson: Weather.fromJson);

    result.when(success: (weather) {
      setState(() {
        _isLoading = false;
        _weatherMsg = "${weather.currentWeather?.temperature ?? 0} C";
      });
    }, error: (error) {
      //handle error here
      _weatherMsg = "Error is : ${error.message}";
      setState(() {
        _isLoading = false;
      });
    });
  }


  Future<void> getCatsFromApi() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _client.getList(_catsUrl,
        query: {
          'limit': '10',
        },
        fromJson: Cat.fromJson);

    result.when(success: (cats) {
      setState(() {
        _isLoading = false;
        _cats = cats;
      });
    }, error: (error) {
      //handle error here
      _weatherMsg = "Error is : ${error.message}";
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Playx Network'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'Current Weather is :',
                    ),
                  ),
                  Text(
                    _weatherMsg,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Expanded(
                      child: ListView.builder(
                          itemCount: _cats.length,
                          itemBuilder: (context, index) {
                    return SizedBox(
                      height: 200,
                      child: Image.network(_cats[index].url ??'', fit: BoxFit.cover,),
                    );
                  }))
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          getWeatherFromApi();
          getCatsFromApi();

        },
        tooltip: 'Weather',
        child: const Icon(Icons.refresh),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
