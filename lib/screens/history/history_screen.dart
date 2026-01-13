import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  final String patientId;
  final String? vitalType; // 'heart_rate', 'spo2', or null for both

  const HistoryScreen({
    super.key,
    this.patientId = 'health-device-001',
    this.vitalType,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<VitalsRecord> historyData = [];
  bool isLoading = true;
  String errorMessage = '';
  late String selectedFilter; // 'all', 'heart_rate', 'spo2'

  // API endpoint
  final String apiUrl = 'https://a1sdvq1q3j.execute-api.me-central-1.amazonaws.com/dev/history';

  @override
  void initState() {
    super.initState();
    // Set initial filter based on vitalType parameter
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
      final response = await http.get(
        Uri.parse('$apiUrl?patient_id=${widget.patientId}&limit=100'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> history = data['history'] ?? [];

        setState(() {
          historyData = history
              .map((item) => VitalsRecord.fromJson(item))
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load history: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading history: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  // Filter data based on selected vital type
  List<VitalsRecord> get filteredData {
    if (selectedFilter == 'all') {
      return historyData;
    } else if (selectedFilter == 'heart_rate') {
      return historyData;
    } else if (selectedFilter == 'spo2') {
      return historyData;
    }
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
          // Filter Tabs
          if (widget.vitalType == null) _buildFilterTabs(),

          // Summary Card
          _buildSummaryCard(),

          // History List
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

    double avgHeartRate = filteredData
        .map((e) => e.heartRate)
        .reduce((a, b) => a + b) / filteredData.length;

    double avgSpO2 = filteredData
        .map((e) => e.spo2)
        .reduce((a, b) => a + b) / filteredData.length;

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
            widget.vitalType == null ? '30-Day Summary' : _getFilterTitle(),
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
              '${filteredData.length} readings',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFilterTitle() {
    if (widget.vitalType == 'heart_rate') {
      return 'Heart Rate Summary';
    } else if (widget.vitalType == 'spo2') {
      return 'SpO₂ Summary';
    }
    return '30-Day Summary';
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
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('hh:mm a').format(date);
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
      deviceId: json['device_id'] ?? '',
    );
  }
}