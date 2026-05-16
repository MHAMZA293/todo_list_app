import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taskify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Nunito',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
      ),
      home: const TodoHomePage(),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class Task {
  final String id;
  String title;
  bool isDone;
  final DateTime createdAt;
  String category;

  Task({
    required this.id,
    required this.title,
    this.isDone = false,
    required this.createdAt,
    this.category = 'Personal',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isDone': isDone,
        'createdAt': createdAt.toIso8601String(),
        'category': category,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        isDone: json['isDone'],
        createdAt: DateTime.parse(json['createdAt']),
        category: json['category'] ?? 'Personal',
      );
}

// ─── Constants ────────────────────────────────────────────────────────────────

const kPrimary    = Color(0xFF6C63FF);
const kAccent     = Color(0xFFFF6584);
const kSuccess    = Color(0xFF43C59E);
const kBackground = Color(0xFFF5F4FF);
const kCard       = Colors.white;
const kTextDark   = Color(0xFF2D2B55);
const kTextLight  = Color(0xFF9896B8);

const kCategories = ['Personal', 'Work', 'Health', 'Study', 'Shopping'];

final kCategoryColors = {
  'Personal' : const Color(0xFF6C63FF),
  'Work'     : const Color(0xFFFF6584),
  'Health'   : const Color(0xFF43C59E),
  'Study'    : const Color(0xFFFFB347),
  'Shopping' : const Color(0xFF5BC0EB),
};

final kCategoryIcons = {
  'Personal' : Icons.person_rounded,
  'Work'     : Icons.work_rounded,
  'Health'   : Icons.favorite_rounded,
  'Study'    : Icons.school_rounded,
  'Shopping' : Icons.shopping_bag_rounded,
};

// ─── Home Page ────────────────────────────────────────────────────────────────

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage>
    with SingleTickerProviderStateMixin {
  List<Task> _tasks = [];
  String _selectedCategory = 'All';
  late AnimationController _fabController;
  final _prefs_key = 'tasks_v2';

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadTasks();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_prefs_key);
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() => _tasks = list);
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefs_key,
      jsonEncode(_tasks.map((t) => t.toJson()).toList()),
    );
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  void _addTask(String title, String category) {
    setState(() {
      _tasks.insert(
        0,
        Task(
          id       : DateTime.now().millisecondsSinceEpoch.toString(),
          title    : title,
          createdAt: DateTime.now(),
          category : category,
        ),
      );
    });
    _saveTasks();
  }

  void _toggleTask(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      final t = _tasks.firstWhere((t) => t.id == id);
      t.isDone = !t.isDone;
    });
    _saveTasks();
  }

  void _deleteTask(String id) {
    setState(() => _tasks.removeWhere((t) => t.id == id));
    _saveTasks();
  }

  void _editTask(Task task, String newTitle) {
    setState(() => task.title = newTitle);
    _saveTasks();
  }

  // ── Filtered list ──────────────────────────────────────────────────────────

  List<Task> get _filtered {
    if (_selectedCategory == 'All') return _tasks;
    return _tasks.where((t) => t.category == _selectedCategory).toList();
  }

  int get _doneCount   => _filtered.where((t) => t.isDone).length;
  int get _totalCount  => _filtered.length;

  // ── UI Builders ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pending = _filtered.where((t) => !t.isDone).toList();
    final done    = _filtered.where((t) =>  t.isDone).toList();

    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildProgressBar(),
            _buildCategoryChips(),
            Expanded(
              child: _filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      children: [
                        if (pending.isNotEmpty) ...[
                          _sectionLabel('To Do', pending.length),
                          ...pending.map((t) => _TaskCard(
                                task     : t,
                                onToggle : () => _toggleTask(t.id),
                                onDelete : () => _deleteTask(t.id),
                                onEdit   : (s) => _editTask(t, s),
                              )),
                        ],
                        if (done.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _sectionLabel('Completed', done.length),
                          ...done.map((t) => _TaskCard(
                                task     : t,
                                onToggle : () => _toggleTask(t.id),
                                onDelete : () => _deleteTask(t.id),
                                onEdit   : (s) => _editTask(t, s),
                              )),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? '🌤 Good morning'
                   : hour < 17 ? '☀️ Good afternoon'
                   :             '🌙 Good evening';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting,
              style: const TextStyle(
                  fontSize: 13,
                  color: kTextLight,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          const Text('Taskify',
              style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: kTextDark,
                  letterSpacing: -1)),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final pct = _totalCount == 0 ? 0.0 : _doneCount / _totalCount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_doneCount of $_totalCount tasks done',
                  style: const TextStyle(
                      color: kTextLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
              Text('${(pct * 100).round()}%',
                  style: const TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value         : value,
                minHeight     : 8,
                backgroundColor: kPrimary.withOpacity(0.1),
                valueColor    : const AlwaysStoppedAnimation<Color>(kPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final cats = ['All', ...kCategories];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection     : Axis.horizontal,
        padding             : const EdgeInsets.symmetric(horizontal: 20),
        itemCount           : cats.length,
        separatorBuilder    : (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat      = cats[i];
          final selected = cat == _selectedCategory;
          final color    = cat == 'All' ? kPrimary : kCategoryColors[cat]!;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color : selected ? color : color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(22),
                boxShadow: selected
                    ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cat != 'All') ...[
                    Icon(kCategoryIcons[cat],
                        size: 14,
                        color: selected ? Colors.white : color),
                    const SizedBox(width: 5),
                  ],
                  Text(cat,
                      style: TextStyle(
                          color     : selected ? Colors.white : color,
                          fontWeight: FontWeight.w700,
                          fontSize  : 13)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String label, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 0, 10),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize  : 16,
                    color     : kTextDark)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color       : kPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color     : kPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize  : 12)),
            ),
          ],
        ),
      );

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width : 100, height: 100,
              decoration: BoxDecoration(
                color : kPrimary.withOpacity(0.08),
                shape : BoxShape.circle,
              ),
              child: const Icon(Icons.checklist_rounded,
                  size: 50, color: kPrimary),
            ),
            const SizedBox(height: 20),
            const Text('All clear!',
                style: TextStyle(
                    fontSize  : 22,
                    fontWeight: FontWeight.w800,
                    color     : kTextDark)),
            const SizedBox(height: 6),
            const Text('Tap + to add your first task',
                style: TextStyle(color: kTextLight, fontSize: 14)),
          ],
        ),
      );

  Widget _buildFAB() => FloatingActionButton.extended(
        onPressed     : _showAddTaskSheet,
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation     : 8,
        icon          : const Icon(Icons.add_rounded, size: 22),
        label         : const Text('New Task',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      );

  // ── Bottom Sheet ───────────────────────────────────────────────────────────

  void _showAddTaskSheet() {
    final titleCtrl   = TextEditingController();
    String category   = 'Personal';

    showModalBottomSheet(
      context           : context,
      isScrollControlled: true,
      backgroundColor   : Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top   : 24, left: 24, right: 24),
          decoration: const BoxDecoration(
            color        : kCard,
            borderRadius : BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width : 40, height: 4,
                  decoration: BoxDecoration(
                    color       : kTextLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('New Task',
                  style: TextStyle(
                      fontSize  : 22,
                      fontWeight: FontWeight.w800,
                      color     : kTextDark)),
              const SizedBox(height: 20),
              // Title field
              Container(
                decoration: BoxDecoration(
                  color       : kBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller   : titleCtrl,
                  autofocus    : true,
                  textCapitalization: TextCapitalization.sentences,
                  style        : const TextStyle(
                      color: kTextDark, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText     : 'What needs to be done?',
                    hintStyle    : TextStyle(color: kTextLight.withOpacity(0.7)),
                    border       : InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    prefixIcon   : const Icon(Icons.edit_rounded,
                        color: kPrimary, size: 20),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Category picker
              const Text('Category',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color     : kTextDark,
                      fontSize  : 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: kCategories.map((cat) {
                  final sel   = cat == category;
                  final color = kCategoryColors[cat]!;
                  return GestureDetector(
                    onTap: () => setSheetState(() => category = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding : const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? color : color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: sel
                            ? [BoxShadow(
                                color : color.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3))]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(kCategoryIcons[cat],
                              size : 14,
                              color: sel ? Colors.white : color),
                          const SizedBox(width: 5),
                          Text(cat,
                              style: TextStyle(
                                  color     : sel ? Colors.white : color,
                                  fontWeight: FontWeight.w700,
                                  fontSize  : 13)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Add button
              SizedBox(
                width : double.infinity,
                height: 54,
                child : ElevatedButton(
                  onPressed: () {
                    final t = titleCtrl.text.trim();
                    if (t.isNotEmpty) {
                      _addTask(t, category);
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 6,
                    shadowColor: kPrimary.withOpacity(0.4),
                  ),
                  child: const Text('Add Task',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Task Card ────────────────────────────────────────────────────────────────

class _TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final ValueChanged<String> onEdit;

  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync  : this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96, upperBound: 1.0,
      value  : 1.0,
    );
    _scaleAnim = CurvedAnimation(
        parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_)  => _controller.reverse();
  void _onTapUp(_)    => _controller.forward();
  void _onTapCancel() => _controller.forward();

  void _showEditDialog() {
    final ctrl = TextEditingController(text: widget.task.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Task',
            style: TextStyle(fontWeight: FontWeight.w800, color: kTextDark)),
        content: TextField(
          controller: ctrl,
          autofocus : true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            border     : OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide  : const BorderSide(color: kPrimary)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide  : const BorderSide(color: kPrimary, width: 2)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child    : const Text('Cancel',
                  style: TextStyle(color: kTextLight))),
          ElevatedButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) {
                widget.onEdit(t);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task  = widget.task;
    final color = kCategoryColors[task.category] ?? kPrimary;

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown  : _onTapDown,
        onTapUp    : _onTapUp,
        onTapCancel: _onTapCancel,
        child: Dismissible(
          key      : Key(task.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => widget.onDelete(),
          background: Container(
            margin       : const EdgeInsets.only(bottom: 12),
            alignment    : Alignment.centerRight,
            padding      : const EdgeInsets.only(right: 24),
            decoration   : BoxDecoration(
              color       : kAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.delete_rounded,
                color: kAccent, size: 26),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color      : kCard,
              borderRadius: BorderRadius.circular(20),
              boxShadow  : [
                BoxShadow(
                    color : kPrimary.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Material(
              color       : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onLongPress : _showEditDialog,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Category color bar
                      Container(
                        width       : 4, height: 44,
                        decoration  : BoxDecoration(
                          color       : color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Checkbox
                      GestureDetector(
                        onTap: widget.onToggle,
                        child: AnimatedContainer(
                          duration : const Duration(milliseconds: 200),
                          width    : 26, height: 26,
                          decoration: BoxDecoration(
                            color: task.isDone
                                ? kSuccess
                                : Colors.transparent,
                            border: Border.all(
                              color: task.isDone ? kSuccess : kTextLight,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: task.isDone
                              ? const Icon(Icons.check_rounded,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Title + category
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style   : TextStyle(
                                fontSize      : 15,
                                fontWeight    : FontWeight.w700,
                                color         : task.isDone
                                    ? kTextLight
                                    : kTextDark,
                                decoration    : task.isDone
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                decorationColor: kTextLight,
                              ),
                              child: Text(task.title,
                                  maxLines  : 2,
                                  overflow  : TextOverflow.ellipsis),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(kCategoryIcons[task.category],
                                    size: 11, color: color),
                                const SizedBox(width: 4),
                                Text(task.category,
                                    style: TextStyle(
                                        color     : color,
                                        fontSize  : 11,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Edit button
                      IconButton(
                        icon   : const Icon(Icons.more_vert_rounded,
                            color: kTextLight, size: 20),
                        onPressed: _showEditDialog,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
