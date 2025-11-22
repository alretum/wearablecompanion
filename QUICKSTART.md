# Quick Start Checklist

Use this checklist to get your Parkinson's Freeze Detection system up and running.

## ☑️ Prerequisites

- [ ] DevEco Studio installed with HarmonyOS SDK 5.0+
- [ ] AWS Account with permissions to create Lambda functions
- [ ] HarmonyOS wearable device for testing
- [ ] Basic understanding of TypeScript/ArkTS

## 📋 Step-by-Step Setup

### Phase 1: AWS Backend (30-60 minutes)

- [ ] **1.1** Create DynamoDB tables (see AWS_SETUP.md)
  - [ ] TremorReports table
  - [ ] FreezePredictions table
  - [ ] MonitoringSessions table

- [ ] **1.2** Create Lambda functions (see AWS_SETUP.md)
  - [ ] parkinson-tremor-report
  - [ ] parkinson-freeze-alert
  - [ ] parkinson-sync-data

- [ ] **1.3** Create API Gateway
  - [ ] POST /tremor-report
  - [ ] POST /freeze-alert
  - [ ] POST /sync-data
  - [ ] Enable CORS for all endpoints
  - [ ] Deploy to 'prod' stage

- [ ] **1.4** Note your API Gateway URL
  - Format: `https://[API-ID].execute-api.[REGION].amazonaws.com/prod`

- [ ] **1.5** (Optional) Set up API key or Cognito authentication

### Phase 2: Configure Application (5 minutes)

- [ ] **2.1** Open project in DevEco Studio

- [ ] **2.2** Update `entry/src/main/ets/config/AppConfig.ets`
  ```typescript
  // Replace these with your actual endpoints:
  static readonly TREMOR_REPORT_ENDPOINT = 'https://YOUR-API-ID...';
  static readonly FREEZE_ALERT_ENDPOINT = 'https://YOUR-API-ID...';
  static readonly SYNC_DATA_ENDPOINT = 'https://YOUR-API-ID...';
  static readonly AWS_REGION = 'YOUR-REGION';
  ```

- [ ] **2.3** (Optional) Add authentication in `connectivity/APIService.ets`
  ```typescript
  'Authorization': `Bearer ${YOUR_JWT_TOKEN}`,
  'X-API-Key': 'YOUR_API_KEY',
  ```

### Phase 3: Implement Algorithms (Variable - depends on complexity)

Choose your approach (see ALGORITHM_GUIDE.md for details):

#### Option A: Simple Rule-Based (1-2 hours)
- [ ] **3.1** Implement peak detection in `TremorDetector.ets`
- [ ] **3.2** Implement threshold-based prediction in `PredictionAlgorithm.ets`
- [ ] **3.3** Test with synthetic data
- [ ] **3.4** Tune thresholds

#### Option B: Signal Processing (4-8 hours)
- [ ] **3.1** Implement FFT or autocorrelation for tremor detection
- [ ] **3.2** Implement feature extraction for freeze prediction
- [ ] **3.3** Test and validate
- [ ] **3.4** Optimize performance

#### Option C: Machine Learning (1-2 weeks)
- [ ] **3.1** Collect/obtain training data
- [ ] **3.2** Train ML model offline
- [ ] **3.3** Convert to mobile-compatible format (TFLite/ONNX)
- [ ] **3.4** Implement inference in algorithms
- [ ] **3.5** Validate accuracy

**Files to edit:**
- [ ] `entry/src/main/ets/algorithms/TremorDetector.ets`
  - [ ] `analyzeTremorPattern()` method
  - [ ] `calculateTremorSeverity()` method
  
- [ ] `entry/src/main/ets/algorithms/PredictionAlgorithm.ets`
  - [ ] `detectTremorPattern()` method
  - [ ] `detectGaitDisturbance()` method
  - [ ] `calculateFreezeProbability()` method

### Phase 4: Build and Test (30 minutes)

- [ ] **4.1** Build the project in DevEco Studio
  - Build → Make Module 'entry'
  - Check for compilation errors

- [ ] **4.2** Connect HarmonyOS wearable device
  - Enable developer mode on device
  - Connect via USB or WiFi

- [ ] **4.3** Deploy to device
  - Run → Run 'entry'
  - Grant all permissions when prompted:
    - Accelerometer
    - Gyroscope
    - Health Data (Heart Rate)
    - Internet
    - Background Running

- [ ] **4.4** Test functionality
  - [ ] Open app on watch
  - [ ] Click "Test API Connection" - should show success
  - [ ] Click "Start Monitoring" - status should change to "Monitoring..."
  - [ ] Move watch to see sensor data update
  - [ ] Check "Report File" card shows session info
  - [ ] Verify report.json file is being created
  - [ ] Check logs for algorithm output
  - [ ] Verify data uploads to AWS DynamoDB tables

### Phase 5: Validate (Ongoing)

- [ ] **5.1** Test sensor data collection
  - [ ] Accelerometer readings appear
  - [ ] Gyroscope readings appear
  - [ ] Heart rate updates

- [ ] **5.2** Test tremor detection
  - [ ] Wave watch to simulate tremor
  - [ ] Check if tremor is detected
  - [ ] Verify severity calculation
  - [ ] Confirm data sent to AWS

- [ ] **5.3** Test freeze prediction
  - [ ] Simulate gait disturbances
  - [ ] Check if alerts trigger
  - [ ] Verify vibration feedback
  - [ ] Confirm predictions logged to AWS

- [ ] **5.4** Test background operation
  - [ ] Start monitoring
  - [ ] Press watch button to minimize app
  - [ ] Verify monitoring continues
  - [ ] Check battery usage
  - [ ] Verify report.json continues updating

- [ ] **5.5** Test report file
  - [ ] Check report file location: `{app_files_dir}/report.json`
  - [ ] Verify tremors are logged in real-time
  - [ ] Verify freeze predictions are logged
  - [ ] Check file size grows with events
  - [ ] Confirm data clears after successful upload

- [ ] **5.6** AWS validation
  - [ ] Check CloudWatch logs for Lambda invocations
  - [ ] Verify data in DynamoDB tables
  - [ ] Check for API errors

## 🐛 Troubleshooting

### Build Errors
- [ ] Check HarmonyOS SDK is installed
- [ ] Sync project with oh-package files
- [ ] Clean and rebuild project

### Runtime Errors
- [ ] All permissions granted?
- [ ] AWS endpoints correct in AppConfig.ets?
- [ ] Device has internet connection?
- [ ] Check DevEco Studio logs (bottom panel)

### Sensors Not Working
- [ ] Permissions granted?
- [ ] Device supports required sensors?
- [ ] Check SensorManager logs (Domain 0x0001)

### API Calls Failing
- [ ] Test connectivity with "Test API Connection" button
- [ ] Verify endpoints in AppConfig.ets
- [ ] Check API Gateway CORS settings
- [ ] Check Lambda function logs in CloudWatch
- [ ] Verify API key/authentication if configured

### No Predictions/Detections
- [ ] Algorithms implemented in TODO sections?
- [ ] Sufficient sensor data buffered (50+ samples)?
- [ ] Thresholds too high/low?
- [ ] Check algorithm logs (Domains 0x0002, 0x0003)

## 📊 Success Criteria

Your system is working correctly when:
- ✅ App builds without errors
- ✅ Sensors show real-time data in UI
- ✅ "Test API Connection" shows all endpoints reachable
- ✅ Report file card shows session and file size
- ✅ report.json is created and updated in real-time
- ✅ Tremors are detected and logged to report.json
- ✅ Predictions trigger and are logged to report.json
- ✅ Vibration alerts work
- ✅ Report file uploads to AWS every 5 minutes
- ✅ Data appears in AWS DynamoDB
- ✅ Monitoring continues in background
- ✅ Session statistics update correctly

## 🎯 Minimum Viable Product (MVP)

To have a working MVP, you MUST complete:
1. ✅ Phase 1 (AWS Backend) - CRITICAL
2. ✅ Phase 2 (Configuration) - CRITICAL
3. ✅ Phase 3 (Basic algorithms) - CRITICAL
4. ✅ Phase 4 (Build and Test) - CRITICAL

Phase 5 (Validation) is ongoing and iterative.

## 📞 Need Help?

1. **Check documentation:**
   - README.md - Overall project guide
   - AWS_SETUP.md - AWS infrastructure details
   - ALGORITHM_GUIDE.md - Algorithm implementation
   - PROJECT_SUMMARY.md - Complete feature list

2. **Check logs:**
   - DevEco Studio console for runtime logs
   - AWS CloudWatch for Lambda logs
   - Use hilog domains to filter (0x0001-0x0005)

3. **Verify basics:**
   - Permissions granted
   - Internet connectivity
   - AWS endpoints correct
   - Algorithms implemented

## ⏱️ Estimated Time to MVP

- **Fast track** (using simple rule-based algorithms): 2-3 hours
- **Standard** (signal processing): 1-2 days
- **Advanced** (machine learning): 1-2 weeks

## 🚀 You're Ready!

Once you've completed Phase 1-4, you have a functional Parkinson's freeze detection system! Phase 5 is about refining and validating for production use.

Good luck! 🍀
