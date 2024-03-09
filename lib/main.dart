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
      final fetchResult = await client.fetchRecentMessages();

      print("result:${fetchResult.messages.length}");
      _notes.clear();
      for (final message in fetchResult.messages) {
        final body =
            message.mimeData?.decodeText(message.mimeData?.contentType, "8bit");
        print(message.decodeSubject());
        print(body);
        print("=====================");
        _notes.add(Note(message.decodeSubject() ?? "", body ?? ""));
      }

      await client.logout();
      print("=== IMAP LOGOUT");

      setState(() {
        //na
      });
    } on ImapException catch (e, st) {
      print('IMAP failed with $e \n $st');
    }
  }

  Future<MimeMessage> _newNote(String title, String text) async {
    final builder = MessageBuilder();
    builder.addTextPlain(text);
    builder.subject = title;
    builder.sender = MailAddress.parse(userName);
    builder.setHeader("X-Uniform-Type-Identifier", "com.apple.mail-note");
    return builder.buildMimeMessage();
  }

  Future<void> _addNote(String title, String text) async {
    final note = await _newNote(title, text);

    final client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer(imapServerHost, imapServerPort,
          isSecure: isImapServerSecure);
      await client.login(userName, password);

      final mailboxes = await client.listMailboxes();

      await client
          .selectMailbox(mailboxes.firstWhere((b) => b.name == "Notes"));

      await client.appendMessage(note);
    } on ImapException catch (e, st) {
      print('IMAP failed with $e \n $st');
    }

    //refresh list manually for now here
      _getNotes();
  }

  @override
  void initState() {
    super.initState();
    _getNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: ListView(
          children: _notes.map((e) => Text(e.title)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNote("mailnotes test 2", "this is a test 2"),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class Note {
  final String title;
  final String body;

  Note(this.title, this.body);
}
