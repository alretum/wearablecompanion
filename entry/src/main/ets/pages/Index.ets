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
    Scroll() {
      Column() {
        // Header with gradient background
        Column() {
          Text('Parkinson\'s')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text('Monitor')
            .fontSize(28)
            .fontWeight(900)
            .fontColor(Color.White)
            .margin({ top: -4 })
        }
        .width('100%')
        .padding({ top: 16, bottom: 20, left: 16, right: 16 })
        .linearGradient({
          angle: 135,
          colors: [[0x667EEA, 0.0], [0x764BA2, 1.0]]
        })
        .borderRadius({ bottomLeft: 24, bottomRight: 24 })

        Column() {
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
        .padding(16)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
    .scrollBar(BarState.Off)
  }

  @Builder
  StatusCard() {
    Row() {
      Column() {
        Text('Status')
          .fontSize(12)
          .fontColor('#8E8E93')
          .margin({ bottom: 4 })

        Text(this.getStatusText())
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getStatusColor())

        if (this.appState.errorMessage) {
          Text(this.appState.errorMessage)
            .fontSize(11)
            .fontColor('#FF3B30')
            .margin({ top: 6 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // Status indicator circle
      Circle({ width: 12, height: 12 })
        .fill(this.getStatusColor())
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 8, color: 0x10000000, offsetX: 0, offsetY: 2 })
    .margin({ bottom: 16 })
  }

  @Builder
  SensorDataCard() {
    Column() {
      Text('Live Sensor Data')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1C1C1E')
        .margin({ bottom: 16 })

      // Accelerometer
      Column() {
        Row() {
          Text('📐')
            .fontSize(16)
            .margin({ right: 8 })
          Text('Accelerometer')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3C3C43')
        }
        .margin({ bottom: 6 })
        
        Text(this.formatAccelData())
          .fontSize(12)
          .fontColor('#8E8E93')
          .fontFamily('monospace')
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F2F2F7')
      .borderRadius(10)
      .margin({ bottom: 10 })

      // Gyroscope
      Column() {
        Row() {
          Text('🔄')
            .fontSize(16)
            .margin({ right: 8 })
          Text('Gyroscope')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3C3C43')
        }
        .margin({ bottom: 6 })
        
        Text(this.formatGyroData())
          .fontSize(12)
          .fontColor('#8E8E93')
          .fontFamily('monospace')
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F2F2F7')
      .borderRadius(10)
      .margin({ bottom: 10 })

      // Heart Rate
      Column() {
        Row() {
          Text('❤️')
            .fontSize(16)
            .margin({ right: 8 })
          Text('Heart Rate')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3C3C43')
        }
        .margin({ bottom: 6 })
        
        Text(this.formatHeartRateData())
          .fontSize(12)
          .fontColor('#8E8E93')
          .fontFamily('monospace')
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F2F2F7')
      .borderRadius(10)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 8, color: 0x10000000, offsetX: 0, offsetY: 2 })
    .margin({ bottom: 16 })
  }

  @Builder
  AlertCard() {
    Column() {
      Text('⚠️ Active Alerts')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1C1C1E')
        .margin({ bottom: 16 })

      // Freeze Prediction
      if (this.appState.latestPrediction !== null) {
        Column() {
          Row() {
            Text('⚠️')
              .fontSize(24)
              .margin({ right: 12 })
            
            Column() {
              Text('Freeze Predicted')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FF9500')
                .margin({ bottom: 4 })
              
              Text(`${(this.appState.latestPrediction.probability * 100).toFixed(0)}% probability`)
                .fontSize(13)
                .fontColor('#3C3C43')
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .margin({ bottom: 12 })

          Row() {
            Text(`Confidence: ${(this.appState.latestPrediction.confidence * 100).toFixed(0)}%`)
              .fontSize(11)
              .fontColor('#8E8E93')
          }
          .margin({ bottom: 10 })

          Row() {
            if (this.appState.latestPrediction.indicators.tremor) {
              Text('Tremor')
                .fontSize(10)
                .fontColor(Color.White)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#FF3B30')
                .borderRadius(12)
                .margin({ right: 6 })
            }
            if (this.appState.latestPrediction.indicators.gaitDisturbance) {
              Text('Gait Issue')
                .fontSize(10)
                .fontColor(Color.White)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#FF9500')
                .borderRadius(12)
                .margin({ right: 6 })
            }
            if (this.appState.latestPrediction.indicators.stressSpike) {
              Text('Stress')
                .fontSize(10)
                .fontColor(Color.White)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#FF2D55')
                .borderRadius(12)
            }
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFF3E0')
        .borderRadius(12)
        .border({ width: 2, color: '#FF9500' })
        .margin({ bottom: 12 })
      }

      // Latest Tremor
      if (this.appState.latestTremor !== null) {
        Row() {
          Text('🔴')
            .fontSize(20)
            .margin({ right: 12 })
          
          Column() {
            Text('Tremor Detected')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FF3B30')
              .margin({ bottom: 4 })
            
            Row() {
              Text(`Severity ${this.appState.latestTremor.severity.toFixed(1)}/10`)
                .fontSize(12)
                .fontColor('#3C3C43')
                .margin({ right: 12 })
              
              Text(`${this.appState.latestTremor.duration}ms`)
                .fontSize(12)
                .fontColor('#8E8E93')
            }
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFE5E5')
        .borderRadius(12)
        .border({ width: 2, color: '#FF3B30' })
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 12, color: 0x20000000, offsetX: 0, offsetY: 4 })
    .margin({ bottom: 16 })
  }

  @Builder
  StatisticsCard() {
    Column() {
      Text('Session Statistics')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1C1C1E')
        .margin({ bottom: 16 })

      Row() {
        Column() {
          Text(`${this.appState.totalTremorsDetected}`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#34C759')
          Text('Tremors')
            .fontSize(11)
            .fontColor('#8E8E93')
            .margin({ top: 4 })
        }
        .width('50%')
        .padding(16)
        .backgroundColor('#F2F2F7')
        .borderRadius(12)

        Column() {
          Text(`${this.appState.totalFreezesDetected}`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF9500')
          Text('Freezes')
            .fontSize(11)
            .fontColor('#8E8E93')
            .margin({ top: 4 })
        }
        .width('50%')
        .padding(16)
        .backgroundColor('#F2F2F7')
        .borderRadius(12)
        .margin({ left: 8 })
      }
      .width('100%')

      if (this.appState.monitoringStartTime > 0) {
        Row() {
          Text('⏱️')
            .fontSize(14)
            .margin({ right: 6 })
          Text(this.formatSessionDuration())
            .fontSize(12)
            .fontColor('#8E8E93')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 16 })
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 8, color: 0x10000000, offsetX: 0, offsetY: 2 })
    .margin({ bottom: 16 })
  }

  @Builder
  ReportInfoCard() {
    Column() {
      Row() {
        Text('📄')
          .fontSize(16)
          .margin({ right: 8 })
        Text('Report File')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C1C1E')
      }
      .margin({ bottom: 12 })

      this.ReportInfoContent()
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFBEA')
    .borderRadius(12)
    .border({ width: 1, color: '#FFE082' })
    .margin({ bottom: 16 })
  }

  @Builder
  ReportInfoContent() {
    if (this.monitoringService.getReportLogger()) {
      if (this.monitoringService.getReportLogger()!.getReport()) {
        Column() {
          Text(`Session: ${this.monitoringService.getReportLogger()!.getReport()!.sessionId}`)
            .fontSize(10)
            .fontColor('#8E8E93')
            .margin({ bottom: 6 })
          
          Text(`${this.monitoringService.getReportLogger()!.getReport()!.tremors.length} tremors, ${this.monitoringService.getReportLogger()!.getReport()!.freezePredictions.length} predictions logged`)
            .fontSize(12)
            .fontColor('#3C3C43')
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 6 })
          
          Text(`Size: ${(this.monitoringService.getReportLogger()!.getReportSize() / 1024).toFixed(2)} KB`)
            .fontSize(10)
            .fontColor('#8E8E93')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      } else {
        Text('No active report')
          .fontSize(12)
          .fontColor('#8E8E93')
      }
    } else {
      Text('Report logger not initialized')
        .fontSize(12)
        .fontColor('#8E8E93')
    }
  }

  @Builder
  ControlButtons() {
    Column() {
      if (this.appState.status === MonitoringStatus.STOPPED || 
          this.appState.status === MonitoringStatus.ERROR) {
        Button('Start Monitoring')
          .width('100%')
          .height(52)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#34C759')
          .borderRadius(14)
          .shadow({ radius: 8, color: 0x2034C759, offsetX: 0, offsetY: 4 })
          .onClick(() => {
            this.monitoringService.startMonitoring();
          })
      } else {
        Button('Stop Monitoring')
          .width('100%')
          .height(52)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#FF3B30')
          .borderRadius(14)
          .shadow({ radius: 8, color: 0x20FF3B30, offsetX: 0, offsetY: 4 })
          .onClick(() => {
            this.monitoringService.stopMonitoring();
          })
      }

      Button('Test API Connection')
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .backgroundColor('#007AFF')
        .borderRadius(14)
        .margin({ top: 12 })
        .onClick(() => {
          this.testAPI();
        })
    }
    .width('100%')
    .margin({ bottom: 20 })
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