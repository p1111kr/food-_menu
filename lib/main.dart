import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meals/widgets/app_entry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use PKCE auth flow for email verification and password reset
  await Supabase.initialize(
    url: 'https://krrkfaclcofjydufltih.supabase.co',
    anonKey: 'sb_publishable_5nHgvaIFyIPQPPufKd9IhA_jPcLsb3M',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUri: true,
    ),
    debug: kDebugMode,
  );

  debugPrint('[main] Supabase initialized');

  runApp(
    const ProviderScope(
      child: AppEntry(),
    ),
  );
}
