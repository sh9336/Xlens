import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _cropGuideSeenKey = 'crop_guide_seen';
  static const String _homeGuideSeenKey = 'home_guide_seen';

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  Future<bool> isOnboardingComplete() async {
    await initialize();
    return _prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  Future<void> markOnboardingComplete() async {
    await initialize();
    await _prefs.setBool(_onboardingCompleteKey, true);
  }

  Future<bool> isCropGuideSeen() async {
    await initialize();
    return _prefs.getBool(_cropGuideSeenKey) ?? false;
  }

  Future<void> markCropGuideSeen() async {
    await initialize();
    await _prefs.setBool(_cropGuideSeenKey, true);
  }

  Future<bool> isHomeGuideSeen() async {
    await initialize();
    return _prefs.getBool(_homeGuideSeenKey) ?? false;
  }

  Future<void> markHomeGuideSeen() async {
    await initialize();
    await _prefs.setBool(_homeGuideSeenKey, true);
  }

  Future<void> resetAllGuides() async {
    await initialize();
    await _prefs.remove(_onboardingCompleteKey);
    await _prefs.remove(_cropGuideSeenKey);
    await _prefs.remove(_homeGuideSeenKey);
  }
}
