import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/app_theme.dart';
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/public_evaluation_screen.dart';
import 'services/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? bootstrapError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (AppConfig.hasSupabaseConfig) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabasePublishableKey,
        accessToken: () async =>
            FirebaseAuth.instance.currentUser?.getIdToken(),
      );
    }
  } catch (error) {
    bootstrapError = error;
  }

  if (bootstrapError != null) {
    runApp(BootstrapFailureApp(error: bootstrapError));
    return;
  }

  final controller = AppController();
  await controller.initialize();
  runApp(PracticumConnectApp(controller: controller));
}

class PracticumConnectApp extends StatelessWidget {
  const PracticumConnectApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final evaluationToken = Uri.base.queryParameters['evaluation'];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Practicum Connect',
      theme: AppTheme.light,
      home: evaluationToken != null && evaluationToken.isNotEmpty
          ? PublicEvaluationScreen(
              token: evaluationToken,
              repository: controller.repository,
            )
          : AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                if (controller.busy && controller.user == null) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return controller.user == null
                    ? LoginScreen(controller: controller)
                    : DashboardScreen(controller: controller);
              },
            ),
    );
  }
}

class BootstrapFailureApp extends StatelessWidget {
  const BootstrapFailureApp({super.key, required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Backend configuration could not be loaded',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text(
                  'Check firebase_options.dart and the Supabase configuration '
                  'described in SETUP.md.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
