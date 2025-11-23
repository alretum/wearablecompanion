# Background Monitoring Implementation - Summary

## Changes Made

This implementation enables **tremor detection and API calls to continue running even when the app is closed**.

### 1. New Background Service Extension

**File**: `entry/src/main/ets/serviceability/BackgroundMonitoringService.ets`

- Created a Service Extension Ability that runs independently from the UI
- Automatically starts monitoring when connected
- Maintains continuous background task registration
- Continues running even after UI is destroyed
- Handles IPC communication for start/stop commands

**Key Features**:
```typescript
- onCreate() - Initializes MonitoringService singleton
- onConnect() - Auto-starts monitoring
- onRequest() - Ensures monitoring is active
- onDestroy() - Cleanup when service is stopped
- Continuous background task via backgroundTaskManager
```

### 2. Modified EntryAbility

**File**: `entry/src/main/ets/entryability/EntryAbility.ets`

**Changes**:
- Added `backgroundServiceConnection` property for service communication
- Added `startBackgroundService()` - Launches service on app startup
- Added `disconnectBackgroundService()` - Disconnects without stopping service
- Added `stopBackgroundService()` - Completely stops background service
- Added static `stopBackgroundMonitoring()` - Public API for UI to stop service
- Modified `onDestroy()` - Keeps service running when UI closes

**Lifecycle Behavior**:
```
App Launch → Start Background Service → Connect to Service
App Close → Disconnect from Service (Service Keeps Running)
Stop Button → Stop Background Service → Service Destroyed
```

### 3. Updated Module Configuration

**File**: `entry/src/main/module.json5`

**Changes**:
- Added `BackgroundMonitoringService` to `extensionAbilities` section
- Configured as `type: "service"` with `exported: true`
- Added background modes: `["dataTransfer", "location"]`
- Service inherits background permissions from main ability

### 4. Updated String Resources

**File**: `entry/src/main/resources/base/element/string.json`

**Changes**:
- Added `background_service_desc` string resource
- Description: "Continuous monitoring service for Parkinson's tremor and freeze detection"

### 5. Documentation

**Files Created**:
- `BACKGROUND_SERVICE_GUIDE.md` - Comprehensive guide for background service
- `BACKGROUND_SERVICE_SUMMARY.md` - This summary file

## How It Works

### Normal Operation (App Open)
1. User launches app
2. `EntryAbility` starts and connects to `BackgroundMonitoringService`
3. Service starts `MonitoringService` singleton
4. UI displays real-time data from MonitoringService
5. Tremor detection, freeze prediction, and API calls run continuously

### Background Operation (App Closed)
1. User closes/swipes away the app
2. `EntryAbility.onDestroy()` disconnects from service
3. `BackgroundMonitoringService` **continues running**
4. Monitoring continues independently:
   - ✅ Sensor data collection (accel, gyro, heart rate)
   - ✅ Tremor detection every 60 seconds
   - ✅ Freeze prediction in real-time
   - ✅ Heart rate aggregation every minute
   - ✅ API synchronization every 5 minutes
   - ✅ GPS capture on freeze detection

### Complete Stop (User Action)
1. User clicks "Stop Monitoring" in UI
2. `MonitoringService.stopMonitoring()` called
3. `EntryAbility.stopBackgroundService()` called
4. Service extension destroyed
5. All monitoring stops

## Technical Details

### Permissions Required
- `ohos.permission.KEEP_BACKGROUND_RUNNING` - Allows background operation
- `ohos.permission.LOCATION` - GPS tracking for freeze events
- `ohos.permission.INTERNET` - API communication
- All sensor permissions (accelerometer, gyroscope, heart rate)

### Background Modes
- `dataTransfer` - For continuous API synchronization
- `location` - For GPS tracking during freeze events

### Architecture Pattern
- **Singleton MonitoringService** - Shared between UI and background service
- **Service Extension** - Keeps process alive when UI is closed
- **IPC Communication** - UI communicates with service via RPC
- **Continuous Task** - Registered with system to prevent termination

## Testing

### Test Background Operation

1. **Build and install** the updated app:
   ```bash
   hdc install entry-default-signed.hap
   ```

2. **Launch app** and start monitoring

3. **Close the app** completely (swipe away from recent apps)

4. **Monitor logs** to verify background operation:
   ```bash
   hdc hilog | grep "BackgroundMonitoringService"
   ```

5. **Expected logs** when app is closed:
   ```
   BackgroundMonitoringService onCreate
   BackgroundMonitoringService onConnect
   Monitoring started via background service
   [Background service continues logging sensor data]
   ```

6. **Check API logs** after 5 minutes:
   ```bash
   hdc file recv /data/storage/el2/base/haps/entry/files/api_calls.json
   ```
   Should contain entries timestamped after app was closed

### Verify Continuous Operation

**Create physical movement** (shake watch) while app is closed:
- Tremor detection should trigger every 60 seconds
- Heart rate should aggregate every minute
- API sync should occur every 5 minutes
- All data logged even with UI closed

## Configuration

### Auto-Start Monitoring

In `AppConfig.ets`:
```typescript
static readonly AUTO_START_MONITORING = true;
```

When enabled, monitoring starts automatically when:
- App launches for the first time
- Background service starts
- App returns to foreground (if not already monitoring)

### Sync Intervals

Control background sync frequency:
```typescript
// Heart rate aggregation - every 1 minute
static readonly HEART_RATE_AGGREGATE_INTERVAL_MS = 60000;

// API synchronization - every 5 minutes
static readonly DATA_SYNC_INTERVAL_MS = 300000;
```

### Battery Optimization

To reduce battery usage while maintaining background operation:
1. Increase sync intervals
2. Reduce sensor sampling rates
3. Enable data clearing after sync:
   ```typescript
   static readonly CLEAR_DATA_AFTER_SYNC = true;
   ```

## Benefits

✅ **True Background Monitoring**
   - Continues even when app is fully closed
   - Survives screen lock and app switching
   - Independent service lifecycle

✅ **Comprehensive Detection**
   - Tremor detection runs continuously
   - Freeze prediction triggers alerts
   - GPS coordinates captured automatically

✅ **Reliable Data Sync**
   - Scheduled API uploads every 5 minutes
   - Immediate alerts for freeze events
   - Persistent data logging

✅ **System Integration**
   - Proper background task registration
   - Respects HarmonyOS background policies
   - Battery-efficient operation

## Limitations

⚠️ **System Constraints**
- HarmonyOS may terminate service under extreme low memory
- Battery saver modes may restrict background operation
- User can manually force-stop service from system settings

⚠️ **Device Variations**
- Some devices have stricter background policies
- Manufacturer-specific battery optimizations may interfere
- Test on target devices for compatibility

## Next Steps

1. **Build the project** to compile new service extension
2. **Install on test device** and grant all permissions
3. **Test background operation** by closing app and monitoring logs
4. **Verify API uploads** continue after app closure
5. **Monitor battery usage** over extended testing period

## Support

For issues or questions:
- Check logs: `hdc hilog | grep "BackgroundMonitoringService"`
- Review `BACKGROUND_SERVICE_GUIDE.md` for detailed troubleshooting
- Verify all permissions are granted in device settings
- Ensure `AUTO_START_MONITORING = true` in AppConfig

---

**Implementation Date**: November 23, 2025
**Status**: ✅ Complete - Ready for testing
**Compatibility**: HarmonyOS 5.0+ wearable devices
