import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DriverApp());
}

class Shift {
  String id;
  DateTime date;
  int duration;
  double km;
  double fuel;
  double gross;

  Shift({
    required this.id,
    required this.date,
    required this.duration,
    required this.km,
    required this.fuel,
    required this.gross,
  });

  double get net => gross - fuel;

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'duration': duration,
        'km': km,
        'fuel': fuel,
        'gross': gross,
      };

  factory Shift.fromMap(Map<String, dynamic> map) => Shift(
        id: map['id'],
        date: DateTime.parse(map['date']),
        duration: map['duration'],
        km: (map['km'] as num).toDouble(),
        fuel: (map['fuel'] as num).toDouble(),
        gross: (map['gross'] as num).toDouble(),
      );
}

class DriverApp extends StatefulWidget {
  const DriverApp({super.key});

  @override
  State<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends State<DriverApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paulo Luna',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
        cardColor: Colors.white,
        primaryColor: const Color(0xFF00C853),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        primaryColor: const Color(0xFF00E676),
        useMaterial3: true,
      ),
      home: DriverHomePage(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class DriverHomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const DriverHomePage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Timer? _timer;
  
  bool _running = false;
  bool _paused = false;
  int _accumulatedSeconds = 0;
  DateTime? _lastStartTime;
  
  List<Shift> _shifts = [];

  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    end: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59),
  );
  String _filterLabel = 'Hoje';

  static const List<String> _meses = [
    '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  static const List<String> _mesesAbbr = [
    '', 'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez'
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final running = prefs.getBool('timer_running') ?? false;
    final paused = prefs.getBool('timer_paused') ?? false;
    final accumulated = prefs.getInt('timer_accumulated') ?? 0;
    final startTimeStr = prefs.getString('timer_start_time');
    final String? shiftsJson = prefs.getString('shifts_data');

    List<Shift> loadedShifts = [];
    if (shiftsJson != null && shiftsJson.isNotEmpty) {
      try {
        final List decoded = jsonDecode(shiftsJson);
        loadedShifts = decoded.map((e) => Shift.fromMap(e)).toList();
      } catch (_) {}
    }

    setState(() {
      _running = running;
      _paused = paused;
      _accumulatedSeconds = accumulated;
      _shifts = loadedShifts;
      if (startTimeStr != null) {
        _lastStartTime = DateTime.tryParse(startTimeStr);
      }
    });

    if (_running && !_paused) {
      _startTimer();
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('timer_running', _running);
    await prefs.setBool('timer_paused', _paused);
    await prefs.setInt('timer_accumulated', _accumulatedSeconds);
    
    if (_lastStartTime != null) {
      await prefs.setString('timer_start_time', _lastStartTime!.toIso8601String());
    } else {
      await prefs.remove('timer_start_time');
    }
    
    final String encoded = jsonEncode(_shifts.map((e) => e.toMap()).toList());
    await prefs.setString('shifts_data', encoded);
  }

  int get _currentSeconds {
    if (_running && !_paused && _lastStartTime != null) {
      final elapsed = DateTime.now().difference(_lastStartTime!).inSeconds;
      return _accumulatedSeconds + elapsed;
    }
    return _accumulatedSeconds;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _start() {
    setState(() {
      _running = true;
      _paused = false;
      _lastStartTime = DateTime.now();
      _accumulatedSeconds = 0;
    });
    _saveData();
    _startTimer();
  }

  void _pause() {
    if (_lastStartTime != null) {
      final elapsed = DateTime.now().difference(_lastStartTime!).inSeconds;
      _accumulatedSeconds += elapsed;
      _lastStartTime = null;
    }
    setState(() {
      _paused = true;
    });
    _timer?.cancel();
    _saveData();
  }

  void _resume() {
    setState(() {
      _paused = false;
      _lastStartTime = DateTime.now();
    });
    _saveData();
    _startTimer();
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _paused = false;
      _accumulatedSeconds = 0;
      _lastStartTime = null;
    });
    _saveData();
  }

  String _formatTime(int s) {
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  String _formatDatePt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = _mesesAbbr[dt.month];
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d de $m de $y às $h:$min';
  }

  void _openFinishModal() {
    _pause();
    final totalSecs = _currentSeconds;
    final kmCtrl = TextEditingController();
    final fuelCtrl = TextEditingController();
    final grossCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar Jornada'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tempo trabalhado: ${_formatTime(totalSecs)}',
                  style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(
                controller: kmCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'KM Rodados', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fuelCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Gasto Combustível (R\$)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: grossCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Faturamento Bruto (R\$)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resume();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final k = double.tryParse(kmCtrl.text.replaceAll(',', '.')) ?? 0.0;
              final f = double.tryParse(fuelCtrl.text.replaceAll(',', '.')) ?? 0.0;
              final g = double.tryParse(grossCtrl.text.replaceAll(',', '.')) ?? 0.0;

              final newShift = Shift(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                date: DateTime.now(),
                duration: totalSecs,
                km: k,
                fuel: f,
                gross: g,
              );

              setState(() {
                _shifts.insert(0, newShift);
              });
              
              _saveData();
              Navigator.pop(ctx);
              _reset();
              _tabs.animateTo(1);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _openShiftFormModal({Shift? shiftToEdit}) {
    final isEditing = shiftToEdit != null;
    DateTime selectedDate = isEditing ? shiftToEdit.date : DateTime.now();
    int totalSecs = isEditing ? shiftToEdit.duration : 0;

    final hoursCtrl = TextEditingController(text: (totalSecs ~/ 3600).toString());
    final minsCtrl = TextEditingController(text: ((totalSecs % 3600) ~/ 60).toString());
    final kmCtrl = TextEditingController(text: isEditing ? shiftToEdit.km.toString() : '');
    final fuelCtrl = TextEditingController(text: isEditing ? shiftToEdit.fuel.toString() : '');
    final grossCtrl = TextEditingController(text: isEditing ? shiftToEdit.gross.toString() : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(isEditing ? 'Editar Jornada' : 'Adicionar Turno Passado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Data: ${_formatDatePt(selectedDate)}'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (pickedTime != null) {
                        setModalState(() {
                          selectedDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Horas', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: minsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Minutos', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: kmCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'KM Rodados', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fuelCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Combustível (R\$)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: grossCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Faturamento Bruto (R\$)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final h = int.tryParse(hoursCtrl.text) ?? 0;
                final m = int.tryParse(minsCtrl.text) ?? 0;
                final totalDur = (h * 3600) + (m * 60);
                final k = double.tryParse(kmCtrl.text.replaceAll(',', '.')) ?? 0.0;
                final f = double.tryParse(fuelCtrl.text.replaceAll(',', '.')) ?? 0.0;
                final g = double.tryParse(grossCtrl.text.replaceAll(',', '.')) ?? 0.0;

                setState(() {
                  if (isEditing) {
                    final index = _shifts.indexWhere((s) => s.id == shiftToEdit.id);
                    if (index != -1) {
                      _shifts[index] = Shift(
                        id: shiftToEdit.id,
                        date: selectedDate,
                        duration: totalDur,
                        km: k,
                        fuel: f,
                        gross: g,
                      );
                    }
                  } else {
                    _shifts.insert(
                      0,
                      Shift(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        date: selectedDate,
                        duration: totalDur,
                        km: k,
                        fuel: f,
                        gross: g,
                      ),
                    );
                  }
                  _saveData();
                });

                Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteShift(Shift shift) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Turno'),
        content: const Text('Deseja realmente remover este registro de jornada?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _shifts.removeWhere((s) => s.id == shift.id);
                _saveData();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _openDateFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        DateTime displayedMonth = DateTime(_selectedRange.start.year, _selectedRange.start.month, 1);
        DateTime? tempStart = _selectedRange.start;
        DateTime? tempEnd = _selectedRange.end;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final now = DateTime.now();

            void applyShortcut(String label, DateTime start, DateTime end) {
              setState(() {
                _filterLabel = label;
                _selectedRange = DateTimeRange(
                  start: DateTime(start.year, start.month, start.day),
                  end: DateTime(end.year, end.month, end.day, 23, 59, 59),
                );
              });
              Navigator.pop(ctx);
            }

            int daysInMonth = DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
            int firstWeekday = DateTime(displayedMonth.year, displayedMonth.month, 1).weekday % 7;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[500], borderRadius: BorderRadius.circular(10)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Selecionar período', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _shortcutChip('Hoje', () => applyShortcut('Hoje', now, now)),
                        _shortcutChip('Ontem', () {
                          final y = now.subtract(const Duration(days: 1));
                          applyShortcut('Ontem', y, y);
                        }),
                        _shortcutChip('7 dias', () {
                          final start = now.subtract(const Duration(days: 7));
                          applyShortcut('Últimos 7 dias', start, now);
                        }),
                        _shortcutChip('Este mês', () {
                          final start = DateTime(now.year, now.month, 1);
                          applyShortcut('${_meses[now.month]} de ${now.year}', start, now);
                        }),
                        _shortcutChip('Mês passado', () {
                          final prevMonth = DateTime(now.year, now.month - 1, 1);
                          final lastDay = DateTime(now.year, now.month, 0);
                          applyShortcut('${_meses[prevMonth.month]} de ${prevMonth.year}', prevMonth, lastDay);
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setSheetState(() {
                            displayedMonth = DateTime(displayedMonth.year, displayedMonth.month - 1, 1);
                          });
                        },
                      ),
                      Text('${_meses[displayedMonth.month]} ${displayedMonth.year}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setSheetState(() {
                            displayedMonth = DateTime(displayedMonth.year, displayedMonth.month + 1, 1);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
                    itemCount: firstWeekday + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < firstWeekday) return const SizedBox.shrink();
                      final dayNumber = index - firstWeekday + 1;
                      final dayDate = DateTime(displayedMonth.year, displayedMonth.month, dayNumber);

                      bool isSelectedStart = tempStart != null && dayDate.year == tempStart!.year && dayDate.month == tempStart!.month && dayDate.day == tempStart!.day;
                      bool isSelectedEnd = tempEnd != null && dayDate.year == tempEnd!.year && dayDate.month == tempEnd!.month && dayDate.day == tempEnd!.day;
                      bool isInRange = tempStart != null && tempEnd != null && dayDate.isAfter(tempStart!) && dayDate.isBefore(tempEnd!);

                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            if (tempStart == null || (tempStart != null && tempEnd != null)) {
                              tempStart = dayDate;
                              tempEnd = null;
                            } else if (tempStart != null && tempEnd == null) {
                              if (dayDate.isBefore(tempStart!)) {
                                tempStart = dayDate;
                              } else {
                                tempEnd = dayDate;
                              }
                            }
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: (isSelectedStart || isSelectedEnd) ? const Color(0xFF00C853) : isInRange ? const Color(0xFF00C853).withOpacity(0.25) : Colors.transparent,
                            borderRadius: BorderRadius.circular((isSelectedStart || isSelectedEnd) ? 20 : 6),
                          ),
                          alignment: Alignment.center,
                          child: Text('$dayNumber', style: TextStyle(color: (isSelectedStart || isSelectedEnd) ? Colors.white : null, fontWeight: (isSelectedStart || isSelectedEnd) ? FontWeight.bold : FontWeight.normal)),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (tempStart != null) {
                          final finalEnd = tempEnd ?? tempStart!;
                          setState(() {
                            _filterLabel = '${tempStart!.day}/${_mesesAbbr[tempStart!.month]} – ${finalEnd.day}/${_mesesAbbr[finalEnd.month]}';
                            _selectedRange = DateTimeRange(
                              start: DateTime(tempStart!.year, tempStart!.month, tempStart!.day),
                              end: DateTime(finalEnd.year, finalEnd.month, finalEnd.day, 23, 59, 59),
                            );
                          });
                        }
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Aplicar período', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _shortcutChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: widget.isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE8E8E8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  List<Shift> get _filteredShifts {
    return _shifts.where((s) {
      return s.date.isAfter(_selectedRange.start.subtract(const Duration(seconds: 1))) &&
          s.date.isBefore(_selectedRange.end.add(const Duration(seconds: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paulo Luna', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Alternar Tema',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Filtrar Datas',
            onPressed: _openDateFilterBottomSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.timer), text: 'Jornada'),
            Tab(icon: Icon(Icons.analytics), text: 'Histórico & Lucros'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildTimerTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: _tabs.index == 1
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.white,
              onPressed: () => _openShiftFormModal(),
              tooltip: 'Adicionar Turno Passado',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTimerTab() {
    final secs = _currentSeconds;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _running
                ? (_paused ? 'EM PAUSA' : 'EM JORNADA')
                : 'DISPONÍVEL',
            style: TextStyle(
              color: _running
                  ? (_paused ? Colors.amber : const Color(0xFF00E676))
                  : Colors.grey,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 15),
          Text(_formatTime(secs), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_running)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('INICIAR', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _paused ? Colors.blueAccent : Colors.amber[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _paused ? _resume : _pause,
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                  label: Text(_paused ? 'RETOMAR' : 'PAUSAR', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 15),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _running ? _openFinishModal : null,
                icon: const Icon(Icons.stop),
                label: const Text('FINALIZAR', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final list = _filteredShifts;
    final totalKm = list.fold(0.0, (sum, i) => sum + i.km);
    final totalFuel = list.fold(0.0, (sum, i) => sum + i.fuel);
    final totalNet = list.fold(0.0, (sum, i) => sum + i.net);
    final totalSec = list.fold(0, (sum, i) => sum + i.duration);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: InkWell(
            onTap: _openDateFilterBottomSheet,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF222222) : const Color(0xFFEAEAEA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF00C853)),
                      const SizedBox(width: 8),
                      Text('Período: $_filterLabel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const Text('Alterar', style: TextStyle(color: Color(0xFF00C853), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _metricItem('Horas Trabalhadas', _formatTime(totalSec), Icons.access_time),
                    _metricItem('KM Rodados', '${totalKm.toStringAsFixed(1)} km', Icons.directions_car),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _metricItem('Gasto Combustível', 'R\$ ${totalFuel.toStringAsFixed(2)}', Icons.local_gas_station, color: Colors.redAccent),
                    _metricItem('Lucro Líquido', 'R\$ ${totalNet.toStringAsFixed(2)}', Icons.attach_money, color: const Color(0xFF00C853)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Turnos Registrados', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => _openShiftFormModal(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Novo Turno', style: TextStyle(fontSize: 12)),
              )
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Nenhum turno para este período.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final item = list[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.black12,
                          child: Icon(Icons.drive_eta, color: Color(0xFF00C853)),
                        ),
                        title: Text(_formatDatePt(item.date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(
                          '${_formatTime(item.duration)} • ${item.km} km • Gas: R\$ ${item.fuel.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'R\$ ${item.net.toStringAsFixed(2)}',
                              style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _openShiftFormModal(shiftToEdit: item);
                                } else if (val == 'delete') {
                                  _deleteShift(item);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')]),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Excluir', style: TextStyle(color: Colors.red))]),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _metricItem(String label, String value, IconData icon, {Color color = Colors.grey}) {
    return Row(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color == Colors.grey ? null : color)),
          ],
        )
      ],
    );
  }
}
