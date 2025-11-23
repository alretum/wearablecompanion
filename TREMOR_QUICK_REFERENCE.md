# Tremor Detection - Quick Reference

## What Was Implemented

### Core Algorithm (MotionAnalyzer.ets)
✅ **Step A:** Gravity removal via Euclidean magnitude + detrending  
✅ **Step B:** Activity gate (variance > 1.5 = walking detected)  
✅ **Step C:** MAD (tremor severity) + ZCR with hysteresis (frequency)  
✅ **Step D:** 0-10 scoring with 3 Hz minimum frequency filter  

### Integration
✅ Updated `TremorDetector` to use MotionAnalyzer  
✅ 60-second reporting interval with 10-second data bursts  
✅ Tremor data flows into existing `HeartRateLogger`  
✅ Backend uploads include tremor data per minute  

### Configuration
✅ Accelerometer: 50 Hz (20ms), REGULAR type (raw + gravity)  
✅ Tremor detection: ENABLED  
✅ Manual gravity compensation: DISABLED (algorithm handles it)  

## Data Structure

Each minute includes tremor data:
```typescript
{
  status: 'active' | 'sedentary',
  magnitude: 0.0-10.0,  // Clinical score
  frequency: 0.0-15.0   // Hz (0 if walking or no tremor)
}
```

## Algorithm Constants

```typescript
WALK_THRESH = 1.5       // Walking detection threshold
NOISE_FLOOR = 0.05      // Frequency counting dead zone
MIN_FREQ_HZ = 3.0       // Minimum valid tremor frequency
SCALING_FACTOR = 1.5    // Magnitude normalization
```

## Usage Flow

1. **Continuous monitoring** collects accelerometer data (50Hz)
2. **Every 60 seconds**, TremorDetector triggers a 10-second burst analysis
3. **MotionAnalyzer** processes ~500 samples:
   - Removes gravity
   - Checks if walking (activity gate)
   - Calculates MAD and frequency
   - Generates 0-10 score
4. **TremorEvent** is passed to HeartRateLogger
5. **Every 5 minutes**, data uploads to backend with tremor info

## Testing Commands

Build and deploy:
```bash
cd /Users/ar/Documents/Hackatum25/WearableCompanion
# Use DevEco Studio to build and deploy to Huawei Watch 5
```

Check logs for tremor detection:
```bash
hdc shell hilog | grep TremorDetector
hdc shell hilog | grep MotionAnalyzer
```

## Optional: Full Duty Cycle Mode

`HealthService.ets` is available but not integrated. To use it:
1. In `MonitoringService.ets`, replace continuous accelerometer monitoring
2. Instantiate `HealthService` and call `start()`
3. This will turn accelerometer on/off for true duty cycling

Current approach: Continuous accelerometer with periodic burst analysis (simpler integration)

## Key Files

**New:**
- `algorithms/MotionAnalyzer.ets` - Signal processing core
- `services/HealthService.ets` - Duty cycle service (optional)

**Modified:**
- `algorithms/TremorDetector.ets` - Uses MotionAnalyzer
- `connectivity/APIService.ets` - Includes tremor in uploads
- `config/AppConfig.ets` - Tremor detection enabled

**Unchanged (works as before):**
- `services/HeartRateLogger.ets` - Already supported tremor data
- `sensors/SensorManager.ets` - Already at 50Hz REGULAR mode
- `services/MonitoringService.ets` - Orchestration unchanged
