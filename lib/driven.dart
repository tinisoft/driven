library driven;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart' as auth;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:google_sign_in_dartio/google_sign_in_dartio.dart' as dartio;

var _credential = auth.GoogleSignIn.standard(scopes: [
  drive.DriveApi.driveFileScope,
]);

class Driven {
  Driven({required final bool iAcceptTheRisksOfUsingDriven}) {
    if (!iAcceptTheRisksOfUsingDriven) {
      throw ('Please call Driven with "true" to accept the risks of using Driven\r\n'
          'Using a library to manage peoples\' files on Google Drive is serious business, and if Driven blows something up \r\n'
          'the results could be very bad. By using Driven in your apps, you accept these risks.');
    }
  }

  Future<auth.GoogleSignInAccount?> authenticateWithGoogle(String? clientId,
      {int? port}) async {
    port ??= 8080;
    if (Platform.isLinux) {
      await dartio.GoogleSignInDart.register(clientId: clientId!, port: port);
      _credential = auth.GoogleSignIn(clientId: clientId, scopes: [
        drive.DriveApi.driveFileScope,
      ]);
    }
    try {
      final account = await _credential.signIn();
      if (account != null) {
        print('Signed in as $account');
        signedInStream.add(account);
        return account;
      } else {
        final account = await _credential.signIn();
        signedInStream.add(account);
        return account;
      }
    } on PlatformException catch (e) {
      print(e);
      if (!e.message!.contains('SocketException')) {
        return null;
      }
      port += 10;
      authenticateWithGoogle(clientId, port: port);
    } on Exception catch (ex) {
      print(ex);
      signedInStream.add(null);
      return null;
    }

    // }
  }

  Future<bool> isSignedIn() => _credential.isSignedIn();

  Future<void> signOut() async {
    await _credential.signOut();
    signedInStream.add(null);
  }

  final signedInStream = StreamController<auth.GoogleSignInAccount?>();

  Future<auth.GoogleSignInAccount> userDetail(
      {final bool signIn = true}) async {
    if (!(await _credential.isSignedIn())) {
      if (signIn) {
        await authenticateWithGoogle(null);
      } else {
        throw 'User not signed in, and userDetail called with signIn set to false.';
      }
    }

    return _credential
        .currentUser!; // the user is signed in, so we are guarenteed a non-null user object.
  }
}

class GoogleAuthClient extends http.BaseClient {
  final http.Client _client = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final signedIn = await _credential.isSignedIn();
    if (!signedIn) {
      await _credential.signIn();
    }
    final authenticatedUser = _credential.currentUser;
    if (authenticatedUser?.authHeaders == null) {
      throw 'User not authenticated';
    }
    return _client
        .send(request..headers.addAll(await authenticatedUser!.authHeaders));
  }
}

enum LocateFolderResult {
  /// The full path was located
  successful,

  /// Location of the folder only succeeded to a particular point
  partialDepth,
}

class FolderPathBit {
  final String name;
  final String? id;
  final int depth;

  FolderPathBit(
    this.name,
    this.id,
    this.depth,
  );
}
