import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/responsive.dart';

enum LoopHoleState { idle, pasted, downloading, success, error }

class LoopHoleButton extends StatefulWidget {
  final LoopHoleState state;
  final double progress; 
  final Color portalColor; // Dynamically mapped platform color
  final double? size;

  const LoopHoleButton({
    super.key,
    this.state = LoopHoleState.idle,
    this.progress = 0.0,
    this.portalColor = AppColors.neonPurple,
    this.size,
  });

  @override
  State<LoopHoleButton> createState() => _LoopHoleButtonState();
}

class _LoopHoleButtonState extends State<LoopHoleButton> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _glowAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void didUpdateWidget(LoopHoleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only restart animation if downloading state actually changed to avoid jarring frame jumps
    if (oldWidget.state != widget.state) {
      if (widget.state == LoopHoleState.downloading) {
        _rotationController.duration = const Duration(seconds: 2);
        _rotationController.repeat();
      } else if (oldWidget.state == LoopHoleState.downloading) {
        // Transitioning FROM downloading BACK to standard speed
        _rotationController.duration = const Duration(seconds: 8);
        _rotationController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildGradientRing(double size, double strokeWidth, double speedMultiplier, double opacity) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        final angle = _rotationController.value * 2 * 3.14159265 * speedMultiplier;
        final color = widget.portalColor;
        
        return Transform.rotate(
          angle: angle,
          child: CustomPaint(
            size: Size(size, size),
            painter: RingPainter(
              strokeWidth: strokeWidth,
              colors: [
                Colors.transparent,
                color.withValues(alpha: opacity * 0.4),
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * 0.4),
                Colors.transparent,
              ],
              stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size ?? context.rWidth(0.6);
    final double ratio = size / 200.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background pulsing glow behind entire logo
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                width: size * _glowAnimation.value * 0.8,
                height: size * _glowAnimation.value * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.portalColor.withValues(alpha: 0.12),
                      blurRadius: 35 * ratio,
                      spreadRadius: 8 * ratio,
                    )
                  ],
                ),
              );
            },
          ),
          
          // Main elements
          _buildLogoState(size, ratio),
        ],
      ),
    );
  }

  Widget _buildLogoState(double size, double ratio) {
    switch (widget.state) {
      case LoopHoleState.success:
        return _buildStatusIcon(Icons.check, AppColors.success, size, ratio)
            .animate()
            .scaleXY(begin: 0.8, end: 1.0, duration: 300.ms, curve: Curves.easeOutBack)
            .tint(color: AppColors.success, duration: 500.ms);

      case LoopHoleState.error:
        return _buildStatusIcon(Icons.close, AppColors.error, size, ratio)
            .animate()
            .shakeX(hz: 3, amount: 10 * ratio, duration: 500.ms)
            .tint(color: AppColors.error, duration: 300.ms);

      case LoopHoleState.downloading:
        return _buildDownloadingState(size, ratio);

      case LoopHoleState.idle:
      case LoopHoleState.pasted:
        return _buildRings(size, ratio);
    }
  }

  Widget _buildStatusIcon(IconData icon, Color color, double size, double ratio) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 4 * ratio),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 20 * ratio,
            spreadRadius: 5 * ratio,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 60 * ratio),
    );
  }

  Widget _buildDownloadingState(double size, double ratio) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildRings(size, ratio),
        // Event Horizon progress overlay directly integrated onto the outer ring radius
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: ProgressArcPainter(
              progress: widget.progress,
              strokeWidth: 4.0 * ratio,
              color: widget.portalColor,
              ratio: ratio,
            ),
          ),
        ),
        // Text % in the center
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Text(
              '${(widget.progress * 100).toInt()}%',
              textAlign: TextAlign.center,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22 * ratio,
              ),
            );
          }
        ),
      ],
    );
  }

  Widget _buildRings(double size, double ratio) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Concentric Vortex System recreating deep portal/wormhole projection:
        
        // 1. Slow-moving massive outer ghost ring
        _buildGradientRing(size, 1.0 * ratio, 1.0, 0.12),
        
        // 2. Mid-outer counter-spinning ring
        _buildGradientRing(size * 0.85, 1.8 * ratio, -1.0, 0.25),
        
        // 3. Inward structural ring
        _buildGradientRing(size * 0.70, 2.5 * ratio, 2.0, 0.45),
        
        // 4. Accretion disc inner layer
        _buildGradientRing(size * 0.55, 3.5 * ratio, -3.0, 0.65),
        
        // 5. High-velocity inward event horizon
        _buildGradientRing(size * 0.40, 5.0 * ratio, 5.0, 0.85),
        
        // 6. The tight Singularity spin ring
        _buildGradientRing(size * 0.25, 6.5 * ratio, -8.0, 1.0),

        // Core focal Singularity (the glowing dimensional center dot)
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            double scale = widget.state == LoopHoleState.pasted 
                ? 1.0 + (_pulseController.value * 0.4) 
                : 1.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: size * 0.08,
                height: size * 0.08,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.portalColor,
                  boxShadow: [
                    BoxShadow(
                      color: widget.portalColor,
                      blurRadius: 20 * ratio,
                      spreadRadius: 6 * ratio,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 4 * ratio,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class RingPainter extends CustomPainter {
  final double strokeWidth;
  final List<Color> colors;
  final List<double> stops;

  RingPainter({
    required this.strokeWidth, 
    required this.colors,
    required this.stops,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;
    
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      colors: colors,
      stops: stops,
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(RingPainter oldDelegate) => false;
}

class ProgressArcPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final double ratio;
  
  ProgressArcPainter({
    required this.progress, 
    this.strokeWidth = 4.0,
    required this.color,
    required this.ratio,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    
    // Match RingPainter logic: Outer ring is drawn with size=size, strokeWidth=strokeWidth
    final radius = (size.width / 2) - strokeWidth;
    
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    // Glowing underlay arc for bloom effect
    final bloomPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 6 * ratio
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 * ratio)
      ..strokeCap = StrokeCap.round;

    // Solid neon stroke for edge definition
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
      
    // Start from the top (-pi/2)
    const startAngle = -1.570796; 
    final sweepAngle = 2 * 3.14159265 * progress;
    
    // Draw bloom layer first
    canvas.drawArc(rect, startAngle, sweepAngle, false, bloomPaint);
    
    // Draw bright layer on top
    canvas.drawArc(rect, startAngle, sweepAngle, false, strokePaint);
  }

  @override
  bool shouldRepaint(covariant ProgressArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.strokeWidth != strokeWidth || oldDelegate.ratio != ratio;
  }
}
