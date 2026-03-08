import 'package:flutter/material.dart';
import 'bank/services/event_driven_bridge_source.dart';
import 'bank/features/dashboard_page.dart';
import 'enduser/theme.dart';
import 'enduser/pages/market_page.dart';

void main() {
  runApp(const DemoApp());
}

/// 統合デモアプリ。
/// 左: 銀行ダッシュボード（ダークテーマ）
/// 右: エンドユーザーアプリ（ライトテーマ、スマホ風フレーム）
///
/// エンドユーザーが商品を購入 → PaymentEventBus → 銀行ダッシュボードがリアルタイム更新
class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  final _bridgeSource = EventDrivenBridgeSource();

  @override
  void dispose() {
    _bridgeSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Treasury Gateway Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0B1017)),
      home: Scaffold(
        body: Row(
          children: [
            // ---- 銀行ダッシュボード (左 70%) ----
            Expanded(
              flex: 7,
              child: BankDashboardPage(dataSource: _bridgeSource),
            ),
            // ---- 区切り ----
            Container(width: 1, color: const Color(0xFF2D3F52)),
            // ---- エンドユーザーアプリ (右 30%) ----
            Expanded(
              flex: 3,
              child: _PhoneMockup(
                child: Theme(
                  data: buildEndUserTheme(),
                  child: const MarketPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// スマホ風のフレーム。デモ表示で「これはユーザーのスマホ画面」と分かるように。
class _PhoneMockup extends StatelessWidget {
  final Widget child;
  const _PhoneMockup({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          // ラベル
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.phone_android_rounded, size: 16, color: Color(0xFF6B7280)),
                SizedBox(width: 6),
                Text(
                  'End-User Mobile App',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // スマホフレーム
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF374151), width: 3),
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
