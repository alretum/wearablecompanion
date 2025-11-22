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

// Interface for 3D vector used in gravity compensation
interface Vector3D {
  x: number;
  y: number;
  z: number;
}

// Implementation class for Vector3D
class Vector3DImpl implements Vector3D {
  x: number;
  y: number;
  z: number;

  constructor(x: number, y: number, z: number) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
}

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
  
  // Gravity compensation (for devices where LINEAR_ACCELEROMETER doesn't work properly)
  private gravityVector: Vector3D = new Vector3DImpl(0, 0, 0);
  private calibrationReadings: Vector3D[] = [];
  private isCalibrated: boolean = false;

  constructor() {
    hilog.info(DOMAIN, TAG, 'SensorManager initialized');
    if (AppConfig.ENABLE_MANUAL_GRAVITY_COMPENSATION) {
      hilog.info(DOMAIN, TAG, '⚙️ Manual gravity compensation ENABLED - will calibrate from first readings');
    }
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

    // Reset calibration when starting
    this.resetCalibration();

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
    this.resetCalibration();
    hilog.info(DOMAIN, TAG, 'Stopped monitoring all sensors');
  }

  /**
   * Reset gravity calibration
   */
  private resetCalibration(): void {
    this.calibrationReadings = [];
    this.gravityVector = new Vector3DImpl(0, 0, 0);
    this.isCalibrated = false;
    hilog.info(DOMAIN, TAG, 'Calibration reset - keep device still for initial readings');
  }

  /**
   * Calibrate gravity vector from stationary readings
   * Call this with the first N readings when device is still
   */
  private calibrateGravity(x: number, y: number, z: number): void {
    if (this.isCalibrated) {
      return;
    }

    this.calibrationReadings.push(new Vector3DImpl(x, y, z));

    if (this.calibrationReadings.length >= AppConfig.CALIBRATION_SAMPLES) {
      // Calculate average gravity vector
      const sumX = this.calibrationReadings.reduce((sum, r) => sum + r.x, 0);
      const sumY = this.calibrationReadings.reduce((sum, r) => sum + r.y, 0);
      const sumZ = this.calibrationReadings.reduce((sum, r) => sum + r.z, 0);

      this.gravityVector.x = sumX / this.calibrationReadings.length;
      this.gravityVector.y = sumY / this.calibrationReadings.length;
      this.gravityVector.z = sumZ / this.calibrationReadings.length;

      const magnitude = Math.sqrt(
        this.gravityVector.x * this.gravityVector.x +
        this.gravityVector.y * this.gravityVector.y +
        this.gravityVector.z * this.gravityVector.z
      );

      this.isCalibrated = true;
      hilog.info(DOMAIN, TAG, 
        `Gravity calibrated: x=${this.gravityVector.x.toFixed(2)}, y=${this.gravityVector.y.toFixed(2)}, z=${this.gravityVector.z.toFixed(2)}, mag=${magnitude.toFixed(2)} m/s²`);
      
      if (magnitude > 8.0 && magnitude < 11.0) {
        hilog.info(DOMAIN, TAG, '✅ Gravity vector detected correctly (~9.8 m/s²) - compensation will be applied');
      } else {
        hilog.warn(DOMAIN, TAG, `⚠️ Unusual gravity magnitude: ${magnitude.toFixed(2)} m/s² (expected ~9.8)`);
      }
    }
  }

  /**
   * Remove gravity from accelerometer reading
   */
  private removeGravity(x: number, y: number, z: number): Vector3D {
    if (!this.isCalibrated) {
      // Still calibrating, use raw values
      return new Vector3DImpl(x, y, z);
    }

    // Subtract gravity vector to get linear acceleration
    return new Vector3DImpl(
      x - this.gravityVector.x,
      y - this.gravityVector.y,
      z - this.gravityVector.z
    );
  }

  /**
   * Start linear accelerometer
   * Used to detect gait disturbances and tremors
   * 
   * NOTE: LINEAR_ACCELEROMETER should exclude gravity and only measure motion acceleration.
   * Units are m/s² (meters per second squared).
   * Expected values when stationary: close to 0 on all axes.
   * If you see ~9.8 m/s² on any axis, gravity is NOT being removed properly.
   * 
   * CURRENT SOLUTION: Manual compensation is DISABLED by default because it can cause
   * instability. Instead, collect raw data and process it offline with proper signal
   * processing (low-pass filter to extract gravity, high-pass filter for motion).
   * 
   * For data analysis:
   * - Apply low-pass filter (e.g., 0.3 Hz cutoff) to isolate gravity component
   * - Apply high-pass filter (e.g., 0.3 Hz cutoff) to isolate motion component
   * - Or use complementary filter combining accelerometer + gyroscope data
   */
  private startAccelerometer(): void {
    try {
      sensor.on(sensor.SensorId.LINEAR_ACCELEROMETER, (data: sensor.LinearAccelerometerResponse) => {
        let finalX = data.x;
        let finalY = data.y;
        let finalZ = data.z;
        
        // Apply manual gravity compensation if enabled
        if (AppConfig.ENABLE_MANUAL_GRAVITY_COMPENSATION) {
          // Calibrate gravity during first N readings (device should be still)
          if (!this.isCalibrated) {
            this.calibrateGravity(data.x, data.y, data.z);
          }
          
          // Remove gravity to get true linear acceleration
          const linearAccel = this.removeGravity(data.x, data.y, data.z);
          finalX = linearAccel.x;
          finalY = linearAccel.y;
          finalZ = linearAccel.z;
          
          // Log first reading after calibration to verify
          if (this.isCalibrated && this.calibrationReadings.length === AppConfig.CALIBRATION_SAMPLES) {
            const magnitude = Math.sqrt(finalX * finalX + finalY * finalY + finalZ * finalZ);
            hilog.info(DOMAIN, TAG, 
              `First compensated reading: x=${finalX.toFixed(2)}, y=${finalY.toFixed(2)}, z=${finalZ.toFixed(2)}, mag=${magnitude.toFixed(2)} m/s²`);
            hilog.info(DOMAIN, TAG, '✅ Gravity compensation active - values should be near 0 when stationary');
            this.calibrationReadings.push(new Vector3DImpl(0, 0, 0)); // Dummy value to prevent this log from repeating
          }
        }
        
        const accelData: AccelerometerData = {
          x: finalX,
          y: finalY,
          z: finalZ,
          timestamp: data.timestamp
        };
        
        this.onAccelData?.(accelData);
      }, { interval: 1000000 / AppConfig.ACCELEROMETER_RATE }); // Convert Hz to microseconds

      this.accelSubscribed = true;
      hilog.info(DOMAIN, TAG, 'Linear accelerometer started - monitoring for gravity removal');
    } catch (error) {
      const errorMsg = `Failed to start accelerometer: ${error}`;
      hilog.error(DOMAIN, TAG, errorMsg);
      this.onError?.(errorMsg);
    }
  }

  /**
   * Start gyroscope
   * Used to detect rotational movements and tremors
   * 
   * NOTE: Gyroscope measures ANGULAR VELOCITY (rate of rotation), not absolute orientation.
   * Units are rad/s (radians per second).
   * This is a DELTA/RATE measurement - how fast the device is rotating.
   * Expected values when stationary: close to 0 on all axes.
   * This is DIFFERENT from accelerometer which measures linear acceleration.
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
      hilog.info(DOMAIN, TAG, 'Gyroscope started - measuring angular velocity (rad/s)');
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
        // Validate heart rate reading
        // Filter out invalid readings (255 indicates no sensor contact, 0 is also invalid)
        // Normal human heart rate range: 30-220 BPM
        if (data.heartRate > 0 && data.heartRate < 220 && data.heartRate !== 255) {
          const heartRateData: HeartRateData = {
            bpm: data.heartRate,
            timestamp: Date.now()
          };
          this.onHeartRateData?.(heartRateData);
        } else {
          hilog.warn(DOMAIN, TAG, `Invalid heart rate reading: ${data.heartRate} BPM (sensor not in contact or invalid)`);
        }
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
