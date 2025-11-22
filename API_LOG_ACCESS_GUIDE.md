# How to Access api_calls.json

The `api_calls.json` file logs all API calls made by the app, including full JSON payloads, responses, and timestamps.

## Quick Access Steps

### Step 1: Get the File Path
1. Open the app on your watch
2. Scroll down to the bottom
3. Tap the **"Show API Log Info"** button (teal/green color)
4. Check the console/logs for the file path

The path will be something like:
```
/data/storage/el2/base/haps/entry/files/api_calls.json
```

### Step 2: Download the File Using hdc

**hdc** (HarmonyOS Device Connector) is the command-line tool for HarmonyOS devices.

```bash
# Basic command
hdc file recv <remote_path> <local_path>

# Example
hdc file recv /data/storage/el2/base/haps/entry/files/api_calls.json ./api_calls.json
```

This will download the file to your current directory as `api_calls.json`.

### Step 3: View the File

Open `api_calls.json` in any text editor or JSON viewer. The file contains:

```json
{
  "logStartTime": 1732233600000,
  "logStartTimeISO": "2025-11-22T10:00:00.000Z",
  "deviceId": "DEVICE_123456",
  "userId": "USER_123456",
  "totalRequests": 10,
  "successfulRequests": 8,
  "failedRequests": 2,
  "logs": [
    {
      "timestamp": 1732233600000,
      "timestampISO": "2025-11-22T10:00:00.000Z",
      "endpoint": "https://smmwnlhdcrauwnstfasu.supabase.co/functions/v1/upload-heartrate",
      "method": "POST",
      "payload": {
        "userId": "patient_external_id",
        "deviceId": "smartwatch_device_id",
        "reportTimestamp": "2025-11-22T10:00:00Z",
        "minuteData": [...]
      },
      "responseCode": 200,
      "responseBody": "{\"success\": true}",
      "success": true
    }
  ]
}
```

## What's Logged

For each API call, you'll see:
- **Timestamp** - When the call was made (both Unix timestamp and ISO format)
- **Endpoint** - The full API URL
- **Method** - HTTP method (POST)
- **Payload** - The complete JSON data sent to the API
- **Response Code** - HTTP status code (200, 400, 500, etc.)
- **Response Body** - The API's response
- **Success** - Boolean indicating if the call succeeded
- **Error Message** - If the call failed, the error details

## Statistics

The file also tracks:
- **Total requests** - How many API calls were made
- **Successful requests** - How many succeeded
- **Failed requests** - How many failed

## Alternative Access Methods

### Using DevEco Studio
1. Open DevEco Studio
2. Go to **View** → **Tool Windows** → **Device Manager**
3. Connect your watch
4. Navigate to the file in File Explorer
5. Right-click and download

### Using ADB (if configured)
```bash
adb pull /data/storage/el2/base/haps/entry/files/api_calls.json ./api_calls.json
```

## File Limits

- The log keeps the **last 1000 API calls**
- Older entries are automatically removed
- The file persists across app restarts

## Troubleshooting

**Q: File path not showing?**
- Make sure the app has been initialized (start monitoring at least once)
- Check that the app has run for a few minutes so API calls have been made

**Q: hdc command not found?**
- Install HarmonyOS SDK and add hdc to your PATH
- Location: `{SDK_PATH}/toolchains/`

**Q: Permission denied?**
- Make sure your device is connected: `hdc list targets`
- Enable USB debugging on your watch
- Grant file access permissions if prompted
