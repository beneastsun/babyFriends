import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiaoqiao_companion/core/services/reminder_service.dart';
import 'package:qiaoqiao_companion/core/services/overlay_state_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderService - forced rest overlay behavior', () {
    late ProviderContainer container;
    late ReminderService reminderService;
    late OverlayStateManager overlayManager;
    late MockMethodChannel mockChannel;

    setUp(() {
      mockChannel = MockMethodChannel();
      mockChannel.setUp();

      container = ProviderContainer();
      overlayManager = container.read(overlayStateManagerProvider);
      reminderService = container.read(reminderServiceProvider);
    });

    tearDown(() {
      mockChannel.tearDown();
      container.dispose();
    });

    test('forced rest overlay has durationSeconds=0 and no dismiss delay', () async {
      const packageName = 'com.example.game';
      const reason = 'time is up, need to rest';

      final shown = await reminderService.checkAndShowForbiddenReminder(
        packageName: packageName,
        reason: reason,
        ruleType: 'continuous_usage_limit',
        durationSeconds: 600,
      );

      expect(shown, isTrue, reason: 'forced rest overlay should show');

      final currentRequest = overlayManager.currentRequest;
      expect(currentRequest, isNotNull, reason: 'should have active request');
      expect(currentRequest!.type, OverlayType.lock,
          reason: 'forced rest should use lock type to block user');

      // Bug fix verification: no countdown in dialog
      expect(currentRequest.durationSeconds, equals(0),
          reason: 'FIX: forced rest overlay should NOT show countdown - dialog is informational only');

      // Bug fix verification: immediately dismissible
      expect(currentRequest.dismissDelaySeconds, equals(0),
          reason: 'FIX: forced rest overlay should be immediately dismissible');

      // Bug fix verification: should NOT launch main app on dismiss
      expect(currentRequest.launchAppOnDismiss, isFalse,
          reason: 'FIX: forced rest dismiss should NOT launch main app - countdown widget should appear instead');
    });

    test('forced rest overlay can be dismissed immediately', () async {
      const packageName = 'com.example.game';

      await reminderService.checkAndShowForbiddenReminder(
        packageName: packageName,
        reason: 'time is up',
        ruleType: 'continuous_usage_limit',
        durationSeconds: 600,
      );

      expect(overlayManager.state, isNot(OverlayState.idle));

      await overlayManager.dismissCurrent();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(overlayManager.state, OverlayState.idle);
      expect(overlayManager.currentRequest, isNull);
    });

    test('time_period uses lock type (original behavior preserved)', () async {
      const packageName = 'com.example.video';

      final shown = await reminderService.checkAndShowForbiddenReminder(
        packageName: packageName,
        reason: 'blocked by time period',
        ruleType: 'time_period',
      );

      expect(shown, isTrue);
      final request = overlayManager.currentRequest;
      expect(request, isNotNull);
      expect(request!.type, OverlayType.lock,
          reason: 'time_period should use lock type');
    });

    test('continuous_usage_5min uses reminder type (original behavior preserved)', () async {
      const packageName = 'com.example.game';

      final shown = await reminderService.checkAndShowForbiddenReminder(
        packageName: packageName,
        reason: '5 minutes left',
        ruleType: 'continuous_usage_5min',
      );

      expect(shown, isTrue);

      final request = overlayManager.currentRequest;
      expect(request, isNotNull);
      expect(request!.type, isNot(OverlayType.lock),
          reason: '5min warning should use reminder type, not lock');
    });
  });
}

/// Mock for MethodChannel used by OverlayService
class MockMethodChannel {
  static const _channelName = 'com.qiaoqiao.companion/overlay';

  void setUp() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(_channelName),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'showOverlay':
          case 'hideOverlay':
          case 'showCountdownWidget':
          case 'hideCountdownWidget':
          case 'isOverlayShowing':
            return null;
          default:
            return null;
        }
      },
    );
  }

  void tearDown() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(_channelName),
      null,
    );
  }
}