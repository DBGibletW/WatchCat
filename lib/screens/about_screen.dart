import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF171320),
              Color(0xFF0A0A0E),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Üst bölüm: WatchCat logosu, büyük başlık ve açıklama
                    Column(
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: const Color(0xFF14141C),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0x55FF6B4A),
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22FF6B4A),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: CustomPaint(
                              painter: _WatchCatLogoPainter(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'WatchCat',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Kediler için eğlenceli video keşif platformu! 🐱',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFFB4B4C6),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Uygulama tanıtımı
                    _SectionCard(
                      title: 'Uygulama Hakkında',
                      child: const Text(
                        'WatchCat, kedi videolarını paylaşabileceğin, diğer kullanıcıların videolarını keşfedebileceğin ve yorumlarda etkileşim kurabileceğin bir platformdur.',
                        style: TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFFD0D0DE),
                          height: 1.55,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Geliştirici bilgileri
                    _SectionCard(
                      title: 'Geliştirici Bilgileri',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x1FFF6B4A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0x44FF6B4A),
                              ),
                            ),
                            child: const Text(
                              '🐾 Pawbyte Studio',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF8B70),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'WatchCat, Pawbyte Studio tarafından geliştirilmiştir.',
                            style: TextStyle(
                              fontSize: 14.5,
                              color: Color(0xFFD0D0DE),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Uygulama bilgileri
                    _SectionCard(
                      title: 'Uygulama Bilgileri',
                      child: const Column(
                        children: [
                          _InfoRow(label: 'Uygulama adı', value: 'WatchCat'),
                          Divider(height: 22, color: Color(0xFF262634)),
                          _InfoRow(
                            label: 'Geliştirici',
                            value: 'Pawbyte Studio',
                          ),
                          Divider(height: 22, color: Color(0xFF262634)),
                          _InfoRow(label: 'Sürüm', value: '1.0.0'),
                          Divider(height: 22, color: Color(0xFF262634)),
                          _InfoRow(label: 'Yıl', value: '2026'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Alt bilgi
                    const Text(
                      '© 2026 Pawbyte Studio. Tüm hakları saklıdır.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF8E8EA0),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14141C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF262634)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFFA0A0B2),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _WatchCatLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF14141C);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final scaleX = size.width / 512.0;
    final scaleY = size.height / 512.0;

    final coralPaint = Paint()
      ..color = const Color(0xFFFF6B4A)
      ..style = PaintingStyle.fill;

    final leftEar = Path()
      ..moveTo(115 * scaleX, 225 * scaleY)
      ..lineTo(140 * scaleX, 88 * scaleY)
      ..lineTo(238 * scaleX, 175 * scaleY)
      ..close();
    canvas.drawPath(leftEar, coralPaint);

    final rightEar = Path()
      ..moveTo(397 * scaleX, 225 * scaleY)
      ..lineTo(372 * scaleX, 88 * scaleY)
      ..lineTo(274 * scaleX, 175 * scaleY)
      ..close();
    canvas.drawPath(rightEar, coralPaint);

    canvas.drawOval(
      Rect.fromLTRB(
        106 * scaleX,
        145 * scaleY,
        406 * scaleX,
        425 * scaleY,
      ),
      coralPaint,
    );

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final playTriangle = Path()
      ..moveTo(220 * scaleX, 228 * scaleY)
      ..lineTo(220 * scaleX, 342 * scaleY)
      ..lineTo(322 * scaleX, 285 * scaleY)
      ..close();
    canvas.drawPath(playTriangle, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
