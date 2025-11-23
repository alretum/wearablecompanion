/**
 * MotionAnalyzer - Signal Processing for Parkinson's Tremor Detection
 * 
 * Implements pure algebraic filtering to detect resting tremors (3-12 Hz)
 * while filtering out voluntary movements (walking/activity).
 * 
 * Algorithm Steps:
 * A. Signal Pre-processing (Gravity Removal)
 * B. Activity Gate (Walking Filter) 
 * C. Metric Extraction (Sedentary Only)
 * D. Scoring & Classification
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0010;
const TAG = 'MotionAnalyzer';

export interface AnalysisResult {
  status: 'active' | 'sedentary';
  magnitude: number;  // 0.0-10.0 motion intensity (always calculated)
  frequency: number;  // Hz (0 if not periodic)
  isValid: boolean;   // False if insufficient data
}

export class MotionAnalyzer {
  // Calibration constants
  private readonly WALK_THRESH: number = 1.5;      // Variance threshold for walking detection
  private readonly NOISE_FLOOR: number = 0.05;     // m/s² dead zone for frequency counting
  private readonly MIN_FREQ_HZ: number = 3.0;      // Minimum valid tremor frequency
  private readonly SCALING_FACTOR: number = 1.5;   // Amplitude normalization factor
  private readonly MIN_SAMPLES: number = 50;        // Minimum samples required (1 second at 50Hz)

  constructor() {
    hilog.info(DOMAIN, TAG, 'MotionAnalyzer initialized - Pure algebraic tremor detection');
  }

  /**
   * Analyze a buffer of raw accelerometer data
   * 
   * @param xData - Array of raw X accelerometer values (including gravity)
   * @param yData - Array of raw Y accelerometer values (including gravity)
   * @param zData - Array of raw Z accelerometer values (including gravity)
   * @returns AnalysisResult with status, magnitude, and frequency
   */
  public analyze(xData: number[], yData: number[], zData: number[]): AnalysisResult {
    // Validate input
    if (xData.length !== yData.length || yData.length !== zData.length) {
      hilog.error(DOMAIN, TAG, 'Input arrays have mismatched lengths');
      return this.createInvalidResult();
    }

    if (xData.length < this.MIN_SAMPLES) {
      hilog.warn(DOMAIN, TAG, `Insufficient samples: ${xData.length} < ${this.MIN_SAMPLES}`);
      return this.createInvalidResult();
    }

    // Step A: Signal Pre-processing (Gravity Removal)
    const signal = this.removeGravity(xData, yData, zData);

    // Step B: Activity Gate (Walking Filter)
    const variance = this.calculateVariance(signal);
    
    // Step C: Metric Extraction (for both active and sedentary states)
    const mad = this.calculateMAD(signal);
    const frequency = this.calculateZCR(signal, xData.length);

    // Step D: Scoring & Classification
    // Always calculate magnitude (motion intensity) regardless of activity status
    const motionMagnitude = Math.min((mad / this.SCALING_FACTOR) * 10, 10.0);
    
    // Round to 1 decimal place
    const roundedScore = Math.round(motionMagnitude * 10) / 10;
    const roundedFreq = Math.round(frequency * 10) / 10;
    
    // Determine activity status based on variance
    if (variance > this.WALK_THRESH) {
      hilog.debug(DOMAIN, TAG, 
        `Active state detected (variance=${variance.toFixed(3)} > ${this.WALK_THRESH}), Magnitude=${roundedScore}, Freq=${roundedFreq}Hz`);
      return {
        status: 'active',
        magnitude: roundedScore,
        frequency: roundedFreq,
        isValid: true
      };
    }

    // Sedentary state - log additional info about tremor frequency
    if (frequency < this.MIN_FREQ_HZ) {
      hilog.debug(DOMAIN, TAG, 
        `Low frequency motion: ${frequency.toFixed(1)} Hz < ${this.MIN_FREQ_HZ} Hz minimum`);
    }

    hilog.debug(DOMAIN, TAG, 
      `Sedentary: MAD=${mad.toFixed(3)}, Freq=${roundedFreq}Hz, Magnitude=${roundedScore}`);

    return {
      status: 'sedentary',
      magnitude: roundedScore,
      frequency: roundedFreq,
      isValid: true
    };
  }

  /**
   * Step A: Remove gravity from raw accelerometer data
   * 
   * Calculates Euclidean magnitude, computes mean (gravity vector),
   * then detrends by subtracting mean to center signal at 0.
   */
  private removeGravity(xData: number[], yData: number[], zData: number[]): number[] {
    const n = xData.length;
    const magnitudes: number[] = new Array(n);

    // Calculate Euclidean magnitude for all samples
    for (let i = 0; i < n; i++) {
      magnitudes[i] = Math.sqrt(
        xData[i] * xData[i] + 
        yData[i] * yData[i] + 
        zData[i] * zData[i]
      );
    }

    // Calculate mean (approximates gravity vector)
    const mean = magnitudes.reduce((sum, val) => sum + val, 0) / n;

    // Detrend: subtract mean from every sample
    const signal: number[] = new Array(n);
    for (let i = 0; i < n; i++) {
      signal[i] = magnitudes[i] - mean;
    }

    return signal;
  }

  /**
   * Step B: Calculate variance to detect walking/activity
   * 
   * Standard deviation of the signal indicates motion intensity
   */
  private calculateVariance(signal: number[]): number {
    const n = signal.length;
    if (n === 0) return 0;

    // Signal is already centered at 0 (mean removed), so we can calculate variance directly
    const variance = signal.reduce((sum, val) => sum + val * val, 0) / n;
    return Math.sqrt(variance); // Return standard deviation
  }

  /**
   * Step C: Calculate Mean Absolute Deviation (MAD)
   * 
   * Measures tremor severity/amplitude
   */
  private calculateMAD(signal: number[]): number {
    const n = signal.length;
    if (n === 0) return 0;

    // Signal is already centered at 0, so MAD is just mean of absolute values
    const sumAbsolute = signal.reduce((sum, val) => sum + Math.abs(val), 0);
    return sumAbsolute / n;
  }

  /**
   * Step C: Calculate Zero-Crossing Rate (ZCR) with Hysteresis
   * 
   * Counts transitions across noise floor to estimate frequency.
   * Uses hysteresis to ignore micro-fluctuations.
   */
  private calculateZCR(signal: number[], sampleCount: number): number {
    if (signal.length < 2) return 0;

    let crossings = 0;
    let lastState: 'positive' | 'negative' | 'neutral' = 'neutral';

    // Initialize state based on first sample
    if (signal[0] > this.NOISE_FLOOR) {
      lastState = 'positive';
    } else if (signal[0] < -this.NOISE_FLOOR) {
      lastState = 'negative';
    }

    // Count crossings with hysteresis
    for (let i = 1; i < signal.length; i++) {
      const currentValue = signal[i];

      if (lastState === 'positive' && currentValue < -this.NOISE_FLOOR) {
        crossings++;
        lastState = 'negative';
      } else if (lastState === 'negative' && currentValue > this.NOISE_FLOOR) {
        crossings++;
        lastState = 'positive';
      } else if (lastState === 'neutral') {
        // Exit neutral state when signal exceeds noise floor
        if (currentValue > this.NOISE_FLOOR) {
          lastState = 'positive';
        } else if (currentValue < -this.NOISE_FLOOR) {
          lastState = 'negative';
        }
      }
    }

    // Convert to frequency (Hz)
    // Assuming 50 Hz sampling rate
    const samplingRate = 50;
    const durationSeconds = sampleCount / samplingRate;
    const frequency = (crossings / 2) / durationSeconds; // Divide by 2 for full cycles

    return frequency;
  }

  /**
   * Create an invalid result when analysis cannot be performed
   */
  private createInvalidResult(): AnalysisResult {
    return {
      status: 'sedentary',
      magnitude: 0,
      frequency: 0,
      isValid: false
    };
  }
}
