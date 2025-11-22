import { MonitoringService } from '../services/MonitoringService';
import { AppState, MonitoringStatus } from '../sensors/SensorData';

@Entry
@Component
struct Index {
  @State appState: AppState = new AppState();
  private monitoringService: MonitoringService = MonitoringService.getInstance();

  aboutToAppear(): void {
    // Register for state updates
    this.monitoringService.onStateChange((state: AppState) => {
      this.appState = state;
    });
    
    // Get initial state
    this.appState = this.monitoringService.getState();
  }

  build() {
    Column() {
      // Header
      Text('Parkinson\'s Monitor')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 20 })

      // Status Display
      this.StatusCard()

      // Sensor Data Display
      this.SensorDataCard()

      // Alert Display
      if (this.appState.latestPrediction !== null || this.appState.latestTremor !== null) {
        this.AlertCard()
      }

      // Statistics
      this.StatisticsCard()

      // Report Info
      this.ReportInfoCard()

      // Control Buttons
      this.ControlButtons()
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#F5F5F5')
  }

  @Builder
  StatusCard() {
    Column() {
      Text('Status')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 8 })

      Text(this.getStatusText())
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getStatusColor())
        .margin({ bottom: 8 })

      if (this.appState.errorMessage) {
        Text(this.appState.errorMessage)
          .fontSize(12)
          .fontColor(Color.Red)
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ bottom: 12 })
  }

  @Builder
  SensorDataCard() {
    Column() {
      Text('Sensor Data')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      // Accelerometer
      Row() {
        Text('Accel:')
          .fontSize(12)
          .width('30%')
        Text(this.formatAccelData())
          .fontSize(12)
          .fontFamily('monospace')
      }
      .width('100%')
      .margin({ bottom: 4 })

      // Gyroscope
      Row() {
        Text('Gyro:')
          .fontSize(12)
          .width('30%')
        Text(this.formatGyroData())
          .fontSize(12)
          .fontFamily('monospace')
      }
      .width('100%')
      .margin({ bottom: 4 })

      // Heart Rate
      Row() {
        Text('Heart:')
          .fontSize(12)
          .width('30%')
        Text(this.formatHeartRateData())
          .fontSize(12)
          .fontFamily('monospace')
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ bottom: 12 })
  }

  @Builder
  AlertCard() {
    Column() {
      Text('Recent Alerts')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      // Freeze Prediction
      if (this.appState.latestPrediction !== null) {
        Column() {
          Text('⚠️ Freeze Predicted')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.Orange)
            .margin({ bottom: 4 })
          
          Text(`Probability: ${(this.appState.latestPrediction.probability * 100).toFixed(0)}%`)
            .fontSize(12)
            .margin({ bottom: 2 })
          
          Text(`Confidence: ${(this.appState.latestPrediction.confidence * 100).toFixed(0)}%`)
            .fontSize(12)
            .margin({ bottom: 2 })

          Row() {
            if (this.appState.latestPrediction.indicators.tremor) {
              Text('🔴 Tremor')
                .fontSize(10)
                .margin({ right: 8 })
            }
            if (this.appState.latestPrediction.indicators.gaitDisturbance) {
              Text('🔴 Gait')
                .fontSize(10)
                .margin({ right: 8 })
            }
            if (this.appState.latestPrediction.indicators.stressSpike) {
              Text('🔴 Stress')
                .fontSize(10)
            }
          }
          .margin({ top: 4 })
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#FFF3E0')
        .borderRadius(8)
        .margin({ bottom: 8 })
      }

      // Latest Tremor
      if (this.appState.latestTremor !== null) {
        Column() {
          Text('Tremor Detected')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF6B6B')
            .margin({ bottom: 4 })
          
          Text(`Severity: ${this.appState.latestTremor.severity.toFixed(1)}/10`)
            .fontSize(12)
            .margin({ bottom: 2 })
          
          Text(`Duration: ${this.appState.latestTremor.duration}ms`)
            .fontSize(12)
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#FFE5E5')
        .borderRadius(8)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ bottom: 12 })
  }

  @Builder
  StatisticsCard() {
    Column() {
      Text('Session Statistics')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      Row() {
        Column() {
          Text(`${this.appState.totalTremorsDetected}`)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4CAF50')
          Text('Tremors')
            .fontSize(12)
            .margin({ top: 4 })
        }
        .width('50%')

        Column() {
          Text(`${this.appState.totalFreezesDetected}`)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF9800')
          Text('Freezes')
            .fontSize(12)
            .margin({ top: 4 })
        }
        .width('50%')
      }
      .width('100%')

      if (this.appState.monitoringStartTime > 0) {
        Text(this.formatSessionDuration())
          .fontSize(12)
          .fontColor('#666')
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ bottom: 12 })
  }

  @Builder
  ReportInfoCard() {
    Column() {
      Text('Report File')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 8 })

      this.ReportInfoContent()
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFF9C4')
    .borderRadius(8)
    .margin({ bottom: 12 })
  }

  @Builder
  ReportInfoContent() {
    const reportLogger = this.monitoringService.getReportLogger();
    if (reportLogger) {
      const report = reportLogger.getReport();
      if (report) {
        Column() {
          Text(`Session: ${report.sessionId}`)
            .fontSize(10)
            .fontColor('#666')
            .margin({ bottom: 4 })
          
          Text(`Logged: ${report.tremors.length} tremors, ${report.freezePredictions.length} predictions`)
            .fontSize(11)
            .fontColor('#333')
            .margin({ bottom: 4 })
          
          Text(`File size: ${(reportLogger.getReportSize() / 1024).toFixed(2)} KB`)
            .fontSize(10)
            .fontColor('#666')
        }
        .alignItems(HorizontalAlign.Start)
      } else {
        Text('No active report')
          .fontSize(11)
          .fontColor('#999')
      }
    } else {
      Text('Report logger not initialized')
        .fontSize(11)
        .fontColor('#999')
    }
  }

  @Builder
  ControlButtons() {
    Column() {
      if (this.appState.status === MonitoringStatus.STOPPED || 
          this.appState.status === MonitoringStatus.ERROR) {
        Button('Start Monitoring')
          .width('100%')
          .height(48)
          .fontSize(16)
          .backgroundColor('#4CAF50')
          .onClick(() => {
            this.monitoringService.startMonitoring();
          })
      } else {
        Button('Stop Monitoring')
          .width('100%')
          .height(48)
          .fontSize(16)
          .backgroundColor('#F44336')
          .onClick(() => {
            this.monitoringService.stopMonitoring();
          })
      }

      Button('Test API Connection')
        .width('100%')
        .height(40)
        .fontSize(14)
        .backgroundColor('#2196F3')
        .margin({ top: 8 })
        .onClick(() => {
          this.testAPI();
        })
    }
    .width('100%')
    .margin({ top: 12 })
  }

  // Helper methods
  private getStatusText(): string {
    switch (this.appState.status) {
      case MonitoringStatus.STOPPED:
        return 'Stopped';
      case MonitoringStatus.MONITORING:
        return 'Monitoring...';
      case MonitoringStatus.ALERT:
        return 'ALERT: Freeze Predicted!';
      case MonitoringStatus.ERROR:
        return 'Error';
      default:
        return 'Unknown';
    }
  }

  private getStatusColor(): ResourceColor {
    switch (this.appState.status) {
      case MonitoringStatus.STOPPED:
        return '#999';
      case MonitoringStatus.MONITORING:
        return '#4CAF50';
      case MonitoringStatus.ALERT:
        return '#FF9800';
      case MonitoringStatus.ERROR:
        return '#F44336';
      default:
        return '#999';
    }
  }

  private formatAccelData(): string {
    if (this.appState.currentAccel === null) {
      return 'No data';
    }
    const a = this.appState.currentAccel;
    return `x:${a.x.toFixed(2)} y:${a.y.toFixed(2)} z:${a.z.toFixed(2)}`;
  }

  private formatGyroData(): string {
    if (this.appState.currentGyro === null) {
      return 'No data';
    }
    const g = this.appState.currentGyro;
    return `x:${g.x.toFixed(2)} y:${g.y.toFixed(2)} z:${g.z.toFixed(2)}`;
  }

  private formatHeartRateData(): string {
    if (this.appState.currentHeartRate === null) {
      return 'No data';
    }
    return `${this.appState.currentHeartRate.bpm} BPM`;
  }

  private formatSessionDuration(): string {
    if (this.appState.monitoringStartTime === 0) {
      return '';
    }
    const duration = Date.now() - this.appState.monitoringStartTime;
    const seconds = Math.floor(duration / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    
    if (hours > 0) {
      return `Session: ${hours}h ${minutes % 60}m`;
    } else if (minutes > 0) {
      return `Session: ${minutes}m ${seconds % 60}s`;
    } else {
      return `Session: ${seconds}s`;
    }
  }

  private async testAPI(): Promise<void> {
    const results = await this.monitoringService.testAPIConnectivity();
    // TODO: Display results in a dialog
    console.log('API Test Results:', results);
  }
}