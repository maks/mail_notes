import 'dart:io';

import 'package:enough_mail/imap.dart';
import 'package:file_selector/file_selector.dart';
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
  String? _importProgress;
  late final Future<ImapClient> _imapClient = _initImap();

  String userName = const String.fromEnvironment('USERNAME');
  String password = const String.fromEnvironment('PASSWORD');
  String imapServerHost = 'imap.fastmail.com';
  int imapServerPort = 993;
  bool isImapServerSecure = true;

  Future<ImapClient> _initImap() async {
    final c = ImapClient(isLogEnabled: false);
    await c.connectToServer(imapServerHost, imapServerPort,
        isSecure: isImapServerSecure);
    await c.login(userName, password);
    return c;
  }

  Future<void> _getNotes() async {
    try {
      final client = (await _imapClient);
      final mailboxes = await client.listMailboxes();

      await client
          .selectMailbox(mailboxes.firstWhere((b) => b.name == "Notes"));
      final fetchResult = await client.fetchRecentMessages(
        messageCount: 2000,
      );

      debugPrint("result:${fetchResult.messages.length}");
      _notes.clear();
      for (final message in fetchResult.messages) {
        final body =
            message.mimeData?.decodeText(message.mimeData?.contentType, "8bit");
        // debugPrint(message.decodeSubject());
        // debugPrint(body);
        // debugPrint("=====================");
        _notes.add(Note(message.decodeSubject() ?? "", body ?? ""));
      }

      setState(() {
        // just to trigger refresh of fetched notes
      });
    } on ImapException catch (e, st) {
      debugPrint('IMAP failed with $e \n $st');
    }
  }

  Future<void> _importNotes(Directory importPath) async {
    setState(() {
      _importProgress = "Starting import...";
    });
    final entriesStream = importPath.list();
    int count = 0;   
    await for (final ent in entriesStream) {
      if (ent is File) {
        final ext = p.extension(ent.path);
        if (ext.toLowerCase() == '.md' || ext.toLowerCase() == ".txt") {
          final title = p.basenameWithoutExtension(ent.path);
          final noteText = await ent.readAsString();
          await _addNote(title, noteText);
          debugPrint("added note: $title");
          setState(() {
            _importProgress = "[$count] added note: $title";
          });
          count++;
        }
      }
    }
    setState(() {
    _importProgress = "Finished import:$count txt/md notes imported";
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

    try {
      final client = (await _imapClient);
      final mailboxes = await client.listMailboxes();

      await client
          .selectMailbox(mailboxes.firstWhere((b) => b.name == "Notes"));

      await client.appendMessage(note);
    } on ImapException catch (e, st) {
      debugPrint('IMAP failed with $e \n $st');
    }
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
            onPressed: () async {
              debugPrint("import...");
              final String? directoryPath = await getDirectoryPath();
              if (directoryPath == null) {
                // Operation was canceled by the user.
                return;
              }
              await _importNotes(Directory(directoryPath));
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
      body: _importProgress != null
          ? AlertDialog(
              title: const Text("Import Result"),
              content: Text(_importProgress ?? ""),
              actions: <Widget>[
                TextButton(
                  onPressed: _importProgress!.startsWith("Finished")                      
                      ? () {
                          setState(() {
                            _importProgress = null;
                          });
                          // Navigator.of(context).pop();
                        }
                      : null,
                  child: const Text('Ok'),
                ),
              ],
            )
          : Center(
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
        onPressed: () {
          // _addNote("mailnotes test 2", "this is a test 2");
          //
          //refresh list manually for now here
          // await _getNotes();
          throw UnimplementedError("add note not done yet");
        },
        tooltip: 'Add Note',
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
        const SizedBox(
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
