// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get aboutFlauncher => '关于 Tazama';

  @override
  String get addCategory => '添加分类';

  @override
  String get addSection => '添加分区';

  @override
  String get alphabetical => '按字母顺序';

  @override
  String get showFocusBorders => '显示焦点边框';

  @override
  String get focusBorderThickness => '焦点边框粗细';

  @override
  String get appInfo => '应用信息';

  @override
  String get appKeyClick => '按键点击音效';

  @override
  String get applications => '应用';

  @override
  String get autoHideAppBar => '自动隐藏状态栏';

  @override
  String get hideStatusBarInGrid => '在网格中隐藏状态栏';

  @override
  String get category => '分类';

  @override
  String get categories => '分类';

  @override
  String get date => '日期';

  @override
  String get delete => '删除';

  @override
  String get dialogTextNoFileExplorer => '请安装文件管理器以选择图片。';

  @override
  String disambiguateCategoryTitle(String title) {
    return '$title（分类）';
  }

  @override
  String get gradient => '渐变';

  @override
  String get favoriteApps => '收藏应用';

  @override
  String get grid => '网格';

  @override
  String get height => '高度';

  @override
  String get hide => '隐藏';

  @override
  String get hiddenApplications => '隐藏的应用';

  @override
  String get launcherSections => '分区';

  @override
  String get layout => '布局';

  @override
  String get loading => '加载中';

  @override
  String get manual => '手动';

  @override
  String get modifySection => '修改分区';

  @override
  String get name => '名称';

  @override
  String get newSection => '新建分区';

  @override
  String get allApplications => '全部应用';

  @override
  String get open => '打开';

  @override
  String get picture => '图片';

  @override
  String removeFrom(String name) {
    return '从 $name 中移除';
  }

  @override
  String get renameCategory => '重命名分类';

  @override
  String get reorder => '重新排序';

  @override
  String get row => '行';

  @override
  String get rowHeight => '行高';

  @override
  String get save => '保存';

  @override
  String get spacer => '间隔';

  @override
  String get settings => '设置';

  @override
  String get show => '显示';

  @override
  String get showCategoryTitles => '显示分类标题';

  @override
  String get sort => '排序';

  @override
  String get systemSettings => '系统设置';

  @override
  String get updateCheck => '检查更新';

  @override
  String get updateNoUpdateTitle => '无可用更新';

  @override
  String updateNoUpdateBody(String currentVersion) {
    return '您已是最新版本（$currentVersion）。';
  }

  @override
  String get updateAvailableTitle => '有可用更新';

  @override
  String updateAvailableBody(String latestVersion, String currentVersion) {
    return '版本 $latestVersion 已发布（当前：$currentVersion）。';
  }

  @override
  String get updateChangelog => '更新内容';

  @override
  String get updateDownloadButton => '下载';

  @override
  String get updateReadyToInstallTitle => '准备安装';

  @override
  String updateReadyToInstallBody(String latestVersion) {
    return '版本 $latestVersion 的 APK 已下载。现在开始安装吗？';
  }

  @override
  String get updateInstallButton => '安装';

  @override
  String get updateInstallPermissionTitle => '需要安装权限';

  @override
  String get updateInstallPermissionBody => '允许 Tazama 安装未知应用，然后重试更新。';

  @override
  String get updateOpenPermissionSettingsButton => '打开权限设置';

  @override
  String get updateErrorGeneric => '检查更新失败，请重试。';

  @override
  String textAboutDialog(String repoUrl) {
    return 'Tazama is an open-source launcher for Android TV, based on Arc Launcher by Meddouri Badis, which builds on LTvLauncher and FLauncher.\n\nSource code available at $repoUrl.';
  }

  @override
  String get textEmptyCategory => '此分类为空。';

  @override
  String get time => '时间';

  @override
  String get type => '类型';

  @override
  String get uninstall => '卸载';

  @override
  String get wallpaper => '壁纸';

  @override
  String get withEllipsisAddTo => '添加到...';

  @override
  String get timeBasedWallpaper => '定时壁纸';

  @override
  String get unsplashSlideshow => 'Unsplash 幻灯片';

  @override
  String get unsplashEnable => '显示 Unsplash 照片';

  @override
  String get unsplashAccessKey => 'Unsplash 访问密钥';

  @override
  String get unsplashAccessKeyHelp =>
      '在 unsplash.com/developers 创建免费应用并粘贴其访问密钥。';

  @override
  String get unsplashNotSet => '未设置';

  @override
  String get unsplashInterval => '更换间隔';

  @override
  String unsplashIntervalMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get slideshowCategories => '分类';

  @override
  String get slideshowDay => '白天（6:00 - 18:00）';

  @override
  String get slideshowNight => '夜间（18:00 - 6:00）';

  @override
  String unsplashPhotoCredit(String author) {
    return '照片：$author / Unsplash';
  }

  @override
  String get pickDayWallpaper => '选择白天壁纸';

  @override
  String get pickNightWallpaper => '选择夜间壁纸';

  @override
  String get video => '视频';

  @override
  String get pickDayVideoWallpaper => '选择白天视频';

  @override
  String get pickNightVideoWallpaper => '选择夜间视频';

  @override
  String get watchNextSectionTitle => '继续观看';

  @override
  String get showWatchNextSection => '显示“继续观看”分区';

  @override
  String get watchNextPermissionTitle => '需要“继续观看”权限';

  @override
  String get watchNextPermissionBody => '允许访问电视节目列表以显示您的继续观看内容。';

  @override
  String get watchNextGrantPermission => '授予权限';

  @override
  String get watchNextCheckPermission => '重新检查';

  @override
  String get system => '系统';

  @override
  String get accentColor => '强调色';

  @override
  String get screensaverSettings => '屏保设置';

  @override
  String get screensaverClockStyle => '屏保时钟样式';

  @override
  String get showAppNamesBelowIcons => '在图标下方显示应用名称';

  @override
  String get networkIndicator => '网络指示器';

  @override
  String get customName => '自定义名称';

  @override
  String get lastUsed => '最近使用';

  @override
  String get grantPermission => '授予权限';

  @override
  String get checkStatus => '检查状态';

  @override
  String get watchNextRefresh => '刷新内容';

  @override
  String get watchNextRefreshDescription => '从媒体提供方重新加载推荐内容';

  @override
  String get watchNextRefreshed => '已刷新“继续观看”内容';

  @override
  String get watchNextFilterApps => '筛选应用';

  @override
  String get watchNextFilterAppsDescription => '选择可在“继续观看”中显示内容的应用';

  @override
  String get watchNextNoApps => '当前没有媒体应用提供“继续观看”内容';

  @override
  String get watchNextShowAllApps => '显示所有已安装应用';

  @override
  String get watchNextMaxItems => '最大节目数';

  @override
  String get watchNextMaxItemsUnlimited => '不限';

  @override
  String get redditWallpaper => 'Reddit 壁纸';

  @override
  String get redditWallpaperEnable => '显示 Reddit 壁纸';

  @override
  String get redditSubreddits => '子版块';

  @override
  String get redditSort => '排序方式';

  @override
  String get redditSortHot => '热门';

  @override
  String get redditSortTopDay => '今日最佳';

  @override
  String get redditSortTopWeek => '本周最佳';

  @override
  String get redditSortTopMonth => '本月最佳';

  @override
  String get redditSortTopAll => '历史最佳';

  @override
  String get redditSortNew => '最新';

  @override
  String get redditInterval => '更换间隔';

  @override
  String redditIntervalMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get redditInterval1Hour => '1 小时';

  @override
  String redditIntervalHours(int hours) {
    return '$hours 小时';
  }

  @override
  String get redditInterval1Day => '1 天';

  @override
  String redditIntervalDays(int days) {
    return '$days 天';
  }

  @override
  String get redditClientId => 'Reddit Client ID（可选）';

  @override
  String get redditClientIdHelp =>
      '可选。在 reddit.com/prefs/apps 创建已安装应用，如果您的网络需要，请粘贴其 ID。';

  @override
  String get redditChangeNow => '立即更换壁纸';

  @override
  String get redditAddSubreddit => '添加自定义子版块';

  @override
  String get redditSubredditName => '子版块名称（不含 r/）';

  @override
  String get redditWallpaperUpdated => '壁纸更新成功';

  @override
  String get redditWallpaperFailed => '获取壁纸失败。如果问题持续，请在设置中配置 Reddit Client ID。';

  @override
  String get addToFavorites => '加入收藏';

  @override
  String get removeFromFavorites => '取消收藏';

  @override
  String get addToCategory => '添加到分类';

  @override
  String get setCustomBanner => '设置自定义横幅';

  @override
  String get clearCustomBanner => '清除自定义横幅';

  @override
  String customBannerSetFailed(String error) {
    return '设置横幅失败：$error';
  }

  @override
  String customBannerClearFailed(String error) {
    return '清除横幅失败：$error';
  }

  @override
  String get selectImage => '选择图片';

  @override
  String get selectVideo => '选择视频';

  @override
  String mediaItemCount(int count) {
    return '$count 个项目';
  }

  @override
  String get noImagesFound => '设备上未找到图片';

  @override
  String get noVideosFound => '设备上未找到视频';

  @override
  String get mediaNavigationHint => '方向键：导航  •  返回键：取消';

  @override
  String get mediaSelectionHint => '方向键：导航  •  选择键：设置壁纸  •  返回键：取消';

  @override
  String get mediaPermissionRequired => '需要媒体访问权限';

  @override
  String get mediaPermissionHelp => '授予权限以浏览照片和视频';

  @override
  String get clockStyleMinimal => '极简';

  @override
  String get clockStyleMinimalDescription => '纤细优雅字体（默认）';

  @override
  String get clockStyleBold => '粗体';

  @override
  String get clockStyleBoldDescription => '粗重醒目的字体';

  @override
  String get clockStyleRetro => '复古';

  @override
  String get clockStyleRetroDescription => '等宽复古终端风格';

  @override
  String get clockStyleElegant => '优雅';

  @override
  String get clockStyleElegantDescription => '经典衬线字体';

  @override
  String get clockStyleNeon => '霓虹';

  @override
  String get clockStyleNeonDescription => '超细发光风格';

  @override
  String get clockStylePixel => '像素';

  @override
  String get clockStylePixelDescription => '粗体等宽，街机感';

  @override
  String get clockStyleDigital => '数字';

  @override
  String get clockStyleDigitalDescription => '简洁等宽显示';

  @override
  String get brightnessPermissionRequired => '需要权限';

  @override
  String get brightnessPermissionHelp => '要在此设备上控制亮度，必须通过 ADB 授予权限：';

  @override
  String get brightnessExperimentalNotice => '实验性功能：此功能尚未测试，未来版本可能会根据用户反馈移除。';

  @override
  String get brightnessDeviceSupportNote => '注意：部分 Android TV 设备可能不支持应用级亮度控制。';

  @override
  String get enableBrightnessScheduler => '启用亮度计划';

  @override
  String currentBrightnessSlot(String slot) {
    return '当前：$slot';
  }

  @override
  String get brightnessSlotMorning => '清晨 6 点 - 上午 9 点';

  @override
  String get brightnessSlotDay => '上午 9 点 - 下午 3 点';

  @override
  String get brightnessSlotAfternoon => '下午 3 点 - 下午 6 点';

  @override
  String get brightnessSlotEvening => '下午 6 点 - 晚上 10 点';

  @override
  String get brightnessSlotNight => '夜间 10 点 - 早上 6 点';
}
