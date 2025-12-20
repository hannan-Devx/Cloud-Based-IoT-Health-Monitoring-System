# Health Monitoring System

Flutter-based mobile application for real-time health vitals monitoring using ESP32 sensor and AWS cloud services.

## 🎯 Features

- Real-time heart rate monitoring
- Blood oxygen (SpO2) level tracking
- ESP32 WiFi configuration via mobile app
- AWS cloud integration for data storage
- Live data visualization
- GPS location tracking
- Patient health history

## 🛠 Technologies Used

### Frontend
- **Flutter** - Cross-platform mobile development
- **Dart** - Programming language

### Hardware
- **ESP32 Microcontroller** - IoT device
- **MAX30102 Sensor** - Heart rate & SpO2 measurement

### Cloud Services (AWS)
- **AWS IoT Core** - Device connectivity
- **DynamoDB** - Data storage
- **Lambda** - Serverless compute
- **API Gateway** - REST API endpoints

## 📱 App Screens

- Home Screen - Live vitals display
- WiFi Configuration - ESP32 setup
- History - Patient data history
- Map - GPS location tracking
- Login/Register - User authentication

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.x or higher)
- Android Studio / VS Code
- AWS Account
- ESP32 Development Board

### Installation

1. Clone the repository
```bash
git clone https://github.com/YOUR_USERNAME/health-monitoring-app.git
cd health-monitoring-app
```

2. Install dependencies
```bash
flutter pub get
```

3. Run the app
```bash
flutter run
```

## 📦 Dependencies

```yaml
dependencies:
  http: ^1.1.0
  permission_handler: ^11.0.1
  network_info_plus: ^5.0.0
  shared_preferences: ^2.2.0
```

## 🔧 Configuration

### AWS Setup
1. Create IoT Thing in AWS IoT Core
2. Generate device certificates
3. Create DynamoDB table
4. Deploy Lambda function
5. Configure API Gateway

### ESP32 Setup
1. Upload firmware with certificates
2. Configure WiFi credentials via app
3. Start monitoring

## 📊 System Architecture

```
ESP32 Sensor → AWS IoT Core → DynamoDB → Lambda → API Gateway → Flutter App
```

## 👥 Team

- **Your Name** - Developer
- **Institution** - Final Year Project

## 📄 License

This project is developed as a Final Year Project (FYP).

## 🤝 Contributing

This is an academic project. Contributions are welcome for educational purposes.

## 📧 Contact

For queries, contact: your.email@example.com

---

**Note:** This project is part of Final Year Project (FYP) for [Your Degree] at [Your University].