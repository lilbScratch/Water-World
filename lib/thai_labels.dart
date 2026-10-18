String roleLabel(Object? role) =>
    switch (role.toString().trim().toLowerCase()) {
      'manager' || 'admin' => 'ผู้จัดการ',
      'production' => 'ฝ่ายผลิต',
      'purchasing' => 'ฝ่ายจัดซื้อ',
      'user' || 'unverified' => 'ผู้ใช้งานทั่วไป',
      _ => role?.toString() ?? '',
    };

String orderStatusLabel(String status) => switch (status) {
  'draft' => 'ฉบับร่าง',
  'awaiting_production' => 'รอผลิต',
  'confirmed' => 'พร้อมจัดส่ง',
  'fulfilled' => 'จัดส่งแล้ว',
  'cancelled' => 'ยกเลิกแล้ว',
  _ => status,
};
