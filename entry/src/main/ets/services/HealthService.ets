/**
 * HealthService - Store-and-Forward Duty Cycle for Tremor Detection
 * 
 * Battery-efficient tremor monitoring system:
 * 1. Wake (1x/min): Every 60 seconds, wake the accelerometer
 * 2. Burst (10s): Collect raw sensor data for exactly 10 seconds (Target: 500 samples at 50Hz)
 * 3. Analyze (Local): Process the burst locally to generate a TremorRecord
 * 4. Buffer (RAM): Store the record in a local array
 * 5. Flush (1x/5min): Every 5 minutes (when buffer size = 5), package data and trigger upload
 */

import { sensor } from '@kit.SensorServiceKit';
import { MotionAnalyzer, AnalysisResult } from '../algorithms/MotionAnalyzer';
import { TremorEvent } from '../sensors/SensorData';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0011;
const TAG = 'HealthService';

export interface TremorRecord {
  status: 'active' | 'sedentary';
  magnitude: number;
  frequency: number;
  timestamp: number;
}

export class HealthService {
  private static readonly SAMPLING_RATE_HZ = 50;
  private static readonly BURST_DURATION_MS = 10000;        // 10 seconds
  private static readonly BURST_INTERVAL_MS = 60000;        // 60 seconds (1 minute)
  private static readonly BUFFER_SIZE = 5;                   // 5 records = 5 minutes
  private static readonly TARGET_SAMPLES = 500;              // 500 samples at 50Hz for 10s

  private motionAnalyzer: MotionAnalyzer;
  private tremorBuffer: TremorRecord[] = [];
  private isCollecting: boolean = false;
  private burstTimer: number = -1;
  private collectionTimer: number = -1;
  
  // Sensor data buffers for current burst
  private xBuffer: number[] = [];
  private yBuffer: number[] = [];
  private zBuffer: number[] = [];
  private accelSubscribed: boolean = false;

  // Callback for when buffer is ready to flush (5 minutes of data)
  private onBufferReady?: (records: TremorRecord[]) => void;
  // Callback for each individual tremor record
  private onTremorRecord?: (record: TremorRecord) => void;

  constructor() {
    this.motionAnalyzer = new MotionAnalyzer();
    hilog.info(DOMAIN, TAG, 'HealthService initialized - Duty cycle monitoring');
  }

  /**
   * Start the duty cycle monitoring
   * 
   * @param onTremorRecord - Callback for each individual tremor record (for real-time reporting)
   * @param onBufferReady - Callback when 5 minutes of data is ready for upload
   */
  public start(
    onTremorRecord: (record: TremorRecord) => void,
    onBufferReady: (records: TremorRecord[]) => void
  ): void {
    if (this.burstTimer !== -1) {
      hilog.warn(DOMAIN, TAG, 'Already started');
      return;
    }

    this.onTremorRecord = onTremorRecord;
    this.onBufferReady = onBufferReady;

    hilog.info(DOMAIN, TAG, 'Starting duty cycle: 10s burst every 60s');
    
    // Start first burst immediately
    this.startBurst();

    // Schedule next bursts every 60 seconds
    this.burstTimer = setInterval(() => {
      this.startBurst();
    }, HealthService.BURST_INTERVAL_MS);
  }

  /**
   * Stop the duty cycle monitoring
   */
  public stop(): void {
    if (this.burstTimer !== -1) {
      clearInterval(this.burstTimer);
      this.burstTimer = -1;
    }

    if (this.collectionTimer !== -1) {
      clearTimeout(this.collectionTimer);
      this.collectionTimer = -1;
    }

    this.stopAccelerometer();
    this.isCollecting = false;
    
    hilog.info(DOMAIN, TAG, 'Duty cycle stopped');
  }

  /**
   * Start a 10-second burst of data collection
   */
  private startBurst(): void {
    if (this.isCollecting) {
      hilog.warn(DOMAIN, TAG, 'Already collecting, skipping burst');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Starting 10s data burst');
    
    // Clear buffers
    this.xBuffer = [];
    this.yBuffer = [];
    this.zBuffer = [];
    
    // Start accelerometer
    this.startAccelerometer();
    this.isCollecting = true;

    // Stop after 10 seconds and analyze
    this.collectionTimer = setTimeout(() => {
      this.stopBurst();
    }, HealthService.BURST_DURATION_MS);
  }

  /**
   * Stop the burst and analyze the collected data
   */
  private stopBurst(): void {
    this.stopAccelerometer();
    this.isCollecting = false;

    hilog.info(DOMAIN, TAG, 
      `Burst complete. Collected ${this.xBuffer.length} samples (target: ${HealthService.TARGET_SAMPLES})`);

    // Analyze the collected data
    const result = this.motionAnalyzer.analyze(this.xBuffer, this.yBuffer, this.zBuffer);

    if (result.isValid) {
      const record: TremorRecord = {
        status: result.status,
        magnitude: result.magnitude,
        frequency: result.frequency,
        timestamp: Date.now()
      };

      // Add to buffer
      this.tremorBuffer.push(record);
      hilog.info(DOMAIN, TAG, 
        `Tremor record added: status=${record.status}, mag=${record.magnitude}, freq=${record.frequency}Hz, buffer size=${this.tremorBuffer.length}/${HealthService.BUFFER_SIZE}`);

      // Notify callback for real-time reporting
      this.onTremorRecord?.(record);

      // Check if buffer is ready to flush (5 minutes of data)
      if (this.tremorBuffer.length >= HealthService.BUFFER_SIZE) {
        hilog.info(DOMAIN, TAG, 'Buffer ready to flush (5 minutes of data)');
        this.flushBuffer();
      }
    } else {
      hilog.warn(DOMAIN, TAG, 'Analysis result invalid, skipping record');
    }
  }

  /**
   * Flush the buffer and trigger upload
   */
  private flushBuffer(): void {
    const recordsToFlush = [...this.tremorBuffer];
    this.onBufferReady?.(recordsToFlush);
    
    // Clear buffer after flush
    this.tremorBuffer = [];
    hilog.info(DOMAIN, TAG, `Buffer flushed: ${recordsToFlush.length} records sent for upload`);
  }

  /**
   * Start accelerometer for burst collection
   */
  private startAccelerometer(): void {
    try {
      // Use REGULAR accelerometer as specified (includes gravity)
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        // Collect raw X, Y, Z data
        this.xBuffer.push(data.x);
        this.yBuffer.push(data.y);
        this.zBuffer.push(data.z);
      }, { interval: 20000 }); // 20ms = 50Hz

      this.accelSubscribed = true;
      hilog.debug(DOMAIN, TAG, 'Accelerometer started at 50Hz');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to start accelerometer: ${error}`);
    }
  }

  /**
   * Stop accelerometer
   */
  private stopAccelerometer(): void {
    if (this.accelSubscribed) {
      try {
        sensor.off(sensor.SensorId.ACCELEROMETER);
        this.accelSubscribed = false;
        hilog.debug(DOMAIN, TAG, 'Accelerometer stopped');
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Failed to stop accelerometer: ${error}`);
      }
    }
  }

  /**
   * Get current buffer status
   */
  public getBufferStatus(): { size: number; maxSize: number } {
    return {
      size: this.tremorBuffer.length,
      maxSize: HealthService.BUFFER_SIZE
    };
  }

  /**
   * Manually trigger a flush (for testing or immediate upload)
   */
  public manualFlush(): void {
    if (this.tremorBuffer.length > 0) {
      hilog.info(DOMAIN, TAG, 'Manual flush triggered');
      this.flushBuffer();
    } else {
      hilog.warn(DOMAIN, TAG, 'No data to flush');
    }
  }
}
