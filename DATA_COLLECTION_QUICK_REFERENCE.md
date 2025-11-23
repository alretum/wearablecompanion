# Quick Reference: Finding Your Collected Data

## File Locations on Watch

### Primary Data Collection File
```
/data/storage/el2/base/haps/entry/files/data_collection.json
```
This file contains ALL collected sensor data, events, and GPS coordinates.

### Backup Files (if exported)
```
/data/storage/el2/base/haps/entry/files/data_collection_backup_<timestamp>.json
```

## How to Access Files

### Method 1: HDC (HarmonyOS Device Connector) - RECOMMENDED

```bash
# 1. Connect watch to computer via USB

# 2. List all files in app directory
hdc shell ls /data/storage/el2/base/haps/entry/files/

# 3. Download the data collection file
hdc file recv /data/storage/el2/base/haps/entry/files/data_collection.json ./my_data.json

# 4. File is now in current directory as "my_data.json"
```

### Method 2: DevEco Studio Device File Explorer

1. Connect watch to DevEco Studio
2. Open **View → Tool Windows → Device File Explorer**
3. Navigate to: `/data/storage/el2/base/haps/entry/files/`
4. Right-click `data_collection.json` → **Save As...**
5. Choose local save location

### Method 3: View Logs for File Path

```bash
# In DevEco Studio terminal or command line
hilog | grep "Data collection file path"

# Output will show exact path:
# DataCollectionLogger: Data collection file path: /data/storage/el2/base/haps/entry/files/data_collection.json
```

## What You'll Find in the File

```json
{
  "sessionId": "DATA_COLLECTION_1732233600000",
  "userId": "USER_1732233600000",
  "deviceId": "DEVICE_1732233600000",
  "sessionStart": 1732233600000,
  "sessionEnd": 1732233900000,
  
  // Last 5,000 accelerometer readings (~100 seconds at 50 Hz)
  "accelerometerData": [...],
  
  // Last 5,000 gyroscope readings (~100 seconds at 50 Hz)
  "gyroscopeData": [...],
  
  // Last 500 heart rate readings (~8 minutes at 1 Hz)
  "heartRateData": [...],
  
  // All detected tremor/activity events
  // Note: Also included in 5-minute heart rate reports
  "tremorEvents": [...],
  
  // All freeze predictions with GPS coordinates
  "freezePredictions": [...],
  
  // GPS coordinates collected during freeze events
  "gpsCoordinates": [...],
  
  // Total counts (includes data that was trimmed)
  "totalAccelReadings": 15000,
  "totalGyroReadings": 15000,
  "totalHeartRateReadings": 480,
  "totalTremors": 3,
  "totalFreezes": 1,
  "totalGPSReadings": 1,
  
  "lastUpdated": 1732233900000
}
```

## File Size Expectations

| Duration | Approx. File Size |
|----------|-------------------|
| 1 minute | ~100 KB |
| 5 minutes | ~500 KB |
| 10 minutes | ~1 MB |
| 30 minutes | ~2-3 MB (due to memory limits) |

**Note**: File size stabilizes after ~2 minutes when memory limits are reached (oldest data is removed).

## Quick Analysis

### View File Locally
```bash
# Pretty print JSON
cat my_data.json | python -m json.tool | less

# Count readings
cat my_data.json | grep -c '"timestamp"'

# Check session info
cat my_data.json | grep -A 5 '"sessionId"'
```

### Load in Python
```python
import json

# Load data
with open('my_data.json', 'r') as f:
    data = json.load(f)

# Quick stats
print(f"Session: {data['sessionId']}")
print(f"Duration: {(data['sessionEnd'] - data['sessionStart']) / 1000} seconds")
print(f"Accelerometer readings: {data['totalAccelReadings']}")
print(f"Gyroscope readings: {data['totalGyroReadings']}")
print(f"Heart rate readings: {data['totalHeartRateReadings']}")
print(f"Tremors detected: {data['totalTremors']}")
print(f"Freezes predicted: {data['totalFreezes']}")
print(f"GPS coordinates: {data['totalGPSReadings']}")
```

## Troubleshooting

### "File not found"
- Check if app has been started and monitoring is active
- Look for log message: `hilog | grep "Data collection file path"`
- Verify `ENABLE_DATA_COLLECTION = true` in AppConfig.ets

### "Permission denied"
- Ensure watch is connected via USB
- Try: `hdc shell` first to verify connection
- May need developer mode enabled on watch

### "File empty or corrupt"
- Check logs for save errors: `hilog | grep DataCollectionLogger`
- Verify monitoring has been running for at least a few seconds
- Check available storage on watch

## Data Collection Status in Logs

Monitor collection in real-time:

```bash
# Watch all data collection activity
hilog | grep DataCollectionLogger

# Expected output:
DataCollectionLogger: Data collection file path: /data/storage/.../data_collection.json
DataCollectionLogger: Data collection initialized
DataCollectionLogger: Accelerometer: 100 readings
DataCollectionLogger: Gyroscope: 100 readings
DataCollectionLogger: Heart rate: 72 BPM
DataCollectionLogger: Activity logged: status=active, magnitude=1.20, total=1
DataCollectionLogger: Freeze logged: probability=0.85, total=1
DataCollectionLogger: GPS: 48.135100, 11.582000
DataCollectionLogger: Collection saved: 5000 accel, 5000 gyro, 300 HR
```

## Next Steps

1. **Collect Data**: Run app on watch for 5-10 minutes
2. **Download File**: Use `hdc file recv` command above
3. **Analyze**: Load in Python/MATLAB/Excel
4. **Iterate**: Adjust algorithms based on findings

---

**See [DATA_COLLECTION_GUIDE.md](DATA_COLLECTION_GUIDE.md) for complete documentation.**
