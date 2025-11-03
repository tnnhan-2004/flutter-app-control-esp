// lib/room_detail_page.dart

import 'package:flutter/material.dart';
import 'mainmenu.dart'; // Vẫn import để lấy các lớp Model và UdpManager
import 'dart:convert';
import 'notification_service.dart'; // Import the notification service

class RoomDetailPage extends StatefulWidget {
  final Room room;
  const RoomDetailPage({super.key, required this.room});
  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // As per your existing code, this registers the handler for this page.
    UdpManager.registerCallback(_handleSensorData);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleSensorData(String jsonData) {
    print('[RoomDetailPage] Received raw data: $jsonData');
    try {
      final data = jsonDecode(jsonData);
      if (data['type'] == 'sensor_data') {
        String receivedSensorId = data['sensor_id'];
        double value = (data['value'] as num).toDouble();
        print('[RoomDetailPage] Parsed: ID = "$receivedSensorId", Value = $value');
        bool matchFound = false;
        for (var sensor in widget.room.sensors) {
          if (sensor.id == receivedSensorId) {
            print('✅ MATCH FOUND! Updating UI for "${sensor.id}".');
            matchFound = true;
            if (mounted) {
              setState(() {
                sensor.currentValue = value;
              });

              // === KIỂM TRA NGƯỠNG ===
              if (sensor.enabled && sensor.currentValue > sensor.threshold) {
                print('⚠️ WARNING: ${sensor.id} (${sensor.currentValue}) has exceeded the threshold of ${sensor.threshold}!');

                // Gọi hàm hiển thị thông báo
                NotificationService().showNotification(
                    title: 'Cảnh báo tại ${widget.room.name}',
                    body: '${sensor.id} đã vượt ngưỡng: ${sensor.currentValue.toStringAsFixed(1)}${sensor.type == 'temp' ? '°C' : '%'}'
                );
              }
            }
            break;
          }
        }
        if (!matchFound) {
          print('❌ NO MATCH FOUND for received ID "$receivedSensorId".');
        }
      }
    } catch (e) {
      print("[RoomDetailPage] Error parsing JSON: $e");
    }
  }

  void _controlDevice(Device device, bool isOn) {
    final command = {
      "cmd": "control_device",
      "device_id": device.id,
      "is_on": isOn,
    };
    UdpManager.sendCommand(widget.room, jsonEncode(command));
    setState(() {
      device.isOn = isOn;
    });
  }

  //HÀM HIỂN THỊ DIALOG ĐỂ ĐẶT NGƯỠNG ===
  void _showSetThresholdDialog(Sensor sensor) {
    final controller = TextEditingController(text: sensor.threshold.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set Threshold for ${sensor.id}'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Warning Threshold (${sensor.type == 'temp' ? '°C' : '%'})',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newThreshold = double.tryParse(controller.text);
                if (newThreshold != null) {
                  setState(() {
                    // Cập nhật ngưỡng, giao diện sẽ tự build lại
                    sensor.threshold = newThreshold;
                  });
                  // Lưu ý: Để ngưỡng này được lưu lại sau khi tắt app,
                  // bạn cần gọi hàm _saveRooms() từ MainMenu.
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: Center(
        child: Container(
          width: 375,
          height: 812,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: const Color(0xFFF6F6F6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF49C8F2),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              title: Text(widget.room.name),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Devices'),
                  Tab(text: 'Sensors'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildDevicesTab(),
                _buildSensorsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDevicesTab() {
    if (widget.room.devices.isEmpty) {
      return const Center(child: Text('No devices added to this room.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: widget.room.devices.length,
      itemBuilder: (context, index) {
        final device = widget.room.devices[index];
        IconData iconData;
        switch(device.type) {
          case 'light': iconData = Icons.lightbulb_outline; break;
          case 'fan': iconData = Icons.air_outlined; break;
          case 'ac': iconData = Icons.ac_unit_outlined; break;
          default: iconData = Icons.device_unknown;
        }
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: ListTile(
            leading: Icon(iconData, color: const Color(0xFF49C8F2), size: 30),
            title: Text(device.id, style: const TextStyle(fontWeight: FontWeight.w500)),
            trailing: Switch(
              value: device.isOn,
              onChanged: (bool value) {
                _controlDevice(device, value);
              },
              activeColor: const Color(0xFF49C8F2),
            ),
          ),
        );
      },
    );
  }

  // === CẬP NHẬT: TAB CẢM BIẾN VỚI CHỨC NĂNG ĐẶT NGƯỠNG ===
  Widget _buildSensorsTab() {
    if (widget.room.sensors.isEmpty) {
      return const Center(child: Text('No sensors added to this room.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: widget.room.sensors.length,
      itemBuilder: (context, index) {
        final sensor = widget.room.sensors[index];
        IconData iconData = sensor.type == 'temp' ? Icons.thermostat : Icons.water_drop_outlined;
        String unit = sensor.type == 'temp' ? '°C' : '%';

        // Kiểm tra xem giá trị hiện tại có vượt ngưỡng không
        bool isOverThreshold = sensor.currentValue > sensor.threshold;

        return Card(
          // Đổi màu nền nếu vượt ngưỡng
          color: isOverThreshold ? Colors.orange.shade100 : Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: ListTile(
            leading: Icon(iconData, color: isOverThreshold ? Colors.red : const Color(0xFF49C8F2), size: 30),
            title: Text(sensor.id, style: const TextStyle(fontWeight: FontWeight.w500)),
            // Hiển thị ngưỡng hiện tại
            subtitle: Text('Threshold: ${sensor.threshold.toStringAsFixed(1)} $unit'),
            trailing: Text(
              '${sensor.currentValue.toStringAsFixed(1)} $unit',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                // Đổi màu chữ nếu vượt ngưỡng
                color: isOverThreshold ? Colors.red : Colors.black87,
              ),
            ),
            // Thêm sự kiện onTap
            onTap: () {
              _showSetThresholdDialog(sensor);
            },
          ),
        );
      },
    );
  }
}
