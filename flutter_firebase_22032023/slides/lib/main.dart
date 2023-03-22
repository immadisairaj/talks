import 'package:flutter/material.dart';
import 'package:prides/prides.dart';
import 'package:slides/content/about_me.dart';
import 'package:slides/content/background_widget.dart';
import 'package:slides/content/title_content.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase',
      theme: ThemeData(
        primarySwatch: Colors.yellow,
      ),
      debugShowCheckedModeBanner: false,
      home: Material(
        child: PresentationWidget(
          background: const BackgroundWidget(),
          slides: [
            const TitleSlide.fromText(
              title: 'Flutter + Firebase',
              subtitle: 'Getting started with Firebase for Flutter',
            ),
            const AboutMe(),
            TitleContent(
              slideController: SlideController(),
              title: 'Agenda',
              points: const [
                'What is Firebase?',
                'Movie Recommender (App)',
                'Configure Firebase to Flutter',
                'Authentication',
                'Database (Firestore)',
                'Final Application',
              ],
            ),
            TitleContent(
              slideController: SlideController(),
              title: 'Firebase',
              points: const [
                'It is a platform that helps in building applications',
                'It is a set of backend cloud computing services',
                'It is a Backend-as-a-Service (BaaS)',
                'Provides hosted backend services such as Database, Cloud Storage, Authentication, etc.',
              ],
            ),
            TitleContent(
              slideController: SlideController(),
              title: 'Movie Recommender',
              points: const [
                'Group of friends',
                'Movie enthusiasts',
                'Good recommendations',
              ],
              imagePath: 'assets/app_screenshot.png',
            ),
            const SectionHeader.fromText(title: 'FlutterFire configure (live)'),
            const SectionHeader.fromText(title: 'Email Authentication (live)'),
            TitleContent(
              slideController: SlideController(),
              title: 'Database (Cloud Firestore)',
              points: const [
                'Flexible, scaled database for mobile, web and server development',
                'Realtime updates',
                'Supports offline support for mobile and web',
                'To build responsive apps that work regardless of network latency',
                'Store data in documents organized into collections',
              ],
            ),
            const SectionHeader.fromText(title: 'Using Firestore (live)'),
            TitleContent(
              slideController: SlideController(),
              title: 'Key Takeaways',
              points: const [
                'Firebase',
                'Configure Firebase into Flutter',
                'Authentication',
                'Cloud Firestore',
                'Movie Recommender Application',
              ],
            ),
            const SimpleSlide(slide: ThankYou()),
          ],
        ),
      ),
    );
  }
}

class ThankYou extends StatelessWidget {
  const ThankYou({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: MediaQuery.of(context).size.width / 10,
      bottom: MediaQuery.of(context).size.height / 3,
      child: Text(
        'Thank You',
        style: Theme.of(context)
            .textTheme
            .displayLarge!
            .copyWith(color: Colors.white),
      ),
    );
  }
}
