import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  final String patientId;
  final String? vitalType;

  const HistoryScreen({
    super.key,
    this.patientId = 'esp32-health-monitor',
    this.vitalType,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<VitalsRecord> historyData = [];
  bool isLoading = true;
  String errorMessage = '';
  late String selectedFilter;

  // UPDATE THIS WITH YOUR ACTUAL ENDPOINT
  final String apiUrl = 'https://82x4ep0iwi.execute-api.me-central-1.amazonaws.com/prod/history';

  @override
  void initState() {
    super.initState();
    if (widget.vitalType == 'heart_rate') {
      selectedFilter = 'heart_rate';
    } else if (widget.vitalType == 'spo2') {
      selectedFilter = 'spo2';
    } else {
      selectedFilter = 'all';
    }
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      print('🔍 API URL: $apiUrl');
      print('🔍 Patient ID: ${widget.patientId}');

      final url = '$apiUrl?patient_id=${widget.patientId}&limit=100';
      print('🔍 Full URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      print('📡 Response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Parsed initial data: $data');

        // Handle Lambda response with nested body
        var responseData = data;
        if (data['body'] != null) {
          try {
            responseData = json.decode(data['body']);
            print('✅ Parsed from body: $responseData');
          } catch (e) {
            responseData = data;
            print('⚠️ Could not parse body: $e');
          }
        }

        print('📊 Response data keys: ${responseData.keys}');
        print('📊 History list: ${responseData['history']}');

        final List<dynamic> history = responseData['history'] ?? [];
        print('📊 History count: ${history.length}');

        if (history.isEmpty) {
          print('❌ History is empty!');
        }

        setState(() {
          historyData = history
              .map((item) => VitalsRecord.fromJson(item))
              .toList();
          isLoading = false;
        });

        print('✨ historyData updated: ${historyData.length} records');
      } else {
        setState(() {
          errorMessage = 'Failed to load history: ${response.statusCode}';
          isLoading = false;
        });
        print('❌ API Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading history: ${e.toString()}';
        isLoading = false;
      });
      print('❌ Exception: $e');
    }
  }

  List<VitalsRecord> get filteredData {
    return historyData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading history...'),
          ],
        ),
      )
          : errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 60, color: Colors.red.shade300),
            const SizedBox(height: 20),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
            ),
          ],
        ),
      )
          : filteredData.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox,
                size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            const Text(
              'No history available',
              style: TextStyle(
                  fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            const Text(
              'Start monitoring to see your health data',
              style: TextStyle(
                  fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      )
          : Column(
        children: [
          if (widget.vitalType == null) _buildFilterTabs(),
          _buildSummaryCard(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredData.length,
              itemBuilder: (context, index) {
                return _buildHistoryCard(filteredData[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    if (widget.vitalType == 'heart_rate') {
      return 'Heart Rate History';
    } else if (widget.vitalType == 'spo2') {
      return 'SpO₂ Level History';
    } else {
      return 'Vitals History';
    }
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterButton('All', 'all', Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterButton('Heart Rate', 'heart_rate', Colors.red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterButton('SpO₂', 'spo2', Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String filterValue, Color color) {
    final isSelected = selectedFilter == filterValue;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.white,
        foregroundColor: isSelected ? Colors.white : color,
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: () {
        setState(() {
          selectedFilter = filterValue;
        });
      },
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (filteredData.isEmpty) return const SizedBox.shrink();

    // Filter out zero/invalid values for better average calculation
    final validHeartRateData = filteredData
        .where((e) => e.heartRate > 0 && e.heartRate < 200)
        .toList();

    final validSpO2Data = filteredData
        .where((e) => e.spo2 > 0 && e.spo2 <= 100)
        .toList();

    double avgHeartRate = validHeartRateData.isNotEmpty
        ? validHeartRateData
        .map((e) => e.heartRate)
        .reduce((a, b) => a + b) / validHeartRateData.length
        : 0;

    double avgSpO2 = validSpO2Data.isNotEmpty
        ? validSpO2Data
        .map((e) => e.spo2)
        .reduce((a, b) => a + b) / validSpO2Data.length
        : 0;

    print('📊 Valid HR data: ${validHeartRateData.length}/${filteredData.length}');
    print('📊 Valid SpO2 data: ${validSpO2Data.length}/${filteredData.length}');
    print('📊 Avg HR: $avgHeartRate, Avg SpO2: $avgSpO2');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.redAccent, Colors.red.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '30-Day Summary',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStat(
                'Avg Heart Rate',
                '${avgHeartRate.toStringAsFixed(0)} bpm',
                Icons.favorite,
              ),
              Container(width: 2, height: 50, color: Colors.white30),
              _buildSummaryStat(
                'Avg SpO₂',
                '${avgSpO2.toStringAsFixed(0)}%',
                Icons.bubble_chart,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${filteredData.length} total readings\n(${validHeartRateData.length} valid HR, ${validSpO2Data.length} valid SpO₂)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(VitalsRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  _formatDate(record.timestamp),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(record.timestamp),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildVitalInfo(
                    'Heart Rate',
                    '${record.heartRate}',
                    'bpm',
                    Icons.favorite,
                    Colors.red,
                    _getHeartRateStatus(record.heartRate),
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Colors.grey.shade300,
                ),
                Expanded(
                  child: _buildVitalInfo(
                    'SpO₂',
                    '${record.spo2}',
                    '%',
                    Icons.bubble_chart,
                    Colors.green,
                    _getSpO2Status(record.spo2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalInfo(
      String label,
      String value,
      String unit,
      IconData icon,
      Color color,
      String status,
      ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 10,
              color: _getStatusColor(status),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(int timestamp) {
    try {
      // Agar timestamp chhota hai (seconds format)
      // assume karo milliseconds nahi hai
      int timestampMs;

      if (timestamp < 10000000000) {
        // Timestamp seconds mein hai (small number)
        timestampMs = timestamp * 1000;
      } else {
        // Timestamp milliseconds mein hai (large number)
        timestampMs = timestamp;
      }

      final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);

      // Agar date 1970 se pehle aaye ya future mein, today use karo
      if (date.isBefore(DateTime(2020)) || date.isAfter(DateTime.now())) {
        return DateFormat('MMM dd, yyyy').format(DateTime.now());
      }

      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      print('Error formatting date: $e');
      return DateFormat('MMM dd, yyyy').format(DateTime.now());
    }
  }

  String _formatTime(int timestamp) {
    try {
      int timestampMs;

      if (timestamp < 10000000000) {
        timestampMs = timestamp * 1000;
      } else {
        timestampMs = timestamp;
      }

      final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);

      // Agar date 1970 se pehle aaye ya future mein, current time use karo
      if (date.isBefore(DateTime(2020)) || date.isAfter(DateTime.now())) {
        return DateFormat('hh:mm a').format(DateTime.now());
      }

      return DateFormat('hh:mm a').format(date);
    } catch (e) {
      print('Error formatting time: $e');
      return DateFormat('hh:mm a').format(DateTime.now());
    }
  }

  String _getHeartRateStatus(int hr) {
    if (hr < 60) return 'Low';
    if (hr > 100) return 'High';
    return 'Normal';
  }

  String _getSpO2Status(int spo2) {
    if (spo2 < 95) return 'Low';
    return 'Normal';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Normal':
        return Colors.green;
      case 'Low':
        return Colors.orange;
      case 'High':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class VitalsRecord {
  final int heartRate;
  final int spo2;
  final int timestamp;
  final String deviceId;

  VitalsRecord({
    required this.heartRate,
    required this.spo2,
    required this.timestamp,
    required this.deviceId,
  });

  factory VitalsRecord.fromJson(Map<String, dynamic> json) {
    return VitalsRecord(
      heartRate: json['heart_rate'] ?? 0,
      spo2: json['spo2'] ?? 0,
      timestamp: json['timestamp'] ?? 0,
      deviceId: json['device_id'] ?? 'esp32-health-monitor',
    );
  }
}