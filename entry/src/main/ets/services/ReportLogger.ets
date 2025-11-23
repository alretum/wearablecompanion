/**
 * ReportLogger - Logs freeze incidents to a local JSON file
 * This file is then uploaded to AWS for doctor review and analysis
 */

import { fileIo } from '@kit.CoreFileKit';
import { FreezePrediction } from '../sensors/SensorData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0006;
const TAG = 'ReportLogger';

export interface SessionReport {
  sessionId: string;
  userId: string;
  deviceId: string;
  sessionStart: number;
  sessionEnd: number;
  totalFreezes: number;
  freezePredictions: FreezePrediction[];
  lastUpdated: number;
}

export class ReportLogger {
  private static readonly REPORT_FILENAME = 'report.json';
  private reportFilePath: string = '';
  private currentReport: SessionReport | null = null;
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext, userId: string, deviceId: string) {
    this.context = context;
    this.reportFilePath = `${context.filesDir}/${ReportLogger.REPORT_FILENAME}`;
    hilog.info(DOMAIN, TAG, `Report file path: ${this.reportFilePath}`);
    
    // Initialize new session
    this.currentReport = {
      sessionId: `SESSION_${Date.now()}`,
      userId: userId,
      deviceId: deviceId,
      sessionStart: Date.now(),
      sessionEnd: 0,
      totalFreezes: 0,
      freezePredictions: [],
      lastUpdated: Date.now()
    };
    
    this.saveReport();
  }

  /**
   * Log a freeze prediction to the report file
   */
  public logFreezePrediction(prediction: FreezePrediction): void {
    if (!this.currentReport) {
      hilog.error(DOMAIN, TAG, 'No active report session');
      return;
    }

    // Add prediction to report
    this.currentReport.freezePredictions.push(prediction);
    this.currentReport.totalFreezes++;
    this.currentReport.lastUpdated = Date.now();

    // Save to file
    this.saveReport();
    
    hilog.info(DOMAIN, TAG, `Freeze logged: probability=${prediction.probability.toFixed(2)}, total=${this.currentReport.totalFreezes}`);
  }

  /**
   * Save report to JSON file
   */
  private saveReport(): void {
    if (!this.currentReport) {
      return;
    }

    try {
      // Update session end time
      this.currentReport.sessionEnd = Date.now();

      // Convert to JSON
      const jsonContent = JSON.stringify(this.currentReport, null, 2);

      // Write to file
      const file = fileIo.openSync(this.reportFilePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, jsonContent);
      fileIo.closeSync(file);

      hilog.debug(DOMAIN, TAG, `Report saved: ${this.currentReport.freezePredictions.length} predictions`);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to save report: ${error}`);
    }
  }

  /**
   * Get the current report data
   */
  public getReport(): SessionReport | null {
    return this.currentReport;
  }

  /**
   * Read report from JSON file
   */
  public readReport(): SessionReport | null {
    try {
      // Check if file exists
      if (!fileIo.accessSync(this.reportFilePath)) {
        hilog.warn(DOMAIN, TAG, 'Report file does not exist');
        return null;
      }

      // Read file
      const file = fileIo.openSync(this.reportFilePath, fileIo.OpenMode.READ_ONLY);
      const content = new ArrayBuffer(1024 * 1024); // 1MB buffer
      const readLen = fileIo.readSync(file.fd, content);
      fileIo.closeSync(file);

      // Parse JSON
      const jsonString = String.fromCharCode(...new Uint8Array(content.slice(0, readLen)));
      const report = JSON.parse(jsonString) as SessionReport;

      hilog.info(DOMAIN, TAG, `Report loaded: ${report.freezePredictions.length} predictions`);
      return report;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to read report: ${error}`);
      return null;
    }
  }

  /**
   * Get the report file path (for uploading to AWS)
   */
  public getReportFilePath(): string {
    return this.reportFilePath;
  }

  /**
   * Get report as JSON string (for uploading to AWS)
   */
  public getReportJSON(): string {
    if (!this.currentReport) {
      return '{}';
    }
    return JSON.stringify(this.currentReport);
  }

  /**
   * Clear tremors and predictions after successful upload
   * Keeps session metadata
   */
  public clearUploadedData(): void {
    if (!this.currentReport) {
      return;
    }

    hilog.info(DOMAIN, TAG, `Clearing uploaded data: ${this.currentReport.freezePredictions.length} predictions`);

    // Keep counts but clear detailed data
    this.currentReport.freezePredictions = [];
    this.currentReport.lastUpdated = Date.now();

    this.saveReport();
  }

  /**
   * End current session and start a new one
   */
  public startNewSession(): void {
    if (this.currentReport) {
      this.currentReport.sessionEnd = Date.now();
      this.saveReport();
    }

    // Create new session
    this.currentReport = {
      sessionId: `SESSION_${Date.now()}`,
      userId: this.currentReport?.userId || 'UNKNOWN',
      deviceId: this.currentReport?.deviceId || 'UNKNOWN',
      sessionStart: Date.now(),
      sessionEnd: 0,
      totalFreezes: 0,
      freezePredictions: [],
      lastUpdated: Date.now()
    };

    this.saveReport();
    hilog.info(DOMAIN, TAG, `New session started: ${this.currentReport.sessionId}`);
  }

  /**
   * Delete report file
   */
  public deleteReport(): void {
    try {
      if (fileIo.accessSync(this.reportFilePath)) {
        fileIo.unlinkSync(this.reportFilePath);
        hilog.info(DOMAIN, TAG, 'Report file deleted');
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to delete report: ${error}`);
    }

    this.currentReport = null;
  }

  /**
   * Get report file size in bytes
   */
  public getReportSize(): number {
    try {
      if (fileIo.accessSync(this.reportFilePath)) {
        const stat = fileIo.statSync(this.reportFilePath);
        return stat.size;
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to get report size: ${error}`);
    }
    return 0;
  }
}
