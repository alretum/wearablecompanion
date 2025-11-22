# Parkinson's Freeze Detection - Wearable Companion

> **A HarmonyOS wearable application that predicts Parkinson's freezing of gait episodes before they occur.**

## 🎯 Quick Overview

This system monitors motion patterns and physiological signals in real-time to:
- ✅ **Predict freezing episodes** 5 seconds before they occur
- ✅ **Detect and log tremors** for medical reporting  
- ✅ **Send real-time alerts** via vibration to warn patients
- ✅ **Sync data to AWS cloud** for doctor review and analysis
- ✅ **Store events locally** in `report.json` file on the watch

---

## 📖 Documentation Quick Links

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **[OVERVIEW.md](OVERVIEW.md)** | Complete system architecture | Understanding the entire system |
| **[QUICKSTART.md](QUICKSTART.md)** | Step-by-step setup checklist | Getting started (read this first!) |
| **[AWS_SETUP.md](AWS_SETUP.md)** | AWS deployment guide | Setting up cloud backend |
| **[ALGORITHM_GUIDE.md](ALGORITHM_GUIDE.md)** | Implementation examples | Coding the detection algorithms |
| **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** | What's built summary | Quick reference |
| **[DATA_COLLECTION_GUIDE.md](DATA_COLLECTION_GUIDE.md)** | Data collection for testing | Branch: `datacollection2` |

---

## 🧪 Data Collection Branch

For comprehensive sensor data collection and testing, checkout the **`datacollection2`** branch:

```bash
git switch datacollection2
```

This branch enables:
- ✅ **All raw sensor data logging** (accelerometer, gyroscope, heart rate at full rate)
- ✅ **Complete event capture** (tremors, freezes, GPS coordinates)
- ✅ **Local JSON export** for analysis with Python/MATLAB
- ✅ **Testing and algorithm development** without cloud upload

See **[DATA_COLLECTION_GUIDE.md](DATA_COLLECTION_GUIDE.md)** for complete instructions.

---

## 🚀 Quick Start (3 Steps)

### 1. Deploy AWS Backend (30 minutes)
```bash
# See AWS_SETUP.md for details
# - Create 2 S3 buckets (reports + heart rate)
# - Deploy 2 Lambda functions  
# - Set up API Gateway with 2 endpoints
```

### 2. Configure App (5 minutes)
```typescript
// Edit: entry/src/main/ets/config/AppConfig.ets

// AWS endpoints - replace with your actual API Gateway URLs
static readonly SYNC_DATA_ENDPOINT = 'https://YOUR-API.../upload-report';
static readonly HEART_RATE_ENDPOINT = 'https://YOUR-API.../upload-heartrate';

// Old endpoints not used anymore
static readonly TREMOR_REPORT_ENDPOINT = '';
static readonly FREEZE_ALERT_ENDPOINT = '';

// Monitoring behavior - app runs continuously by default
static readonly AUTO_START_MONITORING = true; // Set false to require manual start

// Data management - data cleared after upload by default
static readonly CLEAR_DATA_AFTER_SYNC = true; // Set false to retain all data
```

### 3. Test & Deploy
- Mock detection algorithms are already implemented for testing
- Deploy to watch and monitoring starts automatically
- Replace mock algorithms with real implementations later

**Then**: Build, deploy, test! 🎉

---

## 🔄 Always-On Monitoring Mode

By default (`AUTO_START_MONITORING = true`):
- ✅ App starts monitoring **automatically** when launched
- ✅ Continues running in **background** (requires KEEP_BACKGROUND_RUNNING permission)
- ✅ User can manually stop/start via UI buttons
- ✅ Persists across app restarts

To require manual start: Set `AUTO_START_MONITORING = false` in AppConfig.ets

---

## 📱 Local Data Management

All tremors and freeze predictions are logged to local JSON files:

### 1. Report Data (Processed Metrics Only)

**File Location**: `{app_files_dir}/report.json`

**File Structure** (note: NO raw sensor data):
```json
{
  "sessionId": "SESSION_1234567890",
  "userId": "USER_ABC",
  "deviceId": "DEVICE_XYZ",
  "sessionStart": 1234567890000,
  "sessionEnd": 1234567890000,
  "totalTremors": 5,
  "totalFreezes": 2,
  "tremors": [
    {
      "severity": 6.5,
      "duration": 2000,
      "timestamp": 1234567890000
    }
  ],
  "freezePredictions": [
    {
      "probability": 0.85,
      "confidence": 0.92,
      "timestamp": 1234567890000,
      "indicators": {
        "tremor": true,
        "gaitDisturbance": true,
        "stressSpike": false
      },
      "gpsCoordinates": {
        "latitude": 51.5074,
        "longitude": -0.1278,
        "altitude": 11.0,
        "accuracy": 5.0,
        "timestamp": 1234567890000
      }
    }
  ],
  "lastUpdated": 1234567890000
}
```

**Uploaded to**: `/upload-report` endpoint when freeze events occur (no longer on fixed schedule)

**Note**: GPS coordinates are automatically retrieved and included in `freezePredictions` for emergency assistance and location tracking of freeze events. GPS is only used for freeze events, not for tremors.

### 2. Heart Rate Data (Aggregated per Minute)

**Content**: 5 minutes of aggregated heart rate statistics

**Structure**:
```json
{
  "userId": "USER_ABC",
  "deviceId": "DEVICE_XYZ",
  "reportTimestamp": 1234567890000,
  "minutes": [
    {
      "timestamp": 1234567200000,
      "avgBpm": 72.5,
      "minBpm": 68,
      "maxBpm": 78,
      "sampleCount": 60
    },
    // ... 4 more minutes
  ]
}
```

**Uploaded to**: `/upload-heartrate` endpoint every 5 minutes

### Data Characteristics

- **Processed Data Only**: Raw accelerometer/gyroscope data NOT stored (saves space)
- **Continuous Logging**: All events written immediately to files
- **5-Minute Upload**: Both files uploaded every 5 minutes
- **Auto-Clear**: Data cleared after successful upload (if `CLEAR_DATA_AFTER_SYNC = true`)

---

## ☁️ Cloud Integration

### Two Separate Endpoints

**Endpoint 1: `/upload-report`**
- Receives: Processed tremor and freeze prediction data
- Format: Complete report.json with severity, duration, probability metrics
- GPS: Freeze predictions include GPS coordinates for emergency location tracking
- Storage: S3 bucket organized by userId/sessionId
- Trigger: Sent when freeze incident occurs (not on fixed schedule)

**Endpoint 2: `/upload-heartrate`**
- Receives: 5 minutes of aggregated heart rate data (1 entry per minute)
- Format: avgBpm, minBpm, maxBpm, sampleCount for each minute
- Storage: S3 bucket organized by userId/timestamp

### AWS Architecture
```
Wearable Watch
    ↓ (report.json + heartrate.json via HTTPS)
AWS API Gateway
    ├─→ /upload-report → Lambda → S3 (Reports)
    └─→ /upload-heartrate → Lambda → S3 (Heart Rate)
    ↓
S3 Storage (Organized by User/Session)
    ↓
Doctor Dashboard / Data Analysis
```

### AWS Components
- **API Gateway**: Two HTTPS endpoints for data upload
- **Lambda Functions**: Validate and save to S3 (one per endpoint)
- **S3**: Long-term storage organized by user ID
- **CloudWatch**: Monitor uploads and errors

See `AWS_SETUP.md` for complete setup instructions.

### Data Retention Control

Set in `AppConfig.ets`:
```typescript
static readonly CLEAR_DATA_AFTER_SYNC = true;  // Clear after upload (default)
static readonly CLEAR_DATA_AFTER_SYNC = false; // Keep all data for debugging
```

---

## 🏗️ Architecture

```
entry/src/main/ets/
├── config/
│   └── AppConfig.ets          # Configuration and AWS endpoints
├── common/
│   └── CoordinatesConverter.ets # GPS coordinate conversion utility
├── sensors/
│   ├── SensorData.ets         # Data models and interfaces
│   └── SensorManager.ets      # Sensor data collection
├── algorithms/
│   ├── PredictionAlgorithm.ets # Freeze prediction logic (mock)
│   └── TremorDetector.ets      # Tremor detection (mock)
├── services/
│   ├── MonitoringService.ets   # Main orchestrator
│   ├── ReportLogger.ets        # Logs tremors/freezes to report.json
│   └── HeartRateLogger.ets     # Aggregates heart rate per minute
├── connectivity/
│   └── APIService.ets         # AWS Lambda communication
├── services/
│   ├── MonitoringService.ets  # Main orchestrator
│   └── ReportLogger.ets       # Local JSON file logging
├── entryability/
│   └── EntryAbility.ets       # App lifecycle management
└── pages/
    └── Index.ets              # User interface
```

## 📋 Prerequisites

1. **HarmonyOS SDK** - DevEco Studio with HarmonyOS SDK 5.0+
2. **AWS Account** - For Lambda functions and API Gateway
3. **Wearable Device** - HarmonyOS smartwatch with sensors

## ⚙️ Setup Instructions

### 1. Configure AWS Backend

You need to create three AWS Lambda functions with API Gateway endpoints:

#### Lambda Function 1: Tremor Report (`/tremor-report`)
- **Purpose**: Receive tremor event data for doctor reports
- **Method**: POST
- **Payload**: 
```json
{
  "userId": "string",
  "deviceId": "string",
  "tremors": [
    {
      "severity": 0-10,
      "duration": "milliseconds",
      "timestamp": "unix timestamp",
      "accelerometerData": [...],
      "gyroscopeData": [...]
    }
  ],
  "timestamp": "unix timestamp"
}
```

#### Lambda Function 2: Freeze Alert (`/freeze-alert`)
- **Purpose**: Receive real-time freeze predictions
- **Method**: POST
- **Payload**:
```json
{
  "userId": "string",
  "deviceId": "string",
  "prediction": {
    "probability": 0-1,
    "timeToFreeze": "milliseconds",
    "confidence": 0-1,
    "indicators": {
      "tremor": boolean,
      "gaitDisturbance": boolean,
      "stressSpike": boolean
    },
    "gpsCoordinates": {
      "latitude": number,
      "longitude": number,
      "altitude": number,
      "accuracy": number,
      "timestamp": number
    }
  },
  "timestamp": "unix timestamp"
}
```

#### Lambda Function 3: Data Sync (`/sync-data`)
- **Purpose**: Periodic sync of all monitoring data
- **Method**: POST
- **Payload**:
```json
{
  "userId": "string",
  "deviceId": "string",
  "sessionStart": "unix timestamp",
  "sessionEnd": "unix timestamp",
  "totalTremors": number,
  "totalFreezes": number,
  "data": {
    "tremors": [...],
    "predictions": [...]
  }
}
```

### 2. Update Configuration

Edit `entry/src/main/ets/config/AppConfig.ets`:

```typescript
// Replace with your actual AWS API Gateway endpoints
static readonly TREMOR_REPORT_ENDPOINT = 'https://YOUR-API-ID.execute-api.REGION.amazonaws.com/prod/tremor-report';
static readonly FREEZE_ALERT_ENDPOINT = 'https://YOUR-API-ID.execute-api.REGION.amazonaws.com/prod/freeze-alert';
static readonly SYNC_DATA_ENDPOINT = 'https://YOUR-API-ID.execute-api.REGION.amazonaws.com/prod/sync-data';
static readonly AWS_REGION = 'YOUR-REGION'; // e.g., 'us-east-1'
```

### 3. Implement Detection Algorithms

The placeholder algorithms need your implementation:

#### `PredictionAlgorithm.ets`
Located in `entry/src/main/ets/algorithms/PredictionAlgorithm.ets`

**TODO sections to implement:**
- `detectTremorPattern()` - Implement FFT or peak detection for 4-6 Hz tremors
- `detectGaitDisturbance()` - Analyze stride patterns and variability
- `calculateFreezeProbability()` - Implement your ML model or rule-based system

**Research-based indicators:**
- Reduced stride length
- Increased stride variability
- 4-6 Hz tremor frequency
- Heart rate spikes (stress)
- Festination (rapid small steps)

#### `TremorDetector.ets`
Located in `entry/src/main/ets/algorithms/TremorDetector.ets`

**TODO sections to implement:**
- `analyzeTremorPattern()` - Frequency analysis for tremor detection
- `calculateTremorSeverity()` - Amplitude and consistency assessment

**Note**: All detected events are automatically logged to `report.json` by the ReportLogger.

### 4. Add Authentication (Optional but Recommended)

Update `APIService.ets`:
```typescript
// Add your authentication tokens
const headers = {
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${YOUR_JWT_TOKEN}`,
  'X-API-Key': 'YOUR_API_KEY',
};
```

### 5. Build and Deploy

```bash
# Open project in DevEco Studio
# Build the project
# Install on HarmonyOS wearable device
# Grant required permissions when prompted
```

## 🔐 Required Permissions

All permissions are configured in `entry/src/main/module.json5`:

- ✅ `ohos.permission.ACCELEROMETER` - Linear accelerometer for motion
- ✅ `ohos.permission.GYROSCOPE` - Rotation detection
- ✅ `ohos.permission.READ_HEALTH_DATA` - Heart rate monitoring
- ✅ `ohos.permission.INTERNET` - AWS connectivity
- ✅ `ohos.permission.DISTRIBUTED_DATASYNC` - Data synchronization
- ✅ `ohos.permission.KEEP_BACKGROUND_RUNNING` - Background monitoring

## 🎛️ Configuration Options

Edit `AppConfig.ets` to customize:

```typescript
// Sensor sampling rates
ACCELEROMETER_RATE = 50;     // 50 Hz
GYROSCOPE_RATE = 50;         // 50 Hz
HEART_RATE_INTERVAL = 1000;  // 1 second

// Detection thresholds
TREMOR_THRESHOLD = 0.5;
FREEZE_PREDICTION_THRESHOLD = 0.7;
HEART_RATE_SPIKE_THRESHOLD = 20;  // BPM

// Data management
SENSOR_BUFFER_SIZE = 100;
TREMOR_LOG_BATCH_SIZE = 10;
DATA_SYNC_INTERVAL_MS = 300000;   // 5 minutes

// User alerts
ENABLE_VIBRATION_ALERT = true;
ENABLE_SOUND_ALERT = true;
AUTO_START_MONITORING = false;
```

## 📱 User Interface

The watch displays:
- **Status**: Current monitoring state
- **Sensor Data**: Real-time accelerometer, gyroscope, heart rate
- **Alerts**: Freeze predictions and tremor detections
- **Statistics**: Session tremor/freeze counts
- **Controls**: Start/stop monitoring, test API connection

## 🔬 Algorithm Implementation Guide

### Recommended Approaches

1. **Machine Learning Model**
   - Train on labeled Parkinson's gait data
   - Deploy lightweight model (TensorFlow Lite, ONNX)
   - Implement in `calculateFreezeProbability()`

2. **Signal Processing**
   - FFT for frequency analysis (4-6 Hz tremor)
   - Autocorrelation for rhythm detection
   - Peak detection for gait events

3. **Rule-Based System**
   - Combine multiple indicators with weights
   - Use clinical research thresholds
   - Easier to interpret and debug

### Data Features to Extract

- **Acceleration magnitude**: `sqrt(x² + y² + z²)`
- **Variance**: Movement stability
- **Peak frequency**: Dominant oscillation
- **Peak count**: Gait cycle detection
- **Heart rate change**: Stress indicator
- **Time series patterns**: Festination, hesitation

## 🧪 Testing

1. **Test API Connectivity**: Use the "Test API Connection" button in UI
2. **Simulate Sensor Data**: Implement test data generators
3. **Validate Algorithms**: Use known Parkinson's datasets
4. **End-to-End Testing**: Test on actual wearable device

## 📊 Data Flow

1. **Sensors** → Collect accelerometer, gyroscope, heart rate at 50 Hz
2. **Algorithms** → Process in real-time, detect patterns
3. **GPS** → Retrieve coordinates when freeze is predicted
4. **ReportLogger** → Write tremors and freezes (with GPS) to `report.json`
5. **Alerts** → Vibrate/notify user of predicted freeze
6. **API** → Upload `report.json` to AWS when freeze incident occurs
7. **Cloud** → AWS Lambda processes and stores in DynamoDB
8. **Dashboard** → Doctors access reports with freeze locations for patient care

## 🐛 Debugging

Check logs with:
```typescript
hilog.info(DOMAIN, TAG, 'Your message');
```

Log domains:
- `0x0001` - SensorManager
- `0x0002` - PredictionAlgorithm
- `0x0003` - TremorDetector
- `0x0004` - APIService
- `0x0005` - MonitoringService

## 🚀 Next Steps

1. **Implement algorithms** in marked TODO sections
2. **Deploy AWS Lambda functions** with endpoints
3. **Update AppConfig.ets** with your AWS endpoints
4. **Test on wearable device** with real sensor data
5. **Add authentication** for production use
6. **Train/validate** prediction models with clinical data

## 📝 Notes

- The current algorithms are **placeholders** - you must implement the actual detection logic
- AWS endpoints must be configured before deployment
- Consider adding user authentication and data encryption for production
- Battery optimization may be needed for extended monitoring
- Clinical validation is required before medical use

## 📄 License

This is a framework for research and development. Not approved for medical use without proper validation and regulatory approval.

## 🤝 Contributing

This infrastructure is ready for your algorithm implementation. Focus on:
1. Signal processing in `PredictionAlgorithm.ets`
2. Tremor detection in `TremorDetector.ets`
3. AWS Lambda functions for data processing
