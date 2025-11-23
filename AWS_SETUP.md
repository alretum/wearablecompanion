# AWS Setup Guide - Simplified

This guide shows you how to set up a simple AWS backend to receive data from your HarmonyOS wearable.

## Overview

The wearable watch sends two types of data to separate AWS endpoints every 5 minutes:

```
Watch (HarmonyOS)
  ↓ 
  ├─→ POST /upload-report (report.json - processed tremor/freeze data)
  │   └─→ API Gateway → Lambda → S3
  │
  └─→ POST /upload-heartrate (5 minutes of heart rate aggregates)
      └─→ API Gateway → Lambda → S3
```

## What Gets Sent

### 1. Report Data (When Freeze Incidents Occur)

**Endpoint**: `/upload-report`  
**File**: Complete `report.json` with freeze incidents only (no tremor data)
**GPS**: Freeze predictions include GPS coordinates for location tracking

```json
{
  "sessionId": "SESSION_1234567890",
  "userId": "USER_ABC",
  "deviceId": "DEVICE_XYZ",
  "sessionStart": 1234567890000,
  "sessionEnd": 1234567890000,
  "totalFreezes": 2,
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

**Note**: Raw accelerometer and gyroscope data are NOT included. Tremor/activity data is sent via the heart rate endpoint.

### 2. Heart Rate Data (Every 5 minutes)

**Endpoint**: `/upload-heartrate`  
**Content**: 5 entries, one per minute with aggregated statistics + tremor/activity data

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
      "tremorData": {
        "status": "active",
        "magnitude": 1.2,
        "frequency": 5.3,
        "timestamp": 1234567220000
      }
    },
    {
      "timestamp": 1234567260000,
      "avgBpm": 74.2,
      "minBpm": 70,
      "maxBpm": 80,
      "tremorData": {
        "status": "sedentary",
        "magnitude": 0.3,
        "frequency": 0,
        "timestamp": 1234567280000
      }
    },
    {
      "timestamp": 1234567320000,
      "avgBpm": 73.8,
      "minBpm": 69,
      "maxBpm": 79,
      "tremorData": null
    },
    {
      "timestamp": 1234567380000,
      "avgBpm": 75.1,
      "minBpm": 71,
      "maxBpm": 82,
      "tremorData": {
        "status": "active",
        "magnitude": 1.8,
        "frequency": 4.7,
        "timestamp": 1234567400000
      }
    },
    {
      "timestamp": 1234567440000,
      "avgBpm": 73.3,
      "minBpm": 68,
      "maxBpm": 77,
      "tremorData": null
    }
  ]
}
```

**Note**: Each minute may include optional tremor/activity data with status (sedentary/active/unknown/not_worn), motion magnitude (m/s²), and dominant frequency (Hz).

## Setup Steps

### 1. Create S3 Buckets (5 minutes)

Create two buckets - one for reports, one for heart rate data:

```bash
aws s3 mb s3://parkinson-reports-YOUR-NAME --region us-east-1
aws s3 mb s3://parkinson-heartrate-YOUR-NAME --region us-east-1
```

### 2. Create Lambda Functions (20 minutes)

#### Lambda 1: Report Upload Handler

**Function Name**: `parkinson-upload-report`

**Runtime**: Node.js 18.x or Python 3.11

**Code (Node.js)**:

```javascript
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

exports.handler = async (event) => {
    try {
        // Parse the incoming report
        const report = JSON.parse(event.body);
        
        // Validate required fields
        if (!report.sessionId || !report.userId || !report.deviceId) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    success: false,
                    message: 'Missing required fields'
                })
            };
        }
        
        // Generate filename: userId_sessionId_timestamp.json
        const timestamp = Date.now();
        const filename = `${report.userId}/${report.sessionId}_${timestamp}.json`;
        
        // Upload to S3
        await s3.putObject({
            Bucket: 'parkinson-reports-YOUR-NAME',
            Key: filename,
            Body: JSON.stringify(report, null, 2),
            ContentType: 'application/json',
            Metadata: {
                userId: report.userId,
                deviceId: report.deviceId,
                sessionId: report.sessionId,
                tremorCount: String(report.totalTremors || 0),
                freezeCount: String(report.totalFreezes || 0)
            }
        }).promise();
        
        console.log(`Saved report: ${filename}`);
        console.log(`Tremors: ${report.totalTremors}, Freezes: ${report.totalFreezes}`);
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                message: 'Report uploaded successfully',
                filename: filename
            })
        };
        
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: false,
                message: 'Internal server error',
                error: error.message
            })
        };
    }
};
```

**Code (Python 3.11)**:

```python
import json
import boto3
from datetime import datetime

s3 = boto3.client('s3')
BUCKET_NAME = 'parkinson-reports-YOUR-NAME'

def lambda_handler(event, context):
    try:
        # Parse incoming report
        report = json.loads(event['body'])
        
        # Validate required fields
        if not all(k in report for k in ['sessionId', 'userId', 'deviceId']):
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'success': False,
                    'message': 'Missing required fields'
                })
            }
        
        # Generate filename
        timestamp = int(datetime.now().timestamp() * 1000)
        filename = f"{report['userId']}/{report['sessionId']}_{timestamp}.json"
        
        # Upload to S3
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=filename,
            Body=json.dumps(report, indent=2),
            ContentType='application/json',
            Metadata={
                'userId': report['userId'],
                'deviceId': report['deviceId'],
                'sessionId': report['sessionId'],
                'tremorCount': str(report.get('totalTremors', 0)),
                'freezeCount': str(report.get('totalFreezes', 0))
            }
        )
        
        print(f"Saved report: {filename}")
        print(f"Tremors: {report.get('totalTremors', 0)}, Freezes: {report.get('totalFreezes', 0)}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': True,
                'message': 'Report uploaded successfully',
                'filename': filename
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': False,
                'message': 'Internal server error',
                'error': str(e)
            })
        }
```

**IAM Role Permissions for Report Lambda**:

Attach this policy to the Lambda execution role:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl"
            ],
            "Resource": "arn:aws:s3:::parkinson-reports-YOUR-NAME/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
```

#### Lambda 2: Heart Rate Upload Handler

**Function Name**: `parkinson-upload-heartrate`

**Runtime**: Node.js 18.x or Python 3.11

**Code (Node.js)**:

```javascript
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

exports.handler = async (event) => {
    try {
        // Parse the incoming heart rate report
        const report = JSON.parse(event.body);
        
        // Validate required fields
        if (!report.userId || !report.deviceId || !report.minutes || report.minutes.length === 0) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    success: false,
                    message: 'Missing required fields or no heart rate data'
                })
            };
        }
        
        // Generate filename: userId_timestamp.json
        const timestamp = Date.now();
        const filename = `${report.userId}/heartrate_${timestamp}.json`;
        
        // Upload to S3
        await s3.putObject({
            Bucket: 'parkinson-heartrate-YOUR-NAME',
            Key: filename,
            Body: JSON.stringify(report, null, 2),
            ContentType: 'application/json',
            Metadata: {
                userId: report.userId,
                deviceId: report.deviceId,
                minuteCount: String(report.minutes.length),
                avgBpm: String(calculateAverage(report.minutes))
            }
        }).promise();
        
        console.log(`Saved heart rate: ${filename}`);
        console.log(`Minutes: ${report.minutes.length}, Avg BPM: ${calculateAverage(report.minutes)}`);
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                message: 'Heart rate data uploaded successfully',
                filename: filename
            })
        };
        
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: false,
                message: 'Internal server error',
                error: error.message
            })
        };
    }
};

function calculateAverage(minutes) {
    if (minutes.length === 0) return 0;
    const sum = minutes.reduce((acc, m) => acc + m.avgBpm, 0);
    return Math.round(sum / minutes.length * 10) / 10;
}
```

**Code (Python 3.11)**:

```python
import json
import boto3
from datetime import datetime

s3 = boto3.client('s3')
BUCKET_NAME = 'parkinson-heartrate-YOUR-NAME'

def lambda_handler(event, context):
    try:
        # Parse incoming heart rate report
        report = json.loads(event['body'])
        
        # Validate required fields
        if not all(k in report for k in ['userId', 'deviceId', 'minutes']) or len(report['minutes']) == 0:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'success': False,
                    'message': 'Missing required fields or no heart rate data'
                })
            }
        
        # Generate filename
        timestamp = int(datetime.now().timestamp() * 1000)
        filename = f"{report['userId']}/heartrate_{timestamp}.json"
        
        # Calculate average BPM
        avg_bpm = sum(m['avgBpm'] for m in report['minutes']) / len(report['minutes'])
        avg_bpm = round(avg_bpm, 1)
        
        # Upload to S3
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=filename,
            Body=json.dumps(report, indent=2),
            ContentType='application/json',
            Metadata={
                'userId': report['userId'],
                'deviceId': report['deviceId'],
                'minuteCount': str(len(report['minutes'])),
                'avgBpm': str(avg_bpm)
            }
        )
        
        print(f"Saved heart rate: {filename}")
        print(f"Minutes: {len(report['minutes'])}, Avg BPM: {avg_bpm}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': True,
                'message': 'Heart rate data uploaded successfully',
                'filename': filename
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': False,
                'message': 'Internal server error',
                'error': str(e)
            })
        }
```

**IAM Role Permissions for Heart Rate Lambda**:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl"
            ],
            "Resource": "arn:aws:s3:::parkinson-heartrate-YOUR-NAME/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
```

### 3. Create API Gateway (15 minutes)

1. **Create REST API**:
   - Go to API Gateway console
   - Create new REST API
   - Name: `ParkinsonMonitoringAPI`

2. **Create Resources**:
   - Create resource: `/upload-report`
   - Create resource: `/upload-heartrate`

3. **Create POST Methods**:
   
   **For `/upload-report`**:
   - Add POST method
   - Integration type: Lambda Function
   - Select `parkinson-upload-report` function
   - Enable Lambda Proxy integration
   
   **For `/upload-heartrate`**:
   - Add POST method
   - Integration type: Lambda Function
   - Select `parkinson-upload-heartrate` function
   - Enable Lambda Proxy integration

4. **Enable CORS** (for both resources):
   - Select resource
   - Actions → Enable CORS
   - Accept defaults

5. **Deploy API**:
   - Actions → Deploy API
   - Stage: `prod`
   - Note your API endpoint URLs

### 4. Configure Watch App (2 minutes)

Update `entry/src/main/ets/config/AppConfig.ets`:

```typescript
// Replace with your actual API Gateway endpoints
static readonly SYNC_DATA_ENDPOINT = 'https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/prod/upload-report';
static readonly HEART_RATE_ENDPOINT = 'https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/prod/upload-heartrate';

// These are not used anymore
static readonly TREMOR_REPORT_ENDPOINT = '';
static readonly FREEZE_ALERT_ENDPOINT = '';
```

## How It Works

### Watch Behavior

1. **Every 5 minutes** (configurable in `AppConfig.DATA_SYNC_INTERVAL_MS`):
   - Watch uploads **report.json** (processed tremor/freeze data) to `/upload-report`
   - Watch uploads **heart rate report** (5 minutes of aggregated data) to `/upload-heartrate`
   - Waits for success responses

2. **After successful uploads** AND `CLEAR_DATA_AFTER_SYNC = true`:
   - Report.json: Clears `tremors` and `freezePredictions` arrays
   - Heart rate: Clears all 5 minutes of aggregated data
   - Both files are now empty but ready for new events

3. **If uploads fail**:
   - Data remains in files
   - Will retry in 5 minutes
   - New events continue to accumulate

### Data Aggregation

**Heart Rate**:
- Sensor reads heart rate every second
- Every minute, aggregates readings into: avgBpm, minBpm, maxBpm
- Keeps last 5 minutes of aggregates
- Every 5 minutes, uploads all 5 aggregates to AWS

**Tremors/Freezes**:
- Detected in real-time from accelerometer/gyroscope
- Only **processed metrics** saved (severity, duration, probability)
- Raw sensor data is NOT stored to save space
- Accumulated until uploaded every 5 minutes

### AWS Behavior

1. **Receives two JSON payloads**
2. **Saves to S3** with organized paths:
   - Reports: `s3://reports-bucket/USER_ID/SESSION_ID_timestamp.json`
   - Heart Rate: `s3://heartrate-bucket/USER_ID/heartrate_timestamp.json`
3. **Returns success** to watch
4. **Files are timestamped** - can track patient history over time

### Viewing Your Data

Access your data:

```bash
# List all reports for a user
aws s3 ls s3://parkinson-reports-YOUR-NAME/USER_ABC/
aws s3 ls s3://parkinson-heartrate-YOUR-NAME/USER_ABC/

# Download specific files
aws s3 cp s3://parkinson-reports-YOUR-NAME/USER_ABC/SESSION_123_456.json ./report.json
aws s3 cp s3://parkinson-heartrate-YOUR-NAME/USER_ABC/heartrate_789.json ./heartrate.json

# Download all data for a user
aws s3 sync s3://parkinson-reports-YOUR-NAME/USER_ABC/ ./reports/
aws s3 sync s3://parkinson-heartrate-YOUR-NAME/USER_ABC/ ./heartrate/
```

Or use AWS Console → S3 → Browse your buckets

## File Locations

### On Watch (HarmonyOS Device)

**File Path**: `/data/storage/el2/base/haps/entry/files/report.json`

- This is the internal app storage directory
- Accessible only to your app
- Persists across app restarts
- **Size**: Grows until uploaded and cleared (typically < 1 MB)

You can view logs to see the exact path:
```
hilog | grep ReportLogger
```

Look for: `Report file path: /data/storage/.../report.json`

### On Development Machine (Preview/Emulator)

**File Path**: Varies by simulator, but similar structure

To find it:
1. Check DevEco Studio logs when app starts
2. Look for `ReportLogger` log line showing file path
3. Or check: `~/.deveco-studio/system/emulator/[device]/data/...`

**Note**: For local testing, the file exists but won't actually upload to AWS unless you provide real endpoints.

### In AWS (After Upload)

**S3 Path**: 
- Reports: `s3://parkinson-reports-YOUR-NAME/USER_ID/SESSION_ID_timestamp.json`
- Heart Rate: `s3://parkinson-heartrate-YOUR-NAME/USER_ID/heartrate_timestamp.json`

Examples:
```
s3://parkinson-reports-john/
  └── USER_1732233600000/
      ├── SESSION_1732233600000_1732233900000.json
      ├── SESSION_1732233600000_1732234200000.json
      └── SESSION_1732233600000_1732234500000.json

s3://parkinson-heartrate-john/
  └── USER_1732233600000/
      ├── heartrate_1732233900000.json
      ├── heartrate_1732234200000.json
      └── heartrate_1732234500000.json
```

## Testing Your Setup

### 1. Test Lambda Functions

Use AWS Console → Lambda → Test

**For Report Lambda** with this event:

```json
{
  "body": "{\"sessionId\":\"SESSION_TEST\",\"userId\":\"USER_TEST\",\"deviceId\":\"DEVICE_TEST\",\"sessionStart\":1732233600000,\"sessionEnd\":1732233900000,\"totalTremors\":2,\"totalFreezes\":1,\"tremors\":[{\"severity\":5.5,\"duration\":1500,\"timestamp\":1732233700000}],\"freezePredictions\":[{\"probability\":0.75,\"confidence\":0.88,\"timestamp\":1732233800000,\"indicators\":{\"tremor\":true,\"gaitDisturbance\":false,\"stressSpike\":false}}],\"lastUpdated\":1732233900000}"
}
```

**For Heart Rate Lambda** with this event:

```json
{
  "body": "{\"userId\":\"USER_TEST\",\"deviceId\":\"DEVICE_TEST\",\"reportTimestamp\":1732233900000,\"minutes\":[{\"timestamp\":1732233600000,\"avgBpm\":72.5,\"minBpm\":68,\"maxBpm\":78},{\"timestamp\":1732233660000,\"avgBpm\":74.2,\"minBpm\":70,\"maxBpm\":80},{\"timestamp\":1732233720000,\"avgBpm\":73.8,\"minBpm\":69,\"maxBpm\":79},{\"timestamp\":1732233780000,\"avgBpm\":75.1,\"minBpm\":71,\"maxBpm\":82},{\"timestamp\":1732233840000,\"avgBpm\":73.3,\"minBpm\":68,\"maxBpm\":77}]}"
}
```

Expected response for both: `statusCode: 200` with success message

### 2. Check S3 Buckets

```bash
aws s3 ls s3://parkinson-reports-YOUR-NAME/USER_TEST/
aws s3 ls s3://parkinson-heartrate-YOUR-NAME/USER_TEST/
```

You should see JSON files created in both buckets.

### 3. Test from Watch

1. Deploy app to watch
2. Start monitoring
3. Wait 5 minutes (or change `DATA_SYNC_INTERVAL_MS` to 60000 for testing = 1 minute)
4. Check CloudWatch logs for both Lambda functions
5. Check both S3 buckets for uploaded files

## Configuration Options

### Change Upload Frequency

In `AppConfig.ets`:

```typescript
static readonly DATA_SYNC_INTERVAL_MS = 300000; // 5 minutes (default)
static readonly DATA_SYNC_INTERVAL_MS = 60000;  // 1 minute (for testing)
static readonly DATA_SYNC_INTERVAL_MS = 600000; // 10 minutes (battery saving)
```

### Control Data Clearing

In `AppConfig.ets`:

```typescript
static readonly CLEAR_DATA_AFTER_SYNC = true;  // Clear after upload (default)
static readonly CLEAR_DATA_AFTER_SYNC = false; // Keep all data (for debugging)
```

## Troubleshooting

### "Failed to sync report" in logs

**Check**:
1. Is `SYNC_DATA_ENDPOINT` correctly set in `AppConfig.ets`?
2. Is `HEART_RATE_ENDPOINT` correctly set in `AppConfig.ets`?
3. Does the watch have internet connection?
4. Are both Lambda functions deployed and working?
5. Check CloudWatch logs for Lambda errors

### File not found on watch

**Check**:
1. Has `MonitoringService.initialize(context)` been called?
2. Check logs for "Report file path:" message
3. Is monitoring started? (`startMonitoring()` called)
4. Have any events occurred? (tremors or freezes logged)

### S3 file empty or missing

**Check**:
1. Lambda logs in CloudWatch - were functions invoked?
2. Check Lambda IAM roles have S3 write permissions to **both buckets**
3. Verify bucket names match in Lambda code and S3

### "Invalid input" error

**Check**:
- Report JSON has required fields: `sessionId`, `userId`, `deviceId`
- Heart rate JSON has required fields: `userId`, `deviceId`, `minutes`
- JSON is valid format
- Content-Type header is set correctly

### No heart rate data uploaded

**Check**:
1. Is heart rate sensor working? Check UI for BPM readings
2. Has at least 1 minute passed for aggregation?
3. Check logs for "Heart rate data synced" message
4. Verify `HEART_RATE_ENDPOINT` is set correctly

## Cost Estimate

For 1 user with continuous monitoring:

- **Lambda invocations**: 288/day × 30 days × 2 endpoints = 17,280/month (within free tier: 1M requests)
- **Lambda compute**: ~100ms × 17,280 = ~1,728 seconds (within free tier: 400,000 seconds)
- **S3 storage**: 
  - Reports: ~0.5 KB × 8,640 files = ~4.3 MB/month (< $0.01)
  - Heart rate: ~0.3 KB × 8,640 files = ~2.6 MB/month (< $0.01)
- **S3 requests**: 17,280 PUT requests/month (~$0.09)

**Total cost**: < $0.15/month per user (mostly free tier)

## Next Steps

1. **Set up monitoring**: Use CloudWatch to track Lambda invocations and errors
2. **Add data processing**: Create another Lambda triggered by S3 uploads to process/analyze reports
3. **Build dashboard**: Use reports to visualize patient trends over time
4. **Add notifications**: Alert doctors when concerning patterns detected

## Support

If you encounter issues:
1. Check CloudWatch logs for Lambda function
2. Verify API Gateway endpoints are deployed
3. Test Lambda directly with sample JSON
4. Check watch logs for network errors
