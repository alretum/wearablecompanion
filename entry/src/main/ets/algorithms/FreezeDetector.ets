/**
 * FreezeDetector - Real-time Freezing of Gait (FoG) Detection
 * 
 * Implements time-domain Freeze Index algorithm using EMA filters
 * to separate locomotor (0.5-1.5 Hz) and freeze (1.5-8.0 Hz) bands.
 * 
 * Algorithm:
 * 1. Signal Pre-processing: Calculate magnitude and detrend
 * 2. Band Separation: Use EMA filters to split frequency bands
 * 3. Energy Calculation: Compute power in each band
 * 4. Freeze Index: Ratio of freeze/locomotor power with thresholds
 */

import { AccelerometerData } from '../sensors/SensorData.ets';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0020;
const TAG = 'FreezeDetector';

interface BandSignals {
  locoSignal: number[];
  freezeSignal: number[];
}

export class FreezeDetector {
  // EMA filter coefficients
  private readonly ALPHA_LOCO = 0.15;  // Low-pass filter for locomotor band (0.5-1.5 Hz)
  
  // Detection thresholds - LOWERED for better sensitivity
  private readonly MOTION_GATE = 0.1;   // Minimum freeze band power (lowered from 0.5)
  private readonly WALK_GATE = 2.0;     // Maximum locomotor power (increased from 1.0 to be less strict)
  private readonly FREEZE_RATIO = 1.5;  // Freeze Index threshold (lowered from 2.0 for easier detection)
  
  // Rolling buffer for 1-second window (50 samples at 50 Hz)
  private readonly BUFFER_SIZE = 50;
  private buffer: AccelerometerData[] = [];
  
  // EMA filter state
  private previousLoco = 0;
  
  // Detection state
  private isFrozen = false;
  
  // Debug counter for periodic logging
  private sampleCounter = 0;

  constructor() {
    hilog.info(DOMAIN, TAG, 'FreezeDetector initialized - Freeze Index algorithm');
  }

  /**
   * Process a single accelerometer sample and detect FoG
   * 
   * @param sample - Raw accelerometer reading (x, y, z)
   * @returns true if FoG detected, false otherwise
   */
  public detectFreeze(sample: AccelerometerData): boolean {
    // Add sample to rolling buffer
    this.buffer.push(sample);
    if (this.buffer.length > this.BUFFER_SIZE) {
      this.buffer.shift();
    }

    // Need full buffer for analysis
    if (this.buffer.length < this.BUFFER_SIZE) {
      // Log buffer filling progress every 10 samples
      if (this.buffer.length % 10 === 0) {
        hilog.info(DOMAIN, TAG, `Buffer filling: ${this.buffer.length}/${this.BUFFER_SIZE}`);
      }
      return false;
    }

    // Increment sample counter
    this.sampleCounter++;

    // Step A: Signal Pre-processing
    const magnitudes = this.calculateMagnitudes();
    const signal = this.detrendSignal(magnitudes);

    // Step B: Band Separation using EMA
    const bands = this.separateBands(signal);

    // Step C: Energy & Trigger Logic
    const pLoco = this.calculatePower(bands.locoSignal);
    const pFreeze = this.calculatePower(bands.freezeSignal);

    // Apply detection logic
    const fogDetected = this.applyFreezeIndex(pLoco, pFreeze);

    // Update state
    this.isFrozen = fogDetected;

    return fogDetected;
  }

  /**
   * Step A: Calculate Euclidean magnitude for all samples
   */
  private calculateMagnitudes(): number[] {
    const magnitudes: number[] = [];
    
    for (const sample of this.buffer) {
      const mag = Math.sqrt(
        sample.x * sample.x + 
        sample.y * sample.y + 
        sample.z * sample.z
      );
      magnitudes.push(mag);
    }
    
    // Log magnitude statistics periodically (every 50 samples = 1 second)
    if (this.sampleCounter % 50 === 0) {
      const avgMag = magnitudes.reduce((sum, val) => sum + val, 0) / magnitudes.length;
      const maxMag = Math.max(...magnitudes);
      const minMag = Math.min(...magnitudes);
      hilog.info(DOMAIN, TAG, 
        `Magnitude Stats: avg=${avgMag.toFixed(2)}, min=${minMag.toFixed(2)}, max=${maxMag.toFixed(2)}`);
    }
    
    return magnitudes;
  }

  /**
   * Step A: Detrend signal by subtracting mean
   */
  private detrendSignal(magnitudes: number[]): number[] {
    const mean = magnitudes.reduce((sum, val) => sum + val, 0) / magnitudes.length;
    return magnitudes.map(val => val - mean);
  }

  /**
   * Step B: Band Separation using EMA filters
   * 
   * Locomotor Band (0.5-1.5 Hz): Low-pass filter with alpha=0.15
   * Freeze Band (1.5-8.0 Hz): High-pass (subtract locomotor from raw)
   */
  private separateBands(signal: number[]): BandSignals {
    const locoSignal: number[] = [];
    const freezeSignal: number[] = [];

    // Reset EMA state for new buffer
    let loco = this.previousLoco;

    for (const sample of signal) {
      // Apply EMA low-pass filter for locomotor band
      loco = (this.ALPHA_LOCO * sample) + ((1 - this.ALPHA_LOCO) * loco);
      locoSignal.push(loco);

      // Freeze band = Raw - Locomotor (high-pass effect)
      const freeze = sample - loco;
      freezeSignal.push(freeze);
    }

    // Store last locomotor value for next iteration
    this.previousLoco = loco;

    const result: BandSignals = {
      locoSignal: locoSignal,
      freezeSignal: freezeSignal
    };
    return result;
  }

  /**
   * Step C: Calculate power (mean squared) for a signal
   */
  private calculatePower(signal: number[]): number {
    if (signal.length === 0) return 0;
    
    const sumSquared = signal.reduce((sum, val) => sum + (val * val), 0);
    return sumSquared / signal.length;
  }

  /**
   * Step C: Apply Freeze Index logic with thresholds
   */
  private applyFreezeIndex(pLoco: number, pFreeze: number): boolean {
    // Motion Gate: Too quiet (standing still)
    if (pFreeze < this.MOTION_GATE) {
      hilog.info(DOMAIN, TAG, 
        `[FOG] Motion Gate: pFreeze=${pFreeze.toFixed(3)} < ${this.MOTION_GATE} (Standing Still)`);
      return false;
    }

    // Walk Gate: Strong arm swing (walking normally)
    if (pLoco > this.WALK_GATE) {
      hilog.info(DOMAIN, TAG, 
        `[FOG] Walk Gate: pLoco=${pLoco.toFixed(3)} > ${this.WALK_GATE} (Walking Normally)`);
      return false;
    }

    // Prevent divide-by-zero
    if (pLoco === 0) {
      hilog.warn(DOMAIN, TAG, '[FOG] Division by zero avoided (pLoco=0)');
      return false;
    }

    // Calculate Freeze Index
    const freezeIndex = pFreeze / pLoco;

    // Check for NaN
    if (isNaN(freezeIndex)) {
      hilog.warn(DOMAIN, TAG, '[FOG] NaN detected in Freeze Index calculation');
      return false;
    }

    // Trigger condition
    const fogDetected = freezeIndex > this.FREEZE_RATIO;

    // Always log the calculated values to help with debugging
    if (fogDetected) {
      hilog.info(DOMAIN, TAG, 
        `[FOG] ✅ FREEZE DETECTED! Ratio=${freezeIndex.toFixed(2)} (pFreeze=${pFreeze.toFixed(3)}, pLoco=${pLoco.toFixed(3)})`);
    } else {
      hilog.info(DOMAIN, TAG, 
        `[FOG] Normal: Ratio=${freezeIndex.toFixed(2)} < ${this.FREEZE_RATIO} (pFreeze=${pFreeze.toFixed(3)}, pLoco=${pLoco.toFixed(3)})`);
    }

    return fogDetected;
  }

  /**
   * Get current detection state
   */
  public isFreezeActive(): boolean {
    return this.isFrozen;
  }

  /**
   * Reset detector state
   */
  public reset(): void {
    this.buffer = [];
    this.previousLoco = 0;
    this.isFrozen = false;
    this.sampleCounter = 0;
    hilog.info(DOMAIN, TAG, 'FreezeDetector reset');
  }
}
