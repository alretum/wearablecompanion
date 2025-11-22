/**
 * TremorDetector - Detects and logs tremor events
 * 
 * TODO: Implement your tremor detection algorithm
 * 
 * Parkinson's tremor characteristics:
 * - Frequency: 4-6 Hz (resting tremor)
 * - Can affect hands, arms, legs, jaw
 * - Often asymmetric
 * - Pill-rolling motion in hands
 */

import { AccelerometerData, GyroscopeData, TremorEvent } from '../sensors/SensorData';
import { AppConfig } from '../config/AppConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'TremorDetector';

export class TremorDetector {
  private accelBuffer: AccelerometerData[] = [];
  private gyroBuffer: GyroscopeData[] = [];
  private currentTremor: TremorEvent | null = null;
  private tremorStartTime: number = 0;
  private detectedTremors: TremorEvent[] = [];

  constructor() {
    hilog.info(DOMAIN, TAG, 'TremorDetector initialized');
  }

  /**
   * Process sensor data to detect tremors
   * 
   * @param accel - Current accelerometer reading
   * @param gyro - Current gyroscope reading
   * @returns TremorEvent if tremor is detected and complete, null otherwise
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

    // TODO: IMPLEMENT YOUR TREMOR DETECTION ALGORITHM HERE
    // Consider using:
    // - FFT to detect 4-6 Hz frequency components
    // - Peak detection for rhythmic patterns
    // - Magnitude thresholding for significance
    
    const isTremoring = this.analyzeTremorPattern();

    if (isTremoring) {
      if (this.currentTremor === null) {
        // Start new tremor event
        this.tremorStartTime = accel.timestamp;
        this.currentTremor = {
          severity: 0,
          duration: 0,
          timestamp: this.tremorStartTime,
          accelerometerData: [],
          gyroscopeData: []
        };
        hilog.info(DOMAIN, TAG, 'Tremor started');
      }

      // Accumulate data during tremor
      this.currentTremor.accelerometerData.push(accel);
      this.currentTremor.gyroscopeData.push(gyro);
      this.currentTremor.duration = accel.timestamp - this.tremorStartTime;
      this.currentTremor.severity = this.calculateTremorSeverity();

    } else if (this.currentTremor !== null) {
      // Tremor ended
      const completedTremor = this.currentTremor;
      this.detectedTremors.push(completedTremor);
      
      hilog.info(DOMAIN, TAG, 
        `Tremor ended: duration=${completedTremor.duration}ms, severity=${completedTremor.severity.toFixed(2)}`);
      
      this.currentTremor = null;
      this.tremorStartTime = 0;
      
      return completedTremor;
    }

    return null;
  }

  /**
   * TODO: Implement tremor pattern analysis
   * Detect 4-6 Hz oscillations characteristic of Parkinson's tremor
   */
  private analyzeTremorPattern(): boolean {
    // Placeholder: Simple threshold-based detection
    // TODO: Implement FFT or autocorrelation for frequency analysis
    
    const windowSize = 20;
    if (this.accelBuffer.length < windowSize) return false;

    const recentAccel = this.accelBuffer.slice(-windowSize);
    
    // Calculate magnitude of acceleration vector
    const magnitudes = recentAccel.map(a => 
      Math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
    );

    // Check for high frequency oscillations
    const variance = this.calculateVariance(magnitudes);
    const peakCount = this.countPeaks(magnitudes);
    
    // Heuristic: 4-6 Hz tremor would have 1-2 peaks in 20 samples at 50 Hz
    // (20 samples = 0.4 seconds, 4-6 Hz = 1.6-2.4 peaks in that time)
    const hasOscillation = peakCount >= 1 && peakCount <= 3;
    const hasSignificantAmplitude = variance > AppConfig.TREMOR_THRESHOLD;

    return hasOscillation && hasSignificantAmplitude;
  }

  /**
   * TODO: Calculate tremor severity (0-10 scale)
   * Consider amplitude, frequency stability, and affected axes
   */
  private calculateTremorSeverity(): number {
    if (this.currentTremor === null || this.currentTremor.accelerometerData.length === 0) {
      return 0;
    }

    // Placeholder: Base severity on amplitude
    // TODO: Implement comprehensive severity assessment
    
    const magnitudes = this.currentTremor.accelerometerData.map(a =>
      Math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
    );

    const maxMagnitude = Math.max(...magnitudes);
    const avgMagnitude = magnitudes.reduce((sum, m) => sum + m, 0) / magnitudes.length;
    
    // Normalize to 0-10 scale (adjust based on testing)
    const severity = Math.min((avgMagnitude / 2.0) * 10, 10);
    
    return severity;
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
   * Helper: Calculate variance
   */
  private calculateVariance(values: number[]): number {
    if (values.length === 0) return 0;
    
    const mean = values.reduce((sum, val) => sum + val, 0) / values.length;
    const squaredDiffs = values.map(val => Math.pow(val - mean, 2));
    return squaredDiffs.reduce((sum, val) => sum + val, 0) / values.length;
  }

  /**
   * Get all detected tremors (for batching to server)
   */
  public getDetectedTremors(): TremorEvent[] {
    return [...this.detectedTremors];
  }

  /**
   * Clear detected tremors after sending to server
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
    this.currentTremor = null;
    this.tremorStartTime = 0;
    this.detectedTremors = [];
    hilog.info(DOMAIN, TAG, 'Detector reset');
  }

  /**
   * Get current tremor count
   */
  public getTremorCount(): number {
    return this.detectedTremors.length;
  }
}
