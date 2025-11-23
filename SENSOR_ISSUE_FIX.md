# Sensor Issues - Analysis & Fix

## Issue 1: LINEAR_ACCELEROMETER Not Removing Gravity ❌

**Problem:**
- Y-axis showing ~980-1000 (which is 9.8-10 m/s² = gravity)
- `LINEAR_ACCELEROMETER` should exclude gravity but appears not to be working
- This is a device/firmware issue - some HarmonyOS watches don't properly implement LINEAR_ACCELEROMETER

**Expected Behavior:**
- When watch is stationary: all axes should be near 0 m/s²
- Only motion should create non-zero readings

**Current Behavior:**
- One axis (likely Y when watch is flat) shows ~9.8 m/s² constantly
- This indicates gravity is NOT being removed

## Issue 2: Accelerometer vs Gyroscope Data Differences ✅

**This is NORMAL and EXPECTED!**

### Accelerometer:
- **Measures:** Linear acceleration (m/s²)
- **Type:** Absolute value of current acceleration
- **Includes:** Device motion + gravity (unless using LINEAR_ACCELEROMETER)
- **When stationary:** Shows gravity vector (~9.8 m/s² on one axis)
- **When moving:** Shows acceleration changes

### Gyroscope:
- **Measures:** Angular velocity (rad/s or °/s)
- **Type:** RATE of change (delta) - how fast it's rotating
- **Does NOT include:** Gravity or position
- **When stationary:** Shows ~0 on all axes
- **When rotating:** Shows rotation speed

**Example:**
```
Watch laying flat on table:
- Accelerometer: x=0, y=9.8, z=0  (gravity pulling down)
- Gyroscope: x=0, y=0, z=0       (not rotating)

Watch being shaken:
- Accelerometer: x=2.5, y=11.3, z=-1.2  (motion + gravity)
- Gyroscope: x=0.5, y=-0.2, z=0.1       (rotation speed)
```

## Solution Options

### Option 1: Try ACCELEROMETER_UNCALIBRATED (If Available)
Some devices have better implementations of uncalibrated sensors.

### Option 2: Use Regular ACCELEROMETER + Manual Gravity Subtraction
Calculate gravity vector when stationary, then subtract it from all readings.

### Option 3: High-Pass Filter
Filter out the constant gravity component by only keeping high-frequency changes.

### Option 4: Use Sensor Fusion
Combine accelerometer + gyroscope data to calculate true linear acceleration.

## Recommended Fix

I'll implement **Option 2** with automatic calibration:

1. When monitoring starts, device should be stationary
2. Record first ~10 readings to calculate average gravity vector
3. Subtract this gravity vector from all subsequent readings
4. Recalibrate periodically if needed

This will give you proper linear acceleration data regardless of device orientation.

## How to Verify the Fix

After applying the fix, when the watch is stationary:
- All axes should show values close to 0 (± 0.5 m/s²)
- Only when moving should you see significant values
- Magnitude should be much lower than 9.8 when still

When walking/moving:
- Should see oscillations in the axis aligned with movement direction
- Values should be in the range of -5 to +5 m/s² for normal motion
- Tremors would show as higher frequency oscillations (4-6 Hz)
