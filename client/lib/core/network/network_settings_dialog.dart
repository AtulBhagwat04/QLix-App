import 'package:flutter/material.dart';
import '../storage/cache_manager.dart';
import '../network/api_client.dart';
import '../network/socket_client.dart';
import '../theme/app_theme.dart';
import '../constants/app_sizes.dart';
import '../constants/app_colors.dart';
import '../di/injection_container.dart';

void showNetworkSettingsDialog(BuildContext context) {
  final cache = sl<CacheManager>();
  final currentIp = cache.getServerIpOverride() ?? '10.197.55.64';
  final controller = TextEditingController(text: currentIp);

  showDialog(
    context: context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: AppDecoration.glassWrapper(
          context: ctx,
          borderRadius: AppSizes.radiusCard,
          blur: 24.0,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppSizes.radiusInput),
                      ),
                      child: const Icon(
                        Icons.settings_ethernet_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Server Settings',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Specify the IP address or host domain of your QLix backend. Both client and server must be on the same local subnet to connect.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: controller,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Backend IP / Host',
                    hintText: 'e.g. 192.168.1.100',
                    prefixIcon: Icon(Icons.dns_rounded),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onPressed: () async {
                        final newIp = controller.text.trim();
                        if (newIp.isNotEmpty) {
                          await cache.saveServerIpOverride(newIp);
                          sl<ApiClient>().updateBaseUrl(newIp);
                          sl<SocketClient>().disconnect();
                          sl<SocketClient>().connect();
                          
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Server IP updated to: $newIp'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusInput)),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Save & Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

