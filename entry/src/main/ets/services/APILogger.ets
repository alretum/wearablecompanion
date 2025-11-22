/**
 * APILogger - Logs all API calls with payloads to a local JSON file
 * Useful for debugging and tracking data uploads
 */

import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

const DOMAIN = 0x0008;
const TAG = 'APILogger';

export interface APILogEntry {
  timestamp: number;
  timestampISO: string;
  endpoint: string;
  method: string;
  payload: Object;
  responseCode?: number;
  responseBody?: string;
  success: boolean;
  errorMessage?: string;
}

export interface APILogFile {
  logStartTime: number;
  logStartTimeISO: string;
  deviceId: string;
  userId: string;
  totalRequests: number;
  successfulRequests: number;
  failedRequests: number;
  logs: APILogEntry[];
}

export interface APILogStats {
  total: number;
  successful: number;
  failed: number;
}

export class APILogger {
  private static readonly LOG_FILENAME = 'api_calls.json';
  private static readonly MAX_LOG_ENTRIES = 1000; // Keep last 1000 API calls
  private logFilePath: string = '';
  private logData: APILogFile | null = null;
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext, userId: string, deviceId: string) {
    this.context = context;
    this.logFilePath = `${context.filesDir}/${APILogger.LOG_FILENAME}`;
    hilog.info(DOMAIN, TAG, `API log file path: ${this.logFilePath}`);
    
    // Load existing log or create new one
    this.loadLog();
    
    if (!this.logData) {
      this.logData = {
        logStartTime: Date.now(),
        logStartTimeISO: new Date().toISOString(),
        deviceId: deviceId,
        userId: userId,
        totalRequests: 0,
        successfulRequests: 0,
        failedRequests: 0,
        logs: []
      };
      this.saveLog();
    }
  }

  /**
   * Log an API call with its payload
   */
  public logAPICall(
    endpoint: string,
    method: string,
    payload: Object,
    success: boolean,
    responseCode?: number,
    responseBody?: string,
    errorMessage?: string
  ): void {
    if (!this.logData) {
      hilog.error(DOMAIN, TAG, 'Log data not initialized');
      return;
    }

    const now = Date.now();
    const entry: APILogEntry = {
      timestamp: now,
      timestampISO: new Date(now).toISOString(),
      endpoint: endpoint,
      method: method,
      payload: payload,
      responseCode: responseCode,
      responseBody: responseBody,
      success: success,
      errorMessage: errorMessage
    };

    // Add entry to log
    this.logData.logs.push(entry);
    this.logData.totalRequests++;
    
    if (success) {
      this.logData.successfulRequests++;
    } else {
      this.logData.failedRequests++;
    }

    // Trim old entries if exceeding max
    if (this.logData.logs.length > APILogger.MAX_LOG_ENTRIES) {
      this.logData.logs.shift();
    }

    // Save to file
    this.saveLog();
    
    hilog.info(DOMAIN, TAG, 
      `API call logged: ${method} ${endpoint} - ${success ? 'SUCCESS' : 'FAILED'} (${responseCode || 'N/A'})`);
  }

  /**
   * Load existing log from file
   */
  private loadLog(): void {
    try {
      if (!fileIo.accessSync(this.logFilePath)) {
        hilog.info(DOMAIN, TAG, 'No existing API log file found, will create new one');
        return;
      }

      const file = fileIo.openSync(this.logFilePath, fileIo.OpenMode.READ_ONLY);
      const content = new ArrayBuffer(1024 * 1024); // 1MB buffer
      const readLen = fileIo.readSync(file.fd, content);
      fileIo.closeSync(file);

      if (readLen > 0) {
        const textDecoder = new util.TextDecoder('utf-8', { ignoreBOM: true });
        const jsonContent = textDecoder.decodeWithStream(new Uint8Array(content.slice(0, readLen)));
        this.logData = JSON.parse(jsonContent) as APILogFile;
        hilog.info(DOMAIN, TAG, `Loaded existing API log with ${this.logData.logs.length} entries`);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to load API log: ${error}`);
      this.logData = null;
    }
  }

  /**
   * Save log to JSON file
   */
  private saveLog(): void {
    if (!this.logData) {
      return;
    }

    try {
      // Convert to JSON
      const jsonContent = JSON.stringify(this.logData, null, 2);

      // Write to file
      const file = fileIo.openSync(this.logFilePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, jsonContent);
      fileIo.closeSync(file);

      hilog.debug(DOMAIN, TAG, `API log saved: ${this.logData.logs.length} entries`);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to save API log: ${error}`);
    }
  }

  /**
   * Get log statistics
   */
  public getStats(): APILogStats {
    if (!this.logData) {
      const emptyStats: APILogStats = { total: 0, successful: 0, failed: 0 };
      return emptyStats;
    }

    const stats: APILogStats = {
      total: this.logData.totalRequests,
      successful: this.logData.successfulRequests,
      failed: this.logData.failedRequests
    };
    return stats;
  }

  /**
   * Get the log file path for external access
   */
  public getLogFilePath(): string {
    return this.logFilePath;
  }

  /**
   * Clear all logged API calls
   */
  public clearLog(): void {
    if (!this.logData) {
      return;
    }

    this.logData.logs = [];
    this.logData.totalRequests = 0;
    this.logData.successfulRequests = 0;
    this.logData.failedRequests = 0;
    this.saveLog();
    
    hilog.info(DOMAIN, TAG, 'API log cleared');
  }

  /**
   * Export log as JSON string
   */
  public exportLog(): string {
    if (!this.logData) {
      return '{}';
    }

    return JSON.stringify(this.logData, null, 2);
  }
}
