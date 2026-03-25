# Known Issues

## MissingPluginException on Windows: EventChannel file_intent/events

**Status:** Open
**Platform:** Windows (desktop)
**Severity:** Low — cosmetic error, does not affect functionality

### Error

```
MissingPluginException(No implementation found for method listen on channel
photography_toolbox/file_intent/events)

#0 MethodChannel._invokeMethod (package:flutter/src/services/platform_channel.dart:365:7)
#1 EventChannel.receiveBroadcastStream.<anonymous closure>
```

### Cause

`FileIntentService.init()` calls `_eventChannel.receiveBroadcastStream().listen()` which internally invokes a platform method. On Windows, there is no native handler registered for this channel (only Android/iOS have Kotlin/Swift implementations). The `MissingPluginException` is thrown asynchronously from Flutter's `BinaryMessenger` on the root zone — neither `try-catch`, `onError`, nor `runZonedGuarded` can intercept it because the platform channel infrastructure dispatches on the root isolate's zone, not the caller's zone.

### Fix

Guard `FileIntentService.init()` with a platform check — skip EventChannel and MethodChannel calls entirely on desktop (`Platform.isWindows || Platform.isLinux || Platform.isMacOS`). File intent handling is only meaningful on mobile (Android/iOS), so this loses no functionality.

**File:** `lib/services/file_intent_service.dart`
