import 'package:cloud_firestore/cloud_firestore.dart';

class JobSeeder {
  // sample data — thay / mở rộng theo nhu cầu
  static final List<Map<String, dynamic>> _sampleJobs = [
    {
      'Company': 'CÔNG TY CỔ PHẦN BẤT ĐỘNG SẢN PHỐ XANH HOLDINGS',
      'Job':
          'Nhân Viên Kinh Doanh - Lương Cứng 8 Triệu -12 Triệu - Được Đào Tạo Nghề - Không Giới Hạn Thu Nhập - Tự Do Thời Gian',
      'Location': 'Hà Nội',
      'Salary': '8 - 40 triệu',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN MỤC TIÊU VIỆT',
      'Job':
          'Trực Page/ Chăm Sóc Khách Hàng/ Hotline Tuyển Sinh/ Sales Online/ Telesales (Data Sẵn 100%) Tại TP.HCM',
      'Location': 'Hồ Chí Minh',
      'Salary': 'Từ 7 triệu',
    },
    {
      'Company': 'CÔNG TY CP KINH DOANH VÀ PHÁT TRIỂN ĐỊA ỐC VIETSTARLAND',
      'Job': 'Kế Toán Tổng Hợp Thu Nhập Thỏa Thuận Theo Năng Lực Tại Hà Nội',
      'Location': 'Hà Nội',
      'Salary': 'Thoả thuận',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN MASFICO VIỆT NAM',
      'Job':
          'Chuyên Viên Phát Triển Thị Trường Kênh Đại Lý - Thu Nhập Từ 18-25 Triệu/Tháng',
      'Location': 'Hồ Chí Minh',
      'Salary': '18 - 25 triệu',
    },
    {
      'Company': 'CÔNG TY TNHH BAMECA',
      'Job': 'Nhân Viên Quán Cà Phê - BAMECA - VẠN PHÚC - HÀ ĐÔNG - HÀ NỘI',
      'Location': 'Hà Nội',
      'Salary': 'Thoả thuận',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN EDUVATOR',
      'Job':
          'Tư Vấn Khóa Học & Chăm Sóc Học Viên - Lương Cứng 8tr - 18tr Thu Nhập Không Giới Hạn (Không Yêu Cầu Kinh Nghiệm Giáo Dục)',
      'Location': 'Hồ Chí Minh & 2 nơi khác',
      'Salary': '15 - 20 triệu',
    },
    {
      'Company': 'CÔNG TY CP TƯ VẤN THƯƠNG HIỆU SAO KIM',
      'Job':
          'Account Excutive/Chuyên Viên Kinh Doanh/ Sales B2B/ Tư Vấn Dịch Vụ Digital (Thu Nhập 15 -20 Triệu) Tại Hà Nội/ HCM',
      'Location': 'Hà Nội',
      'Salary': '15 - 20 triệu',
    },
    {
      'Company': 'Công ty TNHH Xe nâng Bình Minh',
      'Job':
          'Nhân Viên Kinh Doanh (Mảng Cho Thuê) - Thu Nhập Hấp Dẫn Cao 30 Triệu Đồng Làm Việc Tại Hà Nội Hoặc Hồ Chí Minh',
      'Location': 'Hà Nội',
      'Salary': '8 - 30 triệu',
    },
    {
      'Company': 'CÔNG TY TNHH KINH DOANH CÔNG NGHỆ D-TECH',
      'Job': 'Sales Brand Manager',
      'Location': 'HCM',
      'Salary': 'Tới 4',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN BRIGHT ENGINEERING VIỆT NAM',
      'Job':
          'Kỹ Sư Thiết Kế Cơ Khí (Làm Việc Tại Nhật Bản)- Đào Tạo Tiếng Nhật Và Thiết Kế Miễn Phí',
      'Location': 'Hà Nội',
      'Salary': '50 - 100 triệu',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN ĐẦU TƯ XÂY DỰNG SƠN THÀNH AN',
      'Job': 'Kế Toán Trưởng Làm Việc Tại Đà Nẵng',
      'Location': 'Đà Nẵng',
      'Salary': 'Thoả thuận',
    },
    {
      'Company': 'Công ty Cổ phần Quốc Tế TICO',
      'Job': 'Nhân Viên Kinh Doanh/Sales Logistics Tại Thanh Hóa',
      'Location': 'Thanh Hoá',
      'Salary': '7 - 20 triệu',
    },
    {
      'Company':
          'Công Ty TNHH Bảo Hiểm Nhân Thọ Prudential Việt Nam – Bộ Phận Hợp Tác Kinh Doanh',
      'Job':
          'Chuyên Viên Tư Vấn Bảo Hiểm - Kênh Hợp Tác Ngân Hàng SEABANK Tại Hồ Chí Minh - Hà Nội - Hải Dương',
      'Location': 'Hà Nội & 2 nơi khác',
      'Salary': 'Thoả thuận',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN CÔNG NGHỆ VÀ THIẾT BỊ TOÀN CẦU',
      'Job':
          'Nhân Viên Kinh Doanh - Thu Nhập Không Giới Hạn (Trung Bình Từ 15 - 45 Triệu/ Tháng + Thưởng)',
      'Location': 'Hà Nội',
      'Salary': '15 - 45 triệu',
    },
    {
      'Company': 'CÔNG TY TNHH THƯƠNG MẠI DỊCH VỤ TIẾP VẬN LTC',
      'Job': 'Giám Đốc Kinh Doanh Logistics',
      'Location': 'Hồ Chí Minh',
      'Salary': '20 - 35 triệu',
    },
    {
      'Company': 'CÔNG TY TNHH PANEL HOME VINA',
      'Job': 'Nhân Viên Kinh Doanh',
      'Location': 'Hà Nội',
      'Salary': 'Lương Cứng 10 - 25 Triệu (Hà Nội)',
    },
    {
      'Company': 'CÔNG TY CP ĐẦU TƯ VÀ DU LỊCH GOLDEN DRAGON',
      'Job': 'Nhân Viên Đại Diện Kinh Doanh Nghỉ Dưỡng 5 Sao',
      'Location': 'Hồ Chí Minh',
      'Salary': '15 - 25 triệu',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN VẬT TƯ TÂY ĐÔ LONG AN',
      'Job': 'Nhân Viên Marketing Địa Bàn Miền Tây',
      'Location': 'Kiên Giang & 2 nơi khác',
      'Salary': 'Thoả thuận',
    },
    {
      'Company': 'CÔNG TY TNHH DU LỊCH QUỐC TẾ INBOUND VIỆT NAM',
      'Job':
          'Sale Tour Nội Địa Và Quốc Tế Inbound Và Outbound (Kinh Nghiệm Trên 1 Năm Làm Sale Tour) -Thu Nhập Trung Bình Từ 20 - 30 Triệu ++',
      'Location': 'Hà Nội',
      'Salary': '20 - 30 triệu',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN THƯƠNG MẠI VÀ DỊCH VỤ MAI ĐẾN',
      'Job': 'Nhân Viên Kỹ Thuật IT',
      'Location': 'Hà Nội',
      'Salary': '10 - 15 triệu',
    },
    {
      'Company': 'Công ty TNHH Vietnam Concentrix Services',
      'Job':
          'Customer Service - Flight Ticket App / Nhân Viên Chăm Sóc Khách Hàng Vé Máy Bay- Không Áp KPI Quận 12- Thu Nhập 10-13 Triệu',
      'Location': 'Hồ Chí Minh',
      'Salary': '10 - 13 triệu',
    },
    {
      'Company': 'CÔNG TY TNHH GIÁO DỤC UNICLASS',
      'Job':
          'Nhân Viên Kinh Doanh/ Telesale/ Tư Vấn Tuyển Sinh - (Data Sẵn 100% - Thử Việc 100% Lương)',
      'Location': 'Hà Nội',
      'Salary': '11 - 23 triệu',
    },
    {
      'Company': 'CÔNG TY TNHH SẢN XUẤT CÔNG NGHIỆP NAM VIỆT',
      'Job': 'Nhân Viên Kỹ Thuật Điện - Cơ Khí (Lương Từ 8 -12 Triệu + Thưởng)',
      'Location': 'Hà Nội',
      'Salary': '8 - 12 triệu',
    },
    {
      'Company': 'Công Ty TNHH QMH Computer - Tập đoàn Quanta',
      'Job': 'Giám Đốc ( Quản Lý Kỹ Sư ) ( LCM - FATP) - Thu Nhập Hấp Dẫn',
      'Location': 'Nam Định & 6 nơi khác',
      'Salary': 'Thoả thuận',
    },
    {
      'Company': 'Công ty bảo hiểm nhân thọ AIA',
      'Job': 'Chuyên Viên Hoạch Định Tài Chính',
      'Location': 'Hà Nội',
      'Salary': '12 - 24 triệu',
    },
    {
      'Company': 'CÔNG TY TNHH TRIPLE TREE AROMA',
      'Job': 'Nữ Nhân Viên Bán Hàng Full-Time',
      'Location': 'Hà Nội',
      'Salary': '7 - 10 triệu',
    },
    {
      'Company': 'CÔNG TY TNHH BINGCHUN VIỆT NAM',
      'Job':
          'Nhân Viên Kinh Doanh Nhượng Quyền Thương Hiệu Thu Nhập 20 - 30 Triệu',
      'Location': 'Hà Nội',
      'Salary': '20 - 30 triệu',
    },
    {
      'Company': 'CÔNG TY TNHH THƯƠNG MẠI DỊCH VỤ TIẾP VẬN LTC',
      'Job': 'Giám Đốc Kinh Doanh Logistics',
      'Location': 'Hồ Chí Minh',
      'Salary': '20 - 35 triệu',
    },
    {
      'Company': 'Công ty TNHH Esoft Vietnam',
      'Job':
          'Senior Growth Marketing Executive 2+ Year EXP (Attractive Salary)',
      'Location': 'Hà Nội',
      'Salary': 'Thoả thuận',
    },
    {
      'Company': 'CÔNG TY TNHH SMARTWOOD',
      'Job': 'Kế Toán Tổng Hợp',
      'Location': 'Hà Nội',
      'Salary': '11 - 16 triệu',
    },
    {
      'Company': 'Công ty Cổ phần Giáo dục Quốc tế CB Mekong',
      'Job': 'Giáo Viên Tiếng Anh /English Teacher - Bến Tre',
      'Location': 'Tiền Giang & 3 nơi khác',
      'Salary': 'Thoả thuận',
    },
    {
      'Company': 'Công ty TNHH AUO Việt Nam',
      'Job': 'Trợ Lý Tiếng Trung - 部門助理',
      'Location': 'Hà Nam',
      'Salary': '12 - 17 triệu',
    },
    {
      'Company': 'CÔNG TY TNHH TÔN THÉP KOKORO',
      'Job':
          'Nhân Viên Kinh Doanh/ Sales/ Phát Triển Thị Trường - Lương Thưởng Hấp Dẫn - Tại Quận 12 - Hồ Chí Minh',
      'Location': 'Hồ Chí Minh',
      'Salary': 'Thoả thuận',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN THỰC PHẨM VÀ ĐỒ UỐNG TTC',
      'Job': 'Trưởng Kênh GT Làm Việc Tại Hà Nội',
      'Location': 'Hà Nội',
      'Salary': 'Thoả thuận',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN CÔNG NGHỆ INFOSYS VIỆT NAM',
      'Job': 'Presales Network/System/AV Thu Nhập Upto 25 Triệu Tại Hà Nội',
      'Location': 'Hà Nội',
      'Salary': 'Tới 25 triệu',
    },
    {
      'Company': 'CÔNG TY TRÁCH NHIỆM HỮU HẠN HAPOIN VIỆT NAM',
      'Job':
          'Nhân Viên Kinh Doanh / Sales Engineer / Kỹ Thuật SMT Tiếng Trung - Lương Net 14 - 24 Triệu++',
      'Location': 'Hà Nội',
      'Salary': '14 - 24 triệu',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN TẦM NHÌN QUỐC TẾ ALADDIN',
      'Job': 'Chuyên Viên Đào Tạo Ngành F&B Lương 14-20tr',
      'Location': 'Hà Nội',
      'Salary': '14 - 20 triệu',
    },
    {
      'Company': 'CÔNG TY TNHH XNK DAWN HAIR',
      'Job': 'Trưởng Nhóm Kinh Doanh Xuất Nhập Khẩu',
      'Location': 'Hà Nội',
      'Salary': '20 - 50 triệu',
    },
    {
      'Company': 'CÔNG TY TNHH THƯƠNG MẠI DỊCH VỤ XỬ LÝ MÔI TRƯỜNG VIỆT KHẢI.',
      'Job':
          'Nhân Viên An Toàn Lao Động - Thu Nhập Đến 15 Triệu Làm Việc Tại Bắc Tân Uyên (Bình Dương)',
      'Location': 'Bình Dương',
      'Salary': '9.5 - 15 triệu',
    },
    {
      'Company': 'Công ty TNHH 1C Việt Nam',
      'Job': 'Chuyên Viên Triển Khai Phần Mềm Kế Toán',
      'Location': 'Hà Nội',
      'Salary': 'Thoả thuận',
    },
    {
      'Company':
          'CÔNG TY CỔ PHẦN SẢN XUẤT VÀ XUẤT NHẬP KHẨU THÁI HƯNG PHÁT',
      'Job': 'Nhân Viên Cơ Khí/Thợ Hàn/Thợ Tiện Lắp Ráp Máy Bơm',
      'Location': 'Hà Nội',
      'Salary': '8 - 15 triệu',
    },
    {
      'Company': 'Công ty cổ phần Vật liệu Xây dựng Huy Hùng',
      'Job':
          'Nhân Viên Kế Toán Tổng Hợp Lương Cơ Bản Từ 15 Đến 20 Triệu Đồng - Có Ký Túc Xá Hỗ Trợ Nhân Viên Ở Xa',
      'Location': 'Hà Nam',
      'Salary': '15 - 20 triệu',
    },
    {
      'Company': 'Công ty cổ phần Vật liệu Xây dựng Huy Hùng',
      'Job':
          'Kế Toán Thuế - Lương Cơ Bản Từ 12 Đến 15 Triệu Đồng (Có Ký Túc Xá Hỗ Trợ Nhân Viên Ở Xa) Đi Làm Ngay',
      'Location': 'Hà Nam',
      'Salary': '12 - 15 triệu',
    },
    {
      'Company': 'Công ty cổ phần Vật liệu Xây dựng Huy Hùng',
      'Job':
          'Chuyên Viên Kiểm Soát Kiểm Toán Tài Chính Kế Toán Lương Cơ Bản Từ 12 Đến 15 Triệu Đồng (Có Ký Túc Xá Hỗ Trợ Nhân Viên Ở Xa)',
      'Location': 'Hà Nam',
      'Salary': '12 - 15 triệu',
    },
    {
      'Company': 'Công ty cổ phần Hai Bốn Bảy (247Express)',
      'Job': 'Trưởng Nhóm Kế Hoạch',
      'Location': 'Hồ Chí Minh',
      'Salary': 'Thoả thuận',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN THƯƠNG MẠI ĐIỆN MÁY HOA NAM',
      'Job':
          'Kế Toán Viên (Thu Nhập 12 -14 Triệu + Phụ Cấp + Thưởng) Đi Làm Ngay Tại Hà Nội',
      'Location': 'Hà Nội',
      'Salary': '12 - 14 triệu',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN DƯỢC MỸ PHẨM LSI VIỆT NAM',
      'Job':
          'Quản Lý Trình Dược Viên ETC - Lương Cứng 18 - 22 Triệu Tại Hà Nội',
      'Location': 'Hà Nội',
      'Salary': 'Thoả thuận',
    },
    {
      'Company': 'Công ty cổ phần công nghệ và giáo dục KSC',
      'Job':
          'Kế Toán Thuế Mảng Giáo Dục (Từ 3 Năm Kinh Nghiệm) - Thu Nhập Hấp Dẫn 12 - 16 Triệu/Tháng [Hà Nội]',
      'Location': 'Hà Nội',
      'Salary': '12 - 16 triệu',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN ĐẦU TƯ ĐỊA ỐC THÀNH ĐẠT',
      'Job':
          'Trưởng Phòng Kinh Doanh Bất Động Sản Thu Nhập Lên Đến 60 Triệu - Sản Phẩm Dễ Bán',
      'Location': 'Hồ Chí Minh',
      'Salary': '15 - 60 triệu',
    },
    {
      'Company': 'CÔNG TY CỔ PHẦN HÓA CHẤT XÂY DỰNG BÁCH KHOA',
      'Job': 'Nhân Viên Giám Sát Hiện Trường Thu Nhập Từ 14 -17 Triệu',
      'Location': 'Đồng Nai',
      'Salary': '14 - 17 triệu',
    },
  ];

  // Ghi nhiều document theo batch, chunk size <= 500
  static Future<void> seedJobs(
    List<Map<String, dynamic>> jobs, {
    String? ownerId,
  }) async {
    final col = FirebaseFirestore.instance.collection('JobCareers');
    const int chunkSize = 400; // an toàn < 500
    for (var i = 0; i < jobs.length; i += chunkSize) {
      final chunk = jobs.sublist(i, (i + chunkSize).clamp(0, jobs.length));
      final batch = FirebaseFirestore.instance.batch();
      for (final job in chunk) {
        final docRef = col.doc(); // tự tạo id
        final data = {...job, 'createdAt': FieldValue.serverTimestamp()};
        if (ownerId != null) data['ownerId'] = ownerId;
        batch.set(docRef, data);
      }
      await batch.commit();
      print('Seeded ${chunk.length} documents (batch ${i ~/ chunkSize + 1})');
    }
  }

  // Tiện ích: seed mẫu có sẵn
  static Future<void> seedSampleJobs({String? ownerId}) async =>
      seedJobs(_sampleJobs, ownerId: ownerId);
}
