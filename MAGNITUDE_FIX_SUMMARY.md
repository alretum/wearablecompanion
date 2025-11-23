# Algorithm Update: Magnitude Always Reported

## Problem
The original implementation set `magnitude = 0` when frequency was below 3.0 Hz, resulting in data like:
```json
{
  "status": "sedentary",
  "magnitude": 0,
  "frequency": 1.1
}
```

This was clinically misleading because it suggested no motion when there was actually motion (just not at tremor frequency).

## Solution
Updated `MotionAnalyzer.ets` to **always calculate and report magnitude** based on Mean Absolute Deviation (MAD), regardless of frequency.

### Code Changes

**Before:**
```typescript
let score = 0;
if (frequency >= this.MIN_FREQ_HZ) {
  score = Math.min((mad / this.SCALING_FACTOR) * 10, 10.0);
}
```

**After:**
```typescript
// Always calculate magnitude (motion intensity) regardless of frequency
const motionMagnitude = Math.min((mad / this.SCALING_FACTOR) * 10, 10.0);

// Only report valid tremor if frequency is in tremor range (3-12 Hz)
let tremorScore = motionMagnitude;
if (frequency < this.MIN_FREQ_HZ) {
  // Below tremor frequency - report motion but indicate it's not tremor-frequency
  hilog.debug(DOMAIN, TAG, 
    `Low frequency motion: ${frequency.toFixed(1)} Hz < ${this.MIN_FREQ_HZ} Hz minimum`);
}
```

## Result
Now the data properly reflects actual motion:

**Example (sub-tremor frequency):**
```json
{
  "status": "sedentary",
  "magnitude": 2.3,
  "frequency": 1.1
}
```
Interpretation: Patient has mild motion (2.3) but it's slow postural drift (1.1 Hz), NOT Parkinsonian tremor.

**Example (tremor frequency):**
```json
{
  "status": "sedentary",
  "magnitude": 4.2,
  "frequency": 5.3
}
```
Interpretation: Moderate Parkinsonian tremor (4.2 magnitude at 5.3 Hz).

## Clinical Benefits

1. **Better Motion Tracking:** Clinicians can see ALL motion, not just tremor-frequency motion
2. **Dyskinesia Detection:** High magnitude with irregular frequency may indicate medication side effects
3. **Postural Analysis:** Low-frequency motion (drift) is now visible
4. **Treatment Assessment:** Can track overall motion reduction, not just tremor suppression

## Value Ranges (Complete Documentation)

### Status
- `"sedentary"` - At rest (variance ≤ 1.5 m/s²)
- `"active"` - Walking/moving (variance > 1.5 m/s²)

### Magnitude
- **Range:** 0.0 to 10.0
- **Always calculated** when sedentary
- **Interpretation:**
  - 0.0-0.5: No motion
  - 0.6-2.0: Minimal motion
  - 2.1-4.0: Mild tremor
  - 4.1-6.0: Moderate tremor
  - 6.1-8.0: Marked tremor
  - 8.1-10.0: Severe tremor

### Frequency
- **Range:** 0.0 to 15.0 Hz
- **Interpretation:**
  - 0.0 Hz: No oscillation
  - 0.1-2.9 Hz: Sub-tremor (postural drift)
  - **3.0-6.0 Hz: Parkinsonian tremor** ⭐
  - 6.1-8.0 Hz: Essential/postural tremor
  - 8.1-12.0 Hz: Physiological tremor
  - 12.1+ Hz: High-frequency/artifact

## Valid Tremor Criteria
A reading is Parkinsonian tremor when:
```
status == "sedentary" AND
frequency >= 3.0 AND frequency <= 12.0 AND
magnitude > 1.0
```

## Files Modified
- `entry/src/main/ets/algorithms/MotionAnalyzer.ets` - Algorithm logic
- `TREMOR_DATA_SPECIFICATION.md` - Complete clinical documentation

## Testing
Build and deploy to verify magnitude now shows non-zero values for all motion:
```bash
# Watch logs
hdc shell hilog | grep MotionAnalyzer
```

Expected output will now show:
```
Sedentary: MAD=0.156, Freq=1.1Hz, Magnitude=1.0
```
Instead of:
```
Sedentary: MAD=0.156, Freq=1.1Hz, Score=0.0
```
