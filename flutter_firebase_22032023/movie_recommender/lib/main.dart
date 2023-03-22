import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // initialize the firebase app
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // configure what all auth providers we are providing
  FirebaseUIAuth.configureProviders([
    EmailAuthProvider(),
    // TODO: add more providers like Google, Apple, etc.
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Recommender',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      // Firebase Auth changes is being red by this stream builder
      // If, the user is not signed in, show the SignIn screen
      // If user is signed in, show the home page
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SignInScreen();
          }
          return const Home();
        },
      ),
    );
  }
}
