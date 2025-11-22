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
import { APIService } from '../connectivity/APIService';
import { ReportLogger } from './ReportLogger';
import { 
  AppState, 
  MonitoringStatus, 
  AccelerometerData, 
  GyroscopeData, 
  HeartRateData,
  FreezePrediction,
  TremorEvent
} from '../sensors/SensorData';
import { AppConfig } from '../config/AppConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { vibrator } from '@kit.SensorServiceKit';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0005;
const TAG = 'MonitoringService';

interface VibrateOptions {
  type: string;
  duration: number;
}

export class MonitoringService {
  private static instance: MonitoringService | null = null;
  
  private sensorManager: SensorManager;
  private predictionAlgorithm: PredictionAlgorithm;
  private tremorDetector: TremorDetector;
  private apiService: APIService;
  private reportLogger: ReportLogger | null = null;
  
  private appState: AppState;
  private stateCallbacks: ((state: AppState) => void)[] = [];
  
  private syncTimer: number = -1;
  private allPredictions: FreezePrediction[] = [];

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
    const userId = 'USER_' + Date.now(); // TODO: Replace with actual user ID
    const deviceId = 'DEVICE_' + Date.now();
    this.reportLogger = new ReportLogger(context, userId, deviceId);
    hilog.info(DOMAIN, TAG, 'MonitoringService initialized with ReportLogger');
  }

  /**
   * Start monitoring for Parkinson's symptoms
   */
  public startMonitoring(): void {
    if (this.appState.status === MonitoringStatus.MONITORING) {
      hilog.warn(DOMAIN, TAG, 'Already monitoring');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Starting monitoring...');
    
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

    // Start periodic data sync
    this.startDataSync();
    
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
    
    // Final sync before stopping
    this.syncDataToServer();
    
    this.appState.status = MonitoringStatus.STOPPED;
    this.notifyStateChange();
    
    hilog.info(DOMAIN, TAG, 'Monitoring stopped');
  }

  /**
   * Handle accelerometer data
   */
  private handleAccelerometerData(accel: AccelerometerData): void {
    this.appState.currentAccel = accel;
    
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
    this.notifyStateChange();
  }

  /**
   * Process motion data through algorithms
   */
  private processMotionData(accel: AccelerometerData, gyro: GyroscopeData): void {
    if (this.appState.currentHeartRate === null) {
      return; // Wait for heart rate data
    }

    // Detect tremors
    const tremor = this.tremorDetector.detectTremor(accel, gyro);
    if (tremor !== null) {
      this.handleTremorDetected(tremor);
    }

    // Predict freezes
    const prediction = this.predictionAlgorithm.predictFreeze(
      accel, 
      gyro, 
      this.appState.currentHeartRate
    );
    
    if (prediction !== null) {
      this.handleFreezePrediction(prediction);
    }

    this.notifyStateChange();
  }

  /**
   * Handle detected tremor
   */
  private handleTremorDetected(tremor: TremorEvent): void {
    hilog.info(DOMAIN, TAG, `Tremor detected: severity=${tremor.severity.toFixed(2)}`);
    
    this.appState.latestTremor = tremor;
    this.appState.totalTremorsDetected++;

    // Log to report.json file
    this.reportLogger?.logTremor(tremor);
    
    // Send tremor report in batches
    const tremorCount = this.tremorDetector.getTremorCount();
    if (tremorCount >= AppConfig.TREMOR_LOG_BATCH_SIZE) {
      const tremors = this.tremorDetector.getDetectedTremors();
      this.apiService.sendTremorReport(tremors).then((success) => {
        if (success) {
          this.tremorDetector.clearDetectedTremors();
        }
      });
    }
    
    this.notifyStateChange();
  }

  /**
   * Handle freeze prediction
   */
  private handleFreezePrediction(prediction: FreezePrediction): void {
    hilog.info(DOMAIN, TAG, 
      `Freeze predicted: probability=${prediction.probability.toFixed(2)}, confidence=${prediction.confidence.toFixed(2)}`);
    
    this.appState.latestPrediction = prediction;
    this.appState.totalFreezesDetected++;
    this.appState.status = MonitoringStatus.ALERT;
    this.allPredictions.push(prediction);

    // Log to report.json file
    this.reportLogger?.logFreezePrediction(prediction);
    
    // Send alert to server
    this.apiService.sendFreezeAlert(prediction);
    
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
        // Short vibration pattern: 200ms on, 100ms off, 200ms on
        const vibrateOptions: VibrateOptions = {
          type: 'time',
          duration: 500
        };
        vibrator.startVibration(vibrateOptions, (error: Error) => {
          if (error) {
            hilog.error(DOMAIN, TAG, `Vibration failed: ${error}`);
          }
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
   * Start periodic data sync
   */
  private startDataSync(): void {
    if (this.syncTimer !== -1) {
      clearInterval(this.syncTimer);
    }

    this.syncTimer = setInterval(() => {
      this.syncDataToServer();
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
        // Clear uploaded data from report file
        this.reportLogger?.clearUploadedData();
        this.tremorDetector.clearDetectedTremors();
        this.allPredictions = [];
        hilog.info(DOMAIN, TAG, 'Report synced successfully');
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
  public async testAPIConnectivity(): Promise<{ [key: string]: boolean }> {
    return this.apiService.testConnectivity();
  }

  /**
   * Get the report logger instance
   */
  public getReportLogger(): ReportLogger | null {
    return this.reportLogger;
  }

  /**
   * Cleanup resources
   */
  public destroy(): void {
    this.stopMonitoring();
    this.predictionAlgorithm.reset();
    this.tremorDetector.reset();
    hilog.info(DOMAIN, TAG, 'MonitoringService destroyed');
  }
}
