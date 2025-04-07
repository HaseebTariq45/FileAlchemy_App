import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'models/file_format.dart';
import 'services/conversion_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FileAlchemy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const FileAlchemyHomePage(),
    );
  }
}

class FileAlchemyHomePage extends StatefulWidget {
  const FileAlchemyHomePage({super.key});

  @override
  State<FileAlchemyHomePage> createState() => _FileAlchemyHomePageState();
}

class _FileAlchemyHomePageState extends State<FileAlchemyHomePage> {
  File? selectedFile;
  String? selectedFileName;
  String? selectedOutputFormat;
  bool isConverting = false;
  String? conversionError;
  File? convertedFile;

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    
    if (result != null) {
      final file = File(result.files.single.path!);
      
      setState(() {
        selectedFile = file;
        selectedFileName = path.basename(file.path);
        selectedOutputFormat = null;
        convertedFile = null;
        conversionError = null;
      });
    }
  }

  List<String> getAvailableOutputFormats() {
    if (selectedFile == null) return [];
    return ConversionService.getAvailableOutputFormats(selectedFile!);
  }

  Future<void> convertFile() async {
    if (selectedFile == null || selectedOutputFormat == null) return;
    
    setState(() {
      isConverting = true;
      conversionError = null;
      convertedFile = null;
    });
    
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission is required');
      }
      
      // Get temporary directory for output
      final tempDir = await getTemporaryDirectory();
      
      // Use our ConversionService to perform the conversion
      final newFile = await ConversionService.convertFile(
        selectedFile!, 
        selectedOutputFormat!, 
        tempDir.path
      );
      
      setState(() {
        convertedFile = newFile;
        isConverting = false;
      });
    } catch (e) {
      setState(() {
        conversionError = e.toString();
        isConverting = false;
      });
    }
  }

  Future<void> shareConvertedFile() async {
    if (convertedFile != null) {
      await Share.shareXFiles([XFile(convertedFile!.path)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableFormats = getAvailableOutputFormats();
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('FileAlchemy'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: pickFile,
              icon: const Icon(Icons.file_upload),
              label: const Text('Select File'),
            ),
            const SizedBox(height: 20),
            
            if (selectedFile != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected File:',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedFileName ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Convert to:',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      if (availableFormats.isEmpty)
                        const Text('No conversion options available for this file type'),
                      if (availableFormats.isNotEmpty)
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          value: selectedOutputFormat,
                          hint: const Text('Select output format'),
                          onChanged: (value) {
                            setState(() {
                              selectedOutputFormat = value;
                            });
                          },
                          items: availableFormats
                              .map((format) => DropdownMenuItem(
                                    value: format,
                                    child: Text(format.toUpperCase()),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              ElevatedButton.icon(
                onPressed: (selectedOutputFormat != null && !isConverting)
                    ? convertFile
                    : null,
                icon: const Icon(Icons.autorenew),
                label: const Text('Convert'),
              ),
              
              if (isConverting) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 8),
                const Center(child: Text('Converting...')),
              ],
              
              if (conversionError != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: Colors.red[100],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error: $conversionError',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
              
              if (convertedFile != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: Colors.green[100],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conversion Complete!',
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Output File: ${path.basename(convertedFile!.path)}',
                          style: TextStyle(color: Colors.green[800]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: shareConvertedFile,
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
