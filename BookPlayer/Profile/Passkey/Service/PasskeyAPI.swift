//
//  PasskeyAPI.swift
//  BookPlayer
//
//  Created by Claude on 1/9/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

public enum PasskeyAPI {
  // Email verification
  case sendVerificationCode(email: String)
  case checkVerificationCode(email: String, code: String)

  // Registration
  case registrationOptions(email: String, verificationToken: String?, deviceName: String?)
  case registrationVerify(
    email: String,
    credentialId: String,
    attestationObject: String,
    clientDataJSON: String,
    transports: [String]?,
    deviceName: String?
  )

  // Authentication
  case authenticationOptions(email: String?)
  case authenticationVerify(
    credentialId: String,
    authenticatorData: String,
    clientDataJSON: String,
    signature: String,
    userHandle: String?
  )

  // Credential management
  case listPasskeys
  case deletePasskey(id: Int)
  case renamePasskey(id: Int, deviceName: String)

  // Auth method management
  case listAuthMethods
}

extension PasskeyAPI: Endpoint {
  public var path: String {
    switch self {
    case .sendVerificationCode:
      return "/v1/passkey/verify-email/send"
    case .checkVerificationCode:
      return "/v1/passkey/verify-email/check"
    case .registrationOptions:
      return "/v1/passkey/register/options"
    case .registrationVerify:
      return "/v1/passkey/register/verify"
    case .authenticationOptions:
      return "/v1/passkey/auth/options"
    case .authenticationVerify:
      return "/v1/passkey/auth/verify"
    case .listPasskeys:
      return "/v1/passkey/credentials"
    case .deletePasskey(let id):
      return "/v1/passkey/credentials/\(id)"
    case .renamePasskey(let id, _):
      return "/v1/passkey/credentials/\(id)"
    case .listAuthMethods:
      return "/v1/passkey/auth-methods"
    }
  }

  public var method: HTTPMethod {
    switch self {
    case .sendVerificationCode, .checkVerificationCode,
         .registrationOptions, .registrationVerify,
         .authenticationOptions, .authenticationVerify:
      return .post
    case .listPasskeys, .listAuthMethods:
      return .get
    case .deletePasskey:
      return .delete
    case .renamePasskey:
      return .patch
    }
  }

  public var parameters: [String: Any]? {
    switch self {
    case .sendVerificationCode(let email):
      return ["email": email]

    case .checkVerificationCode(let email, let code):
      return ["email": email, "code": code]

    case .registrationOptions(let email, let verificationToken, let deviceName):
      var params: [String: Any] = ["email": email]
      if let verificationToken = verificationToken {
        params["verification_token"] = verificationToken
      }
      if let deviceName = deviceName {
        params["device_name"] = deviceName
      }
      return params

    case .registrationVerify(let email, let credentialId, let attestationObject,
                             let clientDataJSON, let transports, let deviceName):
      var response: [String: Any] = [
        "attestation_object": attestationObject,
        "client_data_json": clientDataJSON
      ]
      if let transports = transports {
        response["transports"] = transports
      }

      var params: [String: Any] = [
        "email": email,
        "credential_id": credentialId,
        "response": response
      ]
      if let deviceName = deviceName {
        params["device_name"] = deviceName
      }
      return params

    case .authenticationOptions(let email):
      if let email = email {
        return ["email": email]
      }
      return [:]

    case .authenticationVerify(let credentialId, let authenticatorData,
                               let clientDataJSON, let signature, let userHandle):
      var response: [String: Any] = [
        "authenticator_data": authenticatorData,
        "client_data_json": clientDataJSON,
        "signature": signature
      ]
      if let userHandle = userHandle {
        response["user_handle"] = userHandle
      }

      return [
        "credential_id": credentialId,
        "response": response
      ]

    case .listPasskeys, .listAuthMethods:
      return nil

    case .deletePasskey:
      return nil

    case .renamePasskey(_, let deviceName):
      return ["device_name": deviceName]
    }
  }
}
