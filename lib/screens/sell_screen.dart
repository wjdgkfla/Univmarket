import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/listing_photo.dart';
import '../data/repository.dart';
import '../widgets/screen_scaffold.dart';

class SellScreen extends StatefulWidget {
  const SellScreen({super.key, this.editingId});
  final String? editingId;
  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      price = TextEditingController(),
      description = TextEditingController();
  String category = 'Electronics';
  String? zone, photo;
  Condition condition = Condition.good;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final repo = context.read<Repository>();
    zone = repo.pickupZones.firstOrNull;
    final listing = widget.editingId == null
        ? null
        : repo.getListing(widget.editingId!);
    if (listing != null) {
      title.text = listing.title;
      price.text = listing.price.toString();
      description.text = listing.description;
      category = listing.tag;
      condition = listing.condition;
      zone = listing.zone;
      photo = listing.imageSource;
    }
  }

  @override
  void dispose() {
    title.dispose();
    price.dispose();
    description.dispose();
    super.dispose();
  }

  void error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> choosePhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 75,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final selected = ListingPhoto.fromBytes(bytes);
      if (mounted) setState(() => photo = selected.dataUri);
    } catch (e) {
      error(e);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || saving) return;
    setState(() => saving = true);
    try {
      await context.read<Repository>().createListing(
        title: title.text,
        price: int.parse(price.text.trim()),
        condition: condition,
        category: category,
        description: description.text,
        acceptsTrades: false,
        pickupZoneName: zone!,
        imageSource: photo,
        editingId: widget.editingId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<Repository>().isDemo
                ? 'Listing saved on this device.'
                : 'Listing saved to your marketplace.',
          ),
        ),
      );
      context.go('/');
    } catch (e) {
      error(e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    return ScreenScaffold(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.editingId != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: saving
                        ? null
                        : () => context.canPop()
                              ? context.pop()
                              : context.go('/profile'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Cancel editing'),
                  ),
                ),
              Text(
                widget.editingId == null
                    ? 'Make room for something new.'
                    : 'Edit your listing',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text('Listing at ${repo.me.school}'),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: saving ? null : choosePhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(photo == null ? 'Add a photo' : 'Change photo'),
              ),
              if (photo != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: photo!.startsWith('data:')
                        ? Image.memory(
                            base64Decode(photo!.split(',').last),
                            height: 180,
                            fit: BoxFit.cover,
                          )
                        : photo!.startsWith('https://')
                        ? Image.network(
                            photo!,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              height: 180,
                              child: Center(child: Text('Photo unavailable')),
                            ),
                          )
                        : Image.asset(photo!, height: 180, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: title,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What are you selling?',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v?.trim().length ?? 0) < 3
                    ? 'Use at least 3 characters.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price in USD',
                  prefixText: '\$ ',
                  helperText: 'Whole dollars. Enter 0 to give it away.',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final amount = int.tryParse(v?.trim() ?? '');
                  return amount == null || amount < 0 || amount > 100000
                      ? 'Enter a whole number from 0 to 100000.'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => category = v!,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<Condition>(
                initialValue: condition,
                decoration: const InputDecoration(
                  labelText: 'Condition',
                  border: OutlineInputBorder(),
                ),
                items: Condition.values
                    .map(
                      (v) => DropdownMenuItem(value: v, child: Text(v.label)),
                    )
                    .toList(),
                onChanged: (v) => condition = v!,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: description,
                minLines: 4,
                maxLines: 6,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText:
                      'Condition, what is included, and anything a buyer should know.',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v?.trim().length ?? 0) < 10
                    ? 'Add at least 10 characters.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: zone,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pickup location',
                  border: OutlineInputBorder(),
                ),
                items: repo.pickupZones
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                validator: (v) =>
                    v == null ? 'Choose a pickup location.' : null,
                onChanged: (v) => zone = v,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: saving ? null : save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                ),
                child: Text(
                  saving
                      ? 'Saving…'
                      : widget.editingId == null
                      ? 'Post listing'
                      : 'Save changes',
                ),
              ),
              if (repo.isDemo)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Local demo: your listing is saved on this device and is not publicly posted.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
