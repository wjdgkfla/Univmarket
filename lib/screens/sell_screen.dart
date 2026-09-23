import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/listing_photo.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/async_action.dart';
import '../widgets/screen_scaffold.dart';

class SellScreen extends StatefulWidget {
  const SellScreen({super.key, this.editingId});
  final String? editingId;
  @override
  State<SellScreen> createState() => _SellScreenState();
}

/// Dropdown sentinel for "type your own pickup spot".
const _customPickupOption = '\u0000custom';
const _maxPhotos = 6;

class _SellScreenState extends State<SellScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      price = TextEditingController(),
      description = TextEditingController(),
      customPickup = TextEditingController();
  String category = 'Electronics';
  String? zone;
  final photos = <String>[];
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
      if (repo.pickupZones.contains(listing.zone)) {
        zone = listing.zone;
      } else if (listing.zone.isNotEmpty) {
        // A removed zone, or a custom spot: keep it editable as free text.
        zone = _customPickupOption;
        customPickup.text = listing.zone;
      }
      photos.addAll(
        listing.images.isNotEmpty ? listing.images : [?listing.imageSource],
      );
    }
  }

  @override
  void dispose() {
    title.dispose();
    price.dispose();
    description.dispose();
    customPickup.dispose();
    super.dispose();
  }

  void error(Object e) {
    if (mounted) showError(context, e);
  }

  Future<void> choosePhoto() async {
    if (photos.length >= _maxPhotos) return;
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
      if (mounted) setState(() => photos.add(selected.dataUri));
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
        pickupZoneName: zone == _customPickupOption ? null : zone,
        customPickup: zone == _customPickupOption ? customPickup.text : null,
        imageSources: photos,
        editingId: widget.editingId,
      );
      if (!mounted) return;
      if (widget.editingId == null) {
        // The Sell tab stays mounted across tab switches. A completed post
        // must not remain as a draft that can be accidentally posted twice.
        form.currentState!.reset();
        title.clear();
        price.clear();
        description.clear();
        customPickup.clear();
        setState(() {
          photos.clear();
          category = 'Electronics';
          condition = Condition.good;
          zone = context.read<Repository>().pickupZones.firstOrNull;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<Repository>().isDemo
                ? 'Listing saved on this device.'
                : 'Listing saved to your marketplace.',
          ),
        ),
      );
      final router = GoRouter.of(context);
      final visiblePath =
          router.routerDelegate.currentConfiguration.last.matchedLocation;
      final formPath = widget.editingId == null
          ? '/sell'
          : '/edit/${widget.editingId}';
      if (visiblePath == formPath) router.go('/');
    } catch (e) {
      error(e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final editing = widget.editingId == null
        ? null
        : repo.getListing(widget.editingId!);
    if (widget.editingId != null &&
        (editing == null || editing.sellerId != repo.me.id)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Listing unavailable')),
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Back to marketplace'),
          ),
        ),
      );
    }
    final c = context.colors;
    final editingMode = widget.editingId != null;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: c.ink,
        ),
      ),
    );

    Widget photoFallback() => Center(
      child: Text(
        'Photo unavailable',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: c.inkSoft),
      ),
    );
    Widget photoPreview(String src) => src.startsWith('data:')
        ? Image.memory(
            base64Decode(src.split(',').last),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => photoFallback(),
          )
        : src.startsWith('https://')
        ? Image.network(
            src,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => photoFallback(),
          )
        : Image.asset(
            src,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => photoFallback(),
          );

    return ScreenScaffold(
      navClearance: !editingMode,
      title: editingMode ? 'Edit your listing' : 'New listing',
      trailing: editingMode
          ? TextButton(
              onPressed: saving
                  ? null
                  : () => context.canPop()
                        ? context.pop()
                        : context.go('/profile'),
              child: const Text('Cancel editing'),
            )
          : null,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: 15,
                        color: c.accent,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Listing at ${repo.me.school}',
                          style: TextStyle(fontSize: 14, color: c.inkSoft),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    photos.isEmpty
                        ? 'Add up to $_maxPhotos photos. A clear, well-lit first photo helps your item sell faster.'
                        : 'Long-press a photo to reorder. The first is the cover.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: c.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 104,
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      buildDefaultDragHandles: true,
                      itemCount:
                          photos.length + (photos.length < _maxPhotos ? 1 : 0),
                      onReorder: (oldIndex, newIndex) {
                        // The trailing "add" tile is not reorderable.
                        if (oldIndex >= photos.length ||
                            newIndex > photos.length) {
                          return;
                        }
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          photos.insert(newIndex, photos.removeAt(oldIndex));
                        });
                      },
                      itemBuilder: (context, index) {
                        if (index == photos.length) {
                          return Padding(
                            key: const ValueKey('add-photo'),
                            padding: const EdgeInsets.only(right: 10),
                            child: Semantics(
                              button: true,
                              label: 'Add a photo',
                              excludeSemantics: true,
                              child: Material(
                                color: c.surface2,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.photo,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: saving ? null : choosePhoto,
                                  child: SizedBox(
                                    width: 96,
                                    height: 96,
                                    child: MediaQuery.withClampedTextScaling(
                                      maxScaleFactor: 1.2,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            CupertinoIcons.camera,
                                            size: 24,
                                            color: c.ink,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            photos.isEmpty
                                                ? 'Add photo'
                                                : 'Add',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: c.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        final src = photos[index];
                        return Padding(
                          key: ValueKey(src),
                          padding: const EdgeInsets.only(right: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.photo,
                            ),
                            child: SizedBox(
                              width: 96,
                              height: 96,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ColoredBox(
                                    color: c.surface2,
                                    child: photoPreview(src),
                                  ),
                                  if (index == 0)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        color: const Color(0x99111214),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 3,
                                        ),
                                        child: const Text(
                                          'Cover',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    right: 3,
                                    top: 3,
                                    child: Semantics(
                                      button: true,
                                      label: 'Remove photo',
                                      excludeSemantics: true,
                                      child: GestureDetector(
                                        onTap: saving
                                            ? null
                                            : () => setState(
                                                () => photos.remove(src),
                                              ),
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: const BoxDecoration(
                                            color: Color(0xB3111214),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            CupertinoIcons.xmark,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  label('Details'),
                  TextFormField(
                    enabled: !saving,
                    controller: title,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'What are you selling?',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 3
                        ? 'Use at least 3 characters.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    enabled: !saving,
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price in USD',
                      prefixText: '\$ ',
                      helperText: 'Whole dollars. Enter 0 to give it away.',
                    ),
                    validator: (v) {
                      final amount = int.tryParse(v?.trim() ?? '');
                      return amount == null || amount < 0 || amount > 100000
                          ? 'Enter a whole number from 0 to 100000.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    icon: const Icon(CupertinoIcons.chevron_down, size: 16),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: saving ? null : (v) => category = v!,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Condition>(
                    initialValue: condition,
                    isExpanded: true,
                    icon: const Icon(CupertinoIcons.chevron_down, size: 16),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    decoration: const InputDecoration(labelText: 'Condition'),
                    items: Condition.values
                        .map(
                          (v) =>
                              DropdownMenuItem(value: v, child: Text(v.label)),
                        )
                        .toList(),
                    onChanged: saving ? null : (v) => condition = v!,
                  ),
                  label('Description'),
                  TextFormField(
                    enabled: !saving,
                    controller: description,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText:
                          'Condition, what is included, and anything a buyer should know.',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 10
                        ? 'Add at least 10 characters.'
                        : null,
                  ),
                  label('Pickup'),
                  DropdownButtonFormField<String>(
                    initialValue: zone,
                    isExpanded: true,
                    icon: const Icon(CupertinoIcons.chevron_down, size: 16),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    decoration: InputDecoration(
                      labelText: 'Pickup location',
                      prefixIcon: Icon(
                        CupertinoIcons.location,
                        size: 18,
                        color: c.inkSoft,
                      ),
                    ),
                    items: [
                      for (final v in repo.pickupZones)
                        DropdownMenuItem(value: v, child: Text(v)),
                      const DropdownMenuItem(
                        value: _customPickupOption,
                        child: Text('Other — type a building name'),
                      ),
                    ],
                    validator: (v) =>
                        v == null ? 'Choose a pickup location.' : null,
                    onChanged: saving ? null : (v) => setState(() => zone = v),
                  ),
                  AnimatedSize(
                    duration: AppMotion.of(context, AppMotion.base),
                    curve: AppMotion.curve,
                    alignment: Alignment.topCenter,
                    child: zone != _customPickupOption
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextFormField(
                              key: const Key('sell-custom-pickup'),
                              enabled: !saving,
                              controller: customPickup,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 80,
                              decoration: const InputDecoration(
                                labelText: 'Building or spot name',
                                hintText: 'e.g. Fenwick Library lobby',
                              ),
                              validator: (v) =>
                                  zone == _customPickupOption &&
                                      (v?.trim().length ?? 0) < 3
                                  ? 'Use at least 3 characters.'
                                  : null,
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: saving ? null : save,
                    child: Text(
                      saving
                          ? 'Saving…'
                          : editingMode
                          ? 'Save changes'
                          : 'Post listing',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
