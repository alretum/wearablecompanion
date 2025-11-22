# Data Access Guide

## How to Access Your Watch Data

### Method 1: Using the App UI (Easiest)

1. **View Statistics:**
   - Open the app on your watch
   - Click **"View Data Collection Stats"** button
   - Check the console/logs to see:
     - Total readings collected
     - Session duration
     - Latest sensor values

2. **Export Data:**
   - Click **"Export Data Collection"** button
   - This creates a backup file with timestamp
   - The console will show the file path
   - Example: `/data/storage/el2/base/haps/entry/files/data_collection_backup_1234567890.json`

### Method 2: Using HDC (HarmonyOS Device Connector)

HDC is like ADB for HarmonyOS devices. Use it to pull files from the watch to your computer.

#### Step 1: Connect your watch
```bash
# Check if watch is connected
hdc list targets

# If not showing, enable developer mode on watch and USB debugging
```

#### Step 2: Find the data file
```bash
# The main data file location:
/data/storage/el2/base/haps/entry/files/data_collection.json

# Backup files (after using Export button):
/data/storage/el2/base/haps/entry/files/data_collection_backup_*.json
```

#### Step 3: Pull the file to your computer
```bash
# Pull the main data collection file
hdc file recv /data/storage/el2/base/haps/entry/files/data_collection.json ./data_collection.json

# Or pull a specific backup
hdc file recv /data/storage/el2/base/haps/entry/files/data_collection_backup_1700000000000.json ./my_data.json
```

#### Step 4: View the data
```bash
# Pretty print the JSON
cat data_collection.json | python3 -m json.tool

# Or open in your favorite editor
code data_collection.json
```

### Method 3: Using File Manager (If Available)

Some HarmonyOS devices allow file access through a file manager app:
1. Navigate to: Internal Storage → Android/data/entry/files/
2. Look for `data_collection.json`
3. Copy to a location you can access

### Method 4: Through DevEco Studio

1. Open **DevEco Studio**
2. Go to **View → Tool Windows → Device File Explorer**
3. Navigate to: `/data/storage/el2/base/haps/entry/files/`
4. Right-click on `data_collection.json`
5. Select **Save As** to download to your computer

---

## Data File Structure

The `data_collection.json` file contains:

```json
{
  "sessionId": "DATA_COLLECTION_1700000000000",
  "userId": "USER_...",
  "deviceId": "DEVICE_...",
  "sessionStart": 1700000000000,
  "sessionEnd": 1700001000000,
  
  "accelerometerData": [
    { "x": 0.5, "y": -0.3, "z": 9.8, "timestamp": 1700000000100 },
    ...
  ],
  
  "gyroscopeData": [
    { "x": 0.1, "y": 0.2, "z": -0.1, "timestamp": 1700000000100 },
    ...
  ],
  
  "heartRateData": [
    { "bpm": 72, "timestamp": 1700000001000 },
    ...
  ],
  
  "tremorEvents": [...],
  "freezePredictions": [...],
  "gpsCoordinates": [...],
  
  "totalAccelReadings": 5000,
  "totalGyroReadings": 5000,
  "totalHeartRateReadings": 100,
  "totalTremors": 0,
  "totalFreezes": 0,
  "totalGPSReadings": 0,
  
  "lastUpdated": 1700001000000
}
```

## Data Limits (To Prevent Memory Issues)

- **Accelerometer**: Max 5,000 readings in memory (~100 seconds at 50Hz, ~500 seconds at 10Hz)
- **Gyroscope**: Max 5,000 readings in memory
- **Heart Rate**: Max 500 readings in memory (~8 minutes at 1Hz)
- **GPS**: Max 100 readings in memory

When limits are reached, oldest data is removed (FIFO). However, total counters keep track of all readings ever collected.

## Tips

1. **Export regularly** - Click "Export Data Collection" to create timestamped backups before data gets rotated out
2. **Check logs** - Console output shows file paths and data statistics
3. **Use HDC** - The most reliable way to get files off the device
4. **Data persistence** - Data is saved to disk every 100 readings for accel/gyro, immediately for heart rate

## Troubleshooting

### "Data collection is disabled"
- Check `AppConfig.ets`: Set `ENABLE_DATA_COLLECTION = true`

### "Cannot find file"
- Make sure monitoring has been started at least once
- Check that data has been collected (at least 100 readings)

### "Permission denied" when using HDC
- Make sure USB debugging is enabled on the watch
- Try running HDC with root: `hdc shell` then `su`

### "File too large"
- Export and clear data regularly
- The file size shown in the app tells you current size

---

## Quick Command Reference

```bash
# Connect to watch
hdc list targets

# Pull main data file
hdc file recv /data/storage/el2/base/haps/entry/files/data_collection.json ./data.json

# View file size
hdc shell ls -lh /data/storage/el2/base/haps/entry/files/data_collection.json

# List all backup files
hdc shell ls -lh /data/storage/el2/base/haps/entry/files/data_collection_backup_*.json

# Pretty print JSON
cat data.json | python3 -m json.tool | less
```
