import { MonitoringService } from '../services/MonitoringService';
import { AppState, MonitoringStatus } from '../sensors/SensorData';

@Entry
@Component
struct Index {
  @State appState: AppState = new AppState();
  @State medicationConfirmation: boolean = false;
  private monitoringService: MonitoringService = MonitoringService.getInstance();
  private uiUpdateTimer: number = -1;
  private confirmationTimer: number = -1;

  aboutToAppear(): void {
    // Register for state updates
    this.monitoringService.onStateChange((state: AppState) => {
      this.appState = state;
    });
    
    // Get initial state
    this.appState = this.monitoringService.getState();
    
    // Start periodic UI updates to refresh sensor data display
    this.uiUpdateTimer = setInterval(() => {
      this.appState = this.monitoringService.getState();
    }, 1000); // Update every second
  }
  
  aboutToDisappear(): void {
    // Clean up timers
    if (this.uiUpdateTimer !== -1) {
      clearInterval(this.uiUpdateTimer);
      this.uiUpdateTimer = -1;
    }
    if (this.confirmationTimer !== -1) {
      clearTimeout(this.confirmationTimer);
      this.confirmationTimer = -1;
    }
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
          colors: [[0x56AB2F, 0.0], [0xA8E063, 1.0]]
        })
        .borderRadius({ bottomLeft: 24, bottomRight: 24 })

        Column() {
          // Medication Button
          this.MedicationButton()

          // Medication Confirmation
          if (this.medicationConfirmation) {
            this.MedicationConfirmation()
          }

          // Status Display
          this.StatusCard()

          // FoG Detection Status
          if (this.monitoringService.isGuardianActive()) {
            this.FogStatusCard()
          }

          // Alert Display
          if (this.appState.latestPrediction !== null || this.appState.latestTremor !== null) {
            this.AlertCard()
          }

          // Statistics
          this.StatisticsCard()

          // Control Buttons
          this.ControlButtons()
        }
        .padding(16)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F8F4')
    .scrollBar(BarState.Off)
  }

  @Builder
  MedicationButton() {
    Button('💊 Medication Taken')
      .width('100%')
      .height(52)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor(Color.White)
      .backgroundColor('#2196F3')
      .borderRadius(16)
      .shadow({ radius: 12, color: 0x202196F3, offsetX: 0, offsetY: 4 })
      .margin({ top: 16, bottom: 12 })
      .onClick(async () => {
        const success = await this.recordMedication();
        if (success) {
          this.showMedicationConfirmation();
        }
      })
  }

  @Builder
  MedicationConfirmation() {
    Row() {
      Text('✓')
        .fontSize(24)
        .fontColor('#4CAF50')
        .margin({ right: 12 })
      
      Column() {
        Text('Medication Recorded')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C1C1E')
        Text(new Date().toLocaleTimeString())
          .fontSize(12)
          .fontColor('#8E8E93')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#E8F5E9')
    .borderRadius(16)
    .border({ width: 2, color: '#4CAF50' })
    .shadow({ radius: 8, color: 0x204CAF50, offsetX: 0, offsetY: 2 })
    .margin({ bottom: 16 })
    .animation({
      duration: 300,
      curve: Curve.EaseInOut
    })
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
  FogStatusCard() {
    Row() {
      Column() {
        Text('🛡️ Guardian Service')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C1C1E')
          .margin({ bottom: 4 })

        Text(this.monitoringService.isFogActive() ? 'FoG DETECTED - Intervention Active' : 'Monitoring...')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.monitoringService.isFogActive() ? '#FF3B30' : '#2E7D32')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // FoG indicator
      if (this.monitoringService.isFogActive()) {
        Column() {
          Text('🚨')
            .fontSize(32)
          Text('FREEZING')
            .fontSize(10)
            .fontColor('#FF3B30')
            .fontWeight(FontWeight.Bold)
        }
      } else {
        Circle({ width: 16, height: 16 })
          .fill('#2E7D32')
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(this.monitoringService.isFogActive() ? '#FFEBEE' : Color.White)
    .borderRadius(16)
    .border({ 
      width: this.monitoringService.isFogActive() ? 2 : 0, 
      color: '#FF3B30' 
    })
    .shadow({ 
      radius: this.monitoringService.isFogActive() ? 12 : 8, 
      color: this.monitoringService.isFogActive() ? 0x30FF3B30 : 0x10000000, 
      offsetX: 0, 
      offsetY: this.monitoringService.isFogActive() ? 4 : 2 
    })
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
          Text('📊')
            .fontSize(20)
            .margin({ right: 12 })
          
          Column() {
            Text('Activity Status')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FF9800')
              .margin({ bottom: 4 })
            
            Row() {
              Text(`${this.appState.latestTremor.status.toUpperCase()}`)
                .fontSize(12)
                .fontColor('#3C3C43')
                .margin({ right: 12 })
              
              Text(`${this.appState.latestTremor.magnitude.toFixed(2)} m/s²`)
                .fontSize(12)
                .fontColor('#8E8E93')
                .margin({ right: 12 })
              
              if (this.appState.latestTremor.frequency > 0) {
                Text(`${this.appState.latestTremor.frequency.toFixed(1)} Hz`)
                  .fontSize(12)
                  .fontColor('#8E8E93')
              }
            }
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFF3E0')
        .borderRadius(12)
        .border({ width: 2, color: '#FF9800' })
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
            .fontColor('#26A69A')
          Text('Tremors')
            .fontSize(11)
            .fontColor('#8E8E93')
            .margin({ top: 4 })
        }
        .width('50%')
        .padding(16)
        .backgroundColor('#E8F5E9')
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
        .backgroundColor('#E8F5E9')
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
  ControlButtons() {
    Column() {
      if (this.appState.status === MonitoringStatus.STOPPED || 
          this.appState.status === MonitoringStatus.ERROR) {
        Button('Start Monitoring')
          .width('100%')
          .height(56)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#2E7D32')
          .borderRadius(16)
          .shadow({ radius: 12, color: 0x202E7D32, offsetX: 0, offsetY: 4 })
          .onClick(() => {
            this.monitoringService.startMonitoring();
          })
      } else {
        Button('Stop Monitoring')
          .width('100%')
          .height(56)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#FF3B30')
          .borderRadius(16)
          .shadow({ radius: 12, color: 0x20FF3B30, offsetX: 0, offsetY: 4 })
          .onClick(() => {
            this.monitoringService.stopMonitoring();
          })
      }
    }
    .width('100%')
    .margin({ bottom: 20 })
  }

  // Helper methods
  private async recordMedication(): Promise<boolean> {
    return await this.monitoringService.recordMedicationIntake();
  }

  private showMedicationConfirmation(): void {
    this.medicationConfirmation = true;
    
    // Clear existing timer if any
    if (this.confirmationTimer !== -1) {
      clearTimeout(this.confirmationTimer);
    }
    
    // Hide confirmation after 3 seconds
    this.confirmationTimer = setTimeout(() => {
      this.medicationConfirmation = false;
      this.confirmationTimer = -1;
    }, 3000);
  }

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
        return '#2E7D32';
      case MonitoringStatus.ALERT:
        return '#FF9800';
      case MonitoringStatus.ERROR:
        return '#F44336';
      default:
        return '#999';
    }
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
}