# AWS Lambda Setup Guide

This guide walks you through setting up the AWS infrastructure for the Parkinson's Freeze Detection system.

## Architecture Overview

```
Wearable Device (HarmonyOS)
    ↓ report.json (HTTPS)
API Gateway
    ↓
Lambda Functions (Node.js/Python)
    ↓
DynamoDB / RDS
    ↓
CloudWatch (Logging & Monitoring)
```

**Data Format**: The wearable sends a complete `report.json` file containing:
- Session metadata (userId, deviceId, timestamps)
- Array of tremor events with sensor data
- Array of freeze predictions with confidence scores

See the main README.md for the complete JSON structure.

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured
- Basic knowledge of Lambda and API Gateway

## Step 1: Create DynamoDB Tables (Recommended)

### Table 1: TremorReports

```bash
aws dynamodb create-table \
    --table-name TremorReports \
    --attribute-definitions \
        AttributeName=userId,AttributeType=S \
        AttributeName=timestamp,AttributeType=N \
    --key-schema \
        AttributeName=userId,KeyType=HASH \
        AttributeName=timestamp,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

### Table 2: FreezePredictions

```bash
aws dynamodb create-table \
    --table-name FreezePredictions \
    --attribute-definitions \
        AttributeName=userId,AttributeType=S \
        AttributeName=timestamp,AttributeType=N \
    --key-schema \
        AttributeName=userId,KeyType=HASH \
        AttributeName=timestamp,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

### Table 3: MonitoringSessions

```bash
aws dynamodb create-table \
    --table-name MonitoringSessions \
    --attribute-definitions \
        AttributeName=userId,AttributeType=S \
        AttributeName=sessionStart,AttributeType=N \
    --key-schema \
        AttributeName=userId,KeyType=HASH \
        AttributeName=sessionStart,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

## Step 2: Create Lambda Functions

### Lambda 1: Tremor Report Handler

**Function Name**: `parkinson-tremor-report`

**Runtime**: Node.js 18.x or Python 3.11

**Example Code (Node.js)**:

```javascript
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    try {
        const body = JSON.parse(event.body);
        const { userId, deviceId, tremors, timestamp } = body;
        
        // Validate input
        if (!userId || !tremors || tremors.length === 0) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    success: false,
                    message: 'Invalid input'
                })
            };
        }
        
        // Store each tremor event
        const promises = tremors.map(tremor => {
            return dynamodb.put({
                TableName: 'TremorReports',
                Item: {
                    userId,
                    timestamp: tremor.timestamp,
                    deviceId,
                    severity: tremor.severity,
                    duration: tremor.duration,
                    reportTimestamp: timestamp,
                    accelerometerData: JSON.stringify(tremor.accelerometerData),
                    gyroscopeData: JSON.stringify(tremor.gyroscopeData)
                }
            }).promise();
        });
        
        await Promise.all(promises);
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                reportId: `TREMOR_${Date.now()}`,
                message: `Stored ${tremors.length} tremor events`
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
                message: 'Internal server error'
            })
        };
    }
};
```

**IAM Role**: Attach policy with DynamoDB write permissions

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:PutItem",
                "dynamodb:UpdateItem"
            ],
            "Resource": "arn:aws:dynamodb:*:*:table/TremorReports"
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

### Lambda 2: Freeze Alert Handler

**Function Name**: `parkinson-freeze-alert`

**Example Code (Node.js)**:

```javascript
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const sns = new AWS.SNS(); // Optional: for notifications

exports.handler = async (event) => {
    try {
        const body = JSON.parse(event.body);
        const { userId, deviceId, prediction, timestamp } = body;
        
        // Store prediction
        await dynamodb.put({
            TableName: 'FreezePredictions',
            Item: {
                userId,
                timestamp: prediction.timestamp,
                deviceId,
                probability: prediction.probability,
                timeToFreeze: prediction.timeToFreeze,
                confidence: prediction.confidence,
                indicators: prediction.indicators,
                alertTimestamp: timestamp
            }
        }).promise();
        
        // Optional: Send notification to caregiver/doctor
        if (prediction.probability > 0.8) {
            await sns.publish({
                TopicArn: 'arn:aws:sns:REGION:ACCOUNT:ParkinsonAlerts',
                Subject: 'High Risk Freeze Alert',
                Message: `User ${userId}: Freeze probability ${(prediction.probability * 100).toFixed(0)}%`
            }).promise();
        }
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                alertId: `FREEZE_${Date.now()}`,
                message: 'Freeze alert recorded'
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
                message: 'Internal server error'
            })
        };
    }
};
```

### Lambda 3: Data Sync Handler

**Function Name**: `parkinson-sync-data`

**Purpose**: Receives the complete `report.json` file from the wearable device

**Example Code (Node.js)**:

```javascript
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    try {
        // Parse the report.json content
        const report = JSON.parse(event.body);
        const { sessionId, userId, deviceId, sessionStart, sessionEnd, 
                totalTremors, totalFreezes, tremors, freezePredictions } = report;
        
        // Store session summary
        await dynamodb.put({
            TableName: 'MonitoringSessions',
            Item: {
                userId,
                sessionStart,
                sessionEnd,
                sessionId,
                deviceId,
                duration: sessionEnd - sessionStart,
                totalTremors,
                totalFreezes,
                syncTimestamp: Date.now()
            }
        }).promise();
        
        // Store detailed tremor data
        const tremorPromises = tremors.map(tremor => {
            return dynamodb.put({
                TableName: 'TremorReports',
                Item: {
                    userId,
                    timestamp: tremor.timestamp,
                    deviceId,
                    severity: tremor.severity,
                    duration: tremor.duration,
                    source: 'batch_sync',
                    accelerometerData: JSON.stringify(tremor.accelerometerData),
                    gyroscopeData: JSON.stringify(tremor.gyroscopeData)
                }
            }).promise();
        });
        
        // Store prediction data
        const predictionPromises = freezePredictions.map(prediction => {
            return dynamodb.put({
                TableName: 'FreezePredictions',
                Item: {
                    userId,
                    timestamp: prediction.timestamp,
                    deviceId,
                    probability: prediction.probability,
                    confidence: prediction.confidence,
                    indicators: prediction.indicators,
                    source: 'batch_sync'
                }
            }).promise();
        });
        
        await Promise.all([...tremorPromises, ...predictionPromises]);
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                syncId: `SYNC_${Date.now()}`,
                message: 'Data synchronized successfully'
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
                message: 'Internal server error'
            })
        };
    }
};
```

## Step 3: Create API Gateway

### Using AWS Console:

1. **Create REST API**
   - Go to API Gateway console
   - Create new REST API
   - Name: `ParkinsonMonitoringAPI`

2. **Create Resources and Methods**

   **Resource**: `/tremor-report`
   - Method: `POST`
   - Integration: Lambda Function
   - Lambda: `parkinson-tremor-report`
   - Enable CORS

   **Resource**: `/freeze-alert`
   - Method: `POST`
   - Integration: Lambda Function
   - Lambda: `parkinson-freeze-alert`
   - Enable CORS

   **Resource**: `/sync-data`
   - Method: `POST`
   - Integration: Lambda Function
   - Lambda: `parkinson-sync-data`
   - Enable CORS

3. **Deploy API**
   - Create deployment stage: `prod`
   - Note the invoke URL: `https://YOUR-API-ID.execute-api.REGION.amazonaws.com/prod`

### Using AWS CLI:

```bash
# Create API
aws apigateway create-rest-api --name ParkinsonMonitoringAPI --region us-east-1

# Get API ID from output, then create resources
# (Full CLI setup is lengthy, use console for easier setup)
```

## Step 4: Configure Authentication (Recommended)

### Option 1: API Key

```bash
# Create API key
aws apigateway create-api-key \
    --name ParkinsonWearableKey \
    --enabled \
    --region us-east-1

# Create usage plan
aws apigateway create-usage-plan \
    --name ParkinsonBasicPlan \
    --throttle burstLimit=100,rateLimit=50 \
    --quota limit=10000,period=DAY \
    --region us-east-1

# Associate API key with usage plan
```

### Option 2: Cognito User Pool (Better for production)

1. Create Cognito User Pool
2. Configure API Gateway to use Cognito authorizer
3. Update wearable app to authenticate users

## Step 5: Update Wearable App Configuration

After deploying, update `entry/src/main/ets/config/AppConfig.ets`:

```typescript
static readonly TREMOR_REPORT_ENDPOINT = 'https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod/tremor-report';
static readonly FREEZE_ALERT_ENDPOINT = 'https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod/freeze-alert';
static readonly SYNC_DATA_ENDPOINT = 'https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod/sync-data';
static readonly AWS_REGION = 'us-east-1';
```

And in `APIService.ets`, add your API key:

```typescript
const headers = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'X-API-Key': 'YOUR_API_KEY_HERE',
};
```

## Step 6: Test the Setup

### Test with curl:

```bash
# Test tremor report endpoint
curl -X POST https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/prod/tremor-report \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR_API_KEY" \
  -d '{
    "userId": "test_user",
    "deviceId": "test_device",
    "tremors": [{
      "severity": 5.5,
      "duration": 2000,
      "timestamp": 1234567890,
      "accelerometerData": [],
      "gyroscopeData": []
    }],
    "timestamp": 1234567890
  }'
```

## Step 7: Monitor and Debug

### CloudWatch Logs

- Each Lambda function has a log group: `/aws/lambda/FUNCTION_NAME`
- Monitor for errors and performance

### X-Ray (Optional)

Enable AWS X-Ray for distributed tracing:

```bash
aws lambda update-function-configuration \
    --function-name parkinson-tremor-report \
    --tracing-config Mode=Active
```

## Cost Estimation

**Free Tier (First 12 months):**
- Lambda: 1M free requests/month
- DynamoDB: 25 GB storage
- API Gateway: 1M API calls/month

**Expected Monthly Cost (after free tier):**
- Lambda: ~$0.20 (for 1 user with 1000 syncs/month)
- DynamoDB: ~$1.25 (for 1 GB storage)
- API Gateway: ~$3.50 (for 1M requests)
- **Total**: ~$5/month per user

## Security Best Practices

1. **Enable encryption at rest** for DynamoDB
2. **Use HTTPS only** for API Gateway
3. **Implement authentication** (Cognito/API keys)
4. **Enable CloudTrail** for audit logging
5. **Set up CloudWatch alarms** for anomalies
6. **Use VPC** for Lambda if processing PHI
7. **Implement rate limiting** on API Gateway
8. **Regular security audits** with AWS Trusted Advisor

## Additional Features to Consider

1. **SNS notifications** for high-risk alerts
2. **S3 storage** for raw sensor data archives
3. **QuickSight dashboards** for doctor visualization
4. **Step Functions** for complex workflows
5. **EventBridge** for scheduled data processing
6. **SageMaker** for ML model training and hosting

## Troubleshooting

### Lambda timeout
- Increase timeout in Lambda configuration (default 3s → 30s)

### CORS errors
- Enable CORS in API Gateway for all methods
- Add proper headers in Lambda responses

### DynamoDB throttling
- Switch to on-demand billing mode
- Or increase provisioned capacity

### Cold starts
- Enable provisioned concurrency for Lambda
- Or use reserved concurrency

## Next Steps

1. Deploy Lambda functions and API Gateway
2. Set up DynamoDB tables
3. Configure authentication
4. Test endpoints with curl/Postman
5. Update wearable app configuration
6. Deploy to production with monitoring
