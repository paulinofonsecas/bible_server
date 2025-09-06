import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:bible_handler/bible_handler.dart';

// A map to cache the loaded Bible versions in memory.
final Map<String, Bible> bibleCache = {};

// The router for our API.
final _router = Router()
  ..get('/versions', _getVersionsHandler)
  ..get('/versions/<versionId>', _getVersionHandler)
  ..get('/versions/<versionId>/<bookId>', _getBookHandler)
  ..get('/versions/<versionId>/<bookId>/<chapter>', _getChapterHandler);

// Handler for GET /versions
// Returns a list of available version IDs.
Response _getVersionsHandler(Request req) {
  return Response.ok(
    jsonEncode(bibleCache.keys.toList()),
    headers: {'Content-Type': 'application/json'},
  );
}

// Handler for GET /versions/<versionId>
// Returns the metadata for a specific version.
Response _getVersionHandler(Request request) {
  final versionId = request.params['versionId'];
  final bible = bibleCache[versionId];

  if (bible == null) {
    return Response.notFound('Version not found.');
  }

  // Return the Bible object without the book content for a summary.
  return Response.ok(
    jsonEncode({
      'name': bible.name,
      'abbreviation': bible.abbreviation,
      'books': bible.books.map((b) => {'id': b.id, 'name': b.name}).toList(),
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

// Handler for GET /versions/<versionId>/<bookId>
// Returns a specific book.
Response _getBookHandler(Request request) {
  final versionId = request.params['versionId'];
  final bookId = request.params['bookId'];
  final bible = bibleCache[versionId];

  if (bible == null) {
    return Response.notFound('Version not found.');
  }

  try {
    final book = bible.books.firstWhere((b) => b.id == bookId);
    return Response.ok(
      jsonEncode(book.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  } on StateError {
    return Response.notFound('Book not found.');
  }
}

// Handler for GET /versions/<versionId>/<bookId>/<chapter>
// Returns a specific chapter.
Response _getChapterHandler(Request request) {
  final versionId = request.params['versionId'];
  final bookId = request.params['bookId'];
  final chapterNum = int.tryParse(request.params['chapter'] ?? '');
  final bible = bibleCache[versionId];

  if (bible == null) {
    return Response.notFound('Version not found.');
  }

  if (chapterNum == null) {
    return Response.badRequest(body: 'Invalid chapter number.');
  }

  try {
    final book = bible.books.firstWhere((b) => b.id == bookId);
    final chapter = book.chapters.firstWhere((c) => c.number == chapterNum);
    return Response.ok(
      jsonEncode(chapter.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  } on StateError {
    return Response.notFound('Book or Chapter not found.');
  }
}


Future<void> main(List<String> args) async {
  // The root directory where Bible versions are stored.
  final biblesRootPath = 'C:\\Users\\PC\\Desktop\\bible_service\\bibles\\versoes_xml';
  final rootDir = Directory(biblesRootPath);

  print('Scanning for Bible versions in $biblesRootPath...');

  if (!await rootDir.exists()) {
    print('Error: Root directory not found: $biblesRootPath');
    return;
  }

  await for (final versionDir in rootDir.list()) {
    if (versionDir is Directory) {
      await for (final potentialBibleDir in (versionDir as Directory).list()) {
        if (potentialBibleDir is Directory) {
          final metadataFile = File('${potentialBibleDir.path}\\metadata.xml');
          if (await metadataFile.exists()) {
            final versionId = versionDir.path.split(Platform.pathSeparator).last;
            print('Metadata file found for $versionId. Loading version from ${potentialBibleDir.path}...');
            try {
              final bible = await loadBibleFromDirectory(potentialBibleDir.path);
              bibleCache[versionId] = bible;
              print('Successfully loaded version: $versionId');
            } catch (e) {
              print('Failed to load version $versionId: $e');
            }
            // Found the bible in this version directory, no need to check other subdirectories.
            break; 
          }
        }
      }
    }
  }

  if (bibleCache.isEmpty) {
    print('Warning: No Bible versions were found or loaded.');
  } else {
    print('Loaded ${bibleCache.length} Bible version(s): ${bibleCache.keys.join(', ')}');
  }

  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline that logs requests.
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(_router.call);

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '8081');
  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');
  print('Access the API at http://localhost:${server.port}');
}
