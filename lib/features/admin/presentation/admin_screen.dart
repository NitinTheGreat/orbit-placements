import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/orbit_notice.dart';
import '../../../models/company.dart';
import '../../../services/firestore_service.dart';

class RequirementDraft {
  RequirementDraft()
    : typeController = TextEditingController(text: 'form'),
      labelController = TextEditingController(),
      urlController = TextEditingController();

  final TextEditingController typeController;
  final TextEditingController labelController;
  final TextEditingController urlController;
  bool isRequired = true;

  CompanyRequirement toRequirement() {
    final type = typeController.text.trim();
    final url = urlController.text.trim();
    final label = labelController.text.trim();
    return CompanyRequirement(
      id: slugify(label),
      type: type.isEmpty ? 'other' : type,
      label: label,
      url: url.isEmpty ? null : url,
      isRequired: isRequired,
    );
  }

  void dispose() {
    typeController.dispose();
    labelController.dispose();
    urlController.dispose();
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _ctcController = TextEditingController();
  final _stipendController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final List<RequirementDraft> _requirements = [];

  DateTime? _deadline;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _ctcController.dispose();
    _stipendController.dispose();
    for (final draft in _requirements) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        _deadline = picked;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_deadline == null) {
      setState(() => _error = 'Pick a registration deadline.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final ctc = _ctcController.text.trim();
    final stipend = _stipendController.text.trim();
    final company = Company(
      id: '',
      name: _nameController.text.trim(),
      category: _categoryController.text.trim(),
      ctc: ctc.isEmpty ? null : ctc,
      stipend: stipend.isEmpty ? null : stipend,
      registrationDeadline: _deadline,
      requirements: _requirements
          .map((draft) => draft.toRequirement())
          .where((requirement) => requirement.label.isNotEmpty)
          .toList(),
    );

    try {
      await _firestoreService.addCompany(company);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save this drive. Check your admin access.';
        });
      }
      return;
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${company.name} added')));
    context.goNamed(AppRoutes.companies);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.goNamed(AppRoutes.companies),
        ),
        title: Text('Add a drive', style: theme.textTheme.titleMedium),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              OrbitSpacing.xl,
              OrbitSpacing.sm,
              OrbitSpacing.xl,
              OrbitSpacing.xxl,
            ),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Company name'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a company name'
                    : null,
              ),
              const SizedBox(height: OrbitSpacing.lg),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'Super Dream, Dream, Core',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a category'
                    : null,
              ),
              const SizedBox(height: OrbitSpacing.lg),
              TextFormField(
                controller: _ctcController,
                decoration: const InputDecoration(
                  labelText: 'CTC',
                  hintText: '12 LPA',
                ),
              ),
              const SizedBox(height: OrbitSpacing.lg),
              TextFormField(
                controller: _stipendController,
                decoration: const InputDecoration(
                  labelText: 'Stipend',
                  hintText: '50k per month',
                ),
              ),
              const SizedBox(height: OrbitSpacing.lg),
              InkWell(
                onTap: _pickDeadline,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Registration deadline',
                  ),
                  child: Text(
                    _deadline == null
                        ? 'Pick a date'
                        : '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Requirements',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _requirements.add(RequirementDraft())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (_requirements.isEmpty)
                Text(
                  'No requirements yet. Add what students must submit.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              for (final draft in _requirements)
                _RequirementEditor(
                  key: ObjectKey(draft),
                  draft: draft,
                  onRemove: () => setState(() {
                    _requirements.remove(draft);
                    draft.dispose();
                  }),
                  onRequiredChanged: (value) =>
                      setState(() => draft.isRequired = value),
                ),
              if (_error != null) ...[
                const SizedBox(height: OrbitSpacing.lg),
                OrbitNotice(message: _error!, icon: Icons.error_outline),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save drive'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementEditor extends StatelessWidget {
  const _RequirementEditor({
    super.key,
    required this.draft,
    required this.onRemove,
    required this.onRequiredChanged,
  });

  final RequirementDraft draft;
  final VoidCallback onRemove;
  final ValueChanged<bool> onRequiredChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: OrbitSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpacing.lg),
        child: Column(
          children: [
            TextFormField(
              controller: draft.labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Fill the registration form',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.typeController,
              decoration: const InputDecoration(
                labelText: 'Type',
                hintText: 'form, oa, ppt, resume',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.urlController,
              decoration: const InputDecoration(labelText: 'URL (optional)'),
              keyboardType: TextInputType.url,
            ),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Required'),
                    value: draft.isRequired,
                    onChanged: onRequiredChanged,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
