import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/app_localizations.dart';
import 'chemical_mixer_page.dart';
import '../widgets/input_decorations.dart';

// ───── Safelight darkroom palette ─────
const _slBg = Color(0xFF000000);
const _slSurface = Color(0xFF0D0202);
const _slSurfaceHigh = Color(0xFF1A0505);
const _slRed = Color(0xFFCC2020);
const _slRedBright = Color(0xFFFF3B3B);
const _slRedDim = Color(0xFF882222);
const _slRedFaint = Color(0xFF551515);
const _slText = Color(0xFFDD4444);
const _slTextDim = Color(0xFF883333);

ColorScheme _safelightScheme() => const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: _slRed,
      onPrimary: Color(0xFF1A0000),
      primaryContainer: _slRedFaint,
      onPrimaryContainer: _slRedBright,
      secondary: _slRedDim,
      onSecondary: Color(0xFF1A0000),
      secondaryContainer: _slRedFaint,
      onSecondaryContainer: _slText,
      tertiary: _slRedBright,
      onTertiary: Color(0xFF1A0000),
      tertiaryContainer: Color(0xFF3A0E0E),
      onTertiaryContainer: _slRedBright,
      surface: _slSurface,
      onSurface: _slText,
      onSurfaceVariant: _slTextDim,
      error: _slRedBright,
      onError: Color(0xFF1A0000),
      outline: _slRedDim,
      outlineVariant: _slRedFaint,
      surfaceContainerHighest: _slSurfaceHigh,
    );

class TimerRunningPage extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const TimerRunningPage({super.key, required this.recipe});

  @override
  State<TimerRunningPage> createState() => _TimerRunningPageState();
}

class _TimerRunningPageState extends State<TimerRunningPage>
    with WidgetsBindingObserver {
  late List<Map<String, dynamic>> _steps;
  late TextEditingController _tempCtrl;
  late FocusNode _tempFocus;
  double? _baseTemp; // null = N/A (no temp compensation)

  int _currentStep = 0;
  int _remainingSeconds = 0;
  int _elapsedSeconds = 0; // elapsed within current step
  bool _isRunning = false;
  bool _isFinished = false;
  bool _redSafelight = false;
  bool _isAgitating = false; // current agitation phase
  bool _safelightActive = false; // darkroom mode
  Timer? _timer;

  // Wall-clock tracking for background accuracy
  DateTime? _runStartedAt;
  int _remainingAtRunStart = 0;
  int _elapsedAtRunStart = 0;

  // Notifications
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  int _nextNotificationId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    _steps = (widget.recipe['steps'] as List)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    _baseTemp = (widget.recipe['baseTemp'] as num?)?.toDouble();
    _redSafelight = widget.recipe['redSafelight'] as bool? ?? false;
    _safelightActive = _redSafelight; // auto-on
    _tempCtrl = TextEditingController(
        text: _baseTemp?.toStringAsFixed(1) ?? '');
    _tempFocus = FocusNode();
    if (_steps.isNotEmpty) {
      _remainingSeconds = _adjustedTime(0);
      _elapsedSeconds = 0;
      _isAgitating = _shouldAgitateAt(0, 0);
    }
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _cancelAllNotifications();
    _tempCtrl.dispose();
    _tempFocus.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isRunning) {
      _recalculateFromWallClock();
    }
  }

  Future<void> _initNotifications() async {
    // Skip on Windows — our stub throws UnsupportedError
    if (!kIsWeb && Platform.isWindows) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    const linux = LinuxInitializationSettings(defaultActionName: 'Open');
    const init = InitializationSettings(
        android: android, iOS: darwin, macOS: darwin, linux: linux);
    await _notifications.initialize(init);

    // Request permission on Android 13+
    if (!kIsWeb && Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  void _recalculateFromWallClock() {
    if (_runStartedAt == null) return;
    final elapsed = DateTime.now().difference(_runStartedAt!).inSeconds;
    final newRemaining = _remainingAtRunStart - elapsed;
    final newElapsed = _elapsedAtRunStart + elapsed;

    if (newRemaining <= 0) {
      _onStepComplete();
    } else {
      setState(() {
        _remainingSeconds = newRemaining;
        _elapsedSeconds = newElapsed;
        _isAgitating = _shouldAgitateAt(_currentStep, newElapsed);
      });
    }
  }

  double? get _actualTemp {
    if (_baseTemp == null) return null;
    return double.tryParse(_tempCtrl.text) ?? _baseTemp;
  }

  bool get _hasTempCompensation => _baseTemp != null;

  int _adjustedTime(int stepIndex) {
    final step = _steps[stepIndex];
    final baseTime = (step['time'] as int? ?? 60).toDouble();
    final type = step['type'] as String;
    if ((type == 'develop' || type == 'custom') && _hasTempCompensation) {
      final actual = _actualTemp!;
      return (baseTime * math.exp(0.081 * (_baseTemp! - actual))).round();
    }
    return baseTime.round();
  }

  bool _shouldAgitateAt(int stepIndex, int elapsed) {
    if (stepIndex >= _steps.length) return false;
    final step = _steps[stepIndex];
    final type = step['type'] as String;
    if (type != 'develop' && type != 'custom') return false;
    final agitation = step['agitation'] as Map<String, dynamic>?;
    final method = agitation?['method'] as String?;
    if (agitation == null || (method != 'hand' && method != 'stand')) {
      return false;
    }

    final initialDuration = agitation['initialDuration'] as int? ?? 30;

    if (elapsed < initialDuration) return true;
    if (method == 'stand') return false;

    final period = agitation['period'] as int? ?? 60;
    final duration = agitation['duration'] as int? ?? 10;
    if (period <= 0) return false;

    final afterInitial = elapsed - initialDuration;
    final posInCycle = afterInitial % period;
    return posInCycle >= (period - duration);
  }

  void _start() {
    if (_isFinished) return;
    _runStartedAt = DateTime.now();
    _remainingAtRunStart = _remainingSeconds;
    _elapsedAtRunStart = _elapsedSeconds;
    setState(() => _isRunning = true);
    _scheduleNotifications();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recalculateFromWallClock();
      if (_remainingSeconds <= 1 && _isRunning) {
        _onStepComplete();
      } else if (_isRunning) {
        final newAgitating =
            _shouldAgitateAt(_currentStep, _elapsedSeconds);
        if (newAgitating != _isAgitating) {
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.click);
        }
        setState(() => _isAgitating = newAgitating);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    _cancelAllNotifications();
    _runStartedAt = null;
    setState(() => _isRunning = false);
  }

  void _onStepComplete() {
    _timer?.cancel();
    _cancelAllNotifications();
    _runStartedAt = null;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    if (_currentStep < _steps.length - 1) {
      final nextStep = _currentStep + 1;
      setState(() {
        _currentStep = nextStep;
        _remainingSeconds = _adjustedTime(nextStep);
        _elapsedSeconds = 0;
        _isAgitating = _shouldAgitateAt(nextStep, 0);
        _isRunning = false;
      });
    } else {
      setState(() {
        _isRunning = false;
        _isFinished = true;
        _remainingSeconds = 0;
        _elapsedSeconds = 0;
      });
    }
  }

  void _skipStep() {
    _timer?.cancel();
    _onStepComplete();
  }

  void _reset() {
    _timer?.cancel();
    _cancelAllNotifications();
    _runStartedAt = null;
    setState(() {
      _currentStep = 0;
      _remainingSeconds = _steps.isNotEmpty ? _adjustedTime(0) : 0;
      _elapsedSeconds = 0;
      _isAgitating = _steps.isNotEmpty ? _shouldAgitateAt(0, 0) : false;
      _isRunning = false;
      _isFinished = false;
    });
  }

  void _cancelAllNotifications() {
    _notifications.cancelAll();
    _nextNotificationId = 0;
  }

  void _scheduleNotifications() {
    _cancelAllNotifications();
    final step = _steps[_currentStep];
    final type = step['type'] as String;
    final l = AppLocalizations.of(context);
    final stepLabel = _stepDisplayLabel(_currentStep, l);

    _scheduleNotification(
      delay: Duration(seconds: _remainingSeconds),
      title: stepLabel,
      body: l.t('timer_notif_step_complete'),
    );

    if (type == 'develop' || type == 'custom') {
      final agitation = step['agitation'] as Map<String, dynamic>?;
      final agMethod = agitation?['method'] as String?;
      if (agitation != null && (agMethod == 'hand' || agMethod == 'stand')) {
        final initialDuration = agitation['initialDuration'] as int? ?? 30;

        if (agMethod == 'hand') {
          final period = agitation['period'] as int? ?? 60;
          final duration = agitation['duration'] as int? ?? 10;
          final totalTime = _adjustedTime(_currentStep);

          for (int n = 0;; n++) {
            final agitateStart =
                initialDuration + (n + 1) * period - duration;
            if (agitateStart >= totalTime) break;
            final fromNow = agitateStart - _elapsedSeconds;
            if (fromNow > 0 && fromNow < _remainingSeconds) {
              _scheduleNotification(
                delay: Duration(seconds: fromNow),
                title: stepLabel,
                body: l.t('timer_notif_agitate'),
              );
            }
          }
        }
      }
    }
  }

  Future<void> _scheduleNotification({
    required Duration delay,
    required String title,
    required String body,
  }) async {
    final id = _nextNotificationId++;
    const androidDetails = AndroidNotificationDetails(
      'darkroom_timer',
      'Darkroom Timer',
      channelDescription: 'Timer step and agitation notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    Future.delayed(delay, () {
      if (_isRunning && mounted) {
        _notifications.show(id, title, body, details);
      }
    });
  }

  void _onTempChanged() {
    if (!_isRunning && !_isFinished) {
      setState(() {
        _remainingSeconds = _adjustedTime(_currentStep);
      });
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  IconData _stepIcon(String type) {
    switch (type) {
      case 'develop': return Icons.science;
      case 'stop': return Icons.stop_circle_outlined;
      case 'fix': return Icons.lock_clock;
      case 'wash': return Icons.water_drop;
      case 'rinse': return Icons.opacity;
      case 'custom': return Icons.info_outline;
      default: return Icons.help_outline;
    }
  }

  Widget _buildAgitationPhase(
      Map<String, dynamic> step, AppLocalizations l, ColorScheme cs) {
    final agitation = step['agitation'] as Map<String, dynamic>?;
    if (agitation == null) return const SizedBox.shrink();
    final method = agitation['method'] as String? ?? 'hand';

    if (method == 'disable') return const SizedBox.shrink();

    if (method == 'rolling') {
      final speed = agitation['speed'] as int? ?? 60;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rotate_right,
                size: 18, color: cs.onPrimaryContainer),
            const SizedBox(width: 6),
            Text(
              '${l.t("recipe_agitation_rolling")} $speed ${l.t("recipe_agitation_rpm")}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onPrimaryContainer),
            ),
          ],
        ),
      );
    }

    // Hand agitation — show current phase
    final isAgitating = _isAgitating && _isRunning;
    final phaseColor =
        isAgitating ? cs.tertiary : cs.onSurfaceVariant;
    final bgColor =
        isAgitating ? cs.tertiaryContainer : cs.surfaceContainerHighest;
    final phaseLabel =
        isAgitating ? l.t('timer_agitate') : l.t('timer_rest');
    final phaseIcon =
        isAgitating ? Icons.back_hand : Icons.pause_circle_outline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(phaseIcon,
                key: ValueKey(isAgitating), size: 18, color: phaseColor),
          ),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              phaseLabel,
              key: ValueKey(isAgitating),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: phaseColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeInfo(ColorScheme cs) {
    final r = widget.recipe;
    final filmStock = r['filmStock'] as String? ?? '';
    final developer = r['developer'] as String? ?? '';
    final dilution = r['dilution'] as String? ?? '';
    final lines = <(IconData, String)>[
      if (filmStock.isNotEmpty) (Icons.camera_roll_outlined, filmStock),
      if (developer.isNotEmpty) (Icons.science_outlined, developer),
      if (dilution.isNotEmpty) (Icons.opacity, dilution),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, text) in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _stepDisplayLabel(int index, AppLocalizations l) {
    final step = _steps[index];
    final type = step['type'] as String;
    final label = step['label'] as String?;
    if ((type == 'develop' || type == 'custom') &&
        label != null &&
        label.isNotEmpty) {
      return label;
    }
    switch (type) {
      case 'develop': return l.t('recipe_step_develop');
      case 'stop': return l.t('recipe_step_stop');
      case 'fix': return l.t('recipe_step_fix');
      case 'wash': return l.t('recipe_step_wash');
      case 'rinse': return l.t('recipe_step_rinse');
      case 'custom': return l.t('recipe_step_custom');
      default: return type;
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isRunning) return true;
    final l = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('timer_exit_title')),
        content: Text(l.t('timer_exit_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('timer_exit_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.t('timer_exit_confirm')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ───── Step row (current / past / future) ─────

  Widget _buildStepRow(int i, AppLocalizations l, ColorScheme cs,
      {required bool isCurrent, required bool isDone}) {
    final step = _steps[i];
    final type = step['type'] as String;
    final time = isCurrent ? _remainingSeconds : _adjustedTime(i);

    if (isCurrent) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_stepIcon(type), color: cs.primary, size: 28),
                const SizedBox(width: 8),
                Text(
                  _stepDisplayLabel(i, l),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: cs.onSurface, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _formatTime(time),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
            ),
            if ((type == 'develop' || type == 'custom') &&
                _hasTempCompensation &&
                _actualTemp != _baseTemp) ...[
              const SizedBox(height: 4),
              Text(
                '${l.t("timer_base")}: ${_formatTime((step['time'] as int? ?? 60))} @ ${_baseTemp!.toStringAsFixed(1)}\u00b0C',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
            if (type == 'develop' || type == 'custom') ...[
              const SizedBox(height: 10),
              _buildAgitationPhase(step, l, cs),
            ],
          ],
        ),
      );
    }

    // Past or future step — compact row
    final color = isDone
        ? (cs.onSurfaceVariant).withValues(alpha: 0.4)
        : (cs.onSurfaceVariant).withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 32),
      child: Row(
        children: [
          if (isDone)
            Icon(Icons.check_circle, size: 16, color: color)
          else
            Icon(_stepIcon(type), size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _stepDisplayLabel(i, l),
              style: TextStyle(
                fontSize: 14,
                color: color,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Text(
            isDone ? '--:--' : _formatTime(time),
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRoll(AppLocalizations l, ColorScheme cs) {
    return Column(
      key: ValueKey(_currentStep),
      children: [
        // Completed steps — pinned to bottom of top area
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (int i = math.max(0, _currentStep - 2);
                  i < _currentStep;
                  i++)
                _buildStepRow(i, l, cs, isCurrent: false, isDone: true),
            ],
          ),
        ),
        // Current step — fixed center
        _buildStepRow(_currentStep, l, cs, isCurrent: true, isDone: false),
        // Remaining steps — pinned to top of bottom area
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              for (int i = _currentStep + 1;
                  i < math.min(_steps.length, _currentStep + 3);
                  i++)
                _buildStepRow(i, l, cs, isCurrent: false, isDone: false),
            ],
          ),
        ),
      ],
    );
  }

  // ───── Safelight toggle chip ─────

  Widget _buildSafelightChip(AppLocalizations l, ColorScheme cs) {
    if (!_redSafelight) {
      // Recipe doesn't allow safelight — muted badge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lightbulb_outline,
                size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(l.t('timer_safelight_off'),
                style:
                    TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    // Recipe allows safelight — tappable glowing chip
    return GestureDetector(
      onTap: () => setState(() => _safelightActive = !_safelightActive),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _safelightActive ? const Color(0xFF3A0808) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _safelightActive ? _slRed : cs.outline,
            width: _safelightActive ? 1.5 : 0.5,
          ),
          boxShadow: _safelightActive
              ? [
                  BoxShadow(
                    color: _slRed.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb,
              size: 14,
              color: _safelightActive ? _slRedBright : cs.primary,
            ),
            const SizedBox(width: 5),
            Text(
              l.t('timer_safelight_on'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _safelightActive ? _slRedBright : cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───── Build ─────

  @override
  Widget build(BuildContext context) {
    final defaultCs = Theme.of(context).colorScheme;
    final cs = _safelightActive ? _safelightScheme() : defaultCs;
    final l = AppLocalizations.of(context);

    final scaffoldBg = _safelightActive ? _slBg : null;
    final appBarBg = _safelightActive ? _slSurface : null;

    return PopScope(
      canPop: !_isRunning,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) Navigator.pop(context);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        color: scaffoldBg ?? Theme.of(context).scaffoldBackgroundColor,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: cs.onSurface),
              onPressed: () async {
                if (_isRunning) {
                  final shouldPop = await _onWillPop();
                  if (shouldPop && context.mounted) Navigator.pop(context);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(l.t('timer_title'),
                style: TextStyle(color: cs.onSurface)),
            backgroundColor: appBarBg ?? Colors.transparent,
            foregroundColor: cs.onSurface,
            elevation: 0,
            actions: [
              if ((widget.recipe['dilution'] as String? ?? '').isNotEmpty)
                IconButton(
                  icon: Icon(Icons.science_outlined, color: cs.onSurface),
                  tooltip: l.t('mixer_title'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChemicalMixerPage(
                        prefillDilution:
                            widget.recipe['dilution'] as String?,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // Temperature input + safelight toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Text(l.t('timer_actual_temp'),
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    if (!_hasTempCompensation)
                      Text(l.t('recipe_temp_na'),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant))
                    else ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IntrinsicWidth(
                        child: TextField(
                          controller: _tempCtrl,
                          focusNode: _tempFocus,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          maxLength: 5,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                              height: 1),
                          decoration: underlineAlwaysDecoration(cs,
                            suffixText: '\u00b0C',
                            suffixStyle:
                                TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                          ),
                          onChanged: (_) => _onTempChanged(),
                          enabled: !_isRunning,
                        ),
                      ),
                      ),
                      if (_actualTemp != _baseTemp) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${l.t("timer_base")}: ${_baseTemp!.toStringAsFixed(1)}\u00b0C)',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                    const Spacer(),
                    _buildSafelightChip(l, cs),
                  ],
                ),
              ),

              // Recipe info
              const SizedBox(height: 8),
              _buildRecipeInfo(cs),
              const SizedBox(height: 8),

              // Step roll
              Expanded(
                child: _isFinished
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                size: 80, color: cs.primary),
                            const SizedBox(height: 16),
                            Text(l.t('timer_complete'),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(color: cs.onSurface)),
                          ],
                        ),
                      )
                    : ClipRect(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            final isIncoming =
                                child.key == ValueKey(_currentStep);
                            final offset = isIncoming
                                ? Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero,
                                  ).animate(animation)
                                : Tween<Offset>(
                                    begin: Offset.zero,
                                    end: const Offset(0, -0.3),
                                  ).animate(animation);
                            return SlideTransition(
                              position: offset,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: _buildStepRoll(l, cs),
                        ),
                      ),
              ),

              // Controls
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: _isFinished
                    ? FilledButton.icon(
                        onPressed: _reset,
                        icon: Icon(Icons.replay,
                            color: _safelightActive
                                ? const Color(0xFF1A0000)
                                : null),
                        label: Text(l.t('timer_reset'),
                            style: TextStyle(
                                color: _safelightActive
                                    ? const Color(0xFF1A0000)
                                    : null)),
                        style: _safelightActive
                            ? FilledButton.styleFrom(
                                backgroundColor: _slRed)
                            : null,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton.outlined(
                            onPressed: _reset,
                            icon: Icon(Icons.replay, color: cs.onSurface),
                            tooltip: l.t('timer_reset'),
                            style: IconButton.styleFrom(
                              side: BorderSide(color: cs.outline),
                            ),
                          ),
                          _safelightActive
                              ? FilledButton.icon(
                                  onPressed:
                                      _isRunning ? _pause : _start,
                                  icon: Icon(
                                    _isRunning
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: const Color(0xFF1A0000),
                                  ),
                                  label: Text(
                                    _isRunning
                                        ? l.t('timer_pause')
                                        : l.t('timer_start'),
                                    style: const TextStyle(
                                        color: Color(0xFF1A0000),
                                        fontWeight: FontWeight.w600),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _slRed,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                  ),
                                )
                              : FilledButton.tonalIcon(
                                  onPressed:
                                      _isRunning ? _pause : _start,
                                  icon: Icon(_isRunning
                                      ? Icons.pause
                                      : Icons.play_arrow),
                                  label: Text(_isRunning
                                      ? l.t('timer_pause')
                                      : l.t('timer_start')),
                                ),
                          IconButton.outlined(
                            onPressed: _currentStep <
                                        _steps.length - 1 ||
                                    _isRunning
                                ? _skipStep
                                : null,
                            icon: Icon(Icons.skip_next,
                                color:
                                    (_currentStep < _steps.length - 1 ||
                                            _isRunning)
                                        ? cs.onSurface
                                        : cs.onSurfaceVariant
                                            .withValues(alpha: 0.3)),
                            tooltip: l.t('timer_skip'),
                            style: IconButton.styleFrom(
                              side: BorderSide(color: cs.outline),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
