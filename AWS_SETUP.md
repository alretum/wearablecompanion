# AWS Setup Guide - Simplified

This guide shows you how to set up a simple AWS backend to receive the `report.json` file from your HarmonyOS wearable.

## Overview

The wearable watch sends a complete `report.json` file every 5 minutes to your AWS endpoint. That's it!

```
Watch (HarmonyOS)
  ↓ POST /upload-report (every 5 min)
  ↓ Complete report.json file
API Gateway
  ↓
Lambda Function
  ↓
S3 Bucket (stores JSON files)
```

## What Gets Sent

Every 5 minutes, the watch sends the complete `report.json` file containing:

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
  ],
  "lastUpdated": 1234567890000
}
```

## Setup Steps

### 1. Create S3 Bucket (5 minutes)

```bash
aws s3 mb s3://parkinson-reports-YOUR-NAME --region us-east-1
```

### 2. Create Lambda Function (10 minutes)

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

**IAM Role Permissions**:

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

### 3. Create API Gateway (10 minutes)

1. **Create REST API**:
   - Go to API Gateway console
   - Create new REST API
   - Name: `ParkinsonReportAPI`

2. **Create Resource**:
   - Create resource: `/upload-report`

3. **Create POST Method**:
   - Add POST method to `/upload-report`
   - Integration type: Lambda Function
   - Select your `parkinson-upload-report` function
   - Enable Lambda Proxy integration

4. **Enable CORS**:
   - Select `/upload-report` resource
   - Actions → Enable CORS
   - Accept defaults

5. **Deploy API**:
   - Actions → Deploy API
   - Stage: `prod`
   - Note your API endpoint URL

### 4. Configure Watch App (2 minutes)

Update `entry/src/main/ets/config/AppConfig.ets`:

```typescript
// Replace with your actual API Gateway endpoint
static readonly SYNC_DATA_ENDPOINT = 'https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/prod/upload-report';

// These are not used anymore - can be set to empty string or same as SYNC_DATA_ENDPOINT
static readonly TREMOR_REPORT_ENDPOINT = '';
static readonly FREEZE_ALERT_ENDPOINT = '';
```

## How It Works

### Watch Behavior

1. **Every 5 minutes** (configurable in `AppConfig.DATA_SYNC_INTERVAL_MS`):
   - Watch reads `report.json` file
   - Sends complete file to AWS via HTTPS POST
   - Waits for success response

2. **If upload succeeds** AND `CLEAR_DATA_AFTER_SYNC = true`:
   - Clears `tremors` array
   - Clears `freezePredictions` array
   - Keeps session metadata (userId, deviceId, counts)
   - File is now empty but ready for new events

3. **If upload fails**:
   - Data remains in file
   - Will retry in 5 minutes
   - New events continue to accumulate

### AWS Behavior

1. **Receives JSON file**
2. **Saves to S3** with organized path: `s3://bucket/USER_ID/SESSION_ID_timestamp.json`
3. **Returns success** to watch
4. **Files are timestamped** - can track patient history over time

### Viewing Your Data

Access your reports:

```bash
# List all reports for a user
aws s3 ls s3://parkinson-reports-YOUR-NAME/USER_ABC/

# Download a specific report
aws s3 cp s3://parkinson-reports-YOUR-NAME/USER_ABC/SESSION_123_456.json ./report.json

# Download all reports for a user
aws s3 sync s3://parkinson-reports-YOUR-NAME/USER_ABC/ ./reports/
```

Or use AWS Console → S3 → Browse your bucket

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

**S3 Path**: `s3://parkinson-reports-YOUR-NAME/USER_ID/SESSION_ID_timestamp.json`

Example:
```
s3://parkinson-reports-john/
  └── USER_1732233600000/
      ├── SESSION_1732233600000_1732233900000.json
      ├── SESSION_1732233600000_1732234200000.json
      └── SESSION_1732233600000_1732234500000.json
```

## Testing Your Setup

### 1. Test Lambda Function

Use AWS Console → Lambda → Test with this event:

```json
{
  "body": "{\"sessionId\":\"SESSION_TEST\",\"userId\":\"USER_TEST\",\"deviceId\":\"DEVICE_TEST\",\"sessionStart\":1732233600000,\"sessionEnd\":1732233900000,\"totalTremors\":2,\"totalFreezes\":1,\"tremors\":[{\"severity\":5.5,\"duration\":1500,\"timestamp\":1732233700000,\"accelerometerData\":[],\"gyroscopeData\":[]}],\"freezePredictions\":[{\"probability\":0.75,\"confidence\":0.88,\"timestamp\":1732233800000,\"indicators\":{\"tremor\":true,\"gaitDisturbance\":false,\"stressSpike\":false}}],\"lastUpdated\":1732233900000}"
}
```

Expected response: `statusCode: 200` with success message

### 2. Check S3 Bucket

```bash
aws s3 ls s3://parkinson-reports-YOUR-NAME/USER_TEST/
```

You should see a JSON file created.

### 3. Test from Watch

1. Deploy app to watch
2. Start monitoring
3. Wait 5 minutes (or change `DATA_SYNC_INTERVAL_MS` to 60000 for testing = 1 minute)
4. Check CloudWatch logs for your Lambda
5. Check S3 bucket for uploaded file

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
2. Does the watch have internet connection?
3. Is the Lambda function deployed and working?
4. Check CloudWatch logs for Lambda errors

### File not found on watch

**Check**:
1. Has `MonitoringService.initialize(context)` been called?
2. Check logs for "Report file path:" message
3. Is monitoring started? (`startMonitoring()` called)
4. Have any events occurred? (tremors or freezes logged)

### S3 file empty or missing

**Check**:
1. Lambda logs in CloudWatch - was function invoked?
2. Check Lambda IAM role has S3 write permissions
3. Verify bucket name matches in both Lambda code and S3

### "Invalid input" error

**Check**:
- Report JSON has required fields: `sessionId`, `userId`, `deviceId`
- JSON is valid format
- Content-Type header is set correctly

## Cost Estimate

For 1 user with continuous monitoring:

- **Lambda invocations**: 288/day × 30 days = 8,640/month (within free tier: 1M requests)
- **Lambda compute**: ~100ms × 8,640 = ~864 seconds (within free tier: 400,000 seconds)
- **S3 storage**: ~1 KB × 8,640 files = ~8.6 MB/month (< $0.01)
- **S3 requests**: 8,640 PUT requests/month (~$0.05)

**Total cost**: < $0.10/month per user (mostly free tier)

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
