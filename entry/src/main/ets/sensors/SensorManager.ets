/**
 * SensorManager - Handles all sensor data collection
 * Manages accelerometer, gyroscope, and heart rate sensors
 */

import { sensor } from '@kit.SensorServiceKit';
import { AccelerometerData, GyroscopeData, HeartRateData } from './SensorData';
import { AppConfig } from '../config/AppConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'SensorManager';

export class SensorManager {
  private isMonitoring: boolean = false;
  
  // Callbacks for sensor data
  private onAccelData?: (data: AccelerometerData) => void;
  private onGyroData?: (data: GyroscopeData) => void;
  private onHeartRateData?: (data: HeartRateData) => void;
  private onError?: (error: string) => void;
  
  // Sensor subscriptions
  private accelSubscribed: boolean = false;
  private gyroSubscribed: boolean = false;
  private heartRateSubscribed: boolean = false;

  constructor() {
    hilog.info(DOMAIN, TAG, 'SensorManager initialized');
  }

  /**
   * Start monitoring all sensors
   */
  public startMonitoring(
    onAccel: (data: AccelerometerData) => void,
    onGyro: (data: GyroscopeData) => void,
    onHeartRate: (data: HeartRateData) => void,
    onError: (error: string) => void
  ): void {
    if (this.isMonitoring) {
      hilog.warn(DOMAIN, TAG, 'Already monitoring sensors');
      return;
    }

    this.onAccelData = onAccel;
    this.onGyroData = onGyro;
    this.onHeartRateData = onHeartRate;
    this.onError = onError;

    this.startAccelerometer();
    this.startGyroscope();
    this.startHeartRate();

    this.isMonitoring = true;
    hilog.info(DOMAIN, TAG, 'Started monitoring all sensors');
  }

  /**
   * Stop monitoring all sensors
   */
  public stopMonitoring(): void {
    if (!this.isMonitoring) {
      return;
    }

    this.stopAccelerometer();
    this.stopGyroscope();
    this.stopHeartRate();

    this.isMonitoring = false;
    hilog.info(DOMAIN, TAG, 'Stopped monitoring all sensors');
  }

  /**
   * Start linear accelerometer
   * Used to detect gait disturbances and tremors
   */
  private startAccelerometer(): void {
    try {
      sensor.on(sensor.SensorId.LINEAR_ACCELEROMETER, (data: sensor.LinearAccelerometerResponse) => {
        const accelData: AccelerometerData = {
          x: data.x,
          y: data.y,
          z: data.z,
          timestamp: data.timestamp
        };
        this.onAccelData?.(accelData);
      }, { interval: 1000000 / AppConfig.ACCELEROMETER_RATE }); // Convert Hz to microseconds

      this.accelSubscribed = true;
      hilog.info(DOMAIN, TAG, 'Linear accelerometer started');
    } catch (error) {
      const errorMsg = `Failed to start accelerometer: ${error}`;
      hilog.error(DOMAIN, TAG, errorMsg);
      this.onError?.(errorMsg);
    }
  }

  /**
   * Start gyroscope
   * Used to detect rotational movements and tremors
   */
  private startGyroscope(): void {
    try {
      sensor.on(sensor.SensorId.GYROSCOPE, (data: sensor.GyroscopeResponse) => {
        const gyroData: GyroscopeData = {
          x: data.x,
          y: data.y,
          z: data.z,
          timestamp: data.timestamp
        };
        this.onGyroData?.(gyroData);
      }, { interval: 1000000 / AppConfig.GYROSCOPE_RATE }); // Convert Hz to microseconds

      this.gyroSubscribed = true;
      hilog.info(DOMAIN, TAG, 'Gyroscope started');
    } catch (error) {
      const errorMsg = `Failed to start gyroscope: ${error}`;
      hilog.error(DOMAIN, TAG, errorMsg);
      this.onError?.(errorMsg);
    }
  }

  /**
   * Start heart rate monitoring
   * Used to detect stress through pulse spikes
   */
  private startHeartRate(): void {
    try {
      sensor.on(sensor.SensorId.HEART_RATE, (data: sensor.HeartRateResponse) => {
        const heartRateData: HeartRateData = {
          bpm: data.heartRate,
          timestamp: Date.now()
        };
        this.onHeartRateData?.(heartRateData);
      }, { interval: AppConfig.HEART_RATE_INTERVAL * 1000 }); // Convert ms to microseconds

      this.heartRateSubscribed = true;
      hilog.info(DOMAIN, TAG, 'Heart rate monitor started');
    } catch (error) {
      const errorMsg = `Failed to start heart rate monitor: ${error}`;
      hilog.error(DOMAIN, TAG, errorMsg);
      this.onError?.(errorMsg);
    }
  }

  /**
   * Stop accelerometer
   */
  private stopAccelerometer(): void {
    if (this.accelSubscribed) {
      try {
        sensor.off(sensor.SensorId.LINEAR_ACCELEROMETER);
        this.accelSubscribed = false;
        hilog.info(DOMAIN, TAG, 'Accelerometer stopped');
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Failed to stop accelerometer: ${error}`);
      }
    }
  }

  /**
   * Stop gyroscope
   */
  private stopGyroscope(): void {
    if (this.gyroSubscribed) {
      try {
        sensor.off(sensor.SensorId.GYROSCOPE);
        this.gyroSubscribed = false;
        hilog.info(DOMAIN, TAG, 'Gyroscope stopped');
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Failed to stop gyroscope: ${error}`);
      }
    }
  }

  /**
   * Stop heart rate monitoring
   */
  private stopHeartRate(): void {
    if (this.heartRateSubscribed) {
      try {
        sensor.off(sensor.SensorId.HEART_RATE);
        this.heartRateSubscribed = false;
        hilog.info(DOMAIN, TAG, 'Heart rate monitor stopped');
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Failed to stop heart rate monitor: ${error}`);
      }
    }
  }

  /**
   * Check if monitoring is active
   */
  public isActive(): boolean {
    return this.isMonitoring;
  }
}
