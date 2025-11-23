# Data Collection Guide

**Branch**: `datacollection2`  
**Purpose**: Comprehensive sensor data collection for testing and analysis

## Overview

This branch enables complete data collection mode, logging **all sensor readings** and events to a local JSON file for analysis. This is useful for:

- Testing sensor accuracy
- Algorithm development and tuning
- Understanding real-world usage patterns
- Debugging sensor issues
- Training machine learning models

## What Data Is Collected

### 1. Raw Sensor Data (High Frequency)

**Accelerometer** (50 Hz):
```typescript
{
  x: number,      // m/s² in X axis
  y: number,      // m/s² in Y axis
  z: number,      // m/s² in Z axis
  timestamp: number  // Unix timestamp in ms
}
```

**Gyroscope** (50 Hz):
```typescript
{
  x: number,      // rad/s around X axis
  y: number,      // rad/s around Y axis
  z: number,      // rad/s around Z axis
  timestamp: number  // Unix timestamp in ms
}
```

**Heart Rate** (1 Hz):
```typescript
{
  bpm: number,           // Beats per minute
  timestamp: number,     // Unix timestamp in ms
  variability?: number   // Heart rate variability (if available)
}
```

### 2. Processed Events

**Tremor/Activity Events**:
```typescript
{
  status: 'sedentary' | 'active' | 'unknown' | 'not_worn',  // Activity classification
  magnitude: number,      // Motion magnitude (m/s²)
  frequency: number,      // Dominant frequency (Hz), 0 if not detected
  timestamp: number       // Unix timestamp in ms
}
```

**Note**: Tremor/activity data is included in heart rate reports (sent every 5 minutes), NOT in separate incident reports.

**Freeze Predictions**:
```typescript
{
  probability: number,  // 0-1 scale (freeze likelihood)
  confidence: number,   // 0-1 scale (prediction confidence)
  timestamp: number,    // Unix timestamp in ms
  indicators: {
    tremor: boolean,
    gaitDisturbance: boolean,
    stressSpike: boolean
  },
  gpsCoordinates?: {
    latitude: number,
    longitude: number,
    altitude: number,
    accuracy: number,
    timestamp: number
  }
}
```

### 3. GPS Coordinates

**Location Data** (when freeze detected):
```typescript
{
  latitude: number,    // Decimal degrees (-90 to 90)
  longitude: number,   // Decimal degrees (-180 to 180)
  altitude: number,    // Meters above sea level
  accuracy: number,    // Horizontal accuracy in meters
  timestamp: number    // Unix timestamp in ms
}
```

## File Location

### On HarmonyOS Watch

**Primary Collection File**:
```
/data/storage/el2/base/haps/entry/files/data_collection.json
```

**Backup Files** (when exported):
```
/data/storage/el2/base/haps/entry/files/data_collection_backup_<timestamp>.json
```

### Finding the File

1. **Via DevEco Studio Logs**:
   ```bash
   hilog | grep DataCollectionLogger
   ```
   Look for: `Data collection file path: /data/storage/.../data_collection.json`

2. **Via Device File Manager** (if available):
   - Connect watch to DevEco Studio
   - Open Device File Explorer
   - Navigate to app's files directory

3. **Via hdc (HarmonyOS Device Connector)**:
   ```bash
   # List files
   hdc shell ls /data/storage/el2/base/haps/entry/files/
   
   # Pull file to local machine
   hdc file recv /data/storage/el2/base/haps/entry/files/data_collection.json ./data_collection.json
   ```

## Configuration

### Enable Data Collection

Edit `entry/src/main/ets/config/AppConfig.ets`:

```typescript
// Data collection mode (for datacollection2 branch testing)
static readonly ENABLE_DATA_COLLECTION = true;  // Enable comprehensive logging
static readonly DATA_COLLECTION_SAVE_INTERVAL = 100; // Save every N readings
```

### Memory Management

The DataCollectionLogger implements automatic memory management:

- **Accelerometer**: Max 5,000 readings (~100 seconds at 50 Hz)
- **Gyroscope**: Max 5,000 readings (~100 seconds at 50 Hz)
- **Heart Rate**: Max 500 readings (~8 minutes at 1 Hz)
- **GPS**: Max 100 readings
- Older readings are automatically removed when limits are reached

### Save Intervals

- Accelerometer/Gyroscope: Saves every 100 readings (~2 seconds)
- Heart Rate: Saves immediately on each reading
- Tremor/Activity Events: Saves immediately
- Freeze Predictions: Saves immediately
- GPS: Saves immediately

**Note on Data Reporting**: While the data collection logger saves tremor events locally, tremor/activity data is transmitted to the server as part of the 5-minute heart rate report, not as separate incident reports.

## Data Collection Report Structure

Complete JSON structure:

```json
{
  "sessionId": "DATA_COLLECTION_1732233600000",
  "userId": "USER_1732233600000",
  "deviceId": "DEVICE_1732233600000",
  "sessionStart": 1732233600000,
  "sessionEnd": 1732233900000,
  
  "accelerometerData": [
    {"x": 0.12, "y": 9.81, "z": 0.05, "timestamp": 1732233600100},
    {"x": 0.15, "y": 9.80, "z": 0.06, "timestamp": 1732233600120},
    // ... up to 5,000 most recent readings
  ],
  
  "gyroscopeData": [
    {"x": 0.01, "y": 0.02, "z": 0.00, "timestamp": 1732233600100},
    {"x": 0.02, "y": 0.01, "z": 0.01, "timestamp": 1732233600120},
    // ... up to 5,000 most recent readings
  ],
  
  "heartRateData": [
    {"bpm": 72, "timestamp": 1732233600000},
    {"bpm": 73, "timestamp": 1732233601000},
    // ... up to 500 most recent readings
  ],
  
  "tremorEvents": [
    {
      "status": "active",
      "magnitude": 1.2,
      "frequency": 5.3,
      "timestamp": 1732233650000
    },
    {
      "status": "sedentary",
      "magnitude": 0.3,
      "frequency": 0,
      "timestamp": 1732233680000
    }
  ],
  
  "freezePredictions": [
    {
      "probability": 0.85,
      "confidence": 0.92,
      "timestamp": 1732233700000,
      "indicators": {
        "tremor": true,
        "gaitDisturbance": true,
        "stressSpike": false
      },
      "gpsCoordinates": {
        "latitude": 48.1351,
        "longitude": 11.5820,
        "altitude": 520.5,
        "accuracy": 10.0,
        "timestamp": 1732233700050
      }
    }
  ],
  
  "gpsCoordinates": [
    {
      "latitude": 48.1351,
      "longitude": 11.5820,
      "altitude": 520.5,
      "accuracy": 10.0,
      "timestamp": 1732233700050
    }
  ],
  
  "totalAccelReadings": 5000,
  "totalGyroReadings": 5000,
  "totalHeartRateReadings": 300,
  "totalTremors": 2,
  "totalFreezes": 1,
  "totalGPSReadings": 1,
  "lastUpdated": 1732233900000
}
```

## Usage Instructions

### 1. Start Data Collection

```bash
# Build and deploy app to watch
# Monitoring starts automatically (AUTO_START_MONITORING = true)
```

### 2. Monitor Collection Progress

Check logs in DevEco Studio:
```bash
hilog | grep DataCollectionLogger
```

You'll see:
- `Data collection file path: /data/storage/.../data_collection.json`
- `Accelerometer: 100 readings`
- `Gyroscope: 100 readings`
- `Heart rate: 72 BPM`
- `Activity logged: status=active, magnitude=1.20, total=1`
- `Freeze logged: probability=0.85, total=1`

### 3. View Statistics

The app logs statistics periodically. Use `MonitoringService.getDataCollectionStats()` to get:

```
Data Collection Stats:
Session: DATA_COLLECTION_1732233600000
Duration: 300s
Accelerometer: 15000 readings (5000 in memory)
Gyroscope: 15000 readings (5000 in memory)
Heart Rate: 300 readings (300 in memory)
Tremors: 2
Freezes: 1
GPS: 1 readings (1 in memory)
```

### 4. Export Data

**Option A: Pull via hdc**
```bash
# Connect watch via USB
hdc shell ls /data/storage/el2/base/haps/entry/files/

# Download the file
hdc file recv /data/storage/el2/base/haps/entry/files/data_collection.json ./local_data_collection.json
```

**Option B: Create Backup**
```typescript
// Call from app code
MonitoringService.getInstance().exportDataCollection();
// This creates: data_collection_backup_<timestamp>.json
```

### 5. Analyze Data

Use the JSON file for:

**Python Analysis**:
```python
import json
import pandas as pd
import matplotlib.pyplot as plt

# Load data
with open('data_collection.json', 'r') as f:
    data = json.load(f)

# Convert to DataFrame
accel_df = pd.DataFrame(data['accelerometerData'])
gyro_df = pd.DataFrame(data['gyroscopeData'])
hr_df = pd.DataFrame(data['heartRateData'])

# Plot accelerometer data
plt.figure(figsize=(12, 6))
plt.plot(accel_df['timestamp'], accel_df['x'], label='X')
plt.plot(accel_df['timestamp'], accel_df['y'], label='Y')
plt.plot(accel_df['timestamp'], accel_df['z'], label='Z')
plt.xlabel('Timestamp')
plt.ylabel('Acceleration (m/s²)')
plt.legend()
plt.title('Accelerometer Data')
plt.show()

# Analyze tremor events
print(f"Total tremors: {data['totalTremors']}")
print(f"Average severity: {sum(t['severity'] for t in data['tremorEvents']) / len(data['tremorEvents']):.2f}")
```

## Data Flow

```
┌─────────────────────────────────────────────────────────┐
│                    WEARABLE WATCH                       │
│                                                         │
│  Sensors (50 Hz)                                        │
│      ↓                                                  │
│  MonitoringService.handle*Data()                        │
│      ↓                                                  │
│  DataCollectionLogger.log*()                            │
│      ↓                                                  │
│  data_collection.json (local file)                      │
│      - Auto-saves every 100 readings                    │
│      - Max limits prevent memory overflow               │
│      - Keeps most recent data in arrays                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
                          ↓
                    (Export/Pull)
                          ↓
┌─────────────────────────────────────────────────────────┐
│              DEVELOPMENT MACHINE                        │
│                                                         │
│  Local File: data_collection.json                       │
│      ↓                                                  │
│  Analysis Tools:                                        │
│      - Python/Pandas                                    │
│      - MATLAB                                           │
│      - Excel                                            │
│      - Custom scripts                                   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Testing Scenarios

### Scenario 1: Baseline Data Collection
**Goal**: Collect normal movement patterns  
**Duration**: 5-10 minutes  
**Actions**: Normal daily activities, walking, sitting

### Scenario 2: Tremor Simulation
**Goal**: Test tremor detection algorithm  
**Duration**: 2-3 minutes  
**Actions**: Simulate hand shaking at 4-6 Hz

### Scenario 3: Freeze Scenario
**Goal**: Collect data during freeze-like events  
**Duration**: 5 minutes  
**Actions**: Stop suddenly while walking, hesitate movements

### Scenario 4: Heart Rate Variability
**Goal**: Capture stress response  
**Duration**: 5 minutes  
**Actions**: Exercise, rest, observe HR changes

## Troubleshooting

### File Not Created

**Check**:
1. `ENABLE_DATA_COLLECTION = true` in AppConfig.ets
2. MonitoringService.initialize() was called with valid context
3. Monitoring has been started
4. Check logs for "Data collection file path" message

### File Too Large

**Solution**:
- Data collection automatically limits array sizes
- Export/backup regularly
- Clear collection: `dataCollectionLogger.clearCollection()`

### Missing Sensor Data

**Check**:
1. Sensor permissions granted
2. Sensors working (check UI for live readings)
3. handleAccelerometerData/handleGyroscopeData/handleHeartRateData are being called
4. Check logs for "Accelerometer: N readings" messages

### GPS Coordinates Not Collected

**Check**:
1. Location permissions granted (APPROXIMATELY_LOCATION)
2. GPS enabled on watch
3. Freeze prediction occurred (GPS only collected during freeze events)
4. Check logs for "GPS coordinates retrieved" or "Failed to get GPS coordinates"

## Best Practices

1. **Regular Exports**: Export data every 10-15 minutes to avoid data loss
2. **Monitor Memory**: Watch for app slowdown if collecting for extended periods
3. **Clear After Export**: Use `clearCollection()` after successful export
4. **Label Sessions**: Note what activities were performed during each collection session
5. **Timestamp Analysis**: Always use timestamps for correlating events across sensors

## Data Privacy

⚠️ **Important**: This branch collects comprehensive sensor data including GPS coordinates.

- Only use for testing purposes
- Do not deploy to production with `ENABLE_DATA_COLLECTION = true`
- Handle collected data according to privacy regulations
- GPS coordinates can reveal personal locations
- Delete test data when no longer needed

## Next Steps

After collecting data:

1. **Analysis**: Use Python/MATLAB to analyze sensor patterns
2. **Algorithm Tuning**: Adjust detection thresholds based on real data
3. **Model Training**: Use data to train ML models for better predictions
4. **Documentation**: Record findings and observations
5. **Merge**: Disable data collection and merge improvements back to main branch

---

**Note**: This data collection mode is specifically for the `datacollection2` branch. Always set `ENABLE_DATA_COLLECTION = false` before merging to production branches.
