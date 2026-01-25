//
//  PasskeyService.swift
//  BookPlayer
//
//  Created by Claude on 1/9/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import AuthenticationServices
import Foundation
import UIKit
import BookPlayerKit

public protocol PasskeyServiceProtocol {
  // Email verification
  func sendVerificationCode(email: String) async throws -> EmailVerificationSendResponse
  func checkVerificationCode(email: String, code: String) async throws -> EmailVerificationCheckResponse

  // Registration
  func registerNewAccount(
    email: String,
    verificationToken: String,
    deviceName: String?
  ) async throws -> PasskeyLoginResponse
  func addPasskeyToAccount(deviceName: String?, email: String) async throws

  // Authentication
  func signIn() async throws -> PasskeyLoginResponse

  // Credential management
  func listPasskeys() async throws -> [PasskeyInfo]
  func deletePasskey(id: Int) async throws
  func renamePasskey(id: Int, deviceName: String) async throws
  func listAuthMethods() async throws -> [AuthMethodInfo]
}

public final class PasskeyService: NSObject, PasskeyServiceProtocol, @unchecked Sendable {
  private let relyingPartyIdentifier = "bookplayer.app"
  private let client: NetworkClientProtocol
  private var provider: NetworkProvider<PasskeyAPI>!

  private var registrationContinuation: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialRegistration, Error>?
  private var authenticationContinuation: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialAssertion, Error>?

  public init(client: NetworkClientProtocol = NetworkClient()) {
    self.client = client
    super.init()
    self.provider = NetworkProvider(client: client)
  }

  // MARK: - Email Verification

  public func sendVerificationCode(email: String) async throws -> EmailVerificationSendResponse {
    do {
      let response: EmailVerificationSendResponse = try await provider.request(
        .sendVerificationCode(email: email)
      )

      if !response.success, let message = response.message {
        throw PasskeyError.emailVerificationFailed(message)
      }

      return response
    } catch let error as BookPlayerError {
      if case .networkErrorWithCode(_, let code) = error,
         code == "EMAIL_ALREADY_REGISTERED" {
        throw PasskeyError.emailAlreadyRegistered
      }
      throw error
    }
  }

  public func checkVerificationCode(email: String, code: String) async throws -> EmailVerificationCheckResponse {
    let response: EmailVerificationCheckResponse = try await provider.request(
      .checkVerificationCode(email: email, code: code)
    )

    if !response.verified, let message = response.message {
      throw PasskeyError.emailVerificationFailed(message)
    }

    return response
  }

  // MARK: - Registration

  public func registerNewAccount(
    email: String,
    verificationToken: String,
    deviceName: String?
  ) async throws -> PasskeyLoginResponse {
    // 1. Request registration options from server (with verification token)
    let options: PasskeyRegistrationOptions = try await provider.request(
      .registrationOptions(email: email, verificationToken: verificationToken, deviceName: deviceName)
    )

    // 2. Create credential with platform authenticator
    let credential = try await performRegistration(
      challenge: options.challenge,
      userId: options.userId,
      userName: email
    )

    // 3. Send attestation to server
    let transports = credential.rawAttestationObject != nil
      ? ["internal"]
      : nil

    let response: PasskeyLoginResponse = try await provider.request(
      .registrationVerify(
        email: email,
        credentialId: credential.credentialID.base64URLEncodedString(),
        attestationObject: credential.rawAttestationObject?.base64URLEncodedString() ?? "",
        clientDataJSON: credential.rawClientDataJSON.base64URLEncodedString(),
        transports: transports,
        deviceName: deviceName
      )
    )

    return response
  }

  public func addPasskeyToAccount(deviceName: String?, email: String) async throws {
    // 1. Request registration options for existing account (requires auth token, no verification needed)
    let options: PasskeyRegistrationOptions = try await provider.request(
      .registrationOptions(email: email, verificationToken: nil, deviceName: deviceName)
    )

    // 2. Create credential
    let credential = try await performRegistration(
      challenge: options.challenge,
      userId: options.userId,
      userName: options.userName
    )

    // 3. Complete registration
    let transports = credential.rawAttestationObject != nil
      ? ["internal"]
      : nil

    // Server returns PasskeyLoginResponse for all registrations, but we ignore it
    // since the user is already logged in when adding a passkey to existing account
    let _: PasskeyLoginResponse = try await provider.request(
      .registrationVerify(
        email: options.userName,
        credentialId: credential.credentialID.base64URLEncodedString(),
        attestationObject: credential.rawAttestationObject?.base64URLEncodedString() ?? "",
        clientDataJSON: credential.rawClientDataJSON.base64URLEncodedString(),
        transports: transports,
        deviceName: deviceName
      )
    )
  }

  // MARK: - Authentication

  public func signIn() async throws -> PasskeyLoginResponse {
    // 1. Request authentication options
    let options: PasskeyAuthenticationOptions = try await provider.request(
      .authenticationOptions(email: nil)
    )

    // 2. Authenticate with platform authenticator
    let assertion = try await performAuthentication(challenge: options.challenge)

    // 3. Verify assertion with server
    let response: PasskeyLoginResponse = try await provider.request(
      .authenticationVerify(
        credentialId: assertion.credentialID.base64URLEncodedString(),
        authenticatorData: assertion.rawAuthenticatorData.base64URLEncodedString(),
        clientDataJSON: assertion.rawClientDataJSON.base64URLEncodedString(),
        signature: assertion.signature.base64URLEncodedString(),
        userHandle: assertion.userID.base64URLEncodedString()
      )
    )

    return response
  }

  // MARK: - Credential Management

  public func listPasskeys() async throws -> [PasskeyInfo] {
    let response: PasskeyListResponse = try await provider.request(.listPasskeys)
    return response.passkeys
  }

  public func deletePasskey(id: Int) async throws {
    let _: PasskeySuccessResponse = try await provider.request(.deletePasskey(id: id))
  }

  public func renamePasskey(id: Int, deviceName: String) async throws {
    let _: PasskeySuccessResponse = try await provider.request(.renamePasskey(id: id, deviceName: deviceName))
  }

  public func listAuthMethods() async throws -> [AuthMethodInfo] {
    let response: AuthMethodListResponse = try await provider.request(.listAuthMethods)
    return response.methods
  }

  // MARK: - Private Methods

  @MainActor
  private func performRegistration(
    challenge: String,
    userId: String,
    userName: String
  ) async throws -> ASAuthorizationPlatformPublicKeyCredentialRegistration {
    guard let challengeData = Data(base64URLEncoded: challenge) else {
      throw PasskeyError.registrationFailed("Invalid challenge")
    }

    let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
      relyingPartyIdentifier: relyingPartyIdentifier
    )

    let registrationRequest = platformProvider.createCredentialRegistrationRequest(
      challenge: challengeData,
      name: userName,
      userID: userId.data(using: .utf8)!
    )

    let controller = ASAuthorizationController(authorizationRequests: [registrationRequest])
    controller.delegate = self
    controller.presentationContextProvider = self

    return try await withCheckedThrowingContinuation { continuation in
      self.registrationContinuation = continuation
      controller.performRequests()
    }
  }

  @MainActor
  private func performAuthentication(
    challenge: String
  ) async throws -> ASAuthorizationPlatformPublicKeyCredentialAssertion {
    guard let challengeData = Data(base64URLEncoded: challenge) else {
      throw PasskeyError.authenticationFailed("Invalid challenge")
    }

    let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
      relyingPartyIdentifier: relyingPartyIdentifier
    )

    let assertionRequest = platformProvider.createCredentialAssertionRequest(
      challenge: challengeData
    )

    let controller = ASAuthorizationController(authorizationRequests: [assertionRequest])
    controller.delegate = self
    controller.presentationContextProvider = self

    return try await withCheckedThrowingContinuation { continuation in
      self.authenticationContinuation = continuation
      controller.performRequests()
    }
  }
}

// MARK: - ASAuthorizationControllerDelegate

extension PasskeyService: ASAuthorizationControllerDelegate {
  public func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    switch authorization.credential {
    case let registration as ASAuthorizationPlatformPublicKeyCredentialRegistration:
      registrationContinuation?.resume(returning: registration)
      registrationContinuation = nil

    case let assertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
      authenticationContinuation?.resume(returning: assertion)
      authenticationContinuation = nil

    default:
      break
    }
  }

  public func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    let authError = error as? ASAuthorizationError

    if authError?.code == .canceled {
      registrationContinuation?.resume(throwing: PasskeyError.userCancelled)
      authenticationContinuation?.resume(throwing: PasskeyError.userCancelled)
    } else {
      registrationContinuation?.resume(throwing: PasskeyError.registrationFailed(error.localizedDescription))
      authenticationContinuation?.resume(throwing: PasskeyError.authenticationFailed(error.localizedDescription))
    }

    registrationContinuation = nil
    authenticationContinuation = nil
  }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension PasskeyService: ASAuthorizationControllerPresentationContextProviding {
  @MainActor
  public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first
    else {
      fatalError("No window available for passkey presentation")
    }
    return window
  }
}
