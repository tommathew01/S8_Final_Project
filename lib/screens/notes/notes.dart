import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:memory_aid/models/note_model.dart';
import 'package:memory_aid/provider/answer_provider.dart';
import 'package:memory_aid/provider/signin_provider.dart';
import 'package:memory_aid/widget/add_note_dialog.dart';
import 'package:memory_aid/widget/noteTile.dart';
import 'package:provider/provider.dart';

import '../../widget/appbar_decoration.dart';

class Notes extends StatelessWidget {
  const Notes({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collection = FirebaseFirestore.instance
        .collection('users/${FirebaseAuth.instance.currentUser!.uid}/notes');
    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.colorScheme.primary,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // Navigator.of(context).push(
            //     MaterialPageRoute(builder: (context) => const AddNoteDialog()));
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const AddNoteDialog();
                });
          },
          backgroundColor: theme.colorScheme.secondary,
          child: const Icon(
            Icons.add,
            color: Colors.white,
          ),
        ),
        appBar: AppBar(
          //backgroundColor: theme.colorScheme.secondary,
          toolbarHeight: 70,
          flexibleSpace: const AppbarDecoration(),
          centerTitle: true,
          title: Text(
            'Notes',
            style: TextStyle(
                color: theme.colorScheme.tertiary,
                fontSize: 20,
                fontWeight: FontWeight.w500),
          ),
        ),
        body: Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 10,
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: collection.snapshots(),
              builder: (_, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error = ${snapshot.error}');
                }
                if (snapshot.hasData) {
                  List<DocumentSnapshot> documents = snapshot.data!.docs;

                  return ListView.builder(
                      itemCount: documents.length,
                      itemBuilder: (BuildContext context, index) {
                        // print("hello here testing");
                        print(documents[index].id);
                        return Padding(
                            padding: const EdgeInsets.only(
                              left: 10,
                              right: 10,
                              top: 20,
                            ),
                            child: NotesTile(
                                id: documents[index].id,
                                note: NoteModel(
                                  title: documents[index].get('title'),
                                  description:
                                      documents[index].get('description'),
                                )));
                      });
                }

                return const Center(child: CircularProgressIndicator());
              },
            )),
      ),
    );
  }

  
}
