import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';
import 'database/database_helper.dart';
import 'models/diary_entry.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diary App',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final dbHelper = DatabaseHelper.instance;
  final picker = ImagePicker();
  FlutterSoundRecorder? audioRecorder;
  FlutterSoundPlayer? audioPlayer;
  late String recordedFilePath;

  List<DiaryEntry> entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
    audioRecorder = FlutterSoundRecorder();
    audioPlayer = FlutterSoundPlayer();
  }

  @override
  void dispose() {
    audioPlayer!.stopPlayer();
    super.dispose();
  }

  void _loadEntries() async {
    List<DiaryEntry> loadedEntries = await dbHelper.getEntries();
    setState(() {
      entries = loadedEntries;
    });
  }

  Widget _buildFormattedDate(DateTime date) {
    final formattedDate = DateFormat('dd MMM yyyy').format(date);
    return Text(formattedDate);
  }

  Future<void> _addEntry(BuildContext context) async {
    TextEditingController titleController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nueva entrada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titulo',
                ),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripcion',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                String title = titleController.text;
                String description = descriptionController.text;

                final DiaryEntry newEntry = DiaryEntry(
                  title: title,
                  date: DateTime.now(),
                  description: description,
                );

                int? id = await dbHelper.insert(newEntry);

                newEntry.id = id;
                entries.insert(0, newEntry);

                setState(() {});

                Navigator.of(context).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteEntry(int index) async {
    int deleted = await dbHelper.delete(entries[index].id!);

    if (deleted > 0) {
      entries.removeAt(index);
      setState(() {});
    }
  }

  Future<void> _deleteAllEntries() async {
    await dbHelper.deleteAll();
    entries.clear();
    setState(() {});
  }

  Future<void> _pickImage(int index) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar opción'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final pickedFile =
                      await picker.pickImage(source: ImageSource.gallery);

                  if (pickedFile == null) return;

                  File imageFile = File(pickedFile.path);

                  String imagePath = imageFile.path;

                  await dbHelper.updatePhoto(entries[index].id!, imagePath);

                  setState(() {
                    entries[index].photo = imagePath;
                  });
                },
                child: const Text('Subir foto'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _startRecording(index);
                },
                child: const Text('Grabar nota de voz'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startRecording(int index) async {
    Directory appDir = await getApplicationDocumentsDirectory();
    String audioPath =
        '${appDir.path}/recording_${DateTime.now().microsecondsSinceEpoch}.aac';

    await audioRecorder!.openAudioSession();
    await audioRecorder!.startRecorder(toFile: audioPath, codec: Codec.aacADTS);

    recordedFilePath = audioPath;
  }

  Future<void> _stopRecording(int index) async {
    await audioRecorder!.stopRecorder();

    await dbHelper.updateAudio(entries[index].id!, recordedFilePath);

    entries[index].audio = recordedFilePath;

    setState(() {});
  }

  Future<void> _playAudio(int index) async {
    if (entries[index].audio != null) {
      await audioPlayer!.startPlayer(
        fromURI: entries[index].audio!,
        codec: Codec.aacADTS,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Diario'),
      ),
      body: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];

          return ListTile(
            leading: GestureDetector(
              onTap: () => _pickImage(index),
              child: entry.photo != null
                  ? CircleAvatar(backgroundImage: FileImage(File(entry.photo!)))
                  : const CircleAvatar(child: Icon(Icons.add_a_photo)),
            ),
            title: Text(
              entry.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            subtitle: _buildFormattedDate(entry.date),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EntryDetailsPage(entry: entry),
                ),
              );
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteEntry(index),
                ),
                IconButton(
                  icon: const Icon(Icons.mic),
                  onPressed: () {
                    if (audioRecorder!.isStopped) {
                      _startRecording(index);
                    } else {
                      _stopRecording(index);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.play_circle_filled),
                  onPressed: () => _playAudio(index),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addEntry(context),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomAppBar(
        child: SizedBox(
          height: 50.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _deleteAllEntries,
                icon: const Icon(Icons.delete),
                label: const Text('Borrar Todo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EntryDetailsPage extends StatelessWidget {
  final DiaryEntry entry;
  final AudioPlayer audioPlayer = AudioPlayer();

  EntryDetailsPage({Key? key, required this.entry}) : super(key: key);

  Future<void> _playAudio(String? audioPath) async {
    if (audioPath != null) {
      int result = await audioPlayer.play(audioPath, isLocal: true);
      if (result == 1) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy hh:mm a').format(entry.date);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de entrada'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (entry.photo != null) Image.file(File(entry.photo!)),
            RichText(
              text: TextSpan(
                text: entry.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            Text(formattedDate),
            Text(entry.description),
            IconButton(
              icon: const Icon(Icons.play_circle_filled),
              onPressed: () => _playAudio(entry.audio),
            ),
          ],
        ),
      ),
    );
  }
}
