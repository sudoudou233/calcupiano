import 'package:calcupiano/design/multiplatform.dart';
import 'package:calcupiano/design/theme.dart';
import 'package:calcupiano/events.dart';
import 'package:calcupiano/foundation.dart';
import 'package:calcupiano/r.dart';
import 'package:calcupiano/stage_manager.dart';
import 'package:calcupiano/ui/soundpack_composer.dart';
import 'package:calcupiano/ui/soundpack_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:rettulf/rettulf.dart';
import 'package:calcupiano/i18n.dart';

part 'soundpack.i18n.dart';

const double _iconSize = 36;

class SoundpackPage extends StatefulWidget {
  const SoundpackPage({super.key});

  @override
  State<SoundpackPage> createState() => _SoundpackPageState();
}

class _SoundpackPageState extends State<SoundpackPage> with LockOrientationMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return WillPopScope(
      onWillPop: () async {
        await StageManager.closeSoundpackPreview(ctx: context);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: I18n.title.text(),
          centerTitle: context.isCupertino,
          actions: [
            PullDownButton(
              itemBuilder: (context) => [
                PullDownMenuItem(
                  icon: Icons.create,
                  title: I18n.createSoundpack,
                  onTap: () {},
                ),
                const PullDownMenuDivider(),
                PullDownMenuTitle(
                  title: I18n.importSoundpack.text(),
                ),
                PullDownMenuActionsRow.medium(
                  items: [
                    PullDownMenuItem(
                      enabled: false,
                      onTap: () {},
                      title: I18n.link,
                      icon: Icons.link,
                    ),
                    if (!kIsWeb)
                      PullDownMenuItem(
                        onTap: () async {
                          await Packager.pickAndImportSoundpackArchive();
                        },
                        title: I18n.localFile,
                        icon: Icons.storage,
                      )
                  ],
                )
              ],
              position: PullDownMenuPosition.automatic,
              buttonBuilder: (context, showMenu) => IconButton(
                onPressed: showMenu,
                icon: const Icon(
                  CupertinoIcons.ellipsis_circle,
                  size: 28,
                ),
              ),
            )
          ],
        ),
        body: buildBody(),
      ),
    );
  }

  @ListenTo([K.customSoundpackIdList])
  Widget buildBody() {
    return H.listenToCustomSoundpackIdList() <<
        (ctx, _, c) {
          return buildSoundpackList(ctx);
        };
  }

  @ListenTo([K.customSoundpackIdList])
  Widget buildSoundpackList(BuildContext ctx) {
    const builtinList = R.builtinSoundpacks;
    final customList = H.customSoundpackIdList ?? const [];
    return MasonryGridView.extent(
      maxCrossAxisExtent: 380,
      itemCount: builtinList.length + customList.length,
      physics: const RangeMaintainingScrollPhysics(),
      itemBuilder: (ctx, index) {
        final Widget res;
        if (index < builtinList.length) {
          res = BuiltinSoundpackItem(
            soundpack: builtinList[index],
          );
        } else {
          res = CustomSoundpackItem(id: customList[index - builtinList.length]);
        }
        return res;
      },
    );
  }
}

class BuiltinSoundpackItem extends StatefulWidget {
  final BuiltinSoundpack soundpack;

  const BuiltinSoundpackItem({
    super.key,
    required this.soundpack,
  });

  @override
  State<BuiltinSoundpackItem> createState() => _BuiltinSoundpackItemState();
}

class _BuiltinSoundpackItemState extends State<BuiltinSoundpackItem> with TickerProviderStateMixin {
  BuiltinSoundpack get soundpack => widget.soundpack;
  var isPlaying = false;
  late final AnimationController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 500),
    );
  }

  @override
  Widget build(BuildContext context) {
    return H.listenToCurrentSoundpackID() << (ctx, _, __) => buildCard(context);
  }

  @ListenTo([K.currentSoundpackID])
  Widget buildCard(
    BuildContext ctx,
  ) {
    final isSelected = H.currentSoundpackID == soundpack.id;
    Widget card = [
      [
        AnimatedOpacity(
          opacity: isSelected ? 1.0 : 0.15,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastLinearToSlowEaseIn,
          child: ClipRRect(
            borderRadius: ctx.cardBorderRadius,
            child: soundpack.preview
                .build(
                  ctx,
                  fit: BoxFit.fill,
                )
                .container(w: double.infinity),
          ),
        ),
      ].stack(),
      ListTile(
        selected: isSelected,
        title: soundpack.displayName.text(style: ctx.textTheme.titleLarge),
        subtitle: [
          "Liplum".text(style: ctx.textTheme.bodyLarge),
          "This is a description.".text(
            style: ctx.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ].column(caa: CrossAxisAlignment.start),
      ),
      ButtonBar(
        children: [
          IconButton(
            icon: AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: CurveTween(curve: Curves.easeIn).animate(ctrl),
            ),
            onPressed: () {
              setState(() {
                isPlaying = !isPlaying;
              });
              if (isPlaying) {
                ctrl.forward();
              } else {
                ctrl.reverse();
              }
            },
          ),
          moreMenu(ctx, soundpack).align(at: Alignment.topRight),
        ],
      ),
    ].column();
    card = InkWell(
      borderRadius: ctx.cardBorderRadius,
      onTap: () {
        eventBus.fire(SoundpackChangeEvent(soundpack));
      },
      child: card,
    ).inSoundpackCard(isSelected: isSelected);
    return card;
  }
}

class CustomSoundpackItem extends StatefulWidget {
  final String id;

  const CustomSoundpackItem({
    super.key,
    required this.id,
  });

  @override
  State<CustomSoundpackItem> createState() => _CustomSoundpackItemState();
}

class _CustomSoundpackItemState extends State<CustomSoundpackItem> {
  /// Cache the Soundpack object, because deserialization is expensive.
  ExternalSoundpackProtocol? _soundpack;

  @override
  void initState() {
    super.initState();
    _soundpack = DB.getSoundpackById(widget.id);
  }

  @override
  void didUpdateWidget(covariant CustomSoundpackItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update current Soundpack object, perhaps due to a deletion.
    _soundpack = DB.getSoundpackById(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final soundpack = _soundpack;
    if (soundpack != null) {
      return H.listenToCurrentSoundpackID() << (ctx, _, __) => buildCard(context, soundpack);
    } else {
      return buildCorruptedSoundpack(context);
    }
  }

  @ListenTo([K.currentSoundpackID])
  Widget buildCard(BuildContext ctx, ExternalSoundpackProtocol soundpack) {
    final isSelected = H.currentSoundpackID == soundpack.id;
    if (soundpack is LocalSoundpack) {
      return buildLocalSoundpackCard(ctx, isSelected, soundpack);
    } else if (soundpack is UrlSoundpack) {
      return buildUrlSoundpackCard(ctx, isSelected, soundpack);
    } else {
      return const SizedBox();
    }
  }

  @ListenTo([K.currentSoundpackID])
  Widget buildLocalSoundpackCard(BuildContext ctx, bool isSelected, LocalSoundpack soundpack) {
    return ListTile(
      leading: _buildSoundpackSwitchIcon(isSelected, soundpack),
      onTap: () {
        eventBus.fire(SoundpackChangeEvent(soundpack));
      },
      selected: isSelected,
      title: (soundpack.meta.name ?? "No Name").text(style: ctx.textTheme.headlineSmall),
      subtitle: [
        // TODO: Better author text
        (soundpack.meta.author ?? "No Author").text(),
        (soundpack.meta.description ?? "No Info").text(),
      ].column(caa: CrossAxisAlignment.start),
      trailing: moreMenu(ctx, soundpack),
    );
  }

  @ListenTo([K.currentSoundpackID])
  Widget buildUrlSoundpackCard(BuildContext ctx, bool isSelected, UrlSoundpack soundpack) {
    return ListTile(
      leading: _buildSoundpackSwitchIcon(isSelected, soundpack),
      selected: isSelected,
      onTap: () {
        eventBus.fire(SoundpackChangeEvent(soundpack));
      },
      title: (soundpack.meta.name ?? "No Name").text(style: ctx.textTheme.headlineSmall),
      subtitle: (soundpack.meta.description ?? "No Info").text(),
      trailing: moreMenu(ctx, soundpack),
    );
  }

  Widget buildCorruptedSoundpack(BuildContext ctx) {
    return ListTile(
      leading: const Icon(Icons.sentiment_very_dissatisfied_outlined, size: _iconSize),
      title: I18n.corruptedSoundpack.text(),
      subtitle: I18n.corruptedSoundpackSubtitle.text(),
      trailing: Icon(Icons.delete_outline, color: ctx.$red$, size: _iconSize).onTap(() async {
        await DB.removeSoundpackById(widget.id);
      }),
    );
  }
}

Widget _buildSoundpackSwitchIcon(bool isSelected, SoundpackProtocol soundpack) {
  if (isSelected) {
    return const Icon(Icons.done, size: _iconSize);
  } else {
    return const SizedBox.square(dimension: _iconSize);
  }
}

extension _MenuX on State {
  Widget moreMenu(
    BuildContext ctx,
    SoundpackProtocol soundpack,
  ) {
    List<PopupMenuEntry> buildExportSoundpackButtons(LocalSoundpack soundpack) {
      final buttons = <PopupMenuEntry>[];
      void add(String title, IconData icon, VoidCallback onTap) {
        buttons.add(PopupMenuItem(
          child: ListTile(
            leading: Icon(icon),
            title: title.text(),
            onTap: () async {
              ctx.navigator.pop();
              onTap();
            },
          ),
        ));
      }

      // TODO: I18n
      if (isSupportShareFiles) {
        add(I18n.op.share, Icons.share_rounded, () async {
          await StageManager.closeSoundpackPreview(ctx: context);
          await Packager.shareSoundpackArchive(soundpack);
        });
      } else {
        add(I18n.op.saveAs, Icons.save_as, () async {
          await StageManager.closeSoundpackPreview(ctx: context);
          await Packager.saveAsSoundpackArchive(soundpack);
        });
      }

      return buttons;
    }

    final btn = PopupMenuButton(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      itemBuilder: (BuildContext context) => <PopupMenuEntry>[
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.piano_outlined),
            title: I18n.op.play$Music.text(),
            onTap: () async {
              ctx.navigator.pop();
              StageManager.showSoundpackPreviewOf(soundpack, ctx: context);
            },
          ),
        ),
        if (soundpack is LocalSoundpack)
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.audio_file_outlined),
              title:I18n.op.compose.text(),
              onTap: () async {
                await StageManager.closeSoundpackPreview(ctx: context);
                ctx.navigator.pop();
                ctx.navigator.push(MaterialPageRoute(builder: (_) => SoundpackComposer(soundpack)));
              },
            ),
          ),
        const PopupMenuDivider(),
        if (soundpack is LocalSoundpack)
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: I18n.op.edit.text(),
              onTap: () async {
                await StageManager.closeSoundpackPreview(ctx: context);
                ctx.navigator.pop();
                final anyChanged =
                    await ctx.navigator.push(MaterialPageRoute(builder: (_) => LocalSoundpackEditor(soundpack)));
                if (anyChanged == true) {
                  if (!mounted) return;
                  // ignore: invalid_use_of_protected_member
                  setState(() {});
                }
              },
            ),
          ),
        if (!kIsWeb)
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: I18n.op.duplicate.text(),
              onTap: () async {
                await StageManager.closeSoundpackPreview(ctx: context);
                ctx.navigator.pop();
                await Packager.duplicateSoundpack(soundpack);
              },
            ),
          ),
        if (soundpack is LocalSoundpack && isDesktop)
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: I18n.op.revealInFolder.text(),
              onTap: () async {
                await StageManager.closeSoundpackPreview(ctx: context);
                ctx.navigator.pop();
                await Packager.revealSoundpackInFolder(soundpack);
              },
            ),
          ),
        if (soundpack is LocalSoundpack) ...buildExportSoundpackButtons(soundpack),
        if (soundpack is! BuiltinSoundpack)
          PopupMenuItem(
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: ctx.$red$),
              title: I18n.op.delete.text(style: TextStyle(color: ctx.$red$)),
              onTap: () async {
                await StageManager.closeSoundpackPreview(ctx: context);
                ctx.navigator.pop();
                await Future.delayed(const Duration(milliseconds: 500));
                await DB.removeSoundpackById(soundpack.id);
              },
            ),
          ),
      ],
      child: IgnorePointer(
          child: TextButton(
        child: const Icon(Icons.more_horiz_rounded),
        onPressed: () {},
      )),
    );
    return btn;
  }
}

extension _SoundpackCardX on Widget {
  Widget inSoundpackCard({required bool isSelected}) {
    return inCard(
      elevation: isSelected ? 15 : 2,
    );
  }
}
