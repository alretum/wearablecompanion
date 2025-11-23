/**
 * Configuration settings for the Parkinson's Freeze Detection App
 */

export class AppConfig {
  // AWS Lambda endpoints - REPLACE WITH YOUR ACTUAL ENDPOINTS
  static readonly AWS_REGION = 'us-east-1'; // Update with your AWS region
  static readonly TREMOR_REPORT_ENDPOINT = ''; // Not used anymore
  static readonly FREEZE_ALERT_ENDPOINT = ''; // Not used anymore
  static readonly SYNC_DATA_ENDPOINT = 'https://your-api-gateway-id.execute-api.us-east-1.amazonaws.com/prod/upload-report';
  static readonly HEART_RATE_ENDPOINT = 'https://smmwnlhdcrauwnstfasu.supabase.co/functions/v1/upload-heartrate';
  static readonly MEDICATION_INTAKE_ENDPOINT = 'https://smmwnlhdcrauwnstfasu.supabase.co/functions/v1/medication-intake';
  
  // Sensor sampling rates (Hz)
  static readonly ACCELEROMETER_RATE = 50; // 10 Hz - reduced for accuracy and stability
  static readonly GYROSCOPE_RATE = 50; // 10 Hz - reduced for accuracy and stability
  static readonly HEART_RATE_INTERVAL = 1000; // 1 second for heart rate
  
  // Detection thresholds
  static readonly TREMOR_THRESHOLD = 0.5; // Adjust based on testing
  static readonly FREEZE_PREDICTION_THRESHOLD = 0.7; // 70% probability
  static readonly HEART_RATE_SPIKE_THRESHOLD = 20; // BPM increase to consider as spike
  
  // Tremor detection thresholds - Motion must meet or exceed BOTH thresholds to be classified as tremor
  static readonly TREMOR_MIN_MAGNITUDE = 3.0; // Minimum magnitude (m/s²) to classify as tremor
  static readonly TREMOR_MIN_FREQUENCY = 1.5; // Minimum frequency (Hz) to classify as tremor
  
  // Data buffering
  static readonly SENSOR_BUFFER_SIZE = 100; // Keep last 100 readings (2 seconds at 50Hz)
  static readonly TREMOR_LOG_BATCH_SIZE = 10; // Send tremor reports in batches
  
  // Timing
  static readonly PREDICTION_WINDOW_MS = 5000; // Predict 5 seconds ahead
  static readonly DATA_SYNC_INTERVAL_MS = 60000; // Sync to server every 5 minutes
  static readonly HEART_RATE_AGGREGATE_INTERVAL_MS = 60000; // Aggregate heart rate every 1 minute
  
  // Monitoring behavior
  static readonly AUTO_START_MONITORING = true; // Set to true for always-on monitoring mode
  
  // Alert settings
  static readonly ENABLE_VIBRATION_ALERT = true;
  static readonly ENABLE_SOUND_ALERT = true;
  
  // Data management
  static readonly CLEAR_DATA_AFTER_SYNC = false; // Set to true to clear report.json after successful upload
  
  // Data collection mode (for datacollection2 branch testing)
  static readonly ENABLE_DATA_COLLECTION = false; // Set to true to collect all sensor data for analysis
  static readonly DATA_COLLECTION_SAVE_INTERVAL = 100; // Save every N readings (accelerometer/gyroscope)
  
  // Algorithm enable/disable (disable for pure data collection)
  static readonly ENABLE_TREMOR_DETECTION = true; // Set to false to disable tremor detection algorithm
  static readonly ENABLE_FREEZE_DETECTION = false; // Set to false to disable freeze prediction algorithm
  
  // Sensor type selection
  // Use LINEAR_ACCELEROMETER (attempts to remove gravity) or regular ACCELEROMETER (includes gravity)
  // Options: 'LINEAR' or 'REGULAR'
  // LINEAR: Uses LINEAR_ACCELEROMETER - should exclude gravity but may not work on all devices
  // REGULAR: Uses standard ACCELEROMETER - includes gravity (raw values)
  static readonly ACCELEROMETER_TYPE: 'LINEAR' | 'REGULAR' = 'REGULAR'; // REGULAR for stability
  
  // Gravity compensation - DISABLED to collect raw accelerometer values
  // Raw data includes gravity and will be processed offline if needed
  static readonly ENABLE_MANUAL_GRAVITY_COMPENSATION = false; // DISABLED - using raw values
  static readonly CALIBRATION_SAMPLES = 50; // Not used when compensation is disabled
}
