//
//  FirebaseUser.swift
//  FireUI
//
//  Created by Brianna Doubt on 8/30/20.
//

import Foundation
import Firebase
import SwiftUI

public class FirebaseUser: ObservableObject, FirestoreObservable {

    @Published public var isAuthenticated: Bool = true
    @Published public var uid: String?
    
    @Published public var nickname = ""
    @Published public var email = ""
    @Published public var password = ""
    @Published public var verifyPassword = ""

    var listener: ListenerRegistration?
    
    public init(basePath: String, initialize: Bool = false) {
        UINavigationBar.appearance().barTintColor = UIColor(Color("BackgroundColor"))
        
        self.basePath = basePath
        
        if initialize {
            initializeFirebase()
        }
        
        self.isAuthenticated = Auth.auth().currentUser != nil
    }
    
    private var basePath: String
    private var authHandler: AuthStateDidChangeListenerHandle?
    
    private func setAppCheck() {
        let providerFactory = FireAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
    }
    
    private func initializeFirebase() {
        setAppCheck()
        FirebaseApp.configure()
    }
    
    private func stateDidChangeListener(auth: Auth, user: User?) {
        withAnimation {
            guard let user = user else {
                self.isAuthenticated = false
                return
            }
            self.uid = user.uid
            self.isAuthenticated = true
        }
    }

    func setListener() {
        Auth.auth().useAppLanguage()
        Auth.auth().addStateDidChangeListener(stateDidChangeListener(auth:user:))
    }

    public func signUp<Human: Person>(newPerson: (_ uid: PersonID, _ email: String, _ nickname: String) async throws -> Human) async throws {
        if nickname == "" {
            throw FireUIError.missingNickname
        }
        if email == "" {
            throw FireUIError.missingEmailAddress
        }
        if password == "" {
            throw FireUIError.missingPassword
        }
        if verifyPassword == "" {
            throw FireUIError.missingPasswordVerification
        }
        guard password == verifyPassword else {
            throw FireUIError.failedPasswordVerification
        }
        
        let user = try await Auth.auth().createUser(withEmail: email, password: password).user

        try await user.sendEmailVerification()
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = nickname
        
        let uid = user.uid
        
        let person = try await newPerson(uid, email, nickname)
        try person.save()
    }

    public func updateEmail(email: String) async throws {
        try await Auth.auth().currentUser?.updateEmail(to: email)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func signIn() async throws {
        if email.isEmpty {
            throw FireUIError.missingEmailAddress
        }

        if password.isEmpty {
            throw FireUIError.missingPassword
        }
        
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func delete<Human: Person>(person: Human) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FireUIError.userNotFound
        }
        try await user.delete()
        try await person.delete()
    }

    private func updateUserProfile(displayName: String?) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FireUIError.userNotFound
        }
        let changeRequest = user.createProfileChangeRequest()
        if let displayName = displayName {
            changeRequest.displayName = displayName
        }
        try await changeRequest.commitChanges()
    }
}
