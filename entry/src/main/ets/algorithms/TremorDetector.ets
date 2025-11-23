/**
 * TremorDetector - Detects activity status and motion characteristics
 * 
 * Uses advanced signal processing (MotionAnalyzer) to detect Parkinson's tremors (3-12 Hz)
 * while filtering out voluntary movements (walking/activity).
 * 
 * Implements battery-efficient "store-and-forward duty cycle":
 * - Wakes every 60 seconds
 * - Collects 10 seconds of data (500 samples at 50Hz)
 * - Analyzes locally using algebraic filters
 * - Reports as part of the 5-minute heart rate report
 */

import { AccelerometerData, GyroscopeData, TremorEvent, ActivityStatus } from '../sensors/SensorData';
import { MotionAnalyzer } from './MotionAnalyzer';
import { AppConfig } from '../config/AppConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'TremorDetector';

export class TremorDetector {
  private motionAnalyzer: MotionAnalyzer;
  private accelBuffer: AccelerometerData[] = [];
  private detectedTremors: TremorEvent[] = [];
  private lastReportTime: number = 0;
  private static readonly REPORT_INTERVAL_MS = 60000; // Report every 60 seconds (1 minute)
  private static readonly BURST_DURATION_MS = 10000;  // Collect 10 seconds of data
  private static readonly TARGET_SAMPLES = 500;        // 500 samples at 50Hz
  
  private isCollectingBurst: boolean = false;
  private burstStartTime: number = 0;

  constructor() {
    this.motionAnalyzer = new MotionAnalyzer();
    hilog.info(DOMAIN, TAG, 'TremorDetector initialized - Advanced tremor detection with duty cycle');
  }

  /**
   * Process sensor data to detect activity and motion characteristics
   * 
   * Uses duty cycle: collects data for 10s every 60s, then analyzes using MotionAnalyzer
   * 
   * @param accel - Current accelerometer reading (raw values with gravity)
   * @param gyro - Current gyroscope reading (not used in new algorithm)
   * @returns TremorEvent with activity status and motion metrics, or null if not ready
   */
  public detectTremor(accel: AccelerometerData, gyro: GyroscopeData): TremorEvent | null {
    const now = Date.now();
    
    // Check if it's time to start a new burst
    if (!this.isCollectingBurst && (now - this.lastReportTime >= TremorDetector.REPORT_INTERVAL_MS)) {
      this.startBurst(now);
    }
    
    // If collecting burst, add data to buffer
    if (this.isCollectingBurst) {
      this.accelBuffer.push(accel);
      
      // Check if burst duration is complete
      const burstElapsed = now - this.burstStartTime;
      if (burstElapsed >= TremorDetector.BURST_DURATION_MS) {
        return this.endBurst(now);
      }
    }
    
    return null;
  }

  /**
   * Start a new data collection burst
   */
  private startBurst(timestamp: number): void {
    this.isCollectingBurst = true;
    this.burstStartTime = timestamp;
    this.accelBuffer = [];
    hilog.info(DOMAIN, TAG, 'Starting 10s data burst');
  }

  /**
   * End the burst and analyze collected data
   */
  private endBurst(timestamp: number): TremorEvent | null {
    this.isCollectingBurst = false;
    this.lastReportTime = timestamp;
    
    hilog.info(DOMAIN, TAG, 
      `Burst complete. Collected ${this.accelBuffer.length} samples (target: ${TremorDetector.TARGET_SAMPLES})`);
    
    // Analyze the burst using MotionAnalyzer
    if (this.accelBuffer.length < 50) {
      hilog.warn(DOMAIN, TAG, 'Insufficient samples for analysis');
      return null;
    }
    
    // Extract X, Y, Z arrays from buffer
    const xData = this.accelBuffer.map(a => a.x);
    const yData = this.accelBuffer.map(a => a.y);
    const zData = this.accelBuffer.map(a => a.z);
    
    // Analyze using MotionAnalyzer
    const result = this.motionAnalyzer.analyze(xData, yData, zData);
    
    if (!result.isValid) {
      hilog.warn(DOMAIN, TAG, 'Analysis result invalid');
      return null;
    }
    
    // Filter based on tremor detection thresholds
    // Motion must meet or exceed BOTH magnitude and frequency thresholds to be classified as tremor
    if (result.status === 'sedentary' && 
        (result.magnitude < AppConfig.TREMOR_MIN_MAGNITUDE || result.frequency < AppConfig.TREMOR_MIN_FREQUENCY)) {
      hilog.info(DOMAIN, TAG, 
        `Motion below tremor threshold (magnitude=${result.magnitude.toFixed(1)} < ${AppConfig.TREMOR_MIN_MAGNITUDE} or frequency=${result.frequency.toFixed(1)} < ${AppConfig.TREMOR_MIN_FREQUENCY} Hz) - not classified as tremor`);
      return null;
    }
    
    // Convert to TremorEvent
    const status = result.status === 'active' ? ActivityStatus.ACTIVE : ActivityStatus.SEDENTARY;
    
    const tremorEvent: TremorEvent = {
      status: status,
      magnitude: result.magnitude,
      frequency: result.frequency,
      timestamp: timestamp
    };

    this.detectedTremors.push(tremorEvent);
    hilog.info(DOMAIN, TAG, 
      `Tremor detected: status=${status}, magnitude=${result.magnitude.toFixed(1)}, frequency=${result.frequency.toFixed(1)} Hz`);

    return tremorEvent;
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
    this.detectedTremors = [];
    this.lastReportTime = 0;
    this.isCollectingBurst = false;
    this.burstStartTime = 0;
    hilog.info(DOMAIN, TAG, 'Detector reset');
  }

  /**
   * Get current tremor count
   */
  public getTremorCount(): number {
    return this.detectedTremors.length;
  }
}
