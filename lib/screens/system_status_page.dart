import '../thai_labels.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SystemStatusPage extends StatelessWidget {
  const SystemStatusPage({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('บัญชีและการจัดเก็บข้อมูล')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(auth.currentUser?.displayName ?? ''),
            subtitle: Text(
              '${auth.currentUser?.username} - ${roleLabel(auth.currentUser?.role)}',
            ),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'ทุกบัญชีที่เข้าสู่ระบบใช้ฟังก์ชันงานทั่วไปได้ ส่วนภาพรวมและการจัดการบทบาทสงวนไว้สำหรับผู้จัดการ',
              ),
            ),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'ข้อมูลจัดเก็บในฐานข้อมูล SQLite ของแอปบนอุปกรณ์นี้ R5 ครอบคลุมการเข้าสู่ระบบ สมัครสมาชิก และกำหนดบทบาท โดยยังไม่รองรับการซิงก์ข้อมูลระหว่างอุปกรณ์',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
