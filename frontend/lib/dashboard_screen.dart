import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _summaryData;
  List<dynamic> _transactions = [];
  String _currency = 'USD';
  bool _isLoading = true;
  int _touchedPieIndex = -1;
  int _touchedBarIndex = -1;

  final List<Color> _vibrantColors = const [
    Color(0xFF00F2FE), Color(0xFF4FACFE), // Blues
    Color(0xFFFA709A), Color(0xFFFEE140), // Pink/Yellow
    Color(0xFF43E97B), Color(0xFF38F9D7), // Greens
    Color(0xFFB12A5B), Color(0xFFFF8177), // Red/Oranges
    Color(0xFF8B5CF6), Color(0xFFE0C3FC), // Purples
  ];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      final summaryRes = await http.get(Uri.parse('http://127.0.0.1:8000/analytics/summary'), headers: {'Authorization': 'Bearer $token'});
      final txRes = await http.get(Uri.parse('http://127.0.0.1:8000/transactions'), headers: {'Authorization': 'Bearer $token'});
      final profileRes = await http.get(Uri.parse('http://127.0.0.1:8000/users/me'), headers: {'Authorization': 'Bearer $token'});

      if (summaryRes.statusCode == 200 && txRes.statusCode == 200) {
        if (mounted) {
          setState(() {
            _summaryData = jsonDecode(summaryRes.body);
            _transactions = jsonDecode(txRes.body);
            if (profileRes.statusCode == 200) {
              _currency = jsonDecode(profileRes.body)['currency'] ?? 'USD';
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching dashboard: $e");
    }
  }

  Future<void> _deleteTransaction(int txId, int index) async {
    final deletedTx = _transactions[index];
    setState(() => _transactions.removeAt(index));

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final res = await http.delete(Uri.parse('http://127.0.0.1:8000/transactions/$txId'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode != 200) throw Exception("Failed to delete");
      _fetchDashboardData();
    } catch (e) {
      setState(() => _transactions.insert(index, deletedTx));
    }
  }

  Future<void> _editTransaction(int txId, Map<String, dynamic> updatedData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      
      final res = await http.put(
        Uri.parse('http://127.0.0.1:8000/transactions/$txId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updatedData),
      );

      if (res.statusCode == 400) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(jsonDecode(res.body)['detail'] ?? 'Invalid input'), backgroundColor: Colors.redAccent),
          );
        }
        return;
      }

      if (res.statusCode != 200) throw Exception("Failed to update");
      _fetchDashboardData();
    } catch (e) {
      debugPrint("Error editing transaction: $e");
    }
  }

  void _showEditDialog(Map<String, dynamic> tx) {
    final amountController = TextEditingController(text: tx['amount'].toString());
    final merchantController = TextEditingController(text: tx['merchant']);
    String selectedCategory = tx['category'] ?? 'Misc';
    String selectedDateStr = tx['date'] ?? DateTime.now().toIso8601String().split('T')[0];

    final categories = [
      "Food & Dining", "Transportation", "Utilities", "Housing", "Entertainment", 
      "Shopping", "Groceries", "Healthcare", "Education", "Personal Care", 
      "Travel", "Debt", "Gifts & Donations", "Investments", "Income", "Misc"
    ];
    if (!categories.contains(selectedCategory)) categories.add(selectedCategory);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text("Edit Transaction", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: merchantController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Merchant', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Amount', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      dropdownColor: const Color(0xFF0F172A),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (val) => setDialogState(() => selectedCategory = val!),
                      decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F2FE)),
                  onPressed: () {
                    final updated = {
                      'amount': double.tryParse(amountController.text) ?? 0.0,
                      'merchant': merchantController.text,
                      'category': selectedCategory,
                      'date': selectedDateStr,
                    };
                    _editTransaction(tx['id'], updated);
                    Navigator.pop(ctx);
                  },
                  child: const Text("Save", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  // --- GLASSMORPHISM HELPER ---
  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildAnimatedEntry({required int delay, required Widget child}) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutExpo,
      builder: (context, double value, childWidget) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - value)),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF09090B),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00F2FE))),
      );
    }

    final totalSpend = _summaryData?['total_spend'] ?? 0.0;
    final symbol = const {'USD': '\$', 'EUR': '€', 'GBP': '£', 'INR': '₹', 'JPY': '¥'}[_currency] ?? _currency;
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Insights', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.person, color: Colors.white),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _fetchDashboardData()),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.6),
            radius: 1.5,
            colors: [Color(0xFF2E0854), Color(0xFF09090B)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _fetchDashboardData,
          color: const Color(0xFF00F2FE),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAnimatedEntry(delay: 0, child: _buildHeroCard(formatter.format(totalSpend))),
                const SizedBox(height: 32),
                _buildAnimatedEntry(delay: 100, child: _buildSectionTitle("Where it goes")),
                const SizedBox(height: 16),
                _buildAnimatedEntry(delay: 200, child: _buildDonutChart(formatter)),
                const SizedBox(height: 40),
                _buildAnimatedEntry(delay: 300, child: _buildSectionTitle("Daily Velocity")),
                const SizedBox(height: 16),
                _buildAnimatedEntry(delay: 400, child: _buildBarChart()),
                const SizedBox(height: 40),
                _buildAnimatedEntry(delay: 500, child: _buildSectionTitle("Activity")),
                const SizedBox(height: 16),
                _buildAnimatedEntry(delay: 600, child: _buildTransactionList(formatter)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
    );
  }

  Widget _buildHeroCard(String totalValue) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF00F2FE).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.account_balance_wallet, color: Color(0xFF00F2FE)),
              ),
              const SizedBox(width: 12),
              const Text("Total Expenses", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            totalValue,
            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart(NumberFormat formatter) {
    final breakdown = _summaryData?['category_breakdown'] as List<dynamic>? ?? [];
    if (breakdown.isEmpty) return _buildGlassCard(child: const Center(child: Text("No data", style: TextStyle(color: Colors.white54))));

    return _buildGlassCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Top Category", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      breakdown.isNotEmpty ? breakdown.first['category'] : "-",
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(touchCallback: (e, response) {
                      setState(() {
                        if (!e.isInterestedForInteractions || response == null || response.touchedSection == null) {
                          _touchedPieIndex = -1;
                          return;
                        }
                        _touchedPieIndex = response.touchedSection!.touchedSectionIndex;
                      });
                    }),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 4,
                    centerSpaceRadius: 75,
                    sections: breakdown.asMap().entries.map((entry) {
                      final isTouched = entry.key == _touchedPieIndex;
                      return PieChartSectionData(
                        color: _vibrantColors[(entry.key * 2) % _vibrantColors.length],
                        value: (entry.value['total'] ?? 0).toDouble(),
                        title: isTouched ? formatter.format(entry.value['total']) : '',
                        radius: isTouched ? 30 : 20,
                        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        badgeWidget: isTouched ? null : Container(),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: breakdown.asMap().entries.map((entry) {
              final isTouched = entry.key == _touchedPieIndex;
              final color = _vibrantColors[(entry.key * 2) % _vibrantColors.length];
              return AnimatedScale(
                scale: isTouched ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(isTouched ? 0.8 : 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 4)])),
                      const SizedBox(width: 8),
                      Text(entry.value['category'], style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final trend = _summaryData?['trend'] as List<dynamic>? ?? [];
    if (trend.length < 2) return _buildGlassCard(child: const Center(child: Text("Need more days", style: TextStyle(color: Colors.white54))));

    double maxY = 0;
    for (var t in trend) {
      if ((t['amount'] ?? 0).toDouble() > maxY) maxY = (t['amount'] ?? 0).toDouble();
    }

    return _buildGlassCard(
      padding: const EdgeInsets.only(top: 32, bottom: 16, left: 16, right: 16),
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            maxY: maxY * 1.2,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => Colors.white.withOpacity(0.1),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    "${trend[group.x.toInt()]['date']}\n",
                    const TextStyle(color: Colors.white70, fontSize: 10),
                    children: [TextSpan(text: '\$${rod.toY.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))],
                  );
                },
              ),
              touchCallback: (e, response) {
                setState(() {
                  if (response?.spot != null && e.isInterestedForInteractions) {
                    _touchedBarIndex = response!.spot!.touchedBarGroupIndex;
                  } else {
                    _touchedBarIndex = -1;
                  }
                });
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                    // Parse 'YYYY-MM-DD' to 'MMM D'
                    final dateStr = trend[idx]['date'].toString();
                    try {
                      final dt = DateTime.parse(dateStr);
                      final formatted = DateFormat('MMM d').format(dt);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(formatted, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                      );
                    } catch (_) { return const SizedBox.shrink(); }
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const SizedBox.shrink();
                    return Text(value.toInt().toString(), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10));
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1, dashArray: [5, 5]),
            ),
            barGroups: trend.asMap().entries.map((entry) {
              final isTouched = entry.key == _touchedBarIndex;
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: (entry.value['amount'] ?? 0).toDouble(),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: isTouched ? 22 : 16,
                    borderRadius: BorderRadius.circular(6),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY * 1.2,
                      color: Colors.white.withOpacity(0.02),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionList(NumberFormat formatter) {
    if (_transactions.isEmpty) return _buildGlassCard(child: const Center(child: Text("No recent activity", style: TextStyle(color: Colors.white54))));

    return _buildGlassCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _transactions.length,
        separatorBuilder: (context, index) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
        itemBuilder: (context, index) {
          final tx = _transactions[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            leading: Container(
              height: 48, width: 48,
              decoration: BoxDecoration(color: const Color(0xFF00F2FE).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.receipt_long, color: Color(0xFF00F2FE)),
            ),
            title: Text(tx['merchant'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            subtitle: Text("${tx['category']} • ${tx['date']}", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatter.format(tx['amount'] ?? 0),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _showEditDialog(tx),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _deleteTransaction(tx['id'], index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
