import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:apps_k24/services/http_debug_logger.dart';

class HttpDebugOverlay extends StatefulWidget {
  final Widget child;

  const HttpDebugOverlay({super.key, required this.child});

  @override
  State<HttpDebugOverlay> createState() => _HttpDebugOverlayState();
}

class _HttpDebugOverlayState extends State<HttpDebugOverlay> {
  // Offset for draggable badge position
  Offset _position = const Offset(16, 120);
  bool _isInspectorOpen = false;
  HttpLogItem? _selectedLog;

  @override
  Widget build(BuildContext context) {
    // In production / release mode, render child as-is without overlay
    if (!kDebugMode) {
      return widget.child;
    }

    final mediaQuery = MediaQuery.of(context);

    return Material(
      color: Colors.transparent,
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) => Stack(
              children: [
                // Main app content
                widget.child,

                // Draggable Floating Debug Badge
                ValueListenableBuilder<List<HttpLogItem>>(
                  valueListenable: HttpDebugLogger.logsNotifier,
                  builder: (context, logs, _) {
                    final total = logs.length;
                    final errorCount = logs.where((l) => l.isError).length;

                    return Positioned(
                      left: _position.dx.clamp(0, mediaQuery.size.width - 100),
                      top: _position.dy.clamp(0, mediaQuery.size.height - 60),
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            _position += details.delta;
                          });
                        },
                        onTap: () {
                          setState(() {
                            _isInspectorOpen = true;
                            _selectedLog = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: errorCount > 0
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(
                              color: errorCount > 0
                                  ? const Color(0xFFFF8A80)
                                  : const Color(0xFF38BDF8),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                errorCount > 0
                                    ? Icons.error_outline_rounded
                                    : Icons.api_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'API ($total${errorCount > 0 ? " | $errorCount ❌" : ""})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // In-App Inspector Modal Layer (Self-Contained Overlay)
                if (_isInspectorOpen) ...[
                  // Dark Backdrop
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isInspectorOpen = false;
                          _selectedLog = null;
                        });
                      },
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ),

                  // Bottom Inspector Panel / Detail Panel
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: mediaQuery.size.height * 0.88,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: Material(
                        color: const Color(0xFF0F172A),
                        child: _selectedLog != null
                            ? HttpLogDetailModal(
                                item: _selectedLog!,
                                onBack: () {
                                  setState(() {
                                    _selectedLog = null;
                                  });
                                },
                              )
                            : HttpDebugInspectorModal(
                                onClose: () {
                                  setState(() {
                                    _isInspectorOpen = false;
                                    _selectedLog = null;
                                  });
                                },
                                onSelectLog: (log) {
                                  setState(() {
                                    _selectedLog = log;
                                  });
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HttpDebugInspectorModal extends StatefulWidget {
  final VoidCallback onClose;
  final Function(HttpLogItem) onSelectLog;

  const HttpDebugInspectorModal({
    super.key,
    required this.onClose,
    required this.onSelectLog,
  });

  @override
  State<HttpDebugInspectorModal> createState() => _HttpDebugInspectorModalState();
}

class _HttpDebugInspectorModalState extends State<HttpDebugInspectorModal> {
  String _searchQuery = '';
  String _filterMode = 'ALL'; // ALL, SUCCESS, ERROR

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<HttpLogItem>>(
      valueListenable: HttpDebugLogger.logsNotifier,
      builder: (context, logs, _) {
        final filteredLogs = logs.where((item) {
          final matchesFilter = _filterMode == 'ALL' ||
              (_filterMode == 'SUCCESS' && item.isSuccess) ||
              (_filterMode == 'ERROR' && item.isError);

          if (!matchesFilter) return false;

          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return item.url.toLowerCase().contains(q) ||
              item.method.toLowerCase().contains(q) ||
              (item.statusCode?.toString() ?? '').contains(q);
        }).toList();

        final errorCount = logs.where((l) => l.isError).length;

        return Column(
          children: [
            // Header Handle Bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.bug_report_rounded, color: Color(0xFF38BDF8), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HTTP API Inspector',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Total: ${logs.length} req | Error: $errorCount',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                    onPressed: () {
                      HttpDebugLogger.clearLogs();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),

            // Search Bar & Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari URL, endpoint, atau status...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFilterChip('ALL', 'Semua (${logs.length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('SUCCESS', 'Success (${logs.where((l) => l.isSuccess).length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('ERROR', 'Error ($errorCount)'),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 16),

            // Log Items List
            Expanded(
              child: filteredLogs.isEmpty
                  ? Center(
                      child: Text(
                        logs.isEmpty ? 'Belum ada panggilan HTTP API' : 'Tidak ada hasil filter',
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: filteredLogs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = filteredLogs[index];
                        return _buildLogItemTile(context, item);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String mode, String label) {
    final isSelected = _filterMode == mode;
    Color activeColor = const Color(0xFF38BDF8);
    if (mode == 'ERROR') activeColor = const Color(0xFFEF4444);
    if (mode == 'SUCCESS') activeColor = const Color(0xFF10B981);

    return GestureDetector(
      onTap: () {
        setState(() {
          _filterMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white12,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : Colors.white60,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLogItemTile(BuildContext context, HttpLogItem item) {
    Color methodColor;
    switch (item.method.toUpperCase()) {
      case 'GET':
        methodColor = const Color(0xFF3B82F6);
        break;
      case 'POST':
        methodColor = const Color(0xFF10B981);
        break;
      case 'PUT':
        methodColor = const Color(0xFFF59E0B);
        break;
      case 'DELETE':
        methodColor = const Color(0xFFEF4444);
        break;
      default:
        methodColor = const Color(0xFF8B5CF6);
    }

    final statusColor = item.isSuccess
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    final uri = Uri.tryParse(item.url);
    final path = uri?.path ?? item.url;
    final host = uri?.host ?? '';
    final timeStr = '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}:${item.timestamp.second.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () {
        widget.onSelectLog(item);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isError ? const Color(0xFFEF4444).withValues(alpha: 0.4) : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Method, Path, Status Code
            Row(
              children: [
                // Method Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: methodColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: methodColor, width: 0.8),
                  ),
                  child: Text(
                    item.method.toUpperCase(),
                    style: TextStyle(
                      color: methodColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Path
                Expanded(
                  child: Text(
                    path.isEmpty ? '/' : path,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(width: 8),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.statusCode != null ? '${item.statusCode}' : 'FAIL',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Row 2: Host & Timing info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    host,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.white38, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      '${item.durationMs} ms',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HttpLogDetailModal extends StatefulWidget {
  final HttpLogItem item;
  final VoidCallback onBack;

  const HttpLogDetailModal({
    super.key,
    required this.item,
    required this.onBack,
  });

  @override
  State<HttpLogDetailModal> createState() => _HttpLogDetailModalState();
}

class _HttpLogDetailModalState extends State<HttpLogDetailModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Column(
      children: [
        // Handle Bar
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white30,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Title & Status Summary Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.method,
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.statusCode != null ? '${item.statusCode}' : 'ERROR',
                          style: TextStyle(
                            color: item.isSuccess ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${item.durationMs} ms)',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      item.url,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: item.url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL disalin ke clipboard')),
                  );
                },
              ),
            ],
          ),
        ),

        if (item.errorMessage != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // Tab Bar (Request & Response)
        TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Request'),
            Tab(text: 'Response'),
          ],
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Request View
              _buildSectionView(
                context: context,
                headers: item.requestHeaders,
                body: item.requestBody,
                sectionTitle: 'Request JSON',
              ),

              // Response View
              _buildSectionView(
                context: context,
                headers: item.responseHeaders,
                body: item.responseBody,
                sectionTitle: 'Response JSON',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionView({
    required BuildContext context,
    required Map<String, String>? headers,
    required String? body,
    required String sectionTitle,
  }) {
    final prettyBody = HttpDebugLogger.prettyJson(body);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Copy Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sectionTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: const Color(0xFF38BDF8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy JSON', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: prettyBody));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$sectionTitle disalin ke clipboard')),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Body Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: SelectableText(
              prettyBody,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 11.5,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Headers Title
          const Text(
            'Headers',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),

          // Headers Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: headers == null || headers.isEmpty
                ? const Text(
                    '(Tidak ada header)',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: headers.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SelectableText.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${e.key}: ',
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              TextSpan(
                                text: e.value,
                                style: const TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
