/**
 * MonitoringService - Orchestrates all components for Parkinson's freeze detection
 * 
 * Coordinates:
 * - SensorManager: Collects accelerometer, gyroscope, heart rate data
 * - PredictionAlgorithm: Predicts freezing episodes
 * - TremorDetector: Detects and logs tremors
 * - APIService: Sends data to AWS Lambda functions
 */

import { SensorManager } from '../sensors/SensorManager';
import { PredictionAlgorithm } from '../algorithms/PredictionAlgorithm';
import { TremorDetector } from '../algorithms/TremorDetector';
import { APIService, ConnectivityResults } from '../connectivity/APIService';
import { ReportLogger } from './ReportLogger';
import { HeartRateLogger } from './HeartRateLogger';
import { DataCollectionLogger } from './DataCollectionLogger';
import { APILogStats } from './APILogger';
import { 
  AppState, 
  MonitoringStatus, 
  AccelerometerData, 
  GyroscopeData, 
  HeartRateData,
  FreezePrediction,
  TremorEvent,
  GPSCoordinates
} from '../sensors/SensorData';
import { AppConfig } from '../config/AppConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { vibrator } from '@kit.SensorServiceKit';
import { common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { CoordinateType, toDMS } from '../common/CoordinatesConverter';

const DOMAIN = 0x0005;
const TAG = 'MonitoringService';

interface VibrateTime {
  type: 'time';
  duration: number;
}

export class MonitoringService {
  private static instance: MonitoringService | null = null;
  
  private sensorManager: SensorManager;
  private predictionAlgorithm: PredictionAlgorithm;
  private tremorDetector: TremorDetector;
  private apiService: APIService;
  private reportLogger: ReportLogger | null = null;
  private heartRateLogger: HeartRateLogger | null = null;
  private dataCollectionLogger: DataCollectionLogger | null = null;
  private context: common.UIAbilityContext | null = null;
  private atManager: abilityAccessCtrl.AtManager | null = null;
  
  private appState: AppState;
  private stateCallbacks: ((state: AppState) => void)[] = [];
  
  private syncTimer: number = -1;
  private heartRateAggregationTimer: number = -1;
  private allPredictions: FreezePrediction[] = [];
  private continuousTaskId: number = -1;

  private constructor() {
    this.sensorManager = new SensorManager();
    this.predictionAlgorithm = new PredictionAlgorithm();
    this.tremorDetector = new TremorDetector();
    this.apiService = new APIService();
    this.appState = new AppState();
    
    hilog.info(DOMAIN, TAG, 'MonitoringService initialized');
  }

  /**
   * Get singleton instance
   */
  public static getInstance(): MonitoringService {
    if (MonitoringService.instance === null) {
      MonitoringService.instance = new MonitoringService();
    }
    return MonitoringService.instance;
  }

  /**
   * Initialize ReportLogger with context
   */
  public initialize(context: common.UIAbilityContext): void {
    this.context = context;
    const userId = 'USER_' + Date.now(); // TODO: Replace with actual user ID
    const deviceId = 'DEVICE_' + Date.now();
    this.reportLogger = new ReportLogger(context, userId, deviceId);
    this.heartRateLogger = new HeartRateLogger(userId, deviceId);
    
    // Initialize API logger
    this.apiService.initializeLogger(context, userId, deviceId);
    
    // Initialize data collection logger if enabled
    if (AppConfig.ENABLE_DATA_COLLECTION) {
      this.dataCollectionLogger = new DataCollectionLogger(context, userId, deviceId);
      hilog.info(DOMAIN, TAG, 'Data collection mode ENABLED');
    }
    
    this.atManager = abilityAccessCtrl.createAtManager();
    
    // Request all necessary permissions
    this.requestAllPermissions();
    
    hilog.info(DOMAIN, TAG, 'MonitoringService initialized with ReportLogger, HeartRateLogger, DataCollectionLogger, and GPS');
  }

  /**
   * Request all necessary runtime permissions from the user
   * Returns true if all permissions granted, false otherwise
   */
  private async requestAllPermissions(): Promise<boolean> {
    const perms: Permissions[] = [
      'ohos.permission.READ_HEALTH_DATA',  // Required for heart rate sensor
      'ohos.permission.LOCATION', 
      'ohos.permission.APPROXIMATELY_LOCATION'
    ];
    
    try {
      if (this.atManager && this.context) {
        const result = await this.atManager.requestPermissionsFromUser(this.context, perms);
        hilog.info(DOMAIN, TAG, 'Permission request result: ' + JSON.stringify(result));
        
        // Check if all permissions were granted
        let allGranted = true;
        result.authResults.forEach((authResult, index) => {
          const permName = perms[index];
          if (authResult === 0) {
            hilog.info(DOMAIN, TAG, `Permission granted: ${permName}`);
          } else {
            hilog.warn(DOMAIN, TAG, `Permission denied: ${permName}`);
            allGranted = false;
          }
        });
        return allGranted;
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Request permissions failed: ' + JSON.stringify(err));
    }
    return false;
  }

  /**
   * Record medication intake
   */
  public async recordMedicationIntake(): Promise<boolean> {
    hilog.info(DOMAIN, TAG, 'User recorded medication intake');
    return await this.apiService.recordMedicationIntake();
  }

  /**
   * Get current GPS coordinates
   * Returns GPS coordinates or null if location cannot be retrieved
   */
  private async getGPSCoordinates(): Promise<GPSCoordinates | null> {
    // Check if location services are enabled
    if (!geoLocationManager.isLocationEnabled()) {
      hilog.warn(DOMAIN, TAG, 'Location services are not enabled');
      return null;
    }

    const request: geoLocationManager.SingleLocationRequest = {
      'locatingPriority': geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
      'locatingTimeoutMs': 10000  // 10 second timeout
    };
    
    try {
      const result = await geoLocationManager.getCurrentLocation(request);
      
      // Log coordinates in both formats
      hilog.info(DOMAIN, TAG, `GPS coordinates retrieved: ${result.latitude}, ${result.longitude}`);
      const latDMS = toDMS(result.latitude, CoordinateType.LATITUDE);
      const lonDMS = toDMS(result.longitude, CoordinateType.LONGITUDE);
      hilog.info(DOMAIN, TAG, `GPS coordinates (DMS): ${latDMS}, ${lonDMS}`);
      
      const gpsCoordinates: GPSCoordinates = {
        latitude: result.latitude,
        longitude: result.longitude,
        altitude: result.altitude,
        accuracy: result.accuracy,
        timestamp: result.timeStamp
      };
      
      return gpsCoordinates;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to get GPS coordinates: ' + JSON.stringify(error));
      return null;
    }
  }

  /**
   * Start monitoring for Parkinson's symptoms
   * Ensures all permissions are granted before starting sensors
   */
  public async startMonitoring(): Promise<void> {
    if (this.appState.status === MonitoringStatus.MONITORING) {
      hilog.warn(DOMAIN, TAG, 'Already monitoring');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Starting monitoring...');
    
    // Verify all permissions are granted
    const permissionsGranted = await this.requestAllPermissions();
    if (!permissionsGranted) {
      const errorMsg = 'Cannot start monitoring: Not all permissions granted';
      hilog.error(DOMAIN, TAG, errorMsg);
      this.appState.status = MonitoringStatus.ERROR;
      this.appState.errorMessage = errorMsg;
      this.notifyStateChange();
      return;
    }
    
    this.appState.status = MonitoringStatus.MONITORING;
    this.appState.monitoringStartTime = Date.now();
    this.appState.totalTremorsDetected = 0;
    this.appState.totalFreezesDetected = 0;
    this.appState.errorMessage = '';
    
    // Start sensor monitoring
    this.sensorManager.startMonitoring(
      (accel) => this.handleAccelerometerData(accel),
      (gyro) => this.handleGyroscopeData(gyro),
      (heartRate) => this.handleHeartRateData(heartRate),
      (error) => this.handleSensorError(error)
    );

    // Start continuous background task
    await this.startContinuousTask();
    
    // Start periodic data sync
    this.startDataSync();
    this.startHeartRateAggregation();
    
    this.notifyStateChange();
    hilog.info(DOMAIN, TAG, 'Monitoring started successfully');
  }

  /**
   * Stop monitoring
   */
  public stopMonitoring(): void {
    if (this.appState.status === MonitoringStatus.STOPPED) {
      hilog.warn(DOMAIN, TAG, 'Already stopped');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Stopping monitoring...');
    
    this.sensorManager.stopMonitoring();
    this.stopDataSync();
    this.stopHeartRateAggregation();
    
    // Stop continuous background task
    this.stopContinuousTask();
    
    // Final sync before stopping
    this.syncDataToServer();
    this.syncHeartRateToServer();
    
    this.appState.status = MonitoringStatus.STOPPED;
    this.notifyStateChange();
    
    hilog.info(DOMAIN, TAG, 'Monitoring stopped');
  }

  /**
   * Handle accelerometer data
   */
  private handleAccelerometerData(accel: AccelerometerData): void {
    this.appState.currentAccel = accel;
    
    // Log to data collection if enabled and update lastSaved when persisted
    if (AppConfig.ENABLE_DATA_COLLECTION) {
      const wasSaved = this.dataCollectionLogger?.logAccelerometer(accel);
      if (wasSaved) {
        this.appState.lastSavedAccel = accel;
      }
    }
    
    // Process with current gyroscope data if available
    if (this.appState.currentGyro !== null) {
      this.processMotionData(accel, this.appState.currentGyro);
    }
  }

  /**
   * Handle gyroscope data
   */
  private handleGyroscopeData(gyro: GyroscopeData): void {
    this.appState.currentGyro = gyro;
    
    // Log to data collection if enabled and update lastSaved when persisted
    if (AppConfig.ENABLE_DATA_COLLECTION) {
      const wasSaved = this.dataCollectionLogger?.logGyroscope(gyro);
      if (wasSaved) {
        this.appState.lastSavedGyro = gyro;
      }
    }
    
    // Process with current accelerometer data if available
    if (this.appState.currentAccel !== null) {
      this.processMotionData(this.appState.currentAccel, gyro);
    }
  }

  /**
   * Handle heart rate data
   */
  private handleHeartRateData(heartRate: HeartRateData): void {
    this.appState.currentHeartRate = heartRate;
    
    // Add to heart rate logger
    this.heartRateLogger?.addReading(heartRate);
    
    // Log to data collection if enabled (heart rate saves immediately)
    if (AppConfig.ENABLE_DATA_COLLECTION) {
      this.dataCollectionLogger?.logHeartRate(heartRate);
      this.appState.lastSavedHeartRate = heartRate; // Always saved immediately
    }
    
    this.notifyStateChange();
  }

  /**
   * Process motion data through algorithms
   */
  private processMotionData(accel: AccelerometerData, gyro: GyroscopeData): void {
    if (this.appState.currentHeartRate === null) {
      return; // Wait for heart rate data
    }

    // Detect tremors (only if enabled)
    if (AppConfig.ENABLE_TREMOR_DETECTION) {
      const tremor = this.tremorDetector.detectTremor(accel, gyro);
      if (tremor !== null) {
        this.handleTremorDetected(tremor);
      }
    }

    // Predict freezes (only if enabled)
    if (AppConfig.ENABLE_FREEZE_DETECTION) {
      const prediction = this.predictionAlgorithm.predictFreeze(
        accel, 
        gyro, 
        this.appState.currentHeartRate
      );
      
      if (prediction !== null) {
        this.handleFreezePrediction(prediction);
      }
    }

    this.notifyStateChange();
  }

  /**
   * Handle detected tremor/activity data
   * Tremor data is included in the 5-minute heart rate report
   */
  private handleTremorDetected(tremor: TremorEvent): void {
    hilog.info(DOMAIN, TAG, `Activity detected: status=${tremor.status}, magnitude=${tremor.magnitude.toFixed(2)}, frequency=${tremor.frequency.toFixed(2)}Hz`);
    
    this.appState.latestTremor = tremor;
    this.appState.totalTremorsDetected++;

    // Add tremor data to heart rate logger (will be included in 5-minute report)
    this.heartRateLogger?.addTremorData(tremor);
    
    // Log to data collection if enabled
    if (AppConfig.ENABLE_DATA_COLLECTION) {
      this.dataCollectionLogger?.logTremor(tremor);
    }
    
    // NOTE: Tremor data is NOT sent to incident reports
    // It's included in the periodic heart rate report every 5 minutes
    
    this.notifyStateChange();
  }

  /**
   * Handle freeze prediction
   * Retrieves GPS coordinates and adds them to the prediction
   */
  private async handleFreezePrediction(prediction: FreezePrediction): Promise<void> {
    hilog.info(DOMAIN, TAG, 
      `Freeze predicted: probability=${prediction.probability.toFixed(2)}, confidence=${prediction.confidence.toFixed(2)}`);
    
    // Retrieve GPS coordinates for the freeze event
    const gpsCoordinates = await this.getGPSCoordinates();
    if (gpsCoordinates !== null) {
      prediction.gpsCoordinates = gpsCoordinates;
      hilog.info(DOMAIN, TAG, 
        `GPS coordinates added to freeze prediction: ${gpsCoordinates.latitude}, ${gpsCoordinates.longitude}`);
    } else {
      hilog.warn(DOMAIN, TAG, 'Could not retrieve GPS coordinates for freeze prediction');
    }
    
    this.appState.latestPrediction = prediction;
    this.appState.totalFreezesDetected++;
    this.appState.status = MonitoringStatus.ALERT;
    this.allPredictions.push(prediction);

    // Log to report.json file (with GPS coordinates if available)
    this.reportLogger?.logFreezePrediction(prediction);
    
    // Log to data collection if enabled
    if (AppConfig.ENABLE_DATA_COLLECTION) {
      this.dataCollectionLogger?.logFreezePrediction(prediction);
      if (gpsCoordinates !== null) {
        this.dataCollectionLogger?.logGPS(gpsCoordinates);
      }
    }
    
    // Send alert to server immediately
    this.apiService.sendFreezeAlert(prediction).then((success) => {
      if (success) {
        hilog.info(DOMAIN, TAG, 'Freeze alert sent successfully');
        // Note: Individual freeze alerts are not cleared from report.json
        // They are only cleared during periodic sync if CLEAR_DATA_AFTER_SYNC is enabled
      }
    });
    
    // Alert user
    this.alertUser();
    
    // Return to monitoring after alert
    setTimeout(() => {
      if (this.appState.status === MonitoringStatus.ALERT) {
        this.appState.status = MonitoringStatus.MONITORING;
        this.notifyStateChange();
      }
    }, 5000); // Alert for 5 seconds
    
    this.notifyStateChange();
  }

  /**
   * Handle sensor errors
   */
  private handleSensorError(error: string): void {
    hilog.error(DOMAIN, TAG, `Sensor error: ${error}`);
    this.appState.status = MonitoringStatus.ERROR;
    this.appState.errorMessage = error;
    this.notifyStateChange();
  }

  /**
   * Alert user of predicted freeze
   */
  private alertUser(): void {
    if (AppConfig.ENABLE_VIBRATION_ALERT) {
      try {
        // Short vibration pattern: 500ms vibration
        const vibrateEffect: VibrateTime = {
          type: 'time',
          duration: 500
        };
        vibrator.startVibration(vibrateEffect, {
          usage: 'alarm'
        });
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Vibration failed: ${error}`);
      }
    }

    // TODO: Add sound alert if needed
    // if (AppConfig.ENABLE_SOUND_ALERT) {
    //   // Play alert sound
    // }
  }

  /**
   * Start periodic heart rate aggregation (every minute)
   */
  private startHeartRateAggregation(): void {
    if (this.heartRateAggregationTimer !== -1) {
      clearInterval(this.heartRateAggregationTimer);
    }

    this.heartRateAggregationTimer = setInterval(() => {
      this.heartRateLogger?.triggerAggregation();
    }, AppConfig.HEART_RATE_AGGREGATE_INTERVAL_MS);
  }

  /**
   * Stop periodic heart rate aggregation
   */
  private stopHeartRateAggregation(): void {
    if (this.heartRateAggregationTimer !== -1) {
      clearInterval(this.heartRateAggregationTimer);
      this.heartRateAggregationTimer = -1;
    }
  }

  /**
   * Sync heart rate data to server
   */
  private syncHeartRateToServer(): void {
    if (!this.heartRateLogger) {
      return;
    }

    // Only upload if we have data
    if (!this.heartRateLogger.hasData()) {
      hilog.info(DOMAIN, TAG, 'No heart rate data to upload');
      return;
    }

    const heartRateReport = this.heartRateLogger.getReport();
    
    this.apiService.uploadHeartRateReport(heartRateReport).then((success) => {
      if (success) {
        // Clear heart rate data after successful upload
        this.heartRateLogger?.clearData();
        hilog.info(DOMAIN, TAG, 'Heart rate data synced and cleared successfully');
      } else {
        hilog.error(DOMAIN, TAG, 'Failed to sync heart rate data');
      }
    });
  }

  /**
   * Start continuous background task to keep app running in background
   */
  private async startContinuousTask(): Promise<void> {
    if (!this.context) {
      hilog.error(DOMAIN, TAG, 'Cannot start continuous task: context is null');
      return;
    }

    try {
      await backgroundTaskManager.startBackgroundRunning(
        this.context,
        backgroundTaskManager.BackgroundMode.DATA_TRANSFER,
        {
          wantAgent: undefined // Optional: can add notification to show background activity
        }
      );
      hilog.info(DOMAIN, TAG, 'Continuous background task started - app will run in background');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to start continuous background task: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Stop continuous background task
   */
  private stopContinuousTask(): void {
    if (!this.context) {
      return;
    }

    try {
      backgroundTaskManager.stopBackgroundRunning(this.context);
      hilog.info(DOMAIN, TAG, 'Continuous background task stopped');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to stop continuous background task: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Start periodic data sync
   */
  private startDataSync(): void {
    if (this.syncTimer !== -1) {
      clearInterval(this.syncTimer);
    }

    this.syncTimer = setInterval(() => {
      this.syncDataToServer();
      this.syncHeartRateToServer();
    }, AppConfig.DATA_SYNC_INTERVAL_MS);
  }

  /**
   * Stop periodic data sync
   */
  private stopDataSync(): void {
    if (this.syncTimer !== -1) {
      clearInterval(this.syncTimer);
      this.syncTimer = -1;
    }
  }

  /**
   * Sync data to server
   * Only freeze incidents are sent via this method
   * Tremor data is sent as part of heart rate reports
   */
  private syncDataToServer(): void {
    if (!this.reportLogger) {
      hilog.warn(DOMAIN, TAG, 'ReportLogger not initialized');
      return;
    }

    // Send the report.json file to AWS
    const reportJSON = this.reportLogger.getReportJSON();
    
    this.apiService.syncReportFile(reportJSON).then((success) => {
      if (success) {
        // Clear uploaded data from report file only if enabled in config
        if (AppConfig.CLEAR_DATA_AFTER_SYNC) {
          this.reportLogger?.clearUploadedData();
          this.tremorDetector.clearDetectedTremors();
          this.allPredictions = [];
          hilog.info(DOMAIN, TAG, 'Report synced and cleared successfully');
        } else {
          hilog.info(DOMAIN, TAG, 'Report synced successfully (data retained)');
        }
      } else {
        hilog.error(DOMAIN, TAG, 'Failed to sync report');
      }
    });
  }

  /**
   * Register callback for state changes
   */
  public onStateChange(callback: (state: AppState) => void): void {
    this.stateCallbacks.push(callback);
  }

  /**
   * Notify all registered callbacks of state change
   */
  private notifyStateChange(): void {
    this.stateCallbacks.forEach(callback => callback(this.appState));
  }

  /**
   * Get current application state
   */
  public getState(): AppState {
    return this.appState;
  }

  /**
   * Test API connectivity
   */
  public async testAPIConnectivity(): Promise<ConnectivityResults> {
    return this.apiService.testConnectivity();
  }

  /**
   * Get the report logger instance
   */
  public getReportLogger(): ReportLogger | null {
    return this.reportLogger;
  }

  /**
   * Get the data collection logger instance
   */
  public getDataCollectionLogger(): DataCollectionLogger | null {
    return this.dataCollectionLogger;
  }

  /**
   * Get data collection statistics
   */
  public getDataCollectionStats(): string {
    if (!AppConfig.ENABLE_DATA_COLLECTION || !this.dataCollectionLogger) {
      return 'Data collection is disabled';
    }
    return this.dataCollectionLogger.getStats();
  }

  /**
   * Export data collection to backup file
   */
  public exportDataCollection(): string {
    if (!AppConfig.ENABLE_DATA_COLLECTION || !this.dataCollectionLogger) {
      return '';
    }
    return this.dataCollectionLogger.exportToBackup();
  }

  /**
   * Get API log file path for access
   */
  public getAPILogFilePath(): string | null {
    return this.apiService.getAPILogFilePath();
  }

  /**
   * Get API log statistics
   */
  public getAPILogStats(): APILogStats {
    return this.apiService.getAPILogStats();
  }

  /**
   * Cleanup resources
   */
  public destroy(): void {
    this.stopMonitoring();
    this.stopContinuousTask();
    this.predictionAlgorithm.reset();
    this.tremorDetector.reset();
    hilog.info(DOMAIN, TAG, 'MonitoringService destroyed');
  }
}
