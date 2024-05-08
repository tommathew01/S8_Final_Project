import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cron/cron.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:memory_aid/provider/answer_provider.dart';
import 'package:memory_aid/provider/exercise_provider.dart';
import 'package:memory_aid/provider/note_provider.dart';
import 'package:memory_aid/provider/profile_provider.dart';
import 'package:memory_aid/provider/record_provider.dart';
import 'package:memory_aid/provider/search_provider.dart';
import 'package:memory_aid/provider/signin_provider.dart';
import 'package:memory_aid/provider/summary_provider.dart';
import 'package:memory_aid/screens/home_screen.dart';
import 'package:memory_aid/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  await Firebase.initializeApp();

  AwesomeNotifications().initialize(
    // set the icon to null if you want to use the default app icon
    null,
    [
      NotificationChannel(
          channelKey: 'key1',
          channelName: 'healthguide',
          channelDescription: 'Notification for reminding',
          defaultColor: const Color.fromARGB(255, 153, 106, 223),
          ledColor: Colors.white,
          playSound: true,
          enableLights: true,
          enableVibration: true)
    ],
  );

  final cron = Cron();
  summarize() async {
    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final textId = FirebaseFirestore.instance
        .collection('users/${FirebaseAuth.instance.currentUser!.uid}/texts')
        .doc(currentDate);
    DocumentSnapshot snapshot = await textId.get();
    final data;
    if (snapshot.exists) {
      data = snapshot.data();
      var is_summary_generated = data?['is_summarized'];

      // checking wheather already summarized or not
      if (!is_summary_generated) {
        print("its time for summary");

        // final provider = RecordProvider();
        print("stoping listening");

        // call the summary functions
        String? available = data?['content'] as String?;

        final provider = SummaryProvider();
        final summary = await provider.Summaryquery({"inputs": available});
        print("summary is : $summary");
        final summaryId = FirebaseFirestore.instance
            .collection(
                'users/${FirebaseAuth.instance.currentUser!.uid}/summary')
            .doc(currentDate);
        summaryId
            .set({'id': summaryId, 'summary': summary, 'date': currentDate});

        is_summary_generated = true;
        print("the truth value :");
        print(is_summary_generated);

        // updating the is_summary in the firebase

        textId.update({
          'is_summarized':
              is_summary_generated, // Update the value of 'is_summarized'
        });

        print("Resuming listening im waiting");
      }
    }
  }

  cron.schedule(
      Schedule.parse('0 10 * * *'),
      () async => {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
              id: 1,
              channelKey: 'key1',
              title: 'Exercise!!',
              body: 'Hurry up and Complete todays exercise.',
            ))
          });
  cron.schedule(Schedule.parse('59 23 * * *'), () async => {await summarize()});

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (BuildContext context) => GoogleSignInProvider()),
        ChangeNotifierProvider(
            create: (BuildContext context) => ProfileProvider()),
        ChangeNotifierProvider(
            create: (BuildContext context) => RecordProvider()),
        ChangeNotifierProvider(
            create: (BuildContext context) => NoteProvider()),
        ChangeNotifierProvider(
            create: (BuildContext context) => SummaryProvider()),
        ChangeNotifierProvider(
            create: (BuildContext context) => ExerciseProvider()),
        ChangeNotifierProvider(
            create: (BuildContext context) => AnswerProvider()),
        ChangeNotifierProvider(
            create: (BuildContext context) => SearchProvider()),
      ],
      child: MaterialApp(
        title: 'Memory Aid',
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
              primary: Color.fromARGB(255, 42, 41, 41),
              //Color.fromARGB(255, 45, 44, 44),
              secondary: Color.fromARGB(255, 117, 162, 139),
              tertiary: Colors.white,
              secondaryContainer: Color.fromARGB(255, 153, 194, 172)),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: const LoadApp(),
      ),
    );
  }
}

class LoadApp extends StatelessWidget {
  const LoadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      key: UniqueKey(),
      future: Future.delayed(
        const Duration(seconds: 2),
      ),
      builder: (context, snapshot) {
        if (ConnectionState.waiting == snapshot.connectionState) {
          return const SplashScreen();
        } else {
          return const HomeScreen();
        }
      },
    );
  }
}
