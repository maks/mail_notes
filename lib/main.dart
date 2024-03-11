import 'dart:io';

import 'package:enough_mail/imap.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mail Notes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Mail Notes'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<Note> _notes = [];
  Note? _currentNote;

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

  Future<void> _importNotes(Directory importPath) async {
    final entriesStream = importPath.list();
    entriesStream.forEach((el) async {
      // print("file: ${el.path}");
      if (el is File) {
        final name = p.basename(el.path);
        if (name.endsWith('.md') || name.endsWith(".txt")) {
          final noteText = await el.readAsString();
          final n = Note(name, noteText);
          print("note: $n");
        }
      }
    });
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
        actions: [
          IconButton(
            icon: const Icon(
              Icons.upload,
              color: Colors.white,
            ),
            onPressed: () {
              print("import...");
              _importNotes(Directory("/temp"));
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.settings,
              color: Colors.white,
            ),
            onPressed: () {
               throw UnimplementedError("settings not done yet");
            },
          ),
          
        ],
      ),
      body: Center(
        child: Row(
          children: [
            SizedBox(
              height: 300,
              width: 200,
              child: ListView(
                children: _notes
                    .map((e) => ListTile(
                          title: Text(e.title),
                          onTap: () => setState(() {
                            _currentNote = e;
                          }),
                        ))
                    .toList(),
              ),
            ),
            NoteEditor(note: _currentNote ?? Note("title", "body")),
          ],
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

class NoteEditor extends StatefulWidget {
  final Note note;

  const NoteEditor({super.key, required this.note});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textController.text = widget.note.body;
  }

  @override
  Widget build(BuildContext context) {
    _textController.text = widget.note.body;
    return Column(
      children: [
        Text(
          widget.note.title,
          maxLines: 1,
        ),
        SizedBox(
          width: 220,
          child: TextField(
              // controller: _textController,
              ),
        ),
      ],
    );
  }
}

class Note {
  final String title;
  final String body;

  Note(this.title, this.body);

  @override
  String toString() {
    return "$title\n\n$body";
  }
}
