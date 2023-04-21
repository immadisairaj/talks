import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: const [
          Text('This is center aligned'),
          Align(
            alignment: Alignment.topLeft,
            child: Text('This is left aligned'),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Text('This is right aligned'),
          ),
          Padding(
            padding: EdgeInsets.only(left: 10),
            child: Text('This is center +10 aligned'),
          ),
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: Text('This is center -10 aligned'),
          ),
        ],
      ),
    );
  }
}
