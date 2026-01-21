import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/services/onboarding_service.dart';
import 'core/services/theme_service.dart';
import 'features/ocr/bloc/ocr_bloc.dart';
import 'features/ocr/screens/home_screen.dart';
import 'features/ocr/screens/onboarding_screen.dart';
import 'features/ocr/services/ocr_service.dart';

final themeNotifier = ValueNotifier<AppThemeMode>(AppThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable Edge-to-Edge UI for modern Android/iOS look
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );

  final themeService = ThemeService();
  await themeService.initialize();
  final savedTheme = await themeService.getThemeMode();
  themeNotifier.value = savedTheme;
  runApp(const OCRApp());
}

class OCRApp extends StatelessWidget {
  const OCRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [RepositoryProvider(create: (context) => OcrService())],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => OcrBloc(context.read<OcrService>()),
          ),
        ],
        child: ValueListenableBuilder<AppThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, themeMode, _) {
            ThemeData theme;
            if (themeMode == AppThemeMode.dark) {
              theme = AppTheme.darkTheme;
            } else if (themeMode == AppThemeMode.light) {
              theme = AppTheme.lightTheme;
            } else {
              // System theme - use dark theme as default, you can adjust this
              final brightness = MediaQuery.platformBrightnessOf(context);
              theme = brightness == Brightness.light
                  ? AppTheme.lightTheme
                  : AppTheme.darkTheme;
            }

            return MaterialApp(
              title: 'Xlens OCR',
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: const _AppWrapper(),
            );
          },
        ),
      ),
    );
  }
}

class _AppWrapper extends StatefulWidget {
  const _AppWrapper();

  @override
  State<_AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<_AppWrapper> {
  late final OnboardingService _onboardingService;
  bool? _isOnboardingComplete;

  @override
  void initState() {
    super.initState();
    _onboardingService = OnboardingService();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final isComplete = await _onboardingService.isOnboardingComplete();
    if (mounted) {
      setState(() {
        _isOnboardingComplete = isComplete;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading/splash while checking status
    if (_isOnboardingComplete == null) {
      final theme = Theme.of(context);
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    // Direct synchronous switch - no "waiting" state flashed
    if (_isOnboardingComplete!) {
      return const HomeScreen();
    }

    return OnboardingScreen(
      onOnboardingComplete: () {
        setState(() {
          _isOnboardingComplete = true; // Instantly switch to HomeScreen
        });
      },
    );
  }
}
