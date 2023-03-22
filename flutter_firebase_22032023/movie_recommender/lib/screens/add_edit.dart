import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../modals/movie.dart';

class AddEdit extends StatefulWidget {
  const AddEdit({super.key, this.movie});

  final Movie? movie;

  // a getter to know if to add or edit (isNew when true means adding a movie)
  bool get isNew => movie == null;

  @override
  State<AddEdit> createState() => _AddEditState();
}

class _AddEditState extends State<AddEdit> {
  late TextEditingController movieNameController;
  late TextEditingController movieDescriptionController;

  late bool isEnabledEdit;

  late GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Get the current signed in user to add uid to the document
  final user = FirebaseAuth.instance.currentUser;
  // query for movies to store or edit
  final userQuery =
      FirebaseFirestore.instance.collection('movies').withConverter<Movie>(
            fromFirestore: (snapshot, _) => Movie.fromJson(snapshot.data()!),
            toFirestore: (movie, _) => movie.toJson(),
          );

  @override
  void initState() {
    super.initState();

    // text controller for movie title
    movieNameController = widget.isNew
        ? TextEditingController()
        : TextEditingController.fromValue(
            TextEditingValue(text: widget.movie!.title));
    // text controller for movie description
    movieDescriptionController =
        !widget.isNew && widget.movie!.description != null
            ? TextEditingController.fromValue(
                TextEditingValue(text: widget.movie!.description!))
            : TextEditingController();

    // initially editing is false
    // (this is applicable only if widget.isNew is false)
    isEnabledEdit = false;
  }

  @override
  void dispose() {
    // dispose the controllers
    movieNameController.dispose();
    movieDescriptionController.dispose();
    super.dispose();
  }

  submit() {
    // validate form (title shouldn't be null)
    // if validation is done, add/update the movie
    if (formKey.currentState!.validate()) {
      isEnabledEdit = false;
      // add movie and then pop navigator
      final Movie movie;
      if (widget.isNew) {
        movie = Movie(
          title: movieNameController.text,
          userId: user!.uid,
          userName: user!.displayName ?? user!.email ?? '',
          description: movieDescriptionController.text,
          timestamp: DateTime.now(),
        );
      } else {
        movie = widget.movie!.copyWith(
          title: movieNameController.text,
          // if user has a display name, use that
          // else use user email, as we don't have anonymous signup
          userName: user!.displayName ?? user!.email,
          description: movieDescriptionController.text,
          timestamp: DateTime.now(),
        );
      }
      userQuery.doc(movie.id).set(movie);

      // if new movie, pop to the home screen
      // if edit movie, disable the editing
      if (mounted) {
        if (widget.isNew) {
          Navigator.maybePop(context);
        } else {
          isEnabledEdit = false;
          setState(() {});
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Title based on the state
        title: Text(widget.isNew
            ? 'New Movie'
            : (isEnabledEdit ? 'Edit Movie' : 'Movie')),
        // actions are enabled when movie is already existing
        actions: (!widget.isNew)
            ? [
                if (!isEnabledEdit)
                  IconButton(
                    onPressed: () {
                      isEnabledEdit = !isEnabledEdit;
                      setState(() {});
                    },
                    key: const ValueKey('EditIconButton'),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit movie',
                  ),
                IconButton(
                  onPressed: () {
                    userQuery.doc(widget.movie!.id).delete();
                    Navigator.maybePop(context);
                  },
                  key: const ValueKey('DeleteIconButton'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete movie',
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Movie title:'),
                      TextFormField(
                        controller: movieNameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          // labelText: 'Movie',
                          hintText: 'Enter movie title',
                        ),
                        validator: (value) {
                          // validate movie title that it shouldn't be null
                          // or empty. It should at least contain something
                          if (value == null || value.isEmpty) {
                            return 'Movie title cannot be null';
                          }
                          return null;
                        },
                        // enable editing only if adding new movie, or editing
                        enabled: widget.isNew || isEnabledEdit,
                      ),
                      const SizedBox(height: 10),
                      const Text('Movie description:'),
                      TextFormField(
                        controller: movieDescriptionController,
                        textInputAction: TextInputAction.newline,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          // labelText: 'Description',
                          hintText: 'Enter movie description',
                        ),
                        // enable editing only if adding new movie, or editing
                        enabled: widget.isNew || isEnabledEdit,
                      ),
                      // show created user and created time when already exists
                      if (!widget.isNew)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                              'Created/updated by: ${widget.movie!.userName}'),
                        ),
                      if (!widget.isNew)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                              'Created/updated at: ${widget.movie!.timestamp}'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.isNew || isEnabledEdit)
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Center(
                child: ElevatedButton(
                  onPressed: submit,
                  child: Text(widget.isNew ? 'Add' : 'Save'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
