/**
 * Configuration settings for the Parkinson's Freeze Detection App
 */

export class AppConfig {
  // AWS Lambda endpoints - REPLACE WITH YOUR ACTUAL ENDPOINTS
  static readonly AWS_REGION = 'us-east-1'; // Update with your AWS region
  static readonly TREMOR_REPORT_ENDPOINT = 'https://your-api-gateway-id.execute-api.us-east-1.amazonaws.com/prod/tremor-report';
  static readonly FREEZE_ALERT_ENDPOINT = 'https://your-api-gateway-id.execute-api.us-east-1.amazonaws.com/prod/freeze-alert';
  static readonly SYNC_DATA_ENDPOINT = 'https://your-api-gateway-id.execute-api.us-east-1.amazonaws.com/prod/sync-data';
  
  // Sensor sampling rates (Hz)
  static readonly ACCELEROMETER_RATE = 50; // 50 Hz
  static readonly GYROSCOPE_RATE = 50; // 50 Hz
  static readonly HEART_RATE_INTERVAL = 1000; // 1 second for heart rate
  
  // Detection thresholds
  static readonly TREMOR_THRESHOLD = 0.5; // Adjust based on testing
  static readonly FREEZE_PREDICTION_THRESHOLD = 0.7; // 70% probability
  static readonly HEART_RATE_SPIKE_THRESHOLD = 20; // BPM increase to consider as spike
  
  // Data buffering
  static readonly SENSOR_BUFFER_SIZE = 100; // Keep last 100 readings (2 seconds at 50Hz)
  static readonly TREMOR_LOG_BATCH_SIZE = 10; // Send tremor reports in batches
  
  // Timing
  static readonly PREDICTION_WINDOW_MS = 5000; // Predict 5 seconds ahead
  static readonly DATA_SYNC_INTERVAL_MS = 300000; // Sync to server every 5 minutes
  
  // User settings (can be made configurable via UI)
  static readonly ENABLE_VIBRATION_ALERT = true;
  static readonly ENABLE_SOUND_ALERT = true;
  static readonly AUTO_START_MONITORING = false;
}
