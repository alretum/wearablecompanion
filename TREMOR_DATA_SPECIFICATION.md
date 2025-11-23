# Tremor Data Specification

## Overview
This document describes the tremor detection data structure, value ranges, and clinical interpretation guidelines for the Parkinson's monitoring system.

## Data Structure

### TremorData Object
Each minute of monitoring includes a `tremorData` object with three key metrics:

```typescript
interface TremorData {
  status: 'sedentary' | 'active';  // Activity classification
  magnitude: number;                // Motion intensity (0.0-10.0)
  frequency: number;                // Oscillation frequency in Hz (0.0-15.0)
}
```

## Field Specifications

### 1. Status (Activity Classification)

**Type:** String (enum)  
**Possible Values:**
- `"sedentary"` - User is at rest, minimal voluntary movement detected
- `"active"` - User is walking or moving significantly

**Algorithm Logic:**
- Calculates standard deviation of detrended acceleration magnitude
- If variance > 1.5 m/s²: Status = `"active"`
- If variance ≤ 1.5 m/s²: Status = `"sedentary"`

**Clinical Interpretation:**
- `"active"`: Motion data is unreliable for tremor assessment (voluntary movement dominates)
- `"sedentary"`: Motion data reflects involuntary movements (tremors, dyskinesia)

**Expected Distribution:**
- ~70-80% sedentary (resting patient)
- ~20-30% active (walking, daily activities)

---

### 2. Magnitude (Motion Intensity Score)

**Type:** Number (float)  
**Range:** 0.0 to 10.0  
**Precision:** 1 decimal place  
**Unit:** Clinical severity score (0=none, 10=extreme)

**Algorithm Logic:**
```
1. Calculate Mean Absolute Deviation (MAD) of detrended signal
2. Scale to 0-10: magnitude = min((MAD / 1.5) × 10, 10.0)
3. Round to 1 decimal place
```

**Clinical Interpretation:**

| Magnitude | Severity      | Clinical Description                               |
|-----------|---------------|---------------------------------------------------|
| 0.0-0.5   | None          | No detectable motion, completely still            |
| 0.6-2.0   | Minimal       | Barely perceptible motion, minor finger movements |
| 2.1-4.0   | Mild          | Noticeable tremor, limited amplitude              |
| 4.1-6.0   | Moderate      | Clear tremor, interferes with fine motor tasks    |
| 6.1-8.0   | Marked        | Significant tremor, affects daily activities      |
| 8.1-10.0  | Severe        | Extreme tremor, severely disabling                |

**Important Notes:**
- **Always calculated** when status = `"sedentary"`, regardless of frequency
- Represents raw motion intensity, not necessarily Parkinson's tremor
- May include:
  - Resting tremors (Parkinson's typical: 4-6 Hz)
  - Essential tremor (6-12 Hz)
  - Physiological tremor (8-12 Hz)
  - Low-frequency postural drift (<3 Hz)
  - Dyskinesia (irregular motion)

**Expected Distribution (Parkinson's patients at rest):**
- Healthy/treated: 0.0-2.0 (85% of time)
- Mild symptoms: 2.0-4.0 (10% of time)
- Moderate symptoms: 4.0-6.0 (4% of time)
- Severe symptoms: 6.0+ (1% of time)

**When status = "active":**
- Magnitude is always `0` (walking motion filtered out)

---

### 3. Frequency (Oscillation Rate)

**Type:** Number (float)  
**Range:** 0.0 to 15.0 Hz  
**Precision:** 1 decimal place  
**Unit:** Hertz (cycles per second)

**Algorithm Logic:**
```
1. Count zero-crossings with hysteresis (±0.05 m/s² noise floor)
2. Convert to frequency: (crossings / 2) / duration_seconds
3. Round to 1 decimal place
```

**Clinical Interpretation:**

| Frequency Range | Classification           | Clinical Significance                                    |
|-----------------|--------------------------|----------------------------------------------------------|
| 0.0 Hz          | No oscillation           | Non-periodic motion or completely still                  |
| 0.1-2.9 Hz      | **Sub-tremor**           | Postural drift, slow swaying (NOT tremor)                |
| **3.0-6.0 Hz**  | **Parkinsonian Tremor**  | Classic resting tremor range (peak: 4-5 Hz)             |
| 6.1-8.0 Hz      | Essential/Postural       | Action/postural tremor, early Parkinson's               |
| 8.1-12.0 Hz     | Physiological            | Normal hand tremor, anxiety, medication effect          |
| 12.1+ Hz        | High-frequency           | Muscle fasciculation, artifact, or neurological tremor  |

**Parkinson's Disease Specifics:**
- **Typical resting tremor:** 4-6 Hz (most common: 4.5 Hz)
- **Pill-rolling tremor:** Usually 4-5 Hz
- **Re-emergent tremor:** 3-6 Hz (appears after postural hold)

**Important Notes:**
- Frequency = 0.0 can indicate:
  - No motion detected
  - Non-periodic motion (random movements)
  - Motion below detection threshold
- Low frequencies (0.1-2.9 Hz) are reported but should NOT be classified as tremor
- Medication can shift frequency (e.g., levodopa may reduce tremor frequency)

**Expected Distribution (Parkinson's patients, sedentary):**
- No oscillation (0.0 Hz): ~60% (resting, no tremor active)
- Sub-tremor (0.1-2.9 Hz): ~15% (postural adjustments)
- Parkinsonian tremor (3.0-6.0 Hz): ~20% (actual tremor episodes)
- Other (6.1+ Hz): ~5% (essential tremor, artifact)

**When status = "active":**
- Frequency is always `0` (gait cadence is filtered out)

---

## Data Validation Rules

### Valid Tremor Detection Criteria
A reading is considered a "valid Parkinson's tremor" when:
```
status == "sedentary" AND 
frequency >= 3.0 Hz AND 
frequency <= 12.0 Hz AND
magnitude > 1.0
```

### Red Flags (Potential Artifacts)
- **Magnitude > 8.0 with frequency = 0.0**: Likely dyskinesia or artifact
- **Frequency > 12 Hz with magnitude > 5.0**: Likely sensor noise or external vibration
- **Status = "active" but magnitude > 0**: Data inconsistency (should be caught by algorithm)

---

## Example Data Interpretations

### Example 1: Classic Parkinsonian Tremor
```json
{
  "status": "sedentary",
  "magnitude": 4.2,
  "frequency": 5.3
}
```
**Interpretation:** Moderate Parkinsonian resting tremor. Patient is sitting still with a noticeable tremor at typical Parkinson's frequency (5.3 Hz). Magnitude of 4.2 indicates moderate severity that may interfere with activities.

---

### Example 2: Minimal Motion
```json
{
  "status": "sedentary",
  "magnitude": 0.8,
  "frequency": 0
}
```
**Interpretation:** Patient is very still. Minimal motion detected (magnitude 0.8) with no periodic oscillation. Could indicate good tremor control (medication working) or patient relaxation.

---

### Example 3: Sub-tremor Frequency Motion
```json
{
  "status": "sedentary",
  "magnitude": 2.3,
  "frequency": 1.1
}
```
**Interpretation:** Patient is sedentary but showing slow motion (1.1 Hz). This is below Parkinsonian tremor range - likely postural drift or slow swaying. Magnitude of 2.3 indicates mild motion but NOT tremor. This is NORMAL and should not be flagged as tremor.

---

### Example 4: Walking/Activity
```json
{
  "status": "active",
  "magnitude": 0,
  "frequency": 0
}
```
**Interpretation:** Patient is walking or actively moving. Tremor assessment is suspended during voluntary movement. This is expected and normal during daily activities.

---

### Example 5: Severe Tremor
```json
{
  "status": "sedentary",
  "magnitude": 7.8,
  "frequency": 4.7
}
```
**Interpretation:** Severe Parkinsonian resting tremor. Patient is sedentary with a strong tremor at 4.7 Hz (classic Parkinson's frequency). Magnitude of 7.8 indicates marked severity that significantly impacts function. May indicate medication wearing off.

---

### Example 6: Essential/Postural Tremor
```json
{
  "status": "sedentary",
  "magnitude": 3.5,
  "frequency": 7.2
}
```
**Interpretation:** Moderate motion at 7.2 Hz - higher than typical Parkinsonian resting tremor. Could indicate essential tremor, postural tremor, or medication-induced tremor. Magnitude of 3.5 is moderate.

---

## Data Collection Context

### Sampling Parameters
- **Burst Duration:** 10 seconds per minute
- **Sampling Rate:** 50 Hz (500 samples per burst)
- **Reporting Interval:** Every 60 seconds
- **Duty Cycle:** 16.7% (10s on, 50s off)

### Algorithm Calibration Constants
```typescript
WALK_THRESH = 1.5        // Variance threshold for "active" classification
NOISE_FLOOR = 0.05       // Dead zone for frequency counting (m/s²)
MIN_FREQ_HZ = 3.0        // Minimum for Parkinsonian tremor range
SCALING_FACTOR = 1.5     // MAD-to-magnitude scaling
```

---

## Backend Storage Recommendations

### Database Schema
```sql
CREATE TABLE tremor_readings (
  timestamp TIMESTAMPTZ NOT NULL,
  user_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  status TEXT CHECK (status IN ('sedentary', 'active')),
  magnitude NUMERIC(3,1) CHECK (magnitude BETWEEN 0.0 AND 10.0),
  frequency NUMERIC(4,1) CHECK (frequency BETWEEN 0.0 AND 15.0),
  avg_bpm INTEGER,
  min_bpm INTEGER,
  max_bpm INTEGER
);

CREATE INDEX idx_tremor_user_time ON tremor_readings(user_id, timestamp DESC);
CREATE INDEX idx_tremor_severity ON tremor_readings(magnitude) WHERE status = 'sedentary';
```

### Derived Metrics for Clinical Dashboard
```sql
-- Daily tremor burden score (sum of magnitude when tremor-frequency detected)
SELECT 
  DATE(timestamp) as date,
  SUM(CASE 
    WHEN status = 'sedentary' 
      AND frequency BETWEEN 3.0 AND 12.0 
      AND magnitude > 1.0
    THEN magnitude 
    ELSE 0 
  END) as daily_tremor_score
FROM tremor_readings
WHERE user_id = 'USER_ID'
GROUP BY DATE(timestamp);

-- Tremor episode detection (consecutive readings with magnitude > 3.0)
SELECT 
  timestamp,
  magnitude,
  frequency,
  LAG(timestamp) OVER (ORDER BY timestamp) as prev_time
FROM tremor_readings
WHERE status = 'sedentary' 
  AND magnitude > 3.0
  AND frequency BETWEEN 3.0 AND 12.0;
```

---

## Quality Assurance

### Data Quality Checks
1. **Consistency Check:** If status = "active", magnitude and frequency must be 0
2. **Range Check:** All values must be within specified ranges
3. **Temporal Check:** No more than one reading per minute per device
4. **Correlation Check:** High magnitude should correlate with non-zero frequency

### Known Limitations
- **Cannot detect:** Intention tremor (requires motion capture during reaching)
- **May misclassify:** Severe dyskinesia as high-magnitude tremor
- **Affected by:** External vibration (vehicle, machinery)
- **Not validated for:** Tremor during sleep (sleep tremor rare in Parkinson's)

---

## Clinical Use Cases

### Medication Titration
Monitor magnitude trends:
- **Increase dose:** If magnitude consistently > 4.0 during "ON" periods
- **Decrease dose:** If dyskinesia suspected (high magnitude with irregular frequency)
- **Adjust timing:** If tremor increases before next dose (wearing-off)

### Symptom Progression Tracking
Compare weekly averages:
- Upward trend in magnitude may indicate disease progression
- Frequency shift may indicate medication tolerance

### Caregiver Alerts
Trigger notifications when:
- Magnitude > 6.0 for > 15 minutes (severe tremor episode)
- Sudden magnitude increase > 3.0 points (acute medication failure)
- Status = "sedentary" for > 6 hours (immobility risk)

---

## References

### Algorithm Basis
- Mean Absolute Deviation (MAD): Robust amplitude estimation
- Zero-Crossing Rate (ZCR): Frequency estimation for oscillatory signals
- Hysteresis: Noise rejection in signal processing

### Clinical References
- Parkinsonian tremor frequency: 3-6 Hz (Deuschl & Elble, 2009)
- UPDRS tremor scoring: 0-4 scale (adapted to 0-10 for granularity)
- Activity classification: Walking variance > 1.5 m/s² (empirical testing)

---

**Document Version:** 1.0  
**Last Updated:** November 23, 2025  
**Algorithm Version:** MotionAnalyzer v1.0
