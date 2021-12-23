//
//  MegaError.swift
//  MegaKit
//
//  Created by Florin Pop on 10.12.21.
//

import Foundation

public enum MegaError: Error, Equatable {
    case badURL, requestFailed, apiError(Int), httpError(Int), badResponse, unknown, cryptographyError, unimplemented
}
