//
//  PasskeyModels.swift
//  BookPlayer
//
//  Created by Claude on 1/9/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

// MARK: - Email Verification Models

public struct EmailVerificationSendResponse: Decodable {
  public let success: Bool
  public let expiresIn: Int
  public let message: String?

  enum CodingKeys: String, CodingKey {
    case success
    case expiresIn = "expires_in"
    case message
  }
}

public struct EmailVerificationCheckResponse: Decodable {
  public let verified: Bool
  public let verificationToken: String?
  public let message: String?

  enum CodingKeys: String, CodingKey {
    case verified
    case verificationToken = "verification_token"
    case message
  }
}

// MARK: - Registration Models

public struct PasskeyRegistrationOptions: Decodable {
  public let challenge: String
  public let userId: String
  public let rpId: String
  public let rpName: String
  public let timeout: Int
  public let userName: String
  public let userDisplayName: String
  public let excludeCredentials: [PasskeyCredentialDescriptor]?

  enum CodingKeys: String, CodingKey {
    case challenge
    case userId = "user_id"
    case rpId = "rp_id"
    case rpName = "rp_name"
    case timeout
    case userName = "user_name"
    case userDisplayName = "user_display_name"
    case excludeCredentials = "exclude_credentials"
  }
}

public struct PasskeyCredentialDescriptor: Decodable {
  public let id: String
  public let type: String
  public let transports: [String]?
}

// MARK: - Authentication Models

public struct PasskeyAuthenticationOptions: Decodable {
  public let challenge: String
  public let timeout: Int
  public let rpId: String
  public let allowCredentials: [PasskeyCredentialDescriptor]?

  enum CodingKeys: String, CodingKey {
    case challenge
    case timeout
    case rpId = "rp_id"
    case allowCredentials = "allow_credentials"
  }
}

// MARK: - Response Models

public struct PasskeyLoginResponse: Decodable {
  public let email: String
  public let token: String
  public let externalId: String
  public let revenuecatId: String
  public let hasSubscription: Bool

  enum CodingKeys: String, CodingKey {
    case email
    case token
    case externalId = "external_id"
    case revenuecatId = "revenuecat_id"
    case hasSubscription = "has_subscription"
  }
}

// MARK: - Credential Management Models

public struct PasskeyInfo: Decodable, Identifiable {
  public let id: Int
  public let deviceName: String?
  public let deviceType: String
  public let backedUp: Bool
  public let lastUsedAt: Date?
  public let createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id = "id_passkey"
    case deviceName = "device_name"
    case deviceType = "device_type"
    case backedUp = "backed_up"
    case lastUsedAt = "last_used_at"
    case createdAt = "created_at"
  }
}

public struct PasskeyListResponse: Decodable {
  public let passkeys: [PasskeyInfo]
}

public struct AuthMethodInfo: Decodable, Identifiable {
  public let id: Int
  public let type: String
  public let isPrimary: Bool
  public let createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case type
    case isPrimary = "is_primary"
    case createdAt = "created_at"
  }
}

public struct AuthMethodListResponse: Decodable {
  public let methods: [AuthMethodInfo]
}

public struct PasskeySuccessResponse: Decodable {
  public let success: Bool
  public let message: String?
}

// MARK: - Error Models

public enum PasskeyError: LocalizedError {
  case registrationFailed(String)
  case authenticationFailed(String)
  case challengeExpired
  case userCancelled
  case platformNotSupported
  case noCredentialAvailable
  case serverError(String)
  case cannotDeleteLastAuthMethod
  case emailVerificationFailed(String)
  case emailVerificationRequired
  case verificationCodeExpired
  case tooManyAttempts
  case emailAlreadyRegistered

  public var errorDescription: String? {
    switch self {
    case .registrationFailed(let message):
      return "Passkey registration failed: \(message)"
    case .authenticationFailed(let message):
      return "Passkey authentication failed: \(message)"
    case .challengeExpired:
      return "The authentication challenge has expired. Please try again."
    case .userCancelled:
      return nil // Silent cancellation
    case .platformNotSupported:
      return "Passkeys are not supported on this device."
    case .noCredentialAvailable:
      return "No passkey found for this account."
    case .serverError(let message):
      return "Server error: \(message)"
    case .cannotDeleteLastAuthMethod:
      return "You must have at least one sign-in method."
    case .emailVerificationFailed(let message):
      return message
    case .emailVerificationRequired:
      return "Please verify your email first."
    case .verificationCodeExpired:
      return "Verification code expired. Please request a new one."
    case .tooManyAttempts:
      return "Too many attempts. Please try again later."
    case .emailAlreadyRegistered:
      return "An account with this email already exists."
    }
  }
}

// MARK: - Base64URL Extensions

public extension Data {
  init?(base64URLEncoded string: String) {
    var base64 = string
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")

    while base64.count % 4 != 0 {
      base64.append("=")
    }

    self.init(base64Encoded: base64)
  }

  func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
