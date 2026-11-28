import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Reemplaza esto por el "ID de cliente web" real de Google Cloud / Firebase
  // (debe terminar en .apps.googleusercontent.com, NO en :web:...)
  static const String _googleServerClientId =
      '251986562473-cujepbu41pq4vurv4d07pho3f1qijasr.apps.googleusercontent.com';
  static const String _appleServerClientId =
      '51986562473-jqeeadbk9me7jskd3eurgq2gjdkdhene.apps.googleusercontent.com';
  static const List<String> _googleScopes = ['email', 'profile'];
  static const List<AppleIDAuthorizationScopes> _appleScopes = [
    AppleIDAuthorizationScopes.email,
    AppleIDAuthorizationScopes.fullName,
  ];

  static const String _appleServerCallbackRedirect =
      'https://geeslyapp.firebaseapp.com/__/auth/handler';
  bool _isGoogleInitialized = false;
  final bool _isAppleInicialized = false;
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    _user = _auth.currentUser;
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_isGoogleInitialized) return;
    await _googleSignIn.initialize(
      serverClientId: kIsWeb ? null : _googleServerClientId,
    );
    _isGoogleInitialized = true;
  
  }


  Future<T?> _runAuthAction<T>(Future<T> Function() action) async {
    _setError(null);
    _setLoading(true);
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Error de autenticación (${e.code})');
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      _setError(
        e.description ?? 'Error al iniciar sesión con Google (${e.code})',
      );
      return null;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      _setError(
        e.message.isNotEmpty ? e.message : 'Error al iniciar sesión con Apple',
      );
      return null;
    } catch (e) {
      _setError('Error inesperado: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // 1. Email y contraseña (Login)
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _runAuthAction(() async {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    });
  }

  // Registro con Email y contraseña
  Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) {
    return _runAuthAction(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName != null && displayName.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
        await credential.user?.reload();
        _user = _auth.currentUser;
      }
      return credential;
    });
  }

  // 2. Google
  Future<UserCredential?> signInWithGoogle() {
    return _runAuthAction(() async {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(googleProvider);
      }

      await _ensureGoogleInitialized();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final String? idToken = googleUser.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-id-token',
          message: 'No se pudo obtener el idToken de Google.',
        );
      }

      // Obtiene el accessToken desde authorizationClient (si ya fue concedido o solicitándolo)
      GoogleSignInClientAuthorization? authz = await googleUser
          .authorizationClient
          .authorizationForScopes(_googleScopes);

      authz ??= await googleUser.authorizationClient.authorizeScopes(
        _googleScopes,
      );

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: authz.accessToken,
      );

      return await _auth.signInWithCredential(credential);
    });
  }

  // 3. Facebook
  Future<UserCredential?> signInWithFacebook() {
    return _runAuthAction(() async {
      if (kIsWeb) {
        final facebookProvider = FacebookAuthProvider();
        return await _auth.signInWithPopup(facebookProvider);
      }

      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status != LoginStatus.success || result.accessToken == null) {
        throw FirebaseAuthException(
          code: 'facebook-login-failed',
          message: result.message ?? 'No se pudo iniciar sesión con Facebook.',
        );
      }

      final OAuthCredential credential = FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );

      return await _auth.signInWithCredential(credential);
    });
  }

  // 4. Apple
  Future<UserCredential?> signInWithApple() {
    return _runAuthAction(() async {
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
        final appleProvider = AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');

        return await _auth.signInWithPopup(appleProvider);
      }

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: _appleScopes,
        /* webAuthenticationOptions: WebAuthenticationOptions(
          clientId: _appleServerClientId,
          redirectUri: Uri.parse(_appleServerCallbackRedirect),
        ),*/
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-apple-id-token',
          message: 'No se pudo obtener el identityToken de Apple.',
        );
      }

      // En AppleAuthProvider.credential: 1er arg = idToken, 2do arg = accessToken / authorizationCode
      final OAuthCredential credential = AppleAuthProvider.credential(
        appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final fullName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ');

      if (fullName.isNotEmpty &&
          (userCredential.user?.displayName == null ||
              userCredential.user!.displayName!.isEmpty)) {
        await userCredential.user?.updateDisplayName(fullName);
        await userCredential.user?.reload();
        _user = _auth.currentUser;
      }

      return userCredential;
    });
  }

  // 5. X (Twitter)
  Future<UserCredential?> signInWithX() {
    return _runAuthAction(() async {
      final twitterProvider = TwitterAuthProvider();
      if (kIsWeb) {
        return await _auth.signInWithPopup(twitterProvider);
      }
      return await _auth.signInWithProvider(twitterProvider);
    });
  }

  // 6. Instagram (vía Custom Token generado por backend / OAuth)
  Future<UserCredential?> signInWithInstagramToken(String customToken) {
    return signInWithCustomToken(customToken);
  }

  // 7. Autenticación directa con Firebase Custom Token
  Future<UserCredential?> signInWithCustomToken(String token) {
    return _runAuthAction(() async {
      if (token.trim().isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-custom-token',
          message: 'El token no puede estar vacío.',
        );
      }
      return await _auth.signInWithCustomToken(token.trim());
    });
  }

  // Recuperar contraseña
  Future<bool> sendPasswordResetEmail(String email) async {
    final result = await _runAuthAction<bool>(() async {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    });
    return result ?? false;
  }

  // Obtener ID Token actual de Firebase
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return await _user?.getIdToken(forceRefresh);
  }

  // Cerrar sesión
  Future<void> signOut() async {
    _setError(null);
    _setLoading(true);
    try {
      await Future.wait([
        _auth.signOut(),
        if (!kIsWeb) _googleSignIn.signOut(),
        FacebookAuth.instance.logOut(),
      ]);
    } finally {
      _setLoading(false);
    }
  }
}
