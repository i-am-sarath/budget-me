import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/categories/models/category_model.dart';
import 'package:agent_money/features/categories/providers/category_provider.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  static const _tabs = [
    (TransactionType.expense, 'Expense'),
    (TransactionType.income, 'Income'),
    (TransactionType.investment, 'Invest'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final categoriesAsync = ref.watch(categoryProvider);
    final currentType = _tabs[_tabCtrl.index].$1;

    return Scaffold(
      backgroundColor: tc.surface,
      body: Column(
        children: [
          // App bar
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: tc.onSurface, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Categories',
                      style: GoogleFonts.inter(
                        color: tc.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: tc.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tc.outlineVariant, width: 0.5),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: tc.onSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: tc.surface,
                unselectedLabelColor: tc.onSurfaceVariant,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 12),
                unselectedLabelStyle:
                    GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
                tabs: _tabs
                    .map((t) => Tab(text: t.$2, height: 36))
                    .toList(),
              ),
            ),
          ),

          // Category list
          Expanded(
            child: categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error: $e')),
              data: (all) {
                final cats = all
                    .where((c) => c.type == currentType.name)
                    .toList();
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: cats.length,
                  itemBuilder: (ctx, i) => _CategoryRow(
                    category: cats[i],
                    tc: tc,
                    onEdit: () => _showEditDialog(cats[i]),
                    onDelete: cats[i].isDefault
                        ? null
                        : () => _confirmDelete(cats[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(currentType),
        backgroundColor: tc.onSurface,
        foregroundColor: tc.surface,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Category',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _showAddDialog(TransactionType type) {
    _showCategoryDialog(
      title: 'New Category',
      onSave: (name, emoji) =>
          ref.read(categoryProvider.notifier).add(name, emoji, type),
    );
  }

  void _showEditDialog(CategoryModel cat) {
    _showCategoryDialog(
      title: 'Edit Category',
      initialName: cat.name,
      initialEmoji: cat.emoji,
      onSave: (name, emoji) =>
          ref.read(categoryProvider.notifier).edit(cat, name, emoji),
    );
  }

  void _showCategoryDialog({
    required String title,
    String? initialName,
    String? initialEmoji,
    required void Function(String name, String emoji) onSave,
  }) {
    final tc = AppThemeColors.of(context);
    final nameCtrl = TextEditingController(text: initialName ?? '');
    final emojiCtrl = TextEditingController(text: initialEmoji ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: tc.surfaceContainerLow,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tc.outlineVariant,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.inter(
                    color: tc.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Emoji field
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: tc.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: emojiCtrl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26),
                      maxLength: 2,
                      decoration: InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        hintText: '⚙️',
                        hintStyle: const TextStyle(fontSize: 26),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      style: GoogleFonts.inter(
                          color: tc.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Category name',
                        hintStyle: GoogleFonts.inter(
                            color: tc.onSurfaceVariant),
                        filled: true,
                        fillColor: tc.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tc.onSurface,
                    foregroundColor: tc.surface,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final emoji =
                        emojiCtrl.text.trim().isEmpty ? '⚙️' : emojiCtrl.text.trim();
                    onSave(name, emoji);
                    Navigator.pop(ctx);
                  },
                  child: Text('Save',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(CategoryModel cat) {
    final tc = AppThemeColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surfaceContainerHigh,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${cat.name}"?',
            style: GoogleFonts.inter(
                color: tc.onSurface, fontWeight: FontWeight.w700)),
        content: Text(
          'Existing transactions with this category will not be affected.',
          style: GoogleFonts.inter(
              color: tc.onSurfaceVariant, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: tc.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tc.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(categoryProvider.notifier).remove(cat.id);
            },
            child: Text('Delete',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Category row
// ─────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  final CategoryModel category;
  final AppThemeColors tc;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _CategoryRow({
    required this.category,
    required this.tc,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tc.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.name,
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (category.isDefault)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tc.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Default',
                style: GoogleFonts.inter(
                    color: tc.onSurfaceVariant, fontSize: 10),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tc.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.edit_rounded,
                  color: tc.onSurfaceVariant, size: 16),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tc.expense.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete_rounded,
                    color: tc.expense, size: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
