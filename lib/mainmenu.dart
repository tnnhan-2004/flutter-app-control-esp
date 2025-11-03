// lib/mainmenu.dart

import 'package:flutter/material.dart';
import 'room_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'loginpage.dart';

// --- MODELS (Không đổi) ---
class Sensor {
  String id;
  String type;
  double threshold;
  bool enabled;
  double currentValue;
  Sensor({required this.id, required this.type, required this.threshold, this.enabled = true, this.currentValue = 0.0});

  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      id: json['id'],
      type: json['type'],
      currentValue: (json['currentValue'] as num).toDouble(),
      threshold: (json['threshold'] as num).toDouble(),
      enabled: json['enabled'],
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id, 'type': type, 'currentValue': currentValue, 'threshold': threshold, 'enabled': enabled,
  };
}

class Device {
  String id;
  String type;
  bool isOn;
  Device({required this.id, required this.type, this.isOn = false});

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(id: json['id'], type: json['type'], isOn: json['isOn']);
  }
  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'isOn': isOn};
}

class Room {
  String name;
  String ip;
  int port;
  List<Sensor> sensors;
  List<Device> devices;
  Room({required this.name, required this.ip, required this.port, List<Sensor>? sensors, List<Device>? devices})
      : sensors = sensors ?? [], devices = devices ?? [];

  factory Room.fromJson(Map<String, dynamic> json) {
    var sensorList = json['sensors'] as List;
    var deviceList = json['devices'] as List;
    List<Sensor> sensors = sensorList.map((i) => Sensor.fromJson(i)).toList();
    List<Device> devices = deviceList.map((i) => Device.fromJson(i)).toList();

    return Room(
      name: json['name'],
      ip: json['ip'],
      port: json['port'],
      sensors: sensors,
      devices: devices,
    );
  }
  Map<String, dynamic> toJson() => {
    'name': name,
    'ip': ip,
    'port': port,
    'sensors': sensors.map((s) => s.toJson()).toList(),
    'devices': devices.map((d) => d.toJson()).toList(),
  };
}

// =======================================================================
// LỚP QUẢN LÝ UDP CÔNG KHAI (PHIÊN BẢN SỬA ĐỔI)
// =======================================================================
class UdpManager {
  static RawDatagramSocket? _socket;
  static const int _port = 5005;
  // Biến để lưu trữ callback hiện tại, có thể thay đổi được
  static Function(String)? _onDataReceived;

  // Hàm private để khởi tạo socket chỉ một lần
  static Future<void> _ensureSocketIsInitialized() async {
    if (_socket != null) return;
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = _socket?.receive();
          if (dg != null) {
            String message = utf8.decode(dg.data);
            // In ra log chung trước khi gọi callback
            print("Received from ESP32: $message");
            // GỌI CALLBACK HIỆN TẠI (NẾU CÓ)
            _onDataReceived?.call(message);
          }
        }
      });
      print('UDP socket listening on port $_port');
    } catch (e) {
      print('Failed to bind UDP socket: $e');
    }
  }

  // Hàm CÔNG KHAI mới để ĐĂNG KÝ hoặc THAY ĐỔI callback
  static Future<void> registerCallback(Function(String) callback) async {
    // Luôn đảm bảo socket đã được khởi tạo
    await _ensureSocketIsInitialized();
    // Gán callback mới
    print('Callback registered/changed for: ${callback.runtimeType}');
    _onDataReceived = callback;
  }

  // Hàm gửi lệnh công khai (không đổi)
  static void sendCommand(Room room, String jsonCommand) {
    if (_socket == null) return;
    try {
      InternetAddress destination = InternetAddress(room.ip);
      _socket?.send(utf8.encode(jsonCommand), destination, room.port);
      print("Sent UDP to ${room.ip}:${room.port} -> $jsonCommand");
    } catch (e) {
      print("Error sending UDP: $e");
    }
  }

  // Hàm đóng socket (không đổi)
  static void close() {
    _socket?.close();
    _socket = null;
    _onDataReceived = null; // Dọn dẹp callback
  }
}
// =======================================================================

class Mainmenu extends StatelessWidget {
  final UserAccount currentUser;
  const Mainmenu({super.key, required this.currentUser});
  @override
  Widget build(BuildContext context) => _MainMenuWithLogic(currentUser: currentUser);
}

class _MainMenuWithLogic extends StatefulWidget {
  final UserAccount currentUser;
  const _MainMenuWithLogic({required this.currentUser});
  @override
  State<_MainMenuWithLogic> createState() => _MainMenuState();
}

// === SỬA ĐỔI: Thêm "with WidgetsBindingObserver" ===
class _MainMenuState extends State<_MainMenuWithLogic> with WidgetsBindingObserver {
  late UserAccount _currentUser;
  int _selectedIndex = 1;
  final List<Room> _rooms = [];
  final List<Map<String, dynamic>> _logs = [];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // === SỬA ĐỔI: Đăng ký observer để theo dõi vòng đời widget ===
    WidgetsBinding.instance.addObserver(this);

    _currentUser = widget.currentUser;
    _addLog('navigation', 'User ${_currentUser.name} logged in.');
    _loadRooms();

    // === SỬA ĐỔI: Sử dụng hàm registerCallback mới ===
    UdpManager.registerCallback(_handleSensorData);
  }

  @override
  void dispose() {
    // === SỬA ĐỔI: Hủy đăng ký observer khi widget bị hủy ===
    WidgetsBinding.instance.removeObserver(this);
    UdpManager.close(); // Đóng socket khi đăng xuất hoặc thoát app
    super.dispose();
  }

  // === HÀM MỚI: Được gọi khi vòng đời ứng dụng/widget thay đổi ===
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Khi người dùng quay lại trang này từ một trang khác (ví dụ RoomDetailPage)
    // state sẽ là 'resumed'
    if (state == AppLifecycleState.resumed) {
      print("MainMenu has resumed. Re-registering its UDP callback.");
      // Đăng ký lại callback của MainMenu để nó nhận lại dữ liệu UDP
      UdpManager.registerCallback(_handleSensorData);
    }
  }


  Future<void> _saveRooms() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> roomListString = _rooms.map((room) => jsonEncode(room.toJson())).toList();
    await prefs.setStringList('user_rooms', roomListString);
  }

  Future<void> _loadRooms() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? roomListString = prefs.getStringList('user_rooms');
    if (roomListString != null) {
      setState(() {
        _rooms.clear();
        _rooms.addAll(roomListString.map((str) => Room.fromJson(jsonDecode(str))));
      });
    }
  }

  // Hàm này bây giờ chỉ hoạt động khi MainMenu đang là trang chính
  void _handleSensorData(String jsonData) {
    try {
      final data = jsonDecode(jsonData);
      if (data['type'] == 'sensor_data') {
        String sensorId = data['sensor_id'];
        double value = (data['value'] as num).toDouble();

        for (var room in _rooms) {
          for (var sensor in room.sensors) {
            if (sensor.id == sensorId) {
              if (mounted) {
                // Không cần setState ở đây vì UI của MainMenu không hiển thị giá trị này
                sensor.currentValue = value;
              }
              return;
            }
          }
        }
      }
    } catch (e) {
      print("Error parsing sensor data in MainMenu: $e");
    }
  }

  void _logout() {
    // UdpManager.close() đã được chuyển vào dispose()
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPageWithLogic()),
          (Route<dynamic> route) => false,
    );
  }

  void _addLog(String type, String message, {bool alert = false}) {
    final entry = {'time': DateTime.now().toIso8601String(), 'type': type, 'message': message, 'alert': alert};
    if (mounted) {
      setState(() => _logs.insert(0, entry));
    }
  }

  void _addRoom() {
    final name = TextEditingController();
    final ip = TextEditingController();
    final port = TextEditingController(text: "5005");
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Room'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Room Name')),
          TextField(controller: ip, decoration: const InputDecoration(labelText: 'ESP32 IP')),
          TextField(controller: port, decoration: const InputDecoration(labelText: 'Port'), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (name.text.isEmpty || ip.text.isEmpty) return;
            setState(() {
              final room = Room(
                  name: name.text,
                  ip: ip.text,
                  port: int.tryParse(port.text) ?? 5005,
                  devices: [
                    Device(id: 'led1', type: 'light', isOn: false),
                    Device(id: 'led2', type: 'light', isOn: false),
                    Device(id: 'fan', type: 'fan', isOn: false),
                    Device(id: 'ml', type: 'ac', isOn: false),
                  ],
                  sensors: [
                    Sensor(id: 'dht_temp', type: 'temp', threshold: 30.0, currentValue: 0.0),
                    Sensor(id: 'dht_humid', type: 'humid', threshold: 65.0, currentValue: 0.0)
                  ]);
              _rooms.add(room);
              _addLog('room', 'Added room ${room.name}');
              _saveRooms();
            });
            Navigator.of(context).pop();
          }, child: const Text('Confirm')),
        ],
      ),
    );
  }

  void _editRoom(int index) { /* ... Bạn có thể thêm logic ở đây nếu cần ... */ }

  void _deleteRoom(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm'),
        content: Text('Delete ${_rooms[index].name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _addLog('room', 'Deleted room ${_rooms[index].name}');
        _rooms.removeAt(index);
        _saveRooms();
      });
    }
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
                    color: const Color(0xFFF6F6F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                child: Stack(children: [
                  Positioned(
                    left: 0, top: 203, right: 0, bottom: 0,
                    child: Container(
                      decoration: const ShapeDecoration(
                        gradient: LinearGradient(begin: Alignment(1.31, 0.57), end: Alignment(0.08, 0.14), colors: [Color(0xFF58E0AA), Color(0xFF49C8F2)]),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40, left: 20, right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: const EdgeInsets.only(top: 40.0), child: Text('Hi, ${_currentUser.name}!', style: TextStyle(color: Colors.black.withOpacity(0.75), fontSize: 32, fontFamily: 'Poppins', fontWeight: FontWeight.w600))),
                        GestureDetector(
                          onTap: _logout,
                          child: CircleAvatar(radius: 26, backgroundColor: const Color(0xFFDDDDDD), child: Text(_currentUser.name.isNotEmpty ? _currentUser.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 24, color: Colors.black54))),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 203.0),
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [_buildLogsTab(), _buildHomeTab(), _buildSettingsTab()],
                    ),
                  ),
                  Positioned(left: 0, right: 0, bottom: 0, child: BottomNavBar(selectedIndex: _selectedIndex, onItemTapped: _onItemTapped)),
                ]))));
  }

  Widget _buildHomeTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Room List", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Expanded(
            child: _rooms.isEmpty
                ? const Center(child: Text("No rooms yet. Add one!", style: TextStyle(color: Colors.white70)))
                : ListView.builder(
              itemCount: _rooms.length,
              itemBuilder: (context, index) {
                final room = _rooms[index];
                return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: ListTile(
                      leading: const Icon(Icons.meeting_room_outlined, color: Color(0xFF50C2C9)),
                      title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("IP: ${room.ip}:${room.port}"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        String pingCommand = '{"cmd":"ping"}';
                        UdpManager.sendCommand(room, pingCommand); // Gọi hàm từ UdpManager
                        Navigator.push(context, MaterialPageRoute(builder: (context) => RoomDetailPage(room: room))).then((_){
                          // Sau khi quay lại từ trang chi tiết, lưu trạng thái phòng (bật/tắt đèn)
                          // và đăng ký lại callback của MainMenu
                          print("Returned from RoomDetailPage. Saving rooms and re-registering callback.");
                          UdpManager.registerCallback(_handleSensorData);
                          _saveRooms();
                        });
                      },
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(leading: const Icon(Icons.edit), title: const Text('Edit'), onTap: () { Navigator.of(context).pop(); _editRoom(index); }),
                              ListTile(leading: const Icon(Icons.delete), title: const Text('Delete'), onTap: () { Navigator.of(context).pop(); _deleteRoom(index); }),
                            ],
                          ),
                        );
                      },
                    ));
              },
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _addRoom, icon: const Icon(Icons.add), label: const Text('Add Room'), style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF50C2C9),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          )),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        children: [
          const Text("Activity Logs", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Expanded(
            child: _logs.isEmpty
                ? const Center(child: Text("No activity yet.", style: TextStyle(color: Colors.white70)))
                : ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return Card(
                  color: (log['alert'] == true) ? Colors.red.shade100 : Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: Icon((log['alert'] == true) ? Icons.warning_amber : Icons.info_outline, color: const Color(0xFF50C2C9)),
                    title: Text(log['message'] ?? ''),
                    subtitle: Text(DateTime.tryParse(log['time'] ?? '')?.toLocal().toString().split('.').first ?? ''),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      children: [
        const Center(child: Text("Settings", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About"),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('About'),
                  content: const Text('SMARTHOME App\nVersion 1.0.0\nMade by Group 9'),
                  actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 90),
      ],
    );
  }
}

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  const BottomNavBar({super.key, required this.selectedIndex, required this.onItemTapped});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 91,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only( topLeft: Radius.circular(30), topRight: Radius.circular(30) ),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.list_alt, 'Logs', 0),
          _buildNavItem(Icons.home, 'Home', 1),
          _buildNavItem(Icons.settings, 'Settings', 2),
        ],
      ),
    );
  }
  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = (selectedIndex == index);
    final Color color = isSelected ? const Color(0xFF49C8F2) : Colors.grey[700]!;
    return GestureDetector(
      onTap: () => onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text( label, style: TextStyle(color: color, fontSize: 12, fontFamily: 'Poppins', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}
