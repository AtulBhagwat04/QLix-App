import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../storage/cache_manager.dart';
import '../network/api_client.dart';
import '../network/socket_client.dart';
import '../theme/app_theme.dart';
import '../constants/app_sizes.dart';
import '../constants/app_colors.dart';
import '../di/injection_container.dart';

Future<String?> autoDetectServerIp() async {
  final savedOverride = sl<CacheManager>().getServerIpOverride();
  final candidateHosts = <String>{
    if (kIsWeb) 'localhost',
    if (!kIsWeb) ...[
      if (savedOverride != null && savedOverride.trim().isNotEmpty)
        savedOverride.trim(),
      '10.109.186.64',
      '10.0.2.2',
      'localhost',
      '127.0.0.1',
      '10.202.235.64',
      '10.128.231.64',
    ],
  }.toList();

  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(milliseconds: 3000),
    receiveTimeout: const Duration(milliseconds: 3000),
  ));

  final completer = Completer<String?>();
  int completedCount = 0;

  for (final host in candidateHosts) {
    if (host.trim().isEmpty) continue;
    dio.get('http://${host.trim()}:3000/health').then((response) async {
      if (response.statusCode == 200 && !completer.isCompleted) {
        final workingIp = host.trim();
        await sl<CacheManager>().saveServerIpOverride(workingIp);
        sl<ApiClient>().updateBaseUrl(workingIp);
        sl<SocketClient>().reconnect();
        completer.complete(workingIp);
      }
    }).catchError((_) {
      // Ignore errors for individual host candidates
    }).whenComplete(() {
      completedCount++;
      if (completedCount >= candidateHosts.length && !completer.isCompleted) {
        completer.complete(null);
      }
    });
  }

  return completer.future;
}

void showNetworkSettingsDialog(BuildContext context) {
  final cache = sl<CacheManager>();
  final currentIp = cache.getServerIpOverride() ?? ApiClient.defaultHost;
  final controller = TextEditingController(text: currentIp);
  bool isSearching = false;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
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
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusInput,
                            ),
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
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'The server runs on port 3000 and is accessible on any IP address. Auto-detect or enter your host IP below.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark
                            ? Colors.white60
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: controller,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Backend IP / Host',
                        hintText: 'e.g. 192.168.1.100 or 10.0.2.2',
                        prefixIcon: const Icon(Icons.dns_rounded),
                        suffixIcon: isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.travel_explore_rounded),
                                tooltip: 'Auto-Detect Server IP',
                                onPressed: () async {
                                  setState(() => isSearching = true);
                                  final ip = await autoDetectServerIp();
                                  setState(() => isSearching = false);
                                  if (ip != null) {
                                    controller.text = ip;
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text('Server detected at: $ip'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } else {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text('No active server detected. Please enter IP manually.'),
                                          backgroundColor: Colors.orangeAccent,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
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
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textSecondaryLight,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          onPressed: () async {
                            final newIp = controller.text.trim();
                            if (newIp.isNotEmpty) {
                              await cache.saveServerIpOverride(newIp);
                              sl<ApiClient>().updateBaseUrl(newIp);
                              sl<SocketClient>().reconnect();

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Server IP updated to: $newIp'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radiusInput,
                                      ),
                                    ),
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
    },
  );
}
