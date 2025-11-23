# Gravity Compensation Fix - Quick Reference

## Problem Solved ✅

**Issue 1:** LINEAR_ACCELEROMETER not removing gravity (Y-axis showing ~980-1000)
- **Root Cause:** Device firmware doesn't properly implement LINEAR_ACCELEROMETER
- **Solution:** Manual gravity compensation with auto-calibration

**Issue 2:** Accelerometer vs Gyroscope differences
- **Status:** This is NORMAL behavior (not a bug!)
- **Accelerometer:** Measures linear acceleration (absolute values)
- **Gyroscope:** Measures angular velocity (rate of change/delta)

## How the Fix Works

### Auto-Calibration on Startup:
1. **Keep watch STILL** when starting monitoring
2. First 20 readings are used to calculate average gravity vector
3. This gravity vector is subtracted from all subsequent readings
4. Result: True linear acceleration without gravity

### What You'll See in Logs:

**During Calibration:**
```
Calibration reset - keep device still for initial readings
```

**After Calibration:**
```
Gravity calibrated: x=0.12, y=9.78, z=0.15, mag=9.79 m/s²
✅ Gravity vector detected correctly (~9.8 m/s²) - compensation will be applied
First compensated reading: x=0.05, y=-0.12, z=0.08, mag=0.15 m/s²
✅ Gravity compensation active - values should be near 0 when stationary
```

## Expected Values After Fix

### When Watch is Stationary:
- **All axes:** ± 0.5 m/s² (close to zero)
- **Magnitude:** < 1.0 m/s²

### When Walking:
- **Values:** -5 to +5 m/s² typical
- **Pattern:** Oscillations at walking frequency (~1-2 Hz)

### When Running:
- **Values:** -10 to +10 m/s² typical
- **Pattern:** Higher amplitude oscillations

### Tremors (if present):
- **Values:** Smaller amplitude but high frequency
- **Pattern:** 4-6 Hz oscillations

## Configuration

In `AppConfig.ets`:
```typescript
ENABLE_MANUAL_GRAVITY_COMPENSATION = true  // Enable the fix
CALIBRATION_SAMPLES = 20                   // Number of samples to average
```

## Important Notes

1. **Keep watch still during startup** - First ~2 seconds (20 samples at 10Hz)
2. **Calibration happens automatically** - No user action needed after enabling
3. **Recalibrates on each start** - Adapts to any watch orientation
4. **No performance impact** - Simple subtraction operation

## Disable If Not Needed

If your device's LINEAR_ACCELEROMETER works correctly (values near 0 when still):
```typescript
ENABLE_MANUAL_GRAVITY_COMPENSATION = false
```

## Verify It's Working

1. Start monitoring with watch laying flat and still
2. Check logs for: "✅ Gravity compensation active"
3. Check data: Y-axis should be ~0, not ~980
4. Move watch: Should see changes in all axes
5. Keep still again: Should return to near 0

## Data Collection Impact

All saved data will now have gravity removed:
- Better for ML/AI analysis
- Clearer motion patterns
- Easier to detect tremors and gait issues
- More consistent across different watch orientations
