import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/voter/voter_dashboard_screen.dart';
import 'screens/voter_profile_screen.dart';
import 'screens/voter/proctored_voting_screen.dart';
import 'screens/voter/face_verification_screen.dart';
import 'state/vote.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'services/proctoring_service.dart';
import 'services/mongodb_service.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/election_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const VoteApp());
}

class VoteApp extends StatelessWidget {
  const VoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VoteState()),
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => ElectionProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<BiometricService>(create: (_) => BiometricService()),
        Provider<ProctoringService>(create: (_) => ProctoringService()),
        Provider<MongoDBService>(create: (_) => MongoDBService()),
        StreamProvider<User?>.value(
          value: FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
      ],
      child: Builder(builder: (context) {
        return MaterialApp(
          title: 'E-Votex',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          initialRoute: '/',
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/':
                return MaterialPageRoute(builder: (_) => const HomeScreen());
              case '/login':
                return MaterialPageRoute(builder: (_) => const LoginScreen());
              case '/signup':
                return MaterialPageRoute(builder: (_) => const SignupScreen());
              case '/admin':
                return MaterialPageRoute(
                    builder: (_) => const AdminDashboardScreen());
              case '/voter':
                return MaterialPageRoute(
                    builder: (_) => const VoterDashboardScreen());
              case '/voter/profile':
                return MaterialPageRoute(
                    builder: (_) => const VoterProfileScreen());
              case '/voter/proctored-voting':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => ProctoredVotingScreen(
                    election: args['election'],
                    sessionId: args['sessionId'],
                    onSessionEnd: args['onSessionEnd'],
                  ),
                );
              case '/voter/face-verification':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => FaceVerificationScreen(
                    userId: args['userId'],
                    isRegistration: args['isRegistration'] ?? false,
                  ),
                );
              default:
                return MaterialPageRoute(builder: (_) => const HomeScreen());
            }
          },
        );
      }),
    );
  }
}
