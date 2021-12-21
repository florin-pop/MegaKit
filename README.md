# MegaKit

Lightweight Swift framework for downloading files from mega.nz

## Why?

The [official iOS SDK](https://github.com/meganz/iOS) is fully featured and therefore quite bloated for a small app.

The purpose of this framework is to only provide support for downloading and decrypting files or folders for the apps that require this functionality.

The runtime only depends on 2 Swift packages:
 - [`BigInt`](https://github.com/attaswift/BigInt) is used to implement the `RSA` decryption for the login process
 - [`CryptoSwift`](https://github.com/krzyzanowskim/CryptoSwift) is used for the `AES` decrytion when downloading files

## How

Some of the code is reverse engineered, some is inspired form:
- [`megatools`](http://megous.com/git/megatools): a command line client for Mega.nz
- [`mega.py`](https://github.com/odwyersoftware/mega.py): Python library for Mega.nz
- [`JDownloader`](https://jdownloader.org/home/index): an open source download manager

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
