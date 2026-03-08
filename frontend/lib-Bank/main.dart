import 'package:flutter/material.dart';
import 'theme.dart';
import 'features/dashboard_page.dart';
import 'services/mock_bridge_data_source.dart';

void main() {
  runApp(const TreasuryGatewayApp());
}

class TreasuryGatewayApp extends StatefulWidget {
  const TreasuryGatewayApp({super.key});

  @override
  State<TreasuryGatewayApp> createState() => _TreasuryGatewayAppState();
}

class _TreasuryGatewayAppState extends State<TreasuryGatewayApp> {
  // ブロックチェーン側実装が確定したら MockBridgeDataSource を差し替える
  final _dataSource = MockBridgeDataSource();

  @override
  void dispose() {
    _dataSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Treasury Gateway',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: DashboardPage(dataSource: _dataSource),
    );
  }
}
