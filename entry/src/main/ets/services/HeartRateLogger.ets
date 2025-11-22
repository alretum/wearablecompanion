/**
 * HeartRateLogger - Aggregates heart rate data per minute
 * Maintains 5 minutes of data (5 entries, 1 per minute)
 * This data is sent separately to AWS heart rate endpoint
 */

import { HeartRateData } from '../sensors/SensorData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConfig } from '../config/AppConfig';

const DOMAIN = 0x0007;
const TAG = 'HeartRateLogger';

export interface HeartRateMinuteAggregate {
  timestamp: number; // Start of the minute
  avgBpm: number;
  minBpm: number;
  maxBpm: number;
  sampleCount: number;
}

export interface HeartRateReport {
  userId: string;
  deviceId: string;
  reportTimestamp: number;
  minutes: HeartRateMinuteAggregate[]; // 5 entries, one per minute
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
  private currentMinuteStart: number = 0;
  private aggregatedMinutes: HeartRateMinuteAggregate[] = [];
  private lastAggregationTime: number = 0;

  constructor(userId: string, deviceId: string) {
    this.userId = userId;
    this.deviceId = deviceId;
    this.currentMinuteStart = this.getMinuteTimestamp(Date.now());
    this.lastAggregationTime = Date.now();
    hilog.info(DOMAIN, TAG, 'HeartRateLogger initialized');
  }

  /**
   * Add heart rate reading
   */
  public addReading(heartRate: HeartRateData): void {
    const currentMinute = this.getMinuteTimestamp(heartRate.timestamp);
    
    // Check if we've moved to a new minute
    if (currentMinute !== this.currentMinuteStart) {
      // Aggregate the previous minute's data
      if (this.currentMinuteData.length > 0) {
        this.aggregateCurrentMinute();
      }
      
      // Start new minute
      this.currentMinuteStart = currentMinute;
      this.currentMinuteData = [];
    }
    
    // Add reading to current minute
    this.currentMinuteData.push(heartRate);
  }

  /**
   * Manually trigger aggregation (called every minute by MonitoringService)
   */
  public triggerAggregation(): void {
    const now = Date.now();
    const timeSinceLastAggregation = now - this.lastAggregationTime;
    
    // Only aggregate if at least 1 minute has passed and we have data
    if (timeSinceLastAggregation >= AppConfig.HEART_RATE_AGGREGATE_INTERVAL_MS && 
        this.currentMinuteData.length > 0) {
      this.aggregateCurrentMinute();
      this.currentMinuteStart = this.getMinuteTimestamp(now);
      this.currentMinuteData = [];
      this.lastAggregationTime = now;
      
      hilog.info(DOMAIN, TAG, `Aggregated heart rate data. Total minutes: ${this.aggregatedMinutes.length}`);
    }
  }

  /**
   * Aggregate current minute's data
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
      sampleCount: this.currentMinuteData.length
    };

    // Add to aggregated minutes
    this.aggregatedMinutes.push(aggregate);

    // Keep only last 5 minutes
    if (this.aggregatedMinutes.length > HeartRateLogger.MAX_MINUTES) {
      this.aggregatedMinutes.shift();
    }

    hilog.debug(DOMAIN, TAG, 
      `Minute aggregated: avg=${aggregate.avgBpm}, min=${minBpm}, max=${maxBpm}, samples=${aggregate.sampleCount}`);
  }

  /**
   * Get heart rate report (5 minutes of data)
   */
  public getReport(): HeartRateReport {
    // Force aggregate current minute if we have data
    if (this.currentMinuteData.length > 0) {
      this.aggregateCurrentMinute();
      this.currentMinuteData = [];
      this.currentMinuteStart = this.getMinuteTimestamp(Date.now());
    }

    return {
      userId: this.userId,
      deviceId: this.deviceId,
      reportTimestamp: Date.now(),
      minutes: [...this.aggregatedMinutes] // Copy array
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
    this.aggregatedMinutes = [];
    this.currentMinuteData = [];
    this.currentMinuteStart = this.getMinuteTimestamp(Date.now());
    hilog.info(DOMAIN, TAG, 'Heart rate data cleared');
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
