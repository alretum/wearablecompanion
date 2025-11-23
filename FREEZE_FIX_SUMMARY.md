# Freeze Detection Fix Summary

## Issues Identified

### 1. **Overly Strict Thresholds**
The original FreezeDetector had thresholds that were too restrictive, making it difficult to trigger freeze detection:

**Original Thresholds:**
- `MOTION_GATE = 0.5` - Too high, rejecting valid freeze patterns
- `WALK_GATE = 1.0` - Too low, rejecting normal arm movements as "walking normally"  
- `FREEZE_RATIO = 2.0` - Required freeze power to be 2x locomotor power

**New Thresholds (More Sensitive):**
- `MOTION_GATE = 0.1` - Lowered to detect more subtle freeze patterns
- `WALK_GATE = 2.0` - Increased to allow more arm movement before rejecting
- `FREEZE_RATIO = 1.5` - Lowered to trigger more easily

### 2. **Insufficient Logging**
The original detector only logged at `debug` level for normal operation, making it hard to diagnose why freezes weren't being detected.

**Changes:**
- Changed all detection logs from `hilog.debug()` to `hilog.info()`
- Added detailed power values (pFreeze, pLoco) to every log
- Added buffer filling progress logs
- Added periodic magnitude statistics every second
- Added sample counter for tracking

### 3. **Gravity in Signal**
The app uses `ACCELEROMETER_TYPE = 'REGULAR'` which includes gravity (~9.8 m/s²). This means:
- Standing still with watch horizontal: magnitude ≈ 9.8 m/s²
- The detrending step removes the mean, which helps
- But the raw magnitudes can be misleading

## What the Algorithm Does

### Freeze Index Algorithm (Time-Domain)

**Step 1: Signal Preprocessing**
```
1. Calculate magnitude: √(x² + y² + z²)
2. Detrend: signal = magnitude - mean
```

**Step 2: Band Separation (EMA Filters)**
```
Locomotor Band (0.5-1.5 Hz) - slow arm swing:
  Loco[i] = 0.15 × Signal[i] + 0.85 × Loco[i-1]

Freeze Band (1.5-8.0 Hz) - tremor-like shaking:
  Freeze[i] = Signal[i] - Loco[i]
```

**Step 3: Energy Calculation & Detection**
```
pLoco = Σ(locoSignal²) / N
pFreeze = Σ(freezeSignal²) / N

Detection Logic:
1. If pFreeze < 0.1 → Standing Still (REJECT)
2. If pLoco > 2.0 → Walking Normally (REJECT)  
3. Freeze Index = pFreeze / pLoco
4. If Freeze Index > 1.5 → FREEZE DETECTED ✅
```

## How to Test

### Testing Patterns

**Pattern 1: Standing Still (Should NOT trigger)**
- Hold watch completely still
- Expected Log: `Motion Gate: pFreeze < 0.1 (Standing Still)`

**Pattern 2: Normal Walking (Should NOT trigger)**  
- Walk normally with natural arm swing
- Expected Log: `Walk Gate: pLoco > 2.0 (Walking Normally)`

**Pattern 3: Freeze Simulation (SHOULD trigger)**
To simulate a freeze, you need:
- **Low locomotor activity** (minimal slow arm swing)
- **High freeze band activity** (tremor-like shaking at 1.5-8 Hz)

**How to perform:**
1. Hold your arm relatively still (low locomotor)
2. Shake your wrist rapidly in small movements (high frequency tremor)
3. The combination creates high pFreeze / low pLoco = high Freeze Index
4. Expected: Detection within 1-2 seconds

### What to Watch in Logs

**1. Buffer Filling (first second):**
```
FreezeDetector: Buffer filling: 10/50
FreezeDetector: Buffer filling: 20/50
...
FreezeDetector: Buffer filling: 50/50
```

**2. Periodic Statistics (every second):**
```
FreezeDetector: Magnitude Stats: avg=9.85, min=9.20, max=10.50
```
- If average is ~9.8, you're mostly still (gravity dominates)
- If average varies significantly, you're moving

**3. Detection Attempts (every sample after buffer fills):**

**Rejected by Motion Gate:**
```
[FOG] Motion Gate: pFreeze=0.05 < 0.1 (Standing Still)
```

**Rejected by Walk Gate:**
```
[FOG] Walk Gate: pLoco=2.50 > 2.0 (Walking Normally)
```

**Normal (no freeze):**
```
[FOG] Normal: Ratio=0.85 < 1.5 (pFreeze=0.450, pLoco=0.530)
```

**FREEZE DETECTED:**
```
[FOG] ✅ FREEZE DETECTED! Ratio=2.30 (pFreeze=0.920, pLoco=0.400)
GuardianService: 🚨 [FOG_STARTED] Initiating intervention...
GuardianService: 🔊 Playing metronome audio (looping)
```

## Understanding the Values

### Typical Values
- **Standing Still**: pLoco ≈ 0.01-0.1, pFreeze ≈ 0.01-0.1
- **Normal Walking**: pLoco ≈ 1.0-3.0, pFreeze ≈ 0.5-1.5
- **Freeze Episode**: pLoco ≈ 0.2-0.5, pFreeze ≈ 0.5-1.5

### Freeze Index Interpretation
- **< 1.0**: Normal movement patterns
- **1.0-1.5**: Borderline (old threshold would reject)
- **> 1.5**: Freeze detected (new threshold)
- **> 2.0**: Strong freeze (old threshold)

## If Freezes Still Don't Trigger

### 1. Check Logs
Look for the pattern you're performing:
- Are you being rejected by Motion Gate? → Shake more vigorously
- Are you being rejected by Walk Gate? → Reduce large arm movements
- Is the Freeze Index close but not quite 1.5? → Note the values

### 2. Further Threshold Adjustments
If needed, you can lower thresholds even more in `FreezeDetector.ets`:

```typescript
// For extremely sensitive detection
private readonly MOTION_GATE = 0.05;  // Even lower
private readonly WALK_GATE = 3.0;     // Even higher  
private readonly FREEZE_RATIO = 1.2;  // Even lower
```

### 3. Consider the Physical Pattern
The freeze detection algorithm is specifically looking for:
- **Shuffling/tremor-like leg movement** (creates high frequency signal)
- **Reduced arm swing** (low locomotor power)

If you're wearing the watch on your wrist, you need to simulate what happens during an actual freeze episode - the arm stops swinging normally but small tremors appear.

## Files Modified

1. **`entry/src/main/ets/algorithms/FreezeDetector.ets`**
   - Lowered MOTION_GATE from 0.5 to 0.1
   - Increased WALK_GATE from 1.0 to 2.0
   - Lowered FREEZE_RATIO from 2.0 to 1.5
   - Changed all detection logs from debug to info level
   - Added detailed power values to all logs
   - Added buffer filling progress logs
   - Added periodic magnitude statistics
   - Added sample counter

## Next Steps

1. **Rebuild and Deploy** the app
2. **Monitor Logs** using `hdc hilog` or device logs
3. **Test the Patterns** described above
4. **Analyze the Values** you see in the logs
5. **Adjust Thresholds** if needed based on real data

The key is to look at the actual pLoco and pFreeze values you're generating and understand why the algorithm is accepting or rejecting them.
