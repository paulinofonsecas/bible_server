# Bible Server

This project provides a RESTful API for accessing Bible translations. It serves Bible content, including books, chapters, and verses, and supports searching within specific Bible versions.

## Features

*   **Dynamic Bible Loading**: Automatically loads Bible translations from a specified GitHub repository.
*   **RESTful API**: Provides endpoints for accessing Bible versions, books, chapters, and verses.
*   **Search Functionality**: Allows searching for text within a specific Bible version.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

*   [Dart SDK](https://dart.dev/get-dart)

### Installation

1.  Clone the repository:

    ```bash
    git clone https://github.com/your-repo/bible_service.git
    cd bible_service/bible_server
    ```

2.  Get the project dependencies:

    ```bash
    dart pub get
    ```

### Running the Server

To run the server, execute the following command from the `bible_server` directory:

```bash
dart bin/server.dart
```

The server will start on `http://localhost:8081` (or the port specified by the `PORT` environment variable).

## API Endpoints

All endpoints return JSON.

### Get All Available Versions

`GET /versions`

Returns a list of available Bible version IDs.

**Example Response:**

```json
[
  "ACF",
  "JFAA",
  "KJA"
]
```

### Get Version Metadata

`GET /versions/{versionId}`

Returns metadata for a specific Bible version, including its name, abbreviation, and a list of books.

**Example:** `GET /versions/KJA`

```json
{
  "name": "King James Atualizada",
  "abbreviation": "KJA",
  "books": [
    {
      "id": "GEN",
      "name": "Gênesis"
    },
    {
      "id": "EXO",
      "name": "Êxodo"
    }
  ]
}
```

### Get a Specific Book

`GET /versions/{versionId}/{bookId}`

Returns the content of a specific book within a Bible version.

**Example:** `GET /versions/KJA/GEN`

```json
{
  "id": "GEN",
  "name": "Gênesis",
  "chapters": [
    {
      "number": 1,
      "verses": [
        {
          "number": 1,
          "text": "No princípio, Deus criou os céus e a terra."
        }
      ]
    }
  ]
}
```

### Get a Specific Chapter

`GET /versions/{versionId}/{bookId}/{chapterNumber}`

Returns the content of a specific chapter within a book.

**Example:** `GET /versions/KJA/GEN/1`

```json
{
  "number": 1,
  "verses": [
    {
      "number": 1,
      "text": "No princípio, Deus criou os céus e a terra."
    },
    {
      "number": 2,
      "text": "A terra, entretanto, era sem forma e vazia; havia trevas sobre a face do abismo, e o Espírito de Deus se movia por sobre as águas."
    }
  ]
}
```

### Search within a Version

`GET /versions/{versionId}/search?q={query}`

Searches for a given query string within a specific Bible version and returns matching verses.

**Parameters:**

*   `q`: The search query string.

**Example:** `GET /versions/KJA/search?q=amor`

```json
{
  "query": "amor",
  "totalResults": 5,
  "results": [
    {
      "book": {
        "id": "JHN",
        "name": "João"
      },
      "chapter": {
        "number": 3
      },
      "verse": {
        "number": 16,
        "text": "Porque Deus tanto amou o mundo que deu o seu Filho Unigênito, para que todo o que nele crer não pereça, mas tenha a vida eterna."
      }
    }
  ]
}
```