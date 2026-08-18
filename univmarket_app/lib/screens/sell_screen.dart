import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/gradient_button.dart';
import '../widgets/screen_scaffold.dart';

const _segments = ['Cash only', 'Trade only', 'Cash + trade'];

class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  int segment = 0;
  bool tradesOn = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Text(
              'Sell an item',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                _PhotoSlot(border: c.accent, iconColor: c.accent),
                const SizedBox(width: 10),
                _PhotoSlot(border: c.line, iconColor: c.inkFaint),
                const SizedBox(width: 10),
                _PhotoSlot(border: c.line, iconColor: c.inkFaint),
                const SizedBox(width: 10),
                _PhotoSlot(border: c.line, iconColor: c.inkFaint),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Field(label: 'Title', value: 'Mini fridge, 3.2 cu ft'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: _Field(label: 'Price', value: '\$55', bare: true),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Field(label: 'Condition', value: 'Good', bare: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Field(label: 'Category', value: 'Dorm essentials'),
          _Field(
            label: 'Description',
            value:
                'Used one year in Rappahannock Dorms. Fridge and small freezer compartment both work great, minor scuff on the door.',
            multiline: true,
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                for (var i = 0; i < _segments.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => segment = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: segment == i ? c.surface : null,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          _segments[i],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: segment == i ? c.ink : c.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accept trade offers',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Buyers can offer their own listings instead of cash',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: c.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: tradesOn,
                  onChanged: (v) => setState(() => tradesOn = v),
                  activeThumbColor: c.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Field(label: 'Pickup zone', value: 'Rappahannock Dorms'),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
            child: GradientButton(
              label: 'Post listing',
              onPressed: () async {
                // Fields above are static display text, not a real form yet
                // (pre-existing gap) — post whatever's currently shown.
                await context.read<Repository>().createListing(
                  title: 'Mini fridge, 3.2 cu ft',
                  price: 55,
                  condition: Condition.good,
                  category: 'Dorm essentials',
                  description:
                      'Used one year in Rappahannock Dorms. Fridge and small '
                      'freezer compartment both work great, minor scuff on '
                      'the door.',
                  acceptsTrades: tradesOn,
                  pickupZoneName: 'Rappahannock Dorms',
                );
                if (context.mounted) context.go('/');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final Color border, iconColor;
  const _PhotoSlot({required this.border, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 1.5, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(Icons.add_rounded, size: 22, color: iconColor),
    );
  }
}

class _Field extends StatelessWidget {
  final String label, value;
  final bool multiline, bare;
  const _Field({
    required this.label,
    required this.value,
    this.multiline = false,
    this.bare = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final field = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: c.inkFaint,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: multiline ? 4 : 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 14.5, color: c.ink),
          ),
        ],
      ),
    );
    if (bare) return field;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: field,
    );
  }
}
