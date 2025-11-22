# Parkinson's Freeze Detection System - Complete Overview

**A comprehensive wearable health monitoring system for Parkinson's disease patients**

## 🎯 System Purpose

This HarmonyOS wearable application predicts and detects Parkinson's disease symptoms in real-time:
- **Freeze Prediction**: Warns 5 seconds before freezing of gait episodes
- **Tremor Detection**: Identifies and measures tremor events with mock algorithms
- **Cloud Reporting**: Automatically uploads patient data for medical analysis
- **Real-time Alerts**: Vibration feedback to warn patients
- **Always-On Monitoring**: Runs continuously by default (configurable)

## 🔄 Monitoring Modes

### Default: Always-On Mode (`AUTO_START_MONITORING = true`)
- App starts monitoring automatically on launch
- Continues in background with KEEP_BACKGROUND_RUNNING permission
- User can stop/start via UI as needed
- Recommended for production use

### Manual Mode (`AUTO_START_MONITORING = false`)
- User must tap "Start Monitoring" button
- Useful for testing or controlled usage
- Can be toggled in AppConfig.ets

## 📦 What's Included

### Core Components

1. **Wearable Application** (HarmonyOS/ArkTS)
   - Real-time sensor monitoring (50 Hz)
   - On-device pattern detection algorithms
   - Local data logging to JSON
   - Cloud synchronization
   - User interface with live monitoring

2. **Local Data Storage**
   - `report.json` file stores all events
   - Persistent across app restarts
   - Automatically synced to cloud
   - Cleared after successful upload

3. **Cloud Integration** (AWS)
   - API Gateway for secure endpoints
   - Lambda functions for data processing
   - DynamoDB for long-term storage
   - CloudWatch for monitoring

4. **Documentation**
   - Complete setup guides
   - Algorithm implementation help
   - AWS deployment instructions
   - Quick-start checklists

## 🏗️ System Architecture

### End-to-End Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        WEARABLE DEVICE                          │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │  Sensors     │ -> │  Algorithms  │ -> │   Loggers    │    │
│  │              │    │              │    │              │    │
│  │ • Accel 50Hz │    │ • Tremor     │    │ ReportLogger │    │
│  │ • Gyro 50Hz  │    │ • Freeze     │    │ (processed)  │    │
│  │ • Heart 1Hz  │    │ • Predict    │    │              │    │
│  └──────────────┘    └──────────────┘    │ HeartRate    │    │
│                                           │ Logger       │    │
│                                           │ (aggregated) │    │
│                                           └──────────────┘    │
│                                                  │              │
│                                                  v              │
│                                          ┌──────────────┐      │
│                                          │  APIService  │      │
│                                          │  (HTTPS)     │      │
│                                          └──────────────┘      │
└───────────────────────────────────────────────┼────────────────┘
                                                │
                                                │ Upload every 5 min
                                                │ (2 endpoints)
                                                v
┌─────────────────────────────────────────────────────────────────┐
│                          AWS CLOUD                              │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │ API Gateway  │ -> │   Lambda     │ -> │      S3      │    │
│  │              │    │              │    │              │    │
│  │ /upload-     │    │ Validate &   │    │ • Reports    │    │
│  │  report      │    │ Save to S3   │    │   bucket     │    │
│  │              │    │              │    │              │    │
│  │ /upload-     │    │ (2 separate  │    │ • Heart Rate │    │
│  │  heartrate   │    │  functions)  │    │   bucket     │    │
│  └──────────────┘    └──────────────┘    └──────────────┘    │
│                                                                 │
│                           ┌──────────────┐                     │
│                           │  CloudWatch  │                     │
│                           │  Monitoring  │                     │
│                           └──────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 v
                        ┌──────────────┐
                        │   Doctor     │
                        │  Dashboard   │
                        └──────────────┘
```

## 📊 Data Flow Details

### 1. Sensor Collection (Watch)
- **Accelerometer**: 50 Hz, detects motion and tremors
- **Gyroscope**: 50 Hz, detects rotation and tremors
- **Heart Rate**: 1 Hz, detects stress through pulse spikes

### 3. Local Storage (Watch)
- **ReportLogger**: Manages report.json file
- **Continuous Writing**: Every event saved immediately
- **File Location**: `{app_files_dir}/report.json`
- **Upload Cycle**: Every 5 minutes to cloud
- **Data Clearing**: Configurable via `CLEAR_DATA_AFTER_SYNC`
  - `true` (default): Clears tremors/predictions after successful upload
  - `false`: Retains all data for debugging

### 4. Cloud Upload (Every 5 minutes)
- **Endpoint**: POST `/sync-data`
- **Payload**: Complete report.json file
- **On Success**: 
  - If `CLEAR_DATA_AFTER_SYNC = true`: Clear event arrays, keep session metadata
  - If `CLEAR_DATA_AFTER_SYNC = false`: Retain all data
- **On Failure**: Retry on next cycle, data preserved
- **PredictionAlgorithm**: Predicts freezing from gait patterns
- Real-time processing with minimal latency

### 3. Local Logging (Watch)
- **ReportLogger** writes to `report.json`
- File location: `{app_files_dir}/report.json`
- Contains: session metadata, tremors, freeze predictions
- Automatically managed (append, clear after upload)

### 4. Cloud Upload (Watch → AWS)
- **Automatic sync**: Every 5 minutes
- **Manual sync**: On demand via API
- **Secure transfer**: HTTPS with optional authentication
- **Retry logic**: Failed uploads are retried

### 5. Cloud Processing (AWS)
- **Validation**: Lambda validates incoming data
- **Storage**: DynamoDB stores for analysis
- **Notifications**: Optional SNS alerts for high-risk events
- **Monitoring**: CloudWatch tracks all operations

### 6. Medical Review (Doctor Dashboard)
- Access to patient history
- Tremor and freeze patterns
- Session-by-session analysis
- Export capabilities for reports

## 🗂️ Project Structure

```
WearableCompanion/
├── README.md                    # This overview (you are here)
├── QUICKSTART.md               # Step-by-step setup checklist
├── AWS_SETUP.md                # Complete AWS deployment guide
├── ALGORITHM_GUIDE.md          # Algorithm implementation help
│
├── entry/src/main/ets/
│   ├── config/
│   │   └── AppConfig.ets       # AWS endpoints & settings
│   │
│   ├── sensors/
│   │   ├── SensorData.ets      # Data models & types
│   │   └── SensorManager.ets   # Sensor collection (50 Hz)
│   │
│   ├── algorithms/
│   │   ├── PredictionAlgorithm.ets  # Freeze prediction (TODO)
│   │   └── TremorDetector.ets       # Tremor detection (TODO)
│   │
│   ├── services/
│   │   ├── MonitoringService.ets    # Main orchestrator
│   │   └── ReportLogger.ets         # Local JSON logging
│   │
│   ├── connectivity/
│   │   └── APIService.ets      # AWS API communication
│   │
│   ├── pages/
│   │   └── Index.ets           # User interface
│   │
│   └── entryability/
│       └── EntryAbility.ets    # App lifecycle
│
└── AppScope/
    ├── app.json5               # App configuration
    └── resources/              # Icons, strings
```

## 🚀 Getting Started

### Prerequisites
- HarmonyOS SDK 5.0+
- DevEco Studio
- AWS Account
- HarmonyOS smartwatch

### Quick Setup (3 Steps)

**1. Deploy AWS Backend** (1 hour)
```bash
# Follow AWS_SETUP.md
# Create DynamoDB tables
# Deploy Lambda functions
# Set up API Gateway
```

**2. Configure Application** (5 minutes)
```typescript
// Edit entry/src/main/ets/config/AppConfig.ets
static readonly TREMOR_REPORT_ENDPOINT = 'https://YOUR-API-ID...';
static readonly FREEZE_ALERT_ENDPOINT = 'https://YOUR-API-ID...';
static readonly SYNC_DATA_ENDPOINT = 'https://YOUR-API-ID...';
```

**3. Implement Algorithms** (1-2 hours minimum)
```typescript
// Edit entry/src/main/ets/algorithms/PredictionAlgorithm.ets
// Edit entry/src/main/ets/algorithms/TremorDetector.ets
// See ALGORITHM_GUIDE.md for implementation options
```

### Detailed Instructions

📖 **Follow `QUICKSTART.md`** for complete step-by-step instructions

## 📄 Report File Format

### Local Storage: `report.json`

```json
{
  "sessionId": "SESSION_1700000000000",
  "userId": "USER_ABC123",
  "deviceId": "DEVICE_XYZ789",
  "sessionStart": 1700000000000,
  "sessionEnd": 1700003600000,
  "totalTremors": 12,
  "totalFreezes": 3,
  "tremors": [
    {
      "severity": 6.5,
      "duration": 2000,
      "timestamp": 1700001000000,
      "accelerometerData": [
        { "x": 0.5, "y": 9.8, "z": 0.1, "timestamp": 1700001000000 },
        // ... more readings
      ],
      "gyroscopeData": [
        { "x": 0.01, "y": 0.02, "z": 0.01, "timestamp": 1700001000000 },
        // ... more readings
      ]
    }
    // ... more tremors
  ],
  "freezePredictions": [
    {
      "probability": 0.85,
      "timeToFreeze": 5000,
      "timestamp": 1700002000000,
      "confidence": 0.92,
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
        "timestamp": 1700002000000
      }
    }
    // ... more predictions
  ],
  "lastUpdated": 1700003600000
}
```

### File Lifecycle

1. **Created**: When monitoring starts
2. **Updated**: Real-time as events occur
3. **GPS Retrieved**: When freeze events are detected
4. **Uploaded**: When freeze incidents occur (event-driven)
5. **Cleared**: After successful upload (metadata retained)
6. **Archived**: Old sessions stored in DynamoDB

## ☁️ Cloud Integration Details

### AWS Services Used

| Service | Purpose | Cost Est. |
|---------|---------|-----------|
| API Gateway | HTTPS endpoints | $3.50/1M requests |
| Lambda | Data processing | $0.20/1M requests |
| DynamoDB | Data storage | $1.25/GB/month |
| CloudWatch | Logging & monitoring | Included |
| **Total** | **Per user/month** | **~$5-10** |

### API Endpoints

1. **POST /tremor-report**
   - Receives individual tremor events
   - Real-time doctor notifications
   - Fast response for immediate alerts

2. **POST /freeze-alert**
   - Receives freeze predictions
   - High-priority processing
   - Optional caregiver notifications

3. **POST /sync-data**
   - Receives complete `report.json`
   - Batch processing for efficiency
   - Triggered when freeze incidents occur
   - Includes GPS coordinates for freeze events

### Security

- ✅ HTTPS encryption (TLS 1.2+)
- ✅ API key authentication (optional)
- ✅ AWS IAM roles for Lambda
- ✅ DynamoDB encryption at rest
- ✅ CloudTrail audit logging
- ⚠️ TODO: User authentication (Cognito)
- ⚠️ TODO: Data anonymization for HIPAA

## 🔧 Configuration Options

### Sensor Rates
```typescript
ACCELEROMETER_RATE = 50;     // Hz
GYROSCOPE_RATE = 50;         // Hz
HEART_RATE_INTERVAL = 1000;  // ms
```

### Detection Thresholds
```typescript
TREMOR_THRESHOLD = 0.5;
FREEZE_PREDICTION_THRESHOLD = 0.7;
HEART_RATE_SPIKE_THRESHOLD = 20;  // BPM
```

### Sync Settings
```typescript
DATA_SYNC_INTERVAL_MS = 300000;   // 5 minutes
TREMOR_LOG_BATCH_SIZE = 10;       // Events per batch
```

## 📱 User Interface

The watch displays:
- **Status**: Monitoring state (Stopped/Monitoring/Alert)
- **Sensor Data**: Real-time x/y/z values and BPM
- **Recent Alerts**: Latest tremor and freeze detections
- **Statistics**: Session tremor/freeze counts
- **Report Info**: Session ID, file size, event counts
- **Controls**: Start/stop monitoring, test connectivity

## ✅ What's Complete

- ✅ Complete sensor data collection pipeline
- ✅ Data model definitions
- ✅ Local JSON file logging system
- ✅ Cloud API integration framework
- ✅ User interface with live updates
- ✅ Background monitoring support
- ✅ Vibration alerts
- ✅ Error handling and logging
- ✅ Comprehensive documentation

## ⚠️ What Needs Implementation

- ⚠️ **Algorithm logic** in TODO sections (REQUIRED)
- ⚠️ **AWS Lambda functions** deployment (REQUIRED)
- ⚠️ **AWS endpoints** configuration (REQUIRED)
- ⚠️ User authentication system (optional)
- ⚠️ Doctor dashboard interface (separate project)
- ⚠️ Clinical validation studies (for medical use)

## 📚 Documentation Index

1. **OVERVIEW.md** (this file) - Complete system overview
2. **README.md** - Main project documentation
3. **QUICKSTART.md** - Step-by-step setup checklist
4. **AWS_SETUP.md** - AWS infrastructure deployment
5. **ALGORITHM_GUIDE.md** - Algorithm implementation help

## 🔬 Research Basis

This system is based on published research on Parkinson's disease:

### Tremor Characteristics
- **Frequency**: 4-6 Hz resting tremor
- **Pattern**: Rhythmic, oscillatory
- **Detection**: Accelerometer + Gyroscope

### Freezing of Gait (FOG) Indicators
- Reduced stride length and velocity
- Increased stride variability
- Festination (rapid, small steps)
- Elevated stress/anxiety (heart rate)
- Tremor increase before freeze

### References
- *Freezing of Gait in Parkinson's Disease* (Clinical indicators)
- *Wearable Sensors for Gait Analysis* (Sensor data interpretation)
- *Machine Learning for Parkinson's Detection* (ML approaches)

## 🎯 Use Cases

### For Patients
- Real-time freeze warnings
- Activity tracking
- Symptom awareness
- Safety improvement

### For Caregivers
- Remote monitoring
- Alert notifications
- Pattern recognition
- Emergency response

### For Doctors
- Long-term trend analysis
- Treatment effectiveness
- Medication adjustment
- Research data collection

## 🔐 Privacy & Compliance

**Current Status**: Development/Research
- ⚠️ Not HIPAA compliant yet
- ⚠️ Not FDA approved
- ⚠️ Not for clinical use

**For Production**:
- Add user authentication
- Implement data encryption
- Get IRB approval for research
- Pursue FDA clearance for medical device
- Ensure HIPAA compliance

## 🤝 Contributing

This is a framework ready for your implementation:

1. **Implement algorithms** (see ALGORITHM_GUIDE.md)
2. **Deploy AWS backend** (see AWS_SETUP.md)
3. **Test thoroughly** (see QUICKSTART.md)
4. **Validate clinically** (with medical professionals)

## 📞 Support

- Check documentation in docs folder
- Review code comments and TODO sections
- Examine log output (hilog domains 0x0001-0x0006)
- Test incrementally with provided tools

## 📄 License

Framework for research and development. Clinical validation and regulatory approval required before medical use.

---

**Ready to start?** → Follow `QUICKSTART.md` for step-by-step instructions!
