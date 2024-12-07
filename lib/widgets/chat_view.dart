import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tealseed_chat/models/loading_indicator_message.dart';
import 'package:tealseed_chat/tealseed_chat.dart';
import 'package:tealseed_chat/widgets/input/input_box.dart';
import 'package:tealseed_chat/widgets/messages/unsupport_message_item.dart';
import 'package:tealseed_chat/widgets/users/user_avatar.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ChatView extends StatefulWidget {
  late final ChatThemeData theme;
  late final ChatController controller;
  ChatView({
    super.key,
    ChatThemeData? theme,
    ChatController? controller,
  }) {
    this.theme = theme ??
        ChatThemeData(
          light: ChatColorThemeData(),
          dark: ChatColorThemeData(),
        );
    this.controller = controller ?? ChatController();
  }
  @override
  State<StatefulWidget> createState() {
    return _ChatViewState();
  }
}

class _ChatViewState extends State<ChatView> {
  late final store = widget.controller.store;
  @override
  void initState() {
    super.initState();
  }

  void _dismissKeyboard() {
    store.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final view = ChatTheme(
      data: ChatThemeData(
        light: widget.theme.light,
        dark: widget.theme.dark,
      ),
      child: Builder(
        builder: (context) => Container(
          color: context.coloredTheme.backgroundColor,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _dismissKeyboard,
                      child: _buildMessageList(context),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _buildUnreadIndicator(context),
                    )
                  ],
                ),
              ),
              InputBox(
                controller: widget.controller,
                textEditingController: store.textEditingController,
                focusNode: store.focusNode,
                onSend: () {
                  store.sendMessage(
                    onSend: (output) async {
                      await widget.controller.actionHandler?.onSendMessage?.call(output);
                    },
                  );
                },
                onCameraTap: () async {
                  if (store.imageFiles.length >= widget.controller.config.imageMaxCount) {
                    return;
                  }
                  await store.pickImage(source: ImageSource.camera);
                  store.focusNode.requestFocus();
                },
                onAlbumTap: () async {
                  if (store.imageFiles.length >= widget.controller.config.imageMaxCount) {
                    return;
                  }
                  _dismissKeyboard();
                  await store.pickImage(source: ImageSource.gallery);
                  store.focusNode.requestFocus();
                },
                onImageTap: (imageFile) {
                  widget.controller.actionHandler?.onImageThumbnailTap?.call(imageFile);
                },
                onImageRemove: (imageFile) {
                  store.removeImage(image: imageFile);
                },
              ),
            ],
          ),
        ),
      ),
    );
    return view;
  }

  Widget _buildMessageList(BuildContext context) {
    return Observer(
      builder: (context) {
        final messages = store.messages.reversed.toList();
        return Align(
          alignment: Alignment.topCenter,
          child: ListView.separated(
            physics: const ClampingScrollPhysics(),
            reverse: false,
            shrinkWrap: true,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            controller: widget.controller.chatScrollController.controller,
            padding: context.layoutTheme.chatViewPadding,
            cacheExtent: 1000,
            separatorBuilder: (context, index) {
              final currentMessage = messages[index];
              final previousMessage = index + 1 < messages.length ? messages[index + 1] : null;
              final isSameUser = previousMessage != null && currentMessage.userId == previousMessage.userId;
              return SizedBox(height: isSameUser && !currentMessage.forceNewBlock ? 4 : 16);
            },
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return Observer(
                builder: (context) {
                  final message = messages[index];
                  final hideUserAvatar = message is ModelLoadingIndicatorMessage;
                  final previousMessage = index + 1 < messages.length ? messages[index + 1] : null;
                  final isMessageFromCurrentUser = store.isMessageFromCurrentUser(message);
                  final isSameUser = previousMessage != null && message.userId == previousMessage.userId;

                  final builder = widget.controller.viewFactory.buildFor(
                    context,
                    message: message,
                    isMessageFromCurrentUser: isMessageFromCurrentUser,
                  );
                  final messageItem = builder ?? UnsupportMessageItem(isCurrentUser: isMessageFromCurrentUser);
                  final user = store.users[message.userId];
                  final userAvatar = isSameUser && !message.forceNewBlock
                      ? SizedBox(width: context.layoutTheme.userAvatarSize)
                      : UserAvatar(
                          user: user,
                          onTap: () {
                            widget.controller.actionHandler?.onUserAvatarTap?.call(user);
                          },
                        );
                  const avatarMessageSpacing = 8.0;

                  // Wrap messageItem with Flexible widget
                  final flexibleMessageItem = Flexible(
                    child: GestureDetector(
                      onTap: () => widget.controller.actionHandler?.onMessageTap?.call(message),
                      child: messageItem,
                    ),
                  );

                  Widget contentView;
                  if (isMessageFromCurrentUser) {
                    contentView = Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: avatarMessageSpacing + context.layoutTheme.userAvatarSize),
                        flexibleMessageItem,
                        if (!hideUserAvatar)
                          Padding(
                            padding: const EdgeInsets.only(left: avatarMessageSpacing),
                            child: userAvatar,
                          ),
                      ],
                    );
                  } else {
                    contentView = Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!hideUserAvatar)
                          Padding(
                            padding: const EdgeInsets.only(right: avatarMessageSpacing),
                            child: userAvatar,
                          ),
                        flexibleMessageItem,
                        SizedBox(width: avatarMessageSpacing + context.layoutTheme.userAvatarSize),
                      ],
                    );
                  }
                  return VisibilityDetector(
                    key: message.widgetKey,
                    onVisibilityChanged: (visibility) {
                      if (visibility.visibleFraction == 1) {
                        store.readMessage(message: message);
                      }
                    },
                    child: contentView,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildUnreadIndicator(BuildContext context) {
    return Observer(
      builder: (context) {
        if (store.hasUnreadMessages) {
          return GestureDetector(
            onTap: () {
              widget.controller.scrollToBottom();
            },
            child: widget.controller.config.showUnreadCount
                ? IntrinsicWidth(
                    child: Container(
                      height: 32,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: context.coloredTheme.unreadIndicatorBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      alignment: Alignment.center,
                      child: Row(
                        children: [
                          Text(
                            '${store.unreadMessagesCount > 99 ? '99+' : store.unreadMessagesCount}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 4),
                          SvgPicture.asset(
                            'assets/svg/chat/arrow_down.svg',
                            width: 16,
                            height: 16,
                            package: kTealseedChatPackage,
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: context.coloredTheme.unreadIndicatorBackgroundColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/svg/chat/arrow_down.svg',
                      width: 24,
                      height: 24,
                      package: kTealseedChatPackage,
                    ),
                  ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
