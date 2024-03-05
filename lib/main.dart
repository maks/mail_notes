import 'package:enough_mail/imap.dart';
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
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Note> _notes = [];

  String userName = const String.fromEnvironment('USERNAME');
  String password = const String.fromEnvironment('PASSWORD');
  String imapServerHost = 'imap.fastmail.com';
  int imapServerPort = 993;
  bool isImapServerSecure = true;

  Future<void> _getNotes() async {
    final client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer(imapServerHost, imapServerPort,
          isSecure: isImapServerSecure);
      await client.login(userName, password);

      final mailboxes = await client.listMailboxes();

      // await client.selectMailboxByPath("Notes");
      await client
          .selectMailbox(mailboxes.firstWhere((b) => b.name == "Notes"));

      // fetch 10 most recent messages:
      // final fetchResult = await client.fetchRecentMessages(
      //     messageCount: 10, criteria: 'BODY.PEEK[]');
      final fetchResult = await client.fetchRecentMessages();

      print("result:${fetchResult.messages.length}");
      for (final message in fetchResult.messages) {
        final body = message.mimeData?.decodeText(message.mimeData?.contentType, "8bit");
        print(message.decodeSubject());
        print(body);
        print("=====================");
        _notes.add(Note(message.decodeSubject() ?? "", body ?? ""));
      }

      await client.logout();
      print("=== IMAP LOGOUT");
    } on ImapException catch (e) {
      print('IMAP failed with $e');
    }
  }

  Future<MimeMessage> _newNote(String title, String text) async {
    final builder = MessageBuilder();
    builder.addTextPlain(text);
    builder.subject = title;
    builder.sender = MailAddress.parse(userName);
    // builder.setHeader("X-Uniform-Type-Identifier", "com.apple.mail-note");
    return builder.buildMimeMessage();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: ListView(
          children: _notes.map((e) => Text(e.title)).toList(),          
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(_getNotes),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class Note {
  final String title;
  final String body;

  Note(this.title, this.body);
}