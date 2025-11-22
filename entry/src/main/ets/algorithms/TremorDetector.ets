/**
 * TremorDetector - Detects activity status and motion characteristics
 * 
 * Analyzes accelerometer and gyroscope data to determine:
 * - Activity status (sedentary, active, unknown, not_worn)
 * - Motion magnitude (m/s²)
 * - Dominant frequency (Hz) if periodic motion detected
 * 
 * This data is reported as part of the 5-minute heart rate report.
 */

import { AccelerometerData, GyroscopeData, TremorEvent, ActivityStatus } from '../sensors/SensorData';
import { AppConfig } from '../config/AppConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'TremorDetector';

export class TremorDetector {
  private accelBuffer: AccelerometerData[] = [];
  private gyroBuffer: GyroscopeData[] = [];
  private detectedTremors: TremorEvent[] = [];
  private lastReportTime: number = 0;
  private static readonly REPORT_INTERVAL_MS = 10000; // Report every 10 seconds

  constructor() {
    hilog.info(DOMAIN, TAG, 'TremorDetector initialized - monitors activity status and motion');
  }

  /**
   * Process sensor data to detect activity and motion characteristics
   * 
   * @param accel - Current accelerometer reading (raw values with gravity)
   * @param gyro - Current gyroscope reading
   * @returns TremorEvent with activity status and motion metrics, or null if not ready
   */
  public detectTremor(accel: AccelerometerData, gyro: GyroscopeData): TremorEvent | null {
    // Add to buffers
    this.accelBuffer.push(accel);
    this.gyroBuffer.push(gyro);

    // Maintain buffer size
    if (this.accelBuffer.length > AppConfig.SENSOR_BUFFER_SIZE) {
      this.accelBuffer.shift();
    }
    if (this.gyroBuffer.length > AppConfig.SENSOR_BUFFER_SIZE) {
      this.gyroBuffer.shift();
    }

    // Need sufficient data
    if (this.accelBuffer.length < 20) {
      return null;
    }

    // Report at regular intervals
    const now = Date.now();
    if (now - this.lastReportTime < TremorDetector.REPORT_INTERVAL_MS) {
      return null;
    }
    this.lastReportTime = now;

    // Analyze activity status and motion
    const status = this.determineActivityStatus();
    const magnitude = this.calculateMotionMagnitude();
    const frequency = this.detectDominantFrequency();

    const tremorEvent: TremorEvent = {
      status: status,
      magnitude: magnitude,
      frequency: frequency,
      timestamp: now
    };

    this.detectedTremors.push(tremorEvent);
    hilog.debug(DOMAIN, TAG, 
      `Activity: ${status}, magnitude=${magnitude.toFixed(2)} m/s², frequency=${frequency.toFixed(2)} Hz`);

    return tremorEvent;
  }

  /**
   * Determine activity status based on motion patterns
   */
  private determineActivityStatus(): ActivityStatus {
    if (this.accelBuffer.length < 20) {
      return ActivityStatus.UNKNOWN;
    }

    const magnitude = this.calculateMotionMagnitude();
    
    // Thresholds for activity classification (adjust based on testing)
    const SEDENTARY_THRESHOLD = 0.5;  // m/s² - minimal movement
    const ACTIVE_THRESHOLD = 2.0;      // m/s² - significant movement
    
    if (magnitude < SEDENTARY_THRESHOLD) {
      return ActivityStatus.SEDENTARY;
    } else if (magnitude >= ACTIVE_THRESHOLD) {
      return ActivityStatus.ACTIVE;
    } else {
      return ActivityStatus.UNKNOWN;
    }
  }

  /**
   * Calculate overall motion magnitude from recent buffer
   * Returns standard deviation of acceleration magnitude (excluding gravity baseline)
   */
  private calculateMotionMagnitude(): number {
    if (this.accelBuffer.length === 0) {
      return 0;
    }

    const magnitudes = this.accelBuffer.map(a =>
      Math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
    );

    // Calculate standard deviation as measure of motion intensity
    const mean = magnitudes.reduce((sum, m) => sum + m, 0) / magnitudes.length;
    const variance = magnitudes.reduce((sum, m) => sum + Math.pow(m - mean, 2), 0) / magnitudes.length;
    return Math.sqrt(variance);
  }

  /**
   * Detect dominant frequency in motion data
   * Returns 0 if no clear periodic motion detected
   * Otherwise returns frequency in Hz (e.g., 4-6 Hz for tremor)
   */
  private detectDominantFrequency(): number {
    const windowSize = Math.min(50, this.accelBuffer.length);
    if (windowSize < 20) {
      return 0;
    }

    const recentAccel = this.accelBuffer.slice(-windowSize);
    const magnitudes = recentAccel.map(a =>
      Math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
    );

    // Simple peak counting method to estimate frequency
    const peakCount = this.countPeaks(magnitudes);
    
    // Convert to frequency (Hz)
    // Assuming sampling rate from config
    const samplingRate = AppConfig.ACCELEROMETER_RATE;
    const timeWindow = windowSize / samplingRate; // seconds
    const frequency = peakCount / timeWindow / 2; // Divide by 2 for full cycles

    // Only return frequency if it's in a meaningful range (0.5-15 Hz)
    if (frequency >= 0.5 && frequency <= 15) {
      return Math.round(frequency * 10) / 10; // Round to 1 decimal
    }

    return 0;
  }

  /**
   * Helper: Count peaks in signal for frequency analysis
   */
  private countPeaks(values: number[]): number {
    if (values.length < 3) return 0;
    
    let peaks = 0;
    for (let i = 1; i < values.length - 1; i++) {
      if (values[i] > values[i - 1] && values[i] > values[i + 1]) {
        peaks++;
      }
    }
    return peaks;
  }

  /**
   * Get all detected tremors (for reference)
   */
  public getDetectedTremors(): TremorEvent[] {
    return [...this.detectedTremors];
  }

  /**
   * Clear detected tremors
   */
  public clearDetectedTremors(): void {
    this.detectedTremors = [];
    hilog.info(DOMAIN, TAG, 'Cleared detected tremors');
  }

  /**
   * Reset the detector state
   */
  public reset(): void {
    this.accelBuffer = [];
    this.gyroBuffer = [];
    this.detectedTremors = [];
    this.lastReportTime = 0;
    hilog.info(DOMAIN, TAG, 'Detector reset');
  }

  /**
   * Get current tremor count
   */
  public getTremorCount(): number {
    return this.detectedTremors.length;
  }
}
