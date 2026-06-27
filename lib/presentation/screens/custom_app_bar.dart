import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    this.title = 'LoopHole',
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      title: Text(
        title,
        style: GoogleFonts.orbitron(
          color: AppColors.neonPurple,
          fontSize: 28, // Bigger, more dramatic
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          shadows: [
            BoxShadow(
              color: AppColors.neonPurpleGlow.withValues(alpha: 0.5),
              blurRadius: 10,
            ),
          ],
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.neonPurple,
        size: 28,
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2.0),
        child: Container(
          height: 2.0,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.background,
                AppColors.neonPurple.withValues(alpha: 0.5),
                AppColors.background,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 2.0);
}
