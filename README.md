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

---

## 🚀 Quick Start (3 Steps)

### 1. Deploy AWS Backend (1 hour)
```bash
# See AWS_SETUP.md for details
# - Create 3 DynamoDB tables
# - Deploy 3 Lambda functions  
# - Set up API Gateway
```

### 2. Configure App (5 minutes)
```typescript
// Edit: entry/src/main/ets/config/AppConfig.ets
static readonly TREMOR_REPORT_ENDPOINT = 'https://YOUR-API...';
static readonly FREEZE_ALERT_ENDPOINT = 'https://YOUR-API...';
static readonly SYNC_DATA_ENDPOINT = 'https://YOUR-API...';
```

### 3. Implement Algorithms (1-2 hours)
```typescript
// Edit: entry/src/main/ets/algorithms/
// - PredictionAlgorithm.ets (freeze prediction)
// - TremorDetector.ets (tremor detection)
// See ALGORITHM_GUIDE.md for implementation options
```

**Then**: Build, deploy, test! 🎉

---

## 📱 Local Data Management

All tremors and freeze predictions are logged to a local JSON file:

**File Location**: `{app_files_dir}/report.json`

**File Structure**:
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
      "timestamp": 1234567890000,
      "accelerometerData": [...],
      "gyroscopeData": [...]
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
      }
    }
  ]
}
```

This file is continuously updated and uploaded to the cloud for processing.

## ☁️ Cloud Integration

The system integrates with AWS for data storage and analysis:

### AWS Architecture
```
Wearable Watch
    ↓ (report.json via HTTPS)
AWS API Gateway
    ↓
Lambda Functions
    ├─ Process tremor reports
    ├─ Analyze freeze predictions
    └─ Store in DynamoDB
    ↓
Doctor Dashboard
```

### AWS Components
- **API Gateway**: Secure HTTPS endpoints for data upload
- **Lambda Functions**: Process and validate incoming reports
- **DynamoDB**: Store patient data for long-term analysis
- **CloudWatch**: Monitor system health and errors

See `AWS_SETUP.md` for complete setup instructions.

## 🏗️ Architecture

```
entry/src/main/ets/
├── config/
│   └── AppConfig.ets          # Configuration and AWS endpoints
├── sensors/
│   ├── SensorData.ets         # Data models and interfaces
│   └── SensorManager.ets      # Sensor data collection
├── algorithms/
│   ├── PredictionAlgorithm.ets # Freeze prediction logic
│   └── TremorDetector.ets      # Tremor detection and logging
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
3. **ReportLogger** → Write tremors and freezes to `report.json`
4. **Alerts** → Vibrate/notify user of predicted freeze
5. **API** → Upload `report.json` to AWS every 5 minutes
6. **Cloud** → AWS Lambda processes and stores in DynamoDB
7. **Dashboard** → Doctors access reports for patient care

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
