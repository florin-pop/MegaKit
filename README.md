# MegaKit

Lightweight Swift framework for downloading files from mega.nz

## Login example

```
let megaClient = MegaClient()
megaClient.login(using: email, password: password) { result in
    switch result {
    case let .success(sessionID):
        // Use session ID
    case let .failure(error):
        // Handle error
    }
}
```

## Download file example

```
let megaLink = try! MegaLink(url: url)

megaClient.getFileMetadata(from: megaLink, sessionID: sessionID) { result in
    switch result {
        case let .success(fileMetadata):
            // File size: fileMetadata.size
            // File name: fileMetadata.name
            // File decryption key: fileMetadata.key
            // Direct download URL: fileMetadata.url
        case let .failure(error):
            // Handle error
    }
}
```

## Download from folder

```
let megaLink = try! MegaLink(url: url)

megaClient.getContents(of: megaLink, sessionID: sessionID) { result in
    switch result {
    case let .success(items):
        for (_, item) in items {
            // File or folder: item.type
            // Mega ID: item.id
            // Parent folder: item.parent
            // Name: item.attributes.name
            // Decryption key: item.key
            // (optional) File size: item.size

            if item.type == .file {
                megaClient.getDownloadLink(from: item.id, parentNode: megaLink.id, sessionID: sessionID) { result in
                    switch result {
                    case let .success(fileInfo):
                        // Direct download URL: fileInfo.downloadLink
                    case .failure:
                        // Handle error
                    }
                }
            }
        }
    case let .failure(error):
        // Handle error
    }
}
```
