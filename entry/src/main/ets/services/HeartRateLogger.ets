/**
 * HeartRateLogger - Aggregates heart rate and tremor data per minute
 * Maintains 5 minutes of data (5 entries, 1 per minute)
 * This data is sent to AWS heart rate endpoint every 5 minutes
 */

import { HeartRateData, TremorEvent, ActivityStatus } from '../sensors/SensorData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConfig } from '../config/AppConfig';

const DOMAIN = 0x0007;
const TAG = 'HeartRateLogger';

export interface HeartRateMinuteAggregate {
  timestamp: number; // Start of the minute
  avgBpm: number;
  minBpm: number;
  maxBpm: number;
  tremorData: TremorEvent | null; // Tremor/activity data for this minute
}

export interface HeartRateReport {
  userId: string;
  deviceId: string;
  reportTimestamp: number;
  minutes: HeartRateMinuteAggregate[]; // 5 entries, one per minute, each with tremor data
}

export interface HeartRateStats {
  minutesLogged: number;
  latestAvgBpm: number;
}

export class HeartRateLogger {
  private static readonly MAX_MINUTES = 5; // Keep last 5 minutes
  private userId: string;
  private deviceId: string;
  
  private currentMinuteData: HeartRateData[] = [];
  private currentMinuteTremor: TremorEvent | null = null;
  private currentMinuteStart: number = 0;
  private aggregatedMinutes: HeartRateMinuteAggregate[] = [];
  private lastAggregationTime: number = 0;
  private aggregatedTimestamps: Set<number> = new Set(); // Track which minutes have been aggregated

  constructor(userId: string, deviceId: string) {
    this.userId = userId;
    this.deviceId = deviceId;
    this.currentMinuteStart = this.getMinuteTimestamp(Date.now());
    this.lastAggregationTime = Date.now();
    hilog.info(DOMAIN, TAG, 'HeartRateLogger initialized - includes tremor/activity data');
  }

  /**
   * Add tremor/activity data - assigns to the correct minute based on tremor timestamp
   * Priority logic:
   * 1. Keep valid tremor (sedentary + frequency >= 3.0 Hz) over other readings
   * 2. If no valid tremor exists yet, store any reading
   * 3. Don't overwrite valid tremor with "active" or low-frequency readings
   */
  public addTremorData(tremor: TremorEvent): void {
    const tremorMinute = this.getMinuteTimestamp(tremor.timestamp);
    
    // Check if this is a valid tremor (sedentary with tremor-frequency motion)
    const isValidTremor = tremor.status === ActivityStatus.SEDENTARY && 
                          tremor.frequency >= 3.0 && 
                          tremor.magnitude > 0;
    
    // If tremor belongs to current minute being collected
    if (tremorMinute === this.currentMinuteStart) {
      // Check if current stored data is a valid tremor
      const hasValidTremor = this.currentMinuteTremor !== null &&
                             this.currentMinuteTremor.status === ActivityStatus.SEDENTARY &&
                             this.currentMinuteTremor.frequency >= 3.0 &&
                             this.currentMinuteTremor.magnitude > 0;
      
      // Only update if no data yet, or this is valid tremor, or current is not valid
      if (this.currentMinuteTremor === null || isValidTremor || !hasValidTremor) {
        this.currentMinuteTremor = tremor;
        
        if (isValidTremor) {
          hilog.info(DOMAIN, TAG, 
            `Valid tremor stored for current minute: magnitude=${tremor.magnitude.toFixed(1)}, frequency=${tremor.frequency.toFixed(1)}Hz`);
        }
      } else {
        hilog.debug(DOMAIN, TAG, 
          `Keeping existing valid tremor, ignoring ${tremor.status} reading`);
      }
    } else {
      // Tremor belongs to a previous minute - find and update the aggregate
      const aggregateIndex = this.aggregatedMinutes.findIndex(m => m.timestamp === tremorMinute);
      
      if (aggregateIndex !== -1) {
        const existingTremor = this.aggregatedMinutes[aggregateIndex].tremorData;
        const hasValidTremorInAggregate = existingTremor !== null &&
                                          existingTremor.status === ActivityStatus.SEDENTARY &&
                                          existingTremor.frequency >= 3.0 &&
                                          existingTremor.magnitude > 0;
        
        // Only update if no data yet, or this is valid tremor, or existing is not valid
        if (existingTremor === null || isValidTremor || !hasValidTremorInAggregate) {
          this.aggregatedMinutes[aggregateIndex].tremorData = tremor;
          hilog.info(DOMAIN, TAG, 
            `Tremor added to past minute ${new Date(tremorMinute).toISOString()}: magnitude=${tremor.magnitude.toFixed(1)}, frequency=${tremor.frequency.toFixed(1)}Hz`);
        }
      } else {
        hilog.warn(DOMAIN, TAG, 
          `Tremor timestamp ${new Date(tremorMinute).toISOString()} doesn't match any aggregated minute, ignoring`);
      }
    }
  }

  /**
   * Add heart rate reading
   */
  public addReading(heartRate: HeartRateData): void {
    const currentMinute = this.getMinuteTimestamp(heartRate.timestamp);
    
    // Check if we've moved to a new minute
    if (currentMinute !== this.currentMinuteStart) {
      // Aggregate the previous minute's data ONLY if we have data and haven't aggregated it yet
      if (this.currentMinuteData.length > 0 && 
          this.currentMinuteStart > 0 && 
          !this.aggregatedTimestamps.has(this.currentMinuteStart)) {
        this.aggregateCurrentMinute();
        this.aggregatedTimestamps.add(this.currentMinuteStart);
        this.lastAggregationTime = Date.now();
        hilog.info(DOMAIN, TAG, `Aggregated minute ${new Date(this.currentMinuteStart).toISOString()} via addReading`);
      }
      
      // Start new minute
      this.currentMinuteStart = currentMinute;
      this.currentMinuteData = [];
      this.currentMinuteTremor = null; // Reset tremor data for new minute
    }
    
    // Add reading to current minute
    this.currentMinuteData.push(heartRate);
  }

  /**
   * Manually trigger aggregation (called every minute by MonitoringService)
   * This is a backup mechanism in case addReading doesn't catch the minute change
   */
  public triggerAggregation(): void {
    const now = Date.now();
    const timeSinceLastAggregation = now - this.lastAggregationTime;
    
    // Only aggregate if at least 1 minute has passed, we have data, and haven't aggregated this minute yet
    if (timeSinceLastAggregation >= AppConfig.HEART_RATE_AGGREGATE_INTERVAL_MS && 
        this.currentMinuteData.length > 0 &&
        !this.aggregatedTimestamps.has(this.currentMinuteStart)) {
      this.aggregateCurrentMinute();
      this.aggregatedTimestamps.add(this.currentMinuteStart);
      this.currentMinuteStart = this.getMinuteTimestamp(now);
      this.currentMinuteData = [];
      this.currentMinuteTremor = null; // Reset tremor data
      this.lastAggregationTime = now;
      
      hilog.info(DOMAIN, TAG, `Triggered aggregation. Total minutes: ${this.aggregatedMinutes.length}`);
    }
  }

  /**
   * Aggregate current minute's data (heart rate + tremor)
   */
  private aggregateCurrentMinute(): void {
    if (this.currentMinuteData.length === 0) {
      return;
    }

    const bpmValues = this.currentMinuteData.map(d => d.bpm);
    const avgBpm = bpmValues.reduce((sum, bpm) => sum + bpm, 0) / bpmValues.length;
    const minBpm = Math.min(...bpmValues);
    const maxBpm = Math.max(...bpmValues);

    const aggregate: HeartRateMinuteAggregate = {
      timestamp: this.currentMinuteStart,
      avgBpm: Math.round(avgBpm * 10) / 10, // Round to 1 decimal
      minBpm: minBpm,
      maxBpm: maxBpm,
      tremorData: this.currentMinuteTremor // Include tremor/activity data
    };

    // Add to aggregated minutes
    this.aggregatedMinutes.push(aggregate);

    // Keep only last 5 minutes
    if (this.aggregatedMinutes.length > HeartRateLogger.MAX_MINUTES) {
      this.aggregatedMinutes.shift();
    }

    hilog.debug(DOMAIN, TAG, 
      `Minute aggregated: avg=${aggregate.avgBpm}, min=${minBpm}, max=${maxBpm}`);
  }

  /**
   * Get heart rate report (5 minutes of data)
   * Returns current aggregated data WITHOUT modifying state
   */
  public getReport(): HeartRateReport {
    return {
      userId: this.userId,
      deviceId: this.deviceId,
      reportTimestamp: Date.now(),
      minutes: [...this.aggregatedMinutes] // Copy array without modifying state
    };
  }

  /**
   * Check if we have enough data to send (at least 1 minute)
   */
  public hasData(): boolean {
    return this.aggregatedMinutes.length > 0;
  }

  /**
   * Clear aggregated data (called after successful upload)
   */
  public clearData(): void {
    // Clear the timestamps that have been uploaded
    this.aggregatedMinutes.forEach(minute => {
      this.aggregatedTimestamps.delete(minute.timestamp);
    });
    
    this.aggregatedMinutes = [];
    // Don't clear current minute data - it's still being collected
    hilog.info(DOMAIN, TAG, 'Heart rate aggregated data cleared (keeping current minute)');
  }

  /**
   * Get timestamp for the start of the minute
   */
  private getMinuteTimestamp(timestamp: number): number {
    return Math.floor(timestamp / 60000) * 60000; // Round down to minute
  }

  /**
   * Get current stats for UI display
   */
  public getStats(): HeartRateStats {
    const latestMinute = this.aggregatedMinutes[this.aggregatedMinutes.length - 1];
    return {
      minutesLogged: this.aggregatedMinutes.length,
      latestAvgBpm: latestMinute ? latestMinute.avgBpm : 0
    };
  }
}
