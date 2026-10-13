// lib/widgets/services_grid.dart
// 2-column grid of connected streaming services (Deezer, Amazon Music).

import 'package:flutter/material.dart';
import 'package:bella_music/theme/app_theme.dart';
import 'package:bella_music/widgets/glass_container.dart';

class ServicesGrid extends StatelessWidget {
  const ServicesGrid({super.key, required this.services});
  final List<Map<String, String>> services;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: services.length,
      itemBuilder: (context, i) => _ServiceTile(service: services[i]),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});
  final Map<String, String> service;

  @override
  Widget build(BuildContext context) {
    final isConnected = service['status'] == 'connected';
    return GradientCard(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(service['icon'] ?? '🎵', style: const TextStyle(fontSize: 24)),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected
                      ? const Color(0xFF22C55E)
                      : AppTheme.onSurfaceSub,
                  boxShadow: isConnected
                      ? [BoxShadow(
                          color: const Color(0xFF22C55E).withOpacity(0.6),
                          blurRadius: 6,
                        )]
                      : null,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service['name'] ?? '',
                style: const TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                isConnected ? 'Conectado' : 'Desconectado',
                style: TextStyle(
                  fontSize: 11,
                  color: isConnected
                      ? const Color(0xFF22C55E)
                      : AppTheme.onSurfaceSub,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
