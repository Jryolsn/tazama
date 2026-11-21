/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';

import 'package:flauncher/providers/reddit_slideshow.dart';
import 'package:flauncher/providers/unsplash_slideshow.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

const _appKeyClickEnabledKey = "app_key_click_enabled";
const _autoHideAppBar = "auto_hide_app_bar";
const _gradientUuidKey = "gradient_uuid";
const _showCategoryTitles = "show_category_titles";
const _showAppNamesBelowIcons = "show_app_names_below_icons";
const _showDateInStatusBar = "show_date_in_status_bar";
const _showTimeInStatusBar = "show_time_in_status_bar";
const String _showNetworkIndicatorInStatusBar = "show_network_indicator_in_status_bar";
const String _screensaverClockStyle = "screensaver_clock_style";
const String _watchNextMaxItems = "watch_next_max_items";
const String _watchNextExcludedPackages = "watch_next_excluded_packages";

const List<int> WATCH_NEXT_MAX_ITEMS_OPTIONS = [0, 5, 10, 15, 20, 25, 30, 50];

// Fixed focus look (no longer user settings).
const double FOCUS_BORDER_DEFAULT = 1.5;
const String ACCENT_COLOR_WHITE = "FFFFFF";


/// Shortcuts the quick panel can show, in default order.
const List<String> quickPanelItemIds = ['dim', 'vpn', 'lock', 'camera', 'mediaPanel'];


class SettingsService extends ChangeNotifier {
  static final defaultDateFormat = "EEEE d";
  static final defaultTimeFormat = "H:mm";
  final SharedPreferences _sharedPreferences;

  bool get appHighlightAnimationEnabled => false;

  /// "Replace current launcher" (replace_launcher_page.dart): Arc acts as home without being the default.
  bool get replaceLauncher => _sharedPreferences.getBool("replace_launcher") ?? false;

  bool get appKeyClickEnabled => _sharedPreferences.getBool(_appKeyClickEnabledKey) ?? true;

  bool get autoHideAppBarEnabled => _sharedPreferences.getBool(_autoHideAppBar) ?? false;

  bool get showCategoryTitles => _sharedPreferences.getBool(_showCategoryTitles) ?? false;

  bool get showAppNamesBelowIcons => _sharedPreferences.getBool(_showAppNamesBelowIcons) ?? false;

  bool get showDateInStatusBar => _sharedPreferences.getBool(_showDateInStatusBar) ?? false;

  bool get showTimeInStatusBar => _sharedPreferences.getBool(_showTimeInStatusBar) ?? true;

  String? get gradientUuid => _sharedPreferences.getString(_gradientUuidKey);

  String get dateFormat => defaultDateFormat;

  String get timeFormat => defaultTimeFormat;

  bool get showNetworkIndicatorInStatusBar => _sharedPreferences.getBool(_showNetworkIndicatorInStatusBar) ?? true;

  String get accentColorHex => ACCENT_COLOR_WHITE;

  String get screensaverClockStyle => _sharedPreferences.getString(_screensaverClockStyle) ?? "minimal";

  int get watchNextMaxItems => _sharedPreferences.getInt(_watchNextMaxItems) ?? 0;

  bool get showFocusBorders => true;

  double get focusBorderThickness => FOCUS_BORDER_DEFAULT;

  Color get accentColor {
    final hex = accentColorHex;
    return Color(int.parse("0xFF$hex"));
  }

  SettingsService(this._sharedPreferences);

  Future<void> set(String key, bool value) async {
    await _sharedPreferences.setBool(key, value);
    notifyListeners();
  }

  Future<void> setAppKeyClickEnabled(bool value) async {
    return set(_appKeyClickEnabledKey, value);
  }

  Future<void> setAutoHideAppBarEnabled(bool value) async {
    return set(_autoHideAppBar, value);
  }

  Future<void> setGradientUuid(String value) async {
    await _sharedPreferences.setString(_gradientUuidKey, value);
    notifyListeners();
  }

  Future<void> setShowCategoryTitles(bool show) async {
    return set(_showCategoryTitles, show);
  }

  Future<void> setShowAppNamesBelowIcons(bool show) async {
    return set(_showAppNamesBelowIcons, show);
  }

  /// The category shown in the taskbar at the bottom of the home screen.
  int? get taskbarCategoryId => _sharedPreferences.getInt("taskbar_category_id");

  Future<void> setTaskbarCategoryId(int id) async {
    await _sharedPreferences.setInt("taskbar_category_id", id);
    notifyListeners();
  }

  /// Quick panel shortcuts in the user's order; ids unknown to this version are dropped
  /// and new ones are appended, so updates never lose or hide a shortcut silently.
  List<String> get quickPanelOrder {
    final saved = _sharedPreferences.getStringList("quick_panel_order") ?? const [];
    return [
      ...saved.where(quickPanelItemIds.contains),
      ...quickPanelItemIds.where((id) => !saved.contains(id)),
    ];
  }

  Set<String> get quickPanelHidden =>
      (_sharedPreferences.getStringList("quick_panel_hidden") ?? const []).toSet();

  Future<void> moveQuickPanelItem(String id, int delta) async {
    final order = quickPanelOrder;
    final from = order.indexOf(id);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= order.length) return;
    order.insert(to, order.removeAt(from));
    await _sharedPreferences.setStringList("quick_panel_order", order);
    notifyListeners();
  }

  Future<void> setQuickPanelItemShown(String id, bool shown) async {
    final hidden = quickPanelHidden;
    shown ? hidden.remove(id) : hidden.add(id);
    await _sharedPreferences.setStringList("quick_panel_hidden", hidden.toList());
    notifyListeners();
  }

  // Per-category overrides; fall back to the global switches when unset.
  int _categoryUiRevision = 0;
  int get categoryUiRevision => _categoryUiRevision;

  bool showTitleFor(int categoryId) =>
      _sharedPreferences.getBool("category_${categoryId}_show_title") ?? showCategoryTitles;

  bool showAppNamesFor(int categoryId) =>
      _sharedPreferences.getBool("category_${categoryId}_show_app_names") ?? showAppNamesBelowIcons;

  Future<void> setCategoryShowTitle(int categoryId, bool show) async {
    _categoryUiRevision++;
    return set("category_${categoryId}_show_title", show);
  }

  Future<void> setCategoryShowAppNames(int categoryId, bool show) async {
    _categoryUiRevision++;
    return set("category_${categoryId}_show_app_names", show);
  }

  Future<void> setShowDateInStatusBar(bool show) async {
    return set(_showDateInStatusBar, show);
  }

  Future<void> setShowTimeInStatusBar(bool show) async {
    return set(_showTimeInStatusBar, show);
  }

  Future<void> setShowNetworkIndicatorInStatusBar(bool show) async {
    return set(_showNetworkIndicatorInStatusBar, show);
  }

  Future<void> setScreensaverClockStyle(String style) async {
    await _sharedPreferences.setString(_screensaverClockStyle, style);
    notifyListeners();
  }

  Future<void> setWatchNextMaxItems(int value) async {
    await _sharedPreferences.setInt(_watchNextMaxItems, value);
    notifyListeners();
  }

  List<String> get watchNextExcludedPackages =>
      _sharedPreferences.getStringList(_watchNextExcludedPackages) ?? const [];

  Future<void> setWatchNextExcludedPackages(List<String> packages) async {
    await _sharedPreferences.setStringList(_watchNextExcludedPackages, packages);
    notifyListeners();
  }

  Future<void> toggleWatchNextExcludedPackage(String packageName) async {
    final current = List<String>.from(watchNextExcludedPackages);
    if (current.contains(packageName)) {
      current.remove(packageName);
    } else {
      current.add(packageName);
    }
    await setWatchNextExcludedPackages(current);
  }

  bool isWatchNextPackageExcluded(String packageName) =>
      watchNextExcludedPackages.contains(packageName);

  bool get timeBasedWallpaperEnabled => _sharedPreferences.getBool("time_based_wallpaper_enabled") ?? false;

  Future<void> setTimeBasedWallpaperEnabled(bool enabled) async {
    await _sharedPreferences.setBool("time_based_wallpaper_enabled", enabled);
    notifyListeners();
  }

  /// Each user brings their own Unsplash API access key (Demo apps are limited to 50 requests/hour).
  String get unsplashAccessKey => _sharedPreferences.getString("unsplash_access_key") ?? "";

  Future<void> setUnsplashAccessKey(String key) async {
    await _sharedPreferences.setString("unsplash_access_key", key.trim());
    if (key.trim().isEmpty) {
      await _sharedPreferences.setBool("unsplash_slideshow_enabled", false);
    }
    notifyListeners();
  }

  /// The slideshow only runs with an access key.
  bool get unsplashSlideshowEnabled =>
      unsplashAccessKey.isNotEmpty && (_sharedPreferences.getBool("unsplash_slideshow_enabled") ?? false);

  static const List<int> unsplashIntervalChoices = [5, 10, 30, 60];

  int get unsplashIntervalMinutes => _sharedPreferences.getInt("unsplash_interval_minutes") ?? 10;

  Future<void> setUnsplashIntervalMinutes(int minutes) async {
    await _sharedPreferences.setInt("unsplash_interval_minutes", minutes);
    notifyListeners();
  }

  /// Slideshow sources: search keywords, "topics:ID,ID" or "collections:ID,ID".
  /// Slideshow category keys (see slideshowSources) used from 6h to 18h, and the rest of the time.
  List<String> get unsplashDaySources =>
      _sharedPreferences.getStringList("unsplash_day_sources") ?? defaultDaySlideshowSources;

  List<String> get unsplashNightSources =>
      _sharedPreferences.getStringList("unsplash_night_sources") ?? defaultNightSlideshowSources;

  Future<void> setUnsplashSources({required bool day, required List<String> keys}) async {
    await _sharedPreferences.setStringList(day ? "unsplash_day_sources" : "unsplash_night_sources", keys);
    notifyListeners();
  }

  Future<void> setUnsplashSlideshowEnabled(bool enabled) async {
    await _sharedPreferences.setBool("unsplash_slideshow_enabled", enabled);
    if (enabled) {
      await _sharedPreferences.setBool("reddit_wallpaper_enabled", false);
    }
    notifyListeners();
  }

  /// Photographer of the slideshow image on screen, kept across restarts for attribution.
  String? get unsplashAuthor => _sharedPreferences.getString("unsplash_author");

  Future<void> setUnsplashAuthor(String author) => _sharedPreferences.setString("unsplash_author", author);

  // Reddit Wallpaper Settings

  bool get redditWallpaperEnabled => _sharedPreferences.getBool("reddit_wallpaper_enabled") ?? false;

  Future<void> setRedditWallpaperEnabled(bool enabled) async {
    await _sharedPreferences.setBool("reddit_wallpaper_enabled", enabled);
    if (enabled) {
      await _sharedPreferences.setBool("unsplash_slideshow_enabled", false);
    }
    notifyListeners();
  }

  static const List<int> redditIntervalChoices = [5, 10, 30, 60, 360, 720, 1440];

  int get redditIntervalMinutes => _sharedPreferences.getInt("reddit_interval_minutes") ?? 10;

  Future<void> setRedditIntervalMinutes(int minutes) async {
    await _sharedPreferences.setInt("reddit_interval_minutes", minutes);
    notifyListeners();
  }

  List<String> get redditSubreddits => _sharedPreferences.getStringList("reddit_subreddits") ?? defaultRedditSubreddits;

  Future<void> setRedditSubreddits(List<String> subreddits) async {
    await _sharedPreferences.setStringList("reddit_subreddits", subreddits);
    notifyListeners();
  }

  String get redditSort => _sharedPreferences.getString("reddit_sort") ?? RedditSort.hot.key;

  Future<void> setRedditSort(String sort) async {
    await _sharedPreferences.setString("reddit_sort", sort);
    notifyListeners();
  }

  String get redditClientId => _sharedPreferences.getString("reddit_client_id") ?? "";

  Future<void> setRedditClientId(String clientId) async {
    await _sharedPreferences.setString("reddit_client_id", clientId.trim());
    notifyListeners();
  }

  String get redditClientSecret => _sharedPreferences.getString("reddit_client_secret") ?? "";

  Future<void> setRedditClientSecret(String secret) async {
    await _sharedPreferences.setString("reddit_client_secret", secret.trim());
    notifyListeners();
  }

  String? get redditCurrentTitle => _sharedPreferences.getString("reddit_current_title");
  String? get redditCurrentAuthor => _sharedPreferences.getString("reddit_current_author");
  String? get redditCurrentSubreddit => _sharedPreferences.getString("reddit_current_subreddit");

  Future<void> setRedditWallpaperInfo({
    required String title,
    required String author,
    required String subreddit,
  }) async {
    await _sharedPreferences.setString("reddit_current_title", title);
    await _sharedPreferences.setString("reddit_current_author", author);
    await _sharedPreferences.setString("reddit_current_subreddit", subreddit);
    notifyListeners();
  }
}
