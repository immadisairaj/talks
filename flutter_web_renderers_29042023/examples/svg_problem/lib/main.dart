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
      body: Center(
        // child: SvgPicture.asset('assets/Firefox.svg'),
        child: Image.network(
            'https://storage.googleapis.com/cms-storage-bucket/4fd5520fe28ebf839174.svg'),
        // child: SvgPicture.asset(
        //   'assets/flutter_logo.svg',
        //   colorFilter:
        //       const ColorFilter.mode(Colors.blue, BlendMode.difference),
        // ),
      ),
    );
  }
}
