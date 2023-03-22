import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';
import '../modals/movie.dart';
import 'add_edit.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the current signed in user to show hello message
    final user = FirebaseAuth.instance.currentUser;
    // query for movies stored
    final userQuery =
        FirebaseFirestore.instance.collection('movies').withConverter<Movie>(
              fromFirestore: (snapshot, _) => Movie.fromJson(snapshot.data()!),
              toFirestore: (movie, _) => movie.toJson(),
            );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie Recomender'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<ProfileScreen>(
                  builder: (context) => ProfileScreen(
                    actions: [
                      // pop the profile screen on signout
                      SignedOutAction((context) => Navigator.maybePop(context))
                    ],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_outline),
            tooltip: 'Show Profile',
          ),
          IconButton(
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout_outlined),
            tooltip: "Signout",
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                'Hello ${user!.displayName ?? user.email}!',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FirestoreListView<Movie>(
              primary: false,
              shrinkWrap: true,
              // order by descending order of time (added or updated)
              query: userQuery.orderBy('timestamp', descending: true),
              loadingBuilder: (context) => const CircularProgressIndicator(),
              itemBuilder: (conetext, snapshot) {
                Movie movie = snapshot.data();

                return Card(
                  child: ListTile(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        // edit a movie and to update or delete it
                        builder: (context) => AddEdit(movie: movie),
                      ));
                    },
                    title: Text(movie.title),
                    // show subtitle only if it is available
                    subtitle:
                        (movie.description != null && movie.description != '')
                            ? Text(
                                movie.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add_outlined),
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            // add a new movie
            builder: (context) => const AddEdit(),
          ));
        },
      ),
    );
  }
}
