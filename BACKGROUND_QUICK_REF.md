# Background Monitoring - Quick Reference

## ✅ What's Been Implemented

**Tremor detection and API calls now run as a background task when the app is closed.**

## 📁 Files Created/Modified

### New Files
- `entry/src/main/ets/serviceability/BackgroundMonitoringService.ets` - Background service
- `BACKGROUND_SERVICE_GUIDE.md` - Comprehensive guide
- `BACKGROUND_SERVICE_SUMMARY.md` - Implementation summary
- `BACKGROUND_ARCHITECTURE.md` - Visual architecture diagrams
- `BACKGROUND_QUICK_REF.md` - This file

### Modified Files
- `entry/src/main/ets/entryability/EntryAbility.ets` - Starts/connects to service
- `entry/src/main/module.json5` - Registered background service
- `entry/src/main/resources/base/element/string.json` - Added service description

## 🚀 How to Build & Test

1. **Build the project:**
   ```bash
   # In project root
   cd /Users/ar/Documents/Hackatum25/WearableCompanion
   hvigorw clean
   hvigorw assembleHap
   ```

2. **Install on device:**
   ```bash
   hdc install entry/build/default/outputs/default/entry-default-signed.hap
   ```

3. **Launch and start monitoring:**
   - Open app on watch
   - Grant all permissions
   - Monitoring should auto-start

4. **Test background operation:**
   ```bash
   # Close the app (swipe away)
   # Monitor logs to confirm service keeps running:
   hdc hilog | grep "BackgroundMonitoringService"
   ```

5. **Verify data continues:**
   ```bash
   # Wait 5 minutes, then check API logs:
   hdc shell "cat /data/storage/el2/base/haps/entry/files/api_calls.json"
   ```

## 🔍 Key Features

| Feature | Status | Details |
|---------|--------|---------|
| Background Service | ✅ | Runs independently of UI |
| Sensor Collection | ✅ | Accel, gyro, HR continue when closed |
| Tremor Detection | ✅ | 60-second intervals with 10s bursts |
| Freeze Prediction | ✅ | Real-time detection with GPS |
| API Synchronization | ✅ | Every 5 minutes |
| Heart Rate Reports | ✅ | Every 1 minute aggregation |
| Continuous Task | ✅ | Prevents system termination |

## 🔧 Configuration

### Enable/Disable Features

In `entry/src/main/ets/config/AppConfig.ets`:

```typescript
// Auto-start monitoring
static readonly AUTO_START_MONITORING = true;

// Sync intervals
static readonly DATA_SYNC_INTERVAL_MS = 300000;        // 5 minutes
static readonly HEART_RATE_AGGREGATE_INTERVAL_MS = 60000;  // 1 minute

// Detection features
static readonly ENABLE_TREMOR_DETECTION = true;
static readonly ENABLE_FREEZE_DETECTION = true;
```

## 📱 Permissions Required

All automatically configured in `module.json5`:

- ✅ `ohos.permission.KEEP_BACKGROUND_RUNNING` (when: "always")
- ✅ `ohos.permission.LOCATION` (when: "always")
- ✅ `ohos.permission.APPROXIMATELY_LOCATION` (when: "always")
- ✅ `ohos.permission.ACCELEROMETER` (when: "inuse")
- ✅ `ohos.permission.GYROSCOPE` (when: "inuse")
- ✅ `ohos.permission.READ_HEALTH_DATA` (when: "inuse")
- ✅ `ohos.permission.INTERNET` (when: "inuse")

## 🐛 Troubleshooting

### Service Not Starting
```bash
# Check if service is registered
hdc hilog | grep "BackgroundMonitoringService onCreate"

# Should see: "BackgroundMonitoringService onCreate"
```

### Monitoring Stops After Close
```bash
# Verify continuous task
hdc hilog | grep "Continuous background task started"

# Check AUTO_START_MONITORING in AppConfig.ets
```

### No API Calls
```bash
# Check API logger
hdc shell "ls -la /data/storage/el2/base/haps/entry/files/"

# View API call log
hdc shell "cat /data/storage/el2/base/haps/entry/files/api_calls.json"
```

### Permission Issues
```bash
# Re-grant all permissions
# Settings > Apps > Wearable Companion > Permissions
# Enable: Location, Sensors, Internet, Background Running
```

## 📊 Monitoring Background Operation

### View Live Logs
```bash
# All background service logs
hdc hilog | grep "BackgroundMonitoringService"

# Monitoring service logs
hdc hilog | grep "MonitoringService"

# Sensor data logs
hdc hilog | grep "SensorManager"

# API call logs
hdc hilog | grep "APIService"
```

### Check Running Processes
```bash
# List running processes
hdc shell "ps -ef | grep wearablecompanion"

# Check background tasks
hdc shell "dumpsys background_task"
```

## 🎯 Expected Behavior

### When App is Open
- ✅ UI displays real-time sensor data
- ✅ Status shows "Monitoring"
- ✅ Background service runs alongside UI
- ✅ Tremor/freeze detection active
- ✅ API calls every 5 minutes

### When App is Closed
- ✅ Background service continues running
- ✅ Sensors collect data (no UI display)
- ✅ Tremor detection every 60 seconds
- ✅ Freeze prediction triggers alerts
- ✅ API synchronization every 5 minutes
- ✅ GPS captured on freeze events
- ✅ Heart rate aggregated every minute

### When Manually Stopped
- ✅ Background service destroyed
- ✅ All sensors stop
- ✅ Final data sync before stop
- ✅ Monitoring fully halted

## 📈 Performance

### Expected Resource Usage
- **CPU**: ~2-5% (burst to 15% during tremor analysis)
- **Memory**: ~50-80 MB
- **Battery**: ~5-10% per hour (varies by device)
- **Network**: ~100 KB every 5 minutes

### Optimization Tips
1. Increase `DATA_SYNC_INTERVAL_MS` to reduce API calls
2. Reduce sensor rates if battery drains quickly
3. Enable `CLEAR_DATA_AFTER_SYNC` to save memory
4. Disable unused features (tremor/freeze detection)

## 🔗 Documentation

- **Comprehensive Guide**: `BACKGROUND_SERVICE_GUIDE.md`
- **Implementation Details**: `BACKGROUND_SERVICE_SUMMARY.md`
- **Architecture Diagrams**: `BACKGROUND_ARCHITECTURE.md`
- **API Integration**: `API_LOG_ACCESS_GUIDE.md`
- **Data Collection**: `DATA_COLLECTION_GUIDE.md`

## ✅ Checklist Before Testing

- [ ] Built project with `hvigorw assembleHap`
- [ ] Installed HAP on device
- [ ] Granted all permissions in Settings
- [ ] Verified `AUTO_START_MONITORING = true` in AppConfig
- [ ] Confirmed background service registered in module.json5
- [ ] Checked API endpoints configured in AppConfig
- [ ] Ready to test with app closed

## 🎉 Success Criteria

After closing the app, you should see:

1. ✅ Service logs continue in `hdc hilog`
2. ✅ `api_calls.json` grows with new entries every 5 minutes
3. ✅ Tremor detection logs every 60 seconds
4. ✅ Heart rate aggregation logs every minute
5. ✅ Freeze alerts trigger with GPS coordinates
6. ✅ Service survives device screen lock
7. ✅ Data uploads to backend APIs

---

**Status**: ✅ Ready for Testing
**Date**: November 23, 2025
**Next Step**: Build, install, and test background operation
