import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../services/api_service.dart';
import '../services/local_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class AdminDashboardPage extends StatefulWidget {
  final int initialTab;

  const AdminDashboardPage({super.key, this.initialTab = 0});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class RevenueAnalyticsPage extends StatelessWidget {
  const RevenueAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardPage(initialTab: 2);
  }
}

class DriverStatsPage extends StatelessWidget {
  const DriverStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardPage(initialTab: 2);
  }
}

class StudentStatsPage extends StatelessWidget {
  const StudentStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardPage(initialTab: 2);
  }
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _tab = 0;
  bool _loading = true;
  bool _loadingAnalytics = false;
  bool _loadingAudit = false;
  String? _error;

  Map<String, dynamic> _dashboard = {};
  Map<String, dynamic> _revenue = {};
  Map<String, dynamic> _peakHours = {};
  Map<String, dynamic> _driverPerformance = {};
  Map<String, dynamic> _studentStats = {};

  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _studentTripAudit = [];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 3);
    _loadBase();
  }

  Future<void> _loadBase() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getAdminDashboard(),
        ApiService.getAdminRevenue(),
        ApiService.getAdminPeakHours(),
        ApiService.getAdminBuses(),
        ApiService.getAdminDrivers(),
        ApiService.getBusAssignments(),
      ]);

      if (!mounted) return;
      setState(() {
        _dashboard = results[0] as Map<String, dynamic>;
        _revenue = results[1] as Map<String, dynamic>;
        _peakHours = results[2] as Map<String, dynamic>;
        _buses = (results[3] as List).cast<Map<String, dynamic>>();
        _drivers = (results[4] as List).cast<Map<String, dynamic>>();
        _assignments = (results[5] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });

      if (_tab == 2) {
        await _loadAnalytics();
      } else if (_tab == 3) {
        await _loadAudit();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadAnalytics({bool force = false}) async {
    if (_loadingAnalytics) return;
    if (!force && _driverPerformance.isNotEmpty && _studentStats.isNotEmpty) return;
    setState(() => _loadingAnalytics = true);
    try {
      final results = await Future.wait([
        ApiService.getAdminDriverPerformance(),
        ApiService.getAdminStudentStats(),
      ]);
      if (!mounted) return;
      setState(() {
        _driverPerformance = results[0];
        _studentStats = results[1];
        _loadingAnalytics = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingAnalytics = false;
      });
    }
  }

  Future<void> _loadAudit({bool force = false}) async {
    if (_loadingAudit) return;
    if (!force && _studentTripAudit.isNotEmpty) return;
    setState(() => _loadingAudit = true);
    try {
      final rows = await ApiService.getAdminStudentTripAudit();
      if (!mounted) return;
      setState(() {
        _studentTripAudit = rows;
        _loadingAudit = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingAudit = false;
      });
    }
  }

  Future<void> _refreshCurrentTab() async {
    await _loadBase();
    if (_tab == 2) {
      await _loadAnalytics(force: true);
    } else if (_tab == 3) {
      await _loadAudit(force: true);
    }
  }

  Future<void> _onTabSelected(int index) async {
    setState(() => _tab = index);
    if (index == 2) {
      await _loadAnalytics();
    } else if (index == 3) {
      await _loadAudit();
    }
  }

  Future<void> _logout() async {
    await LocalStorage.clearAll();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  String _fmtDate(dynamic value) {
    if (value == null) return '-';
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OverviewPage(
        dashboard: _dashboard,
        revenue: _revenue,
        peakHours: _peakHours,
        onRefresh: _refreshCurrentTab,
      ),
      _OperationsPage(
        buses: _buses,
        drivers: _drivers,
        assignments: _assignments,
        fmtDate: _fmtDate,
        onMutated: _refreshCurrentTab,
      ),
      _AnalyticsPage(
        revenue: _revenue,
        driverPerformance: _driverPerformance,
        studentStats: _studentStats,
        isLoading: _loadingAnalytics,
      ),
      _AuditPage(
        rows: _studentTripAudit,
        fmtDate: _fmtDate,
        isLoading: _loadingAudit,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ['Overview', 'Operations', 'Analytics', 'Travel Audit'][_tab],
        ),
        actions: [
          IconButton(onPressed: _refreshCurrentTab, icon: const Icon(Icons.refresh_rounded)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: _loading
            ? const _SmoothLoadView()
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _refreshCurrentTab)
                : pages[_tab],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ops'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'Audit'),
        ],
      ),
    );
  }
}

class _OverviewPage extends StatelessWidget {
  final Map<String, dynamic> dashboard;
  final Map<String, dynamic> revenue;
  final Map<String, dynamic> peakHours;
  final Future<void> Function() onRefresh;

  const _OverviewPage({
    required this.dashboard,
    required this.revenue,
    required this.peakHours,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final totals = (dashboard['totals'] as Map<String, dynamic>? ?? const {});
    final revPoints = (dashboard['revenue_time_series'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final topDrivers = (dashboard['top_drivers'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final topBuses = (dashboard['top_buses'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          const AppPageHeader(
            title: 'Admin Control Center',
            subtitle: 'Quick snapshot of operations, revenue, and traffic timings.',
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 340;
              final cards = [
                _KpiCard(icon: Icons.school_outlined, label: 'Students', value: '${totals['students'] ?? 0}'),
                _KpiCard(icon: Icons.badge_outlined, label: 'Drivers', value: '${totals['drivers'] ?? 0}'),
                _KpiCard(icon: Icons.directions_bus_outlined, label: 'Buses', value: '${totals['buses'] ?? 0}'),
                _KpiCard(icon: Icons.route_outlined, label: 'Trips', value: '${totals['trips'] ?? 0}'),
                _KpiCard(icon: Icons.play_circle_outline, label: 'Active Trips', value: '${totals['active_trips'] ?? 0}', accent: AppColors.warning),
                _KpiCard(icon: Icons.currency_rupee, label: 'Revenue', value: '₹${totals['revenue'] ?? 0}', accent: AppColors.success),
              ];

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: twoColumns ? 2 : 1,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 108,
                ),
                itemBuilder: (_, i) => cards[i],
              );
            },
          ),
          const SizedBox(height: 12),
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Revenue over time', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 220,
                  child: revPoints.isEmpty
                      ? const Center(child: Text('No revenue data yet'))
                      : revPoints.length < 2
                          ? _SinglePointRevenueHint(
                              totalRevenue: (totals['revenue'] as num?)?.toDouble() ?? 0,
                              singlePointValue: (revPoints.first['value'] as num?)?.toDouble() ?? 0,
                            )
                          : _ScrollableRevenueChart(points: revPoints, height: 220),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Peak tap hours', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 210,
                  child: _PopularTimesBars(peakHours: peakHours),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 760;
              if (isNarrow) {
                return Column(
                  children: [
                    _TopRevenueList(title: 'Revenue by driver', items: (revenue['driver']?['points'] as List? ?? topDrivers).cast<Map<String, dynamic>>()),
                    const SizedBox(height: 10),
                    _TopRevenueList(title: 'Revenue by bus', items: (revenue['bus']?['points'] as List? ?? topBuses).cast<Map<String, dynamic>>()),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _TopRevenueList(title: 'Revenue by driver', items: (revenue['driver']?['points'] as List? ?? topDrivers).cast<Map<String, dynamic>>())),
                  const SizedBox(width: 10),
                  Expanded(child: _TopRevenueList(title: 'Revenue by bus', items: (revenue['bus']?['points'] as List? ?? topBuses).cast<Map<String, dynamic>>())),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OperationsPage extends StatefulWidget {
  final List<Map<String, dynamic>> buses;
  final List<Map<String, dynamic>> drivers;
  final List<Map<String, dynamic>> assignments;
  final String Function(dynamic) fmtDate;
  final Future<void> Function() onMutated;

  const _OperationsPage({
    required this.buses,
    required this.drivers,
    required this.assignments,
    required this.fmtDate,
    required this.onMutated,
  });

  @override
  State<_OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<_OperationsPage> {
  final TextEditingController _busNo = TextEditingController();
  final TextEditingController _route = TextEditingController();
  final TextEditingController _capacity = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  String? _driverId;
  String? _busId;
  DateTime _startTime = DateTime.now();
  DateTime? _endTime;
  bool _creatingBus = false;
  bool _assigning = false;

  @override
  void initState() {
    super.initState();
    _driverId = widget.drivers.isNotEmpty ? widget.drivers.first['id']?.toString() : null;
    _busId = widget.buses.isNotEmpty ? widget.buses.first['id']?.toString() : null;
  }

  @override
  void didUpdateWidget(covariant _OperationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_driverId == null && widget.drivers.isNotEmpty) {
      _driverId = widget.drivers.first['id']?.toString();
    }
    if (_busId == null && widget.buses.isNotEmpty) {
      _busId = widget.buses.first['id']?.toString();
    }
  }

  @override
  void dispose() {
    _busNo.dispose();
    _route.dispose();
    _capacity.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _createBus() async {
    final busNo = _busNo.text.trim();
    final route = _route.text.trim();
    final capacity = int.tryParse(_capacity.text.trim()) ?? 0;
    if (busNo.isEmpty || route.isEmpty || capacity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid bus number, route, and capacity.')),
      );
      return;
    }

    setState(() => _creatingBus = true);
    try {
      await ApiService.createAdminBus(
        busNumber: busNo,
        routeName: route,
        capacity: capacity,
      );
      _busNo.clear();
      _route.clear();
      _capacity.clear();
      await widget.onMutated();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus created successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create bus: $e')),
      );
    } finally {
      if (mounted) setState(() => _creatingBus = false);
    }
  }

  Future<void> _assignBus() async {
    if (_driverId == null || _busId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a driver and bus first.')),
      );
      return;
    }

    if (_endTime != null && _endTime!.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }

    setState(() => _assigning = true);
    try {
      await ApiService.createBusAssignment(
        driverId: _driverId!,
        busId: _busId!,
        startTime: _startTime,
        endTime: _endTime,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      _notes.clear();
      await widget.onMutated();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus assigned to driver.')),
      );
    } catch (e) {
      if (!mounted) return;
      String errorMsg = e.toString();
      final detailMatch = RegExp(r'"detail"\s*:\s*"([^"]+)"').firstMatch(errorMsg);
      if (detailMatch != null) {
        errorMsg = detailMatch.group(1)!;
      } else if (errorMsg.contains('Exception:')) {
        errorMsg = errorMsg.replaceFirst(RegExp(r'^.*?Exception:\s*'), '').trim();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assignment failed: $errorMsg')),
      );
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _pickStartTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (_endTime != null && _endTime!.isBefore(_startTime)) {
        _endTime = _startTime.add(const Duration(hours: 8));
      }
    });
  }

  Future<void> _pickEndTime() async {
    final fallback = _endTime ?? _startTime.add(const Duration(hours: 8));
    final date = await showDatePicker(
      context: context,
      initialDate: fallback,
      firstDate: _startTime,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(fallback),
    );
    if (time == null || !mounted) return;
    setState(() {
      _endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _fmtDateTime(DateTime dt) {
    final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} $hh:$mm $ampm';
  }

  @override
  Widget build(BuildContext context) {
    String driverName(String? id) {
      final row = widget.drivers.where((d) => d['id']?.toString() == id).toList();
      if (row.isEmpty) return 'Unknown driver';
      return row.first['name']?.toString() ?? 'Unknown driver';
    }

    String busName(String? id) {
      final row = widget.buses.where((b) => b['id']?.toString() == id).toList();
      if (row.isEmpty) return 'Unknown bus';
      return '${row.first['bus_number'] ?? '-'} (${row.first['route_name'] ?? 'No route'})';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        const AppPageHeader(
          title: 'Bus and driver operations',
          subtitle: 'Add buses and allocate them to available drivers.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 800;
            final addBusCard = AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add bus', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(controller: _busNo, decoration: const InputDecoration(labelText: 'Bus number (e.g. BUS-101)')),
                  const SizedBox(height: 10),
                  TextField(controller: _route, decoration: const InputDecoration(labelText: 'Route name')),
                  const SizedBox(height: 10),
                  TextField(controller: _capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity')),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _creatingBus ? null : _createBus,
                    icon: _creatingBus
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_rounded),
                    label: Text(_creatingBus ? 'Creating...' : 'Create bus'),
                  ),
                ],
              ),
            );

            final assignCard = AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Allocate bus', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _driverId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Driver'),
                    onChanged: (v) => setState(() => _driverId = v),
                    items: widget.drivers
                        .map((d) => DropdownMenuItem(
                              value: d['id']?.toString(),
                              child: Text(
                                d['name']?.toString() ?? 'Driver',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _busId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Bus'),
                    onChanged: (v) => setState(() => _busId = v),
                    items: widget.buses
                        .map((b) => DropdownMenuItem(
                              value: b['id']?.toString(),
                              child: Text(
                                '${b['bus_number'] ?? '-'} | ${b['route_name'] ?? 'No route'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickStartTime,
                          icon: const Icon(Icons.event_available_rounded),
                          label: Text(
                            'Start: ${_fmtDateTime(_startTime)}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickEndTime,
                          icon: const Icon(Icons.event_busy_rounded),
                          label: Text(
                            _endTime == null
                                ? 'Set end time (optional)'
                                : 'End: ${_fmtDateTime(_endTime!)}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_endTime != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _endTime = null),
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('Clear end time'),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _assigning ? null : _assignBus,
                    icon: _assigning
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.link_rounded),
                    label: Text(_assigning ? 'Assigning...' : 'Assign bus'),
                  ),
                ],
              ),
            );

            if (narrow) {
              return Column(
                children: [addBusCard, const SizedBox(height: 10), assignCard],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: addBusCard),
                const SizedBox(width: 10),
                Expanded(child: assignCard),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Live assignments', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              if (widget.assignments.isEmpty)
                const Text('No assignments available', style: TextStyle(color: AppColors.mutedText))
              else
                ...widget.assignments.take(20).map((a) {
                  final did = a['driver_id']?.toString();
                  final bid = a['bus_id']?.toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${driverName(did)} -> ${busName(bid)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            'Start ${widget.fmtDate(a['start_time'])} | End ${widget.fmtDate(a['end_time'])}',
                            style: const TextStyle(color: AppColors.mutedText),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsPage extends StatelessWidget {
  final Map<String, dynamic> revenue;
  final Map<String, dynamic> driverPerformance;
  final Map<String, dynamic> studentStats;
  final bool isLoading;

  const _AnalyticsPage({
    required this.revenue,
    required this.driverPerformance,
    required this.studentStats,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final revenuePoints = (revenue['time_series']?['points'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        const AppPageHeader(
          title: 'Analytics',
          subtitle: 'Revenue, driver performance, and student usage trends.',
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Daily revenue trend', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              SizedBox(
                height: 240,
                  child: isLoading && revenuePoints.isEmpty
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : revenuePoints.isEmpty
                    ? const Center(child: Text('No data'))
                    : revenuePoints.length < 2
                        ? _SinglePointRevenueHint(
                            totalRevenue: revenuePoints.fold<double>(
                              0,
                              (sum, p) => sum + ((p['value'] as num?)?.toDouble() ?? 0),
                            ),
                            singlePointValue: (revenuePoints.first['value'] as num?)?.toDouble() ?? 0,
                          )
                        : _ScrollableRevenueChart(points: revenuePoints, height: 240),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Revenue per driver', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              SizedBox(
                height: 260,
                child: isLoading && (driverPerformance['labels'] as List? ?? const []).isEmpty
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : BarChart(_barFromDriverRevenue(driverPerformance)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Student trip status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              SizedBox(
                height: 240,
                child: isLoading && (studentStats['status_distribution'] == null)
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _InteractiveStatusPie(studentStats: studentStats),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuditPage extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final String Function(dynamic) fmtDate;
  final bool isLoading;

  const _AuditPage({required this.rows, required this.fmtDate, required this.isLoading});

  @override
  State<_AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<_AuditPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final query = _q.trim().toLowerCase();
    final rows = query.isEmpty
        ? widget.rows
        : widget.rows.where((r) {
            final fields = [
              r['student_name'],
              r['trip_name'],
              r['bus_number'],
              r['route_name'],
              r['driver_name'],
              r['nfc_id'],
            ].map((e) => (e ?? '').toString().toLowerCase());
            return fields.any((f) => f.contains(query));
          }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        const AppPageHeader(
          title: 'Student travel audit',
          subtitle: 'Search who traveled in which trip, bus, route, and time.',
        ),
        const SizedBox(height: 10),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(
            labelText: 'Search by student, trip, bus, route, NFC',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        if (widget.isLoading && rows.isEmpty)
          const AppSurfaceCard(
            child: SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          )
        else if (rows.isEmpty)
          const AppSurfaceCard(
            child: Text('No travel records found', style: TextStyle(color: AppColors.mutedText)),
          )
        else
          ...rows.take(40).map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppSurfaceCard(
                padding: const EdgeInsets.all(12),
                color: AppColors.surfaceAlt,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row['student_name'] ?? 'Unknown'} | ${row['trip_name'] ?? 'Trip'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Bus ${row['bus_number'] ?? '-'} | Route ${row['route_name'] ?? 'Unknown'} | Driver ${row['driver_name'] ?? 'Unknown'}',
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tap ${widget.fmtDate(row['timestamp'])} | NFC ${row['nfc_id']} | ${row['status']} | Fare ₹${row['fare_paid'] ?? 0}',
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.accent;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(color: AppColors.mutedText)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopRevenueList extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;

  const _TopRevenueList({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('No data', style: TextStyle(color: AppColors.mutedText))
          else
            ...items.take(6).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['label']?.toString() ?? '-',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '₹${item['value'] ?? 0}',
                        style: const TextStyle(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _SinglePointRevenueHint extends StatelessWidget {
  final double totalRevenue;
  final double singlePointValue;

  const _SinglePointRevenueHint({
    required this.totalRevenue,
    required this.singlePointValue,
  });

  @override
  Widget build(BuildContext context) {
    final totalText = totalRevenue.toStringAsFixed(totalRevenue % 1 == 0 ? 0 : 1);
    final pointText = singlePointValue.toStringAsFixed(singlePointValue % 1 == 0 ? 0 : 1);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Not enough points for a trend chart yet',
            style: TextStyle(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text('Total revenue: ₹$totalText'),
          Text('Current period revenue: ₹$pointText', style: const TextStyle(color: AppColors.mutedText)),
        ],
      ),
    );
  }
}

class _PopularTimesBars extends StatelessWidget {
  final Map<String, dynamic> peakHours;

  const _PopularTimesBars({required this.peakHours});

  @override
  Widget build(BuildContext context) {
    final labels = (peakHours['labels'] as List? ?? const []).map((e) => e.toString()).toList();
    final values = (peakHours['values'] as List? ?? const []).map((e) => (e as num).toDouble()).toList();
    if (labels.isEmpty || values.isEmpty) {
      return const Center(child: Text('No peak-hour data yet'));
    }
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final maxY = (maxValue + _niceInterval(maxValue)).ceilToDouble();
    final step = math.max(1, (labels.length / 6).ceil());
    final nowHour = DateTime.now().hour;

    final chartWidth = math.max(360.0, labels.length * 34.0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        child: BarChart(
          BarChartData(
        minY: 0,
        maxY: maxY <= 0 ? 10 : maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: _niceInterval(maxValue),
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.border.withValues(alpha: 0.65),
            strokeWidth: 1,
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            getTooltipColor: (_) => AppColors.surface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = labels[group.x.toInt()];
              final taps = rod.toY.toStringAsFixed(0);
              return BarTooltipItem(
                '${_formatHourLabel(label)}\n$taps taps',
                const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: _niceInterval(maxValue),
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    _compactNumber(value),
                    style: const TextStyle(fontSize: 10, color: AppColors.mutedText),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                if (i % step != 0 && i != labels.length - 1) return const SizedBox.shrink();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    _formatHourLabel(labels[i]),
                    style: const TextStyle(fontSize: 9, color: AppColors.mutedText),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(labels.length, (i) {
          final hour = int.tryParse(labels[i].split(':').first) ?? -1;
          final isCurrent = hour == nowHour;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: i < values.length ? values[i] : 0,
                width: 12,
                borderRadius: BorderRadius.circular(8),
                color: isCurrent ? const Color(0xFFE58E8E) : const Color(0xFFC7C7C7),
              ),
            ],
          );
        }),
          ),
        ),
      ),
    );
  }
}

class _ScrollableRevenueChart extends StatefulWidget {
  final List<Map<String, dynamic>> points;
  final double height;

  const _ScrollableRevenueChart({required this.points, required this.height});

  @override
  State<_ScrollableRevenueChart> createState() => _ScrollableRevenueChartState();
}

class _ScrollableRevenueChartState extends State<_ScrollableRevenueChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final width = math.max(340.0, widget.points.length * 22.0);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: widget.height,
        child: LineChart(
          _lineFromPoints(
            widget.points,
            touchedIndex: _touchedIndex,
            onTouchedIndexChanged: (idx) {
              if (!mounted) return;
              setState(() => _touchedIndex = idx);
            },
          ),
        ),
      ),
    );
  }
}

class _InteractiveStatusPie extends StatefulWidget {
  final Map<String, dynamic> studentStats;

  const _InteractiveStatusPie({required this.studentStats});

  @override
  State<_InteractiveStatusPie> createState() => _InteractiveStatusPieState();
}

class _InteractiveStatusPieState extends State<_InteractiveStatusPie> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final dist = (widget.studentStats['status_distribution'] as Map<String, dynamic>? ?? const {});
    final labels = (dist['labels'] as List? ?? const []).map((e) => e.toString()).toList();
    final values = (dist['values'] as List? ?? const []).map((e) => (e as num).toDouble()).toList();
    final total = values.fold<double>(0, (a, b) => a + b);
    if (labels.isEmpty) {
      return const Center(child: Text('No status data'));
    }

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 34,
              sectionsSpace: 3,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (!mounted) return;
                  final idx = response?.touchedSection?.touchedSectionIndex ?? -1;
                  setState(() => _touchedIndex = idx);
                },
              ),
              sections: List.generate(labels.length, (i) {
                final value = i < values.length ? values[i] : 0.0;
                final pct = total > 0 ? (value / total) * 100 : 0;
                final touched = i == _touchedIndex;
                return PieChartSectionData(
                  value: value,
                  color: _seriesColor(i),
                  radius: touched ? 82.0 : 70.0,
                  title: touched ? '${labels[i]}\n${pct.toStringAsFixed(1)}%' : '${pct.toStringAsFixed(0)}%',
                  titleStyle: TextStyle(
                    color: Colors.white,
                    fontSize: touched ? 11.0 : 10.0,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: List.generate(labels.length, (i) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: _seriesColor(i), borderRadius: BorderRadius.circular(99)),
                ),
                const SizedBox(width: 6),
                Text(labels[i], style: const TextStyle(fontSize: 11)),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _SmoothLoadView extends StatefulWidget {
  const _SmoothLoadView();

  @override
  State<_SmoothLoadView> createState() => _SmoothLoadViewState();
}

class _SmoothLoadViewState extends State<_SmoothLoadView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AppSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 50),
              const SizedBox(height: 12),
              const Text('Loading admin workspace...', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: 0.18 + (_controller.value * 0.78),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: AppColors.surfaceAlt,
                    color: AppColors.accent,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AppSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 54, color: AppColors.danger),
              const SizedBox(height: 10),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

LineChartData _lineFromPoints(
  List<Map<String, dynamic>> points, {
  int? touchedIndex,
  ValueChanged<int?>? onTouchedIndexChanged,
}) {
  final spots = <FlSpot>[];
  for (var i = 0; i < points.length; i++) {
    final y = (points[i]['value'] as num?)?.toDouble() ?? 0;
    spots.add(FlSpot(i.toDouble(), y));
  }

  final maxY = spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b);
  final interval = _niceInterval(maxY);
  final step = math.max(1, (points.length / 6).ceil());

  return LineChartData(
    borderData: FlBorderData(show: false),
    gridData: FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => FlLine(
        color: AppColors.border.withValues(alpha: 0.7),
        strokeWidth: 1,
      ),
    ),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 34,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= points.length) return const SizedBox.shrink();
            if (i % step != 0 && i != points.length - 1) return const SizedBox.shrink();
            final raw = points[i]['timestamp']?.toString() ?? '';
            final label = _formatTimeLabel(raw, dense: points.length > 36);
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              child: Text(label, style: const TextStyle(fontSize: 9)),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 56,
          interval: interval,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text(
                _compactNumber(value),
                style: const TextStyle(fontSize: 10, color: AppColors.mutedText),
              ),
            );
          },
        ),
      ),
    ),
    minY: 0,
    maxY: maxY + interval,
    lineTouchData: LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => AppColors.surface,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        tooltipRoundedRadius: 10,
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final idx = spot.x.toInt();
            if (idx < 0 || idx >= points.length) {
              return null;
            }
            final raw = points[idx]['timestamp']?.toString() ?? '';
            final y = (points[idx]['value'] as num?)?.toDouble() ?? 0;
            return LineTooltipItem(
              '${_formatTooltipDate(raw)}\nRevenue: ₹${y.toStringAsFixed(0)}',
              const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
            );
          }).toList();
        },
      ),
      touchCallback: (event, response) {
        if (onTouchedIndexChanged == null) return;
        final idx = response?.lineBarSpots?.isNotEmpty == true
            ? response!.lineBarSpots!.first.x.toInt()
            : null;
        onTouchedIndexChanged(idx);
      },
    ),
    lineBarsData: [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        barWidth: 3,
        color: AppColors.accent,
        dotData: FlDotData(
          show: true,
          checkToShowDot: (spot, barData) => touchedIndex != null && spot.x.toInt() == touchedIndex,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: 4,
            color: AppColors.accent,
            strokeWidth: 1.5,
            strokeColor: AppColors.surface,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: AppColors.surfaceAlt.withValues(alpha: 0.35),
        ),
      ),
    ],
  );
}

BarChartData _barFromDriverRevenue(Map<String, dynamic> performance) {
  final labels = (performance['labels'] as List? ?? const []).map((e) => e.toString()).toList();
  final datasets = (performance['datasets'] as List? ?? const []).cast<Map<String, dynamic>>();
  final values = datasets.isNotEmpty
      ? (datasets.first['values'] as List).map((e) => (e as num).toDouble()).toList()
      : <double>[];
  final maxY = values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b).ceilToDouble();
  final interval = maxY <= 20 ? 5.0 : (maxY / 4).ceilToDouble();

  final step = math.max(1, (labels.length / 6).ceil());

  return BarChartData(
    alignment: BarChartAlignment.spaceAround,
    groupsSpace: 8,
    minY: 0,
    maxY: maxY + interval,
    barGroups: List.generate(labels.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: i < values.length ? values[i] : 0,
            color: _seriesColor(i),
            width: 10,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      );
    }),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: interval,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= labels.length) return const SizedBox.shrink();
            if (i % step != 0 && i != labels.length - 1) return const SizedBox.shrink();
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              child: Text(
                _shortName(labels[i]),
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ),
    ),
  );
}

String _compactNumber(num value) {
  final abs = value.abs();
  if (abs >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
  if (abs >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
  if (abs >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toStringAsFixed(0);
}

double _niceInterval(double maxY) {
  if (maxY <= 20) return 5;
  if (maxY <= 100) return 20;
  final raw = maxY / 5;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final normalized = raw / magnitude;
  final rounded = normalized <= 1
      ? 1
      : normalized <= 2
          ? 2
          : normalized <= 5
              ? 5
              : 10;
  return (rounded * magnitude).toDouble();
}

String _formatTimeLabel(String raw, {bool dense = false}) {
  try {
    final dt = DateTime.parse(raw).toLocal();
    if (dense) {
      return '${dt.day}/${dt.month}';
    }
    final hh = dt.hour.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $hh:00';
  } catch (_) {
    return raw.length > 10 ? raw.substring(0, 10) : raw;
  }
}

String _formatHourLabel(String raw) {
  final hour = int.tryParse(raw.split(':').first);
  if (hour == null) return raw;
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  return '$h12$suffix';
}

String _formatTooltipDate(String raw) {
  try {
    final dt = DateTime.parse(raw).toLocal();
    final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $h12:$mm $suffix';
  } catch (_) {
    return raw;
  }
}

String _shortName(String label) {
  final parts = label.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    final first = parts.first;
    final last = parts.last;
    if (first.toLowerCase() == 'driver') {
      return 'D$last';
    }
    return '${first[0]}$last';
  }
  return label.length <= 8 ? label : '${label.substring(0, 8)}…';
}

Color _seriesColor(int index) {
  const palette = [
    Color(0xFF4E79A7),
    Color(0xFFF28E2B),
    Color(0xFF59A14F),
    Color(0xFFE15759),
    Color(0xFF76B7B2),
    Color(0xFFEDC948),
    Color(0xFFB07AA1),
  ];
  return palette[index % palette.length];
}

