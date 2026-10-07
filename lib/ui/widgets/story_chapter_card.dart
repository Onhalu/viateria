import 'package:flutter/material.dart';

import '../../domain/youtube_url.dart';
import '../../models/models.dart';
import '../../theme/brand_colors.dart';
import 'story_youtube_view.dart';

/// Sage circle with a cream `?`. Locked story stops use this in the list.
/// The map draws the same mark as a registered icon, not this widget.
class StoryQuestionMark extends StatelessWidget {
  const StoryQuestionMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: BrandColors.sage,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '?',
            style: TextStyle(
              color: BrandColors.cream,
              fontSize: size * 0.56,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline story chapter. Cream fill, beige border, Playfair forest title.
///
/// [BrandColors.shellFill] is the welcome header and the bottom nav only —
/// this card never uses it. YouTube plays in-app; otherwise cover + body.
class StoryChapterCard extends StatefulWidget {
  const StoryChapterCard({
    super.key,
    required this.step,
    required this.locale,
    this.expandOnce = false,
  });

  final StoryStep step;
  final String locale;

  /// Expand on the first frame. Reduce-motion leaves the card collapsed;
  /// the parent still scrolls it into view.
  final bool expandOnce;

  @override
  State<StoryChapterCard> createState() => _StoryChapterCardState();
}

class _StoryChapterCardState extends State<StoryChapterCard> {
  var _expanded = false;
  var _appliedExpand = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyExpandOnce();
  }

  @override
  void didUpdateWidget(covariant StoryChapterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expandOnce && !oldWidget.expandOnce) {
      _appliedExpand = false;
    }
    _applyExpandOnce();
  }

  void _applyExpandOnce() {
    if (_appliedExpand || !widget.expandOnce) return;
    _appliedExpand = true;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _expanded = true;
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.step.copyFor(widget.locale);
    final videoId = youtubeVideoId(widget.step.youtubeUrl);
    final imageUrl = widget.step.imageUrl;
    final body = copy.description.trim();
    return Card(
      key: Key('story-chapter-${widget.step.id}'),
      color: BrandColors.cream,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: BrandColors.beige),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('story-chapter-toggle-${widget.step.id}'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      copy.title,
                      key: Key('story-chapter-title-${widget.step.id}'),
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        color: BrandColors.forest,
                        fontSize: 20,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: BrandColors.forest,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              key: Key('story-chapter-body-${widget.step.id}'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (videoId != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: StoryYoutubeEmbed(videoId: videoId),
                      ),
                    )
                  else if (imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          imageUrl,
                          key: Key('story-chapter-image-${widget.step.id}'),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: BrandColors.beige),
                        ),
                      ),
                    ),
                  if (videoId == null && body.isNotEmpty) ...[
                    if (imageUrl != null) const SizedBox(height: 12),
                    Text(
                      body,
                      key: Key('story-chapter-text-${widget.step.id}'),
                      style: const TextStyle(
                        color: BrandColors.bark,
                        fontSize: 15,
                        height: 1.45,
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
