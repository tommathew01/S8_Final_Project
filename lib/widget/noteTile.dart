import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../provider/note_provider.dart';

class NotesTile extends StatelessWidget {
  final NoteModel note;
  final String id;
  const NotesTile({super.key, required this.note, required this.id});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
       constraints:const BoxConstraints(
        minHeight: 150
       ),
      //color: const Color.fromARGB(255, 142, 38, 83),
      decoration:const  BoxDecoration(
        borderRadius:BorderRadius.all(Radius.circular(25)),
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 176, 195, 192),
            Color.fromARGB(255, 110, 153, 148),
            Color.fromARGB(255, 80, 127, 115),
            Color.fromARGB(255, 56, 93, 88)
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        //color: theme.colorScheme.secondary
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.title,
              style: GoogleFonts.poppins(
                  textStyle: TextStyle(
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              note.description,
              style: GoogleFonts.poppins(
                  textStyle: TextStyle(color: theme.colorScheme.tertiary)),
            ),
            
            Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                icon: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
                onPressed: () {
                  print("no its here testing");
                  print(id);
                  Provider.of<NoteProvider>(context, listen: false)
                      .deleteNote(id);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
