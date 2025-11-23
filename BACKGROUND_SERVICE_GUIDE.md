# Background Monitoring Service

## Overview

The Wearable Companion app now includes a **Background Monitoring Service** that ensures tremor detection, freeze prediction, and API synchronization continue to run even when the app is closed or minimized.

## Architecture

### Components

1. **BackgroundMonitoringService** (`BackgroundMonitoringService.ets`)
   - Service Extension Ability that runs independently of the UI
   - Manages the MonitoringService singleton
   - Maintains continuous background task registration
   - Handles tremor detection, freeze prediction, and API calls

2. **EntryAbility** (`EntryAbility.ets`)
   - Main UI ability
   - Starts the background service on app launch
   - Maintains connection to the service while UI is active
   - Disconnects (but doesn't stop) the service when UI is closed

3. **MonitoringService** (`MonitoringService.ets`)
   - Singleton service managing all monitoring logic
   - Shared between UI and background service
   - Coordinates sensors, algorithms, and API communication

## How It Works

### App Lifecycle

1. **App Launch**
   ```
   EntryAbility.onCreate()
     └─> startBackgroundService()
         └─> BackgroundMonitoringService starts
             └─> MonitoringService.startMonitoring()
   ```

2. **App Running (Foreground)**
   - UI displays real-time sensor data and status
   - Background service continues monitoring
   - Both UI and service share the same MonitoringService instance

3. **App Minimized/Background**
   ```
   EntryAbility.onBackground()
     └─> UI goes to background
     └─> Background service continues running
     └─> Monitoring, detection, and API calls continue
   ```

4. **App Closed**
   ```
   EntryAbility.onDestroy()
     └─> disconnectBackgroundService()
     └─> UI connection severed
     └─> Background service keeps running
     └─> Monitoring continues independently
   ```

5. **Complete Stop** (manual user action)
   ```
   User clicks "Stop Monitoring"
     └─> MonitoringService.stopMonitoring()
     └─> EntryAbility.stopBackgroundService()
     └─> BackgroundMonitoringService.onDestroy()
     └─> All monitoring stops
   ```

## Background Capabilities

When the app is closed, the background service continues to:

✅ **Collect sensor data**
   - Accelerometer (50 Hz)
   - Gyroscope (50 Hz)
   - Heart rate (1 Hz)

✅ **Detect tremors**
   - Advanced motion analysis
   - 10-second data bursts every 60 seconds
   - Algebraic filtering for 3-12 Hz tremor detection

✅ **Predict freezes**
   - Real-time freeze prediction algorithm
   - GPS coordinate capture on detection
   - Immediate alert generation

✅ **Sync data to server**
   - Heart rate reports every 5 minutes
   - Freeze incident reports (immediate)
   - Data collection logs (if enabled)

✅ **Maintain continuous operation**
   - Background task registration with system
   - Location and data transfer background modes
   - Survives app closure and screen lock

## Permissions Required

The following permissions are essential for background monitoring:

```json5
{
  "name": "ohos.permission.KEEP_BACKGROUND_RUNNING",
  "reason": "Used to continue monitoring even when app is in background",
  "usedScene": {
    "abilities": ["EntryAbility"],
    "when": "always"
  }
}
```

Additional permissions for background operation:
- `ohos.permission.LOCATION` - GPS tracking for freeze events
- `ohos.permission.INTERNET` - API communication
- `ohos.permission.ACCELEROMETER` - Motion detection
- `ohos.permission.GYROSCOPE` - Rotational movement
- `ohos.permission.READ_HEALTH_DATA` - Heart rate monitoring

## Configuration

### Enable/Disable Auto-Start

In `AppConfig.ets`:

```typescript
// Automatically start monitoring when app launches
static readonly AUTO_START_MONITORING = true;
```

### Background Modes

In `module.json5`:

```json5
"backgroundModes": [
  "dataTransfer",  // For API synchronization
  "location"       // For GPS tracking during freeze events
]
```

## Testing Background Operation

1. **Launch the app** on your HarmonyOS watch
2. **Wait for monitoring to start** (check green status)
3. **Close the app** (swipe away from recent apps)
4. **Perform physical movements** that trigger tremor detection
5. **Check server logs** - data should continue uploading
6. **Check device logs**: `hdc hilog | grep BackgroundMonitoringService`

### Expected Behavior

When app is closed:
- ✅ Sensors continue collecting data
- ✅ Tremor detection runs every 60 seconds
- ✅ Heart rate aggregates every minute
- ✅ API sync happens every 5 minutes
- ✅ Freeze alerts trigger immediately with GPS
- ✅ Continuous task keeps service alive

## Troubleshooting

### Service Not Starting

**Issue**: Background service fails to start

**Solutions**:
1. Check permissions are granted in Settings > Apps > Wearable Companion
2. Verify `KEEP_BACKGROUND_RUNNING` permission is enabled
3. Check logs: `hdc hilog | grep "BackgroundMonitoringService"`

### Monitoring Stops When App Closes

**Issue**: Monitoring stops after closing the app

**Solutions**:
1. Ensure `AUTO_START_MONITORING = true` in AppConfig
2. Check background task registration succeeded in logs
3. Verify device doesn't have aggressive battery optimization
4. Confirm service extension is properly registered in module.json5

### No Data After App Closure

**Issue**: API calls stop when app is closed

**Solutions**:
1. Check internet permission and connectivity
2. Verify API endpoints are configured in AppConfig
3. Check API logger: `entry/files/api_calls.json`
4. Review logs for API errors

### High Battery Usage

**Issue**: Background service drains battery quickly

**Solutions**:
1. Reduce sensor sampling rates in AppConfig
2. Increase `DATA_SYNC_INTERVAL_MS` (default: 5 minutes)
3. Enable data clearing: `CLEAR_DATA_AFTER_SYNC = true`
4. Consider reducing tremor detection frequency

## Limitations

⚠️ **System Restrictions**
- HarmonyOS may still terminate the service under extreme conditions (very low memory, battery saver mode)
- Some devices may have stricter background policies
- User can manually force-stop the service from system settings

⚠️ **API Rate Limits**
- Ensure your backend can handle continuous requests
- Consider implementing exponential backoff for failed requests
- Monitor API usage to avoid quota exhaustion

## Development Notes

### Adding New Background Features

When adding features that should run in background:

1. Add logic to `MonitoringService` (shared singleton)
2. No changes needed in `BackgroundMonitoringService` - it automatically inherits functionality
3. Test with app closed to verify background operation

### Debugging Background Service

View background service logs:
```bash
# Filter for background service logs
hdc hilog | grep "BackgroundMonitoringService"

# Filter for monitoring service logs
hdc hilog | grep "MonitoringService"

# View all app logs
hdc hilog -t "WearableCompanion"
```

### Performance Monitoring

Check if background task is active:
```bash
# List all background tasks
hdc shell "ps -ef | grep wearablecompanion"

# Check continuous task status
hdc shell "dumpsys background_task"
```

## Best Practices

1. **Always test background scenarios** during development
2. **Monitor battery usage** in production
3. **Implement proper error handling** for network failures
4. **Use appropriate sync intervals** to balance data freshness and battery life
5. **Respect user privacy** - clearly communicate background data collection
6. **Provide user control** - option to disable background monitoring

## Future Enhancements

Potential improvements:
- [ ] Adaptive sync intervals based on battery level
- [ ] Local notification when freeze is detected (even with app closed)
- [ ] Offline data queuing with retry logic
- [ ] Battery usage analytics and optimization
- [ ] User-configurable background modes

## References

- [HarmonyOS Background Task Management](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V5/background-task-overview-V5)
- [Service Extension Ability](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V5/serviceextensionability-V5)
- [Continuous Task](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V5/continuous-task-V5)
