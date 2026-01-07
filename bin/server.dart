import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:bible_handler/bible_handler.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

// A map to cache the loaded Bible versions in memory.
final Map<String, Bible> bibleCache = {};

// The router for our API.
final _router = Router()
  ..get('/versions', _getVersionsHandler)
  ..get('/versions/<versionId>/download', _downloadVersionZipHandler)
  ..get('/versions/<versionId>/search', _searchHandler)
  ..get('/versions/<versionId>', _getVersionHandler)
  ..get('/versions/<versionId>/<bookId>', _getBookHandler)
  ..get('/versions/<versionId>/<bookId>/<chapter>', _getChapterHandler);

// Handler for GET /versions/<versionId>/download
// Creates a ZIP file containing the specified Bible version as JSON and returns it.
Response _downloadVersionZipHandler(Request request) {
  final versionId = request.params['versionId'];
  final bible = bibleCache[versionId];

  if (bible == null) {
    return Response.notFound('Version not found.');
  }

  final archive = Archive();
  final jsonContent = jsonEncode(bible.toJson());
  final bytes = utf8.encode(jsonContent);
  archive.addFile(ArchiveFile('$versionId.json', bytes.length, bytes));

  final zipEncoder = ZipEncoder();
  final zipData = zipEncoder.encode(archive);

  if (zipData == null) {
    return Response.internalServerError(body: 'Failed to create ZIP file.');
  }

  return Response.ok(
    zipData,
    headers: {
      'Content-Type': 'application/zip',
      'Content-Disposition': 'attachment; filename="$versionId.zip"',
    },
  );
}

// Handler for GET /versions/<versionId>/search
// Searches for a query within a specific Bible version.
Response _searchHandler(Request request) {
  final versionId = request.params['versionId'];
  final query = request.url.queryParameters['q'];
  final bible = bibleCache[versionId];

  if (bible == null) {
    return Response.notFound('Version not found.');
  }

  if (query == null || query.isEmpty) {
    return Response.badRequest(body: 'Search query (q) is required.');
  }

  final searchResults = bible.search(query);
  return Response.ok(
    searchResults.toJson(),
    headers: {'Content-Type': 'application/json'},
  );
}

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
  final List<String> versionsToLoad = [
    'ACF',
    'ARA',
    'ARC',
    'AS21',
    'JFAA',
    'KJA',
    'KJF',
    'NAA',
    'NBV',
    'NTLH',
    'NVI',
    'NVT',
    'TB',
  ];

  print('Loading Bible versions from GitHub...');

  for (final versionId in versionsToLoad) {
    print('Attempting to load version: $versionId');
    try {
      final bible = await loadBibleFromUrl(versionId);
      bibleCache[versionId] = bible;
      print('Successfully loaded version: $versionId');
    } catch (e) {
      print('Failed to load version $versionId: $e');
    }
  }

  if (bibleCache.isEmpty) {
    print('Warning: No Bible versions were found or loaded.');
  } else {
    print(
      'Loaded ${bibleCache.length} Bible version(s): ${bibleCache.keys.join(', ')}',
    );
  }

  // Configure a pipeline that logs requests.
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(_router.call);

  final client = HttpClient();
  final externalIp = await client
      .getUrl(Uri.parse('https://api.ipify.org'))
      .then((req) => req.close())
      .then((res) => res.transform(utf8.decoder).join())
      .catchError((_) => 'Unavailable');
  client.close();
  print('External IP: $externalIp');
  final port = int.parse(Platform.environment['PORT'] ?? '8081');
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print('Server listening on port ${server.port}');
  print('Access the API at http://$externalIp:${server.port}/versions');
}
