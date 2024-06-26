import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
// import 'package:googleapis_auth.dart';
// Assuming you have a function to handle Google Sign-In

class GoogleSignInProvider extends ChangeNotifier {
  final googleSignIn = GoogleSignIn();
  GoogleSignInAccount? _user;
  bool _isNewUser = true;
  GoogleSignInAccount? get user => _user;
  bool get isNewUser => _isNewUser;

  String _accessToken = '';
  String get accessToken => _accessToken;

  void setAcessToken(String accessToken) {
    _accessToken = accessToken;
    notifyListeners();
  }

  Future googleLogin() async {
    final googleUser =
        await GoogleSignIn(scopes: ['https://mail.google.com/']).signIn();
    if (googleUser == null) return;
    _user = googleUser;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
    setAcessToken(credential.accessToken.toString());
    print("here is the testing");
    print(credential);

    Future<bool> isNewUserMethod(String email) async {
      print("inside here");
      try {
        final methods =
            await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
        notifyListeners();
        return methods.isNotEmpty;
      } catch (e) {
        return false;
      }
    }

    _isNewUser = await isNewUserMethod(googleUser.email);

    await FirebaseAuth.instance.signInWithCredential(credential);
    notifyListeners();
  }

  Future logout() async {
    await googleSignIn.disconnect();
    FirebaseAuth.instance.signOut();
    notifyListeners();
  }
}
