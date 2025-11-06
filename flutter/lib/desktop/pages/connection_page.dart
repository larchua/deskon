// main window right pane

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';

import '../../common.dart';
import '../../common/formatter/id_formatter.dart';
import '../../common/widgets/autocomplete.dart';
import '../../models/platform_model.dart';
import '../../common/widgets/peers_view.dart';
import '../../models/usage_time_model.dart';
import 'package:flutter/foundation.dart';

class OnlineStatusWidget extends StatefulWidget {
  const OnlineStatusWidget({Key? key, this.onSvcStatusChanged})
      : super(key: key);

  final VoidCallback? onSvcStatusChanged;

  @override
  State<OnlineStatusWidget> createState() => _OnlineStatusWidgetState();
}

/// State for the connection page.
class _OnlineStatusWidgetState extends State<OnlineStatusWidget> {
  final _svcStopped = Get.find<RxBool>(tag: 'stop-service');
  final _svcIsUsingPublicServer = true.obs;
  Timer? _updateTimer;

  double get em => 14.0;
  double? get height => bind.isIncomingOnly() ? null : em * 3;

  void onUsePublicServerGuide() {
    const url = "https://rustdesk.com/pricing";
    canLaunchUrlString(url).then((can) {
      if (can) {
        launchUrlString(url);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _updateTimer = periodic_immediate(Duration(seconds: 1), () async {
      updateStatus();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIncomingOnly = bind.isIncomingOnly();
    startServiceWidget() => Offstage(
          offstage: !_svcStopped.value,
          child: InkWell(
                  onTap: () async {
                    await start_service(true);
                  },
                  child: Text(translate("Start service"),
                      style: TextStyle(
                          decoration: TextDecoration.underline, fontSize: em)))
              .marginOnly(left: em),
        );

    setupServerWidget() => Flexible(
          child: Offstage(
            offstage: !(!_svcStopped.value &&
                stateGlobal.svcStatus.value == SvcStatus.ready &&
                _svcIsUsingPublicServer.value),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(', ', style: TextStyle(fontSize: em)),
                Flexible(
                  child: InkWell(
                    onTap: onUsePublicServerGuide,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            translate('setup_server_tip'),
                            style: TextStyle(
                                decoration: TextDecoration.underline,
                                fontSize: em),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        );

    basicWidget() => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 8,
              width: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _svcStopped.value ||
                        stateGlobal.svcStatus.value == SvcStatus.connecting
                    ? kColorWarn
                    : (stateGlobal.svcStatus.value == SvcStatus.ready
                        ? Color.fromARGB(255, 50, 190, 166)
                        : Color.fromARGB(255, 224, 79, 95)),
              ),
            ).marginSymmetric(horizontal: em),
            Container(
              width: isIncomingOnly ? 226 : null,
              child: _buildConnStatusMsg(),
            ),
            // stop
            if (!isIncomingOnly) startServiceWidget(),
            // ready && public
            // No need to show the guide if is custom client.
            if (!isIncomingOnly) setupServerWidget(),
          ],
        );

    return Container(
      height: height,
      child: Obx(() => isIncomingOnly
          ? Column(
              children: [
                basicWidget(),
                Align(
                        child: startServiceWidget(),
                        alignment: Alignment.centerLeft)
                    .marginOnly(top: 2.0, left: 22.0),
              ],
            )
          : basicWidget()),
    ).paddingOnly(right: isIncomingOnly ? 8 : 0);
  }

  _buildConnStatusMsg() {
    widget.onSvcStatusChanged?.call();
    return Text(
      _svcStopped.value
          ? translate("Service is not running")
          : stateGlobal.svcStatus.value == SvcStatus.connecting
              ? translate("connecting_status")
              : stateGlobal.svcStatus.value == SvcStatus.notReady
                  ? translate("not_ready_status")
                  : translate('Ready'),
      style: TextStyle(fontSize: em),
    );
  }

  updateStatus() async {
    final status =
        jsonDecode(await bind.mainGetConnectStatus()) as Map<String, dynamic>;
    final statusNum = status['status_num'] as int;
    if (statusNum == 0) {
      stateGlobal.svcStatus.value = SvcStatus.connecting;
    } else if (statusNum == -1) {
      stateGlobal.svcStatus.value = SvcStatus.notReady;
    } else if (statusNum == 1) {
      stateGlobal.svcStatus.value = SvcStatus.ready;
    } else {
      stateGlobal.svcStatus.value = SvcStatus.notReady;
    }
    _svcIsUsingPublicServer.value = await bind.mainIsUsingPublicServer();
    try {
      stateGlobal.videoConnCount.value = status['video_conn_count'] as int;
    } catch (_) {}
  }
}

/// Connection page for connecting to a remote peer.
class ConnectionPage extends StatefulWidget {
  const ConnectionPage({Key? key}) : super(key: key);

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

/// State for the connection page.
class _ConnectionPageState extends State<ConnectionPage>
    with SingleTickerProviderStateMixin, WindowListener {
  /// Controller for the id input bar.
  final _idController = IDTextEditingController();
  
  /// 定时器用于更新剩余时长显示
  Timer? _usageTimeUpdateTimer;

  final RxBool _idInputFocused = false.obs;
  final FocusNode _idFocusNode = FocusNode();
  final TextEditingController _idEditingController = TextEditingController();

  String selectedConnectionType = 'Connect';

  bool isWindowMinimized = false;

  final AllPeersLoader _allPeersLoader = AllPeersLoader();

  // https://github.com/flutter/flutter/issues/157244
  Iterable<Peer> _autocompleteOpts = [];

  final RxBool _passwordVisible = false.obs;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _allPeersLoader.init(setState);
    _idFocusNode.addListener(onFocusChanged);
    if (_idController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final lastRemoteId = await bind.mainGetLastRemoteId();
        if (lastRemoteId != _idController.id) {
          setState(() {
            _idController.id = lastRemoteId;
          });
        }
      });
    }
    Get.put<TextEditingController>(_idEditingController);
    Get.put<IDTextEditingController>(_idController);
    windowManager.addListener(this);
    
    // 定时更新剩余时长显示（仅开发版）
    if (!kReleaseMode) {
      _usageTimeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {}); // 触发UI更新
        }
      });
    }
  }

  @override
  void dispose() {
    _usageTimeUpdateTimer?.cancel();
    _idController.dispose();
    _passwordController.dispose();
    windowManager.removeListener(this);
    _allPeersLoader.clear();
    _idFocusNode.removeListener(onFocusChanged);
    _idFocusNode.dispose();
    _idEditingController.dispose();
    if (Get.isRegistered<IDTextEditingController>()) {
      Get.delete<IDTextEditingController>();
    }
    if (Get.isRegistered<TextEditingController>()) {
      Get.delete<TextEditingController>();
    }
    super.dispose();
  }

  @override
  void onWindowEvent(String eventName) {
    super.onWindowEvent(eventName);
    if (eventName == 'minimize') {
      isWindowMinimized = true;
    } else if (eventName == 'maximize' || eventName == 'restore') {
      if (isWindowMinimized && isWindows) {
        // windows can't update when minimized.
        Get.forceAppUpdate();
      }
      isWindowMinimized = false;
    }
  }

  @override
  void onWindowEnterFullScreen() {
    // Remove edge border by setting the value to zero.
    stateGlobal.resizeEdgeSize.value = 0;
  }

  @override
  void onWindowLeaveFullScreen() {
    // Restore edge border to default edge size.
    stateGlobal.resizeEdgeSize.value = stateGlobal.isMaximized.isTrue
        ? kMaximizeEdgeSize
        : windowResizeEdgeSize;
  }

  @override
  void onWindowClose() {
    super.onWindowClose();
    bind.mainOnMainWindowClose();
  }

  void onFocusChanged() {
    _idInputFocused.value = _idFocusNode.hasFocus;
    if (_idFocusNode.hasFocus) {
      if (_allPeersLoader.needLoad) {
        _allPeersLoader.getAllPeers();
      }

      final textLength = _idEditingController.value.text.length;
      // Select all to facilitate removing text, just following the behavior of address input of chrome.
      _idEditingController.selection =
          TextSelection(baseOffset: 0, extentOffset: textLength);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoingOnly = bind.isOutgoingOnly();
    return Column(
      children: [
        // 第一段: 本机信息（本机ID、临时密码、刷新、修改按钮）
        if (!isOutgoingOnly)
          ChangeNotifierProvider.value(
            value: gFFI.serverModel,
            child: Consumer<ServerModel>(
              builder: (context, model, child) {
                return _buildLocalDeviceInfo(context, model);
              },
            ),
          ),
        if (!isOutgoingOnly) const Divider(height: 1),
        // 第二段: 远程控制输入框及远程控制按钮、远程文件、远程摄像头等
        _buildRemoteControlSection(context),
        if (!isOutgoingOnly) const Divider(height: 1),
        // 第三段: 最近连接过的设备卡片
        Expanded(
          child: _buildRecentDevicesSection(context),
        ),
        if (!isOutgoingOnly) const Divider(height: 1),
        if (!isOutgoingOnly) OnlineStatusWidget()
      ],
    );
  }

  /// 构建本机ID和临时密码显示区域（第一段）
  Widget _buildLocalDeviceInfo(BuildContext context, ServerModel model) {
    final showOneTime = model.approveMode != 'click' &&
        model.verificationMethod != kUsePermanentPassword;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本机信息',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                // 本机ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.computer,
                            size: 18,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '本机ID',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onDoubleTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: model.serverId.text));
                                showToast(translate("Copied"));
                              },
                              child: Text(
                                model.serverId.text,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.color,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: model.serverId.text));
                              showToast(translate("Copied"));
                            },
                            tooltip: translate("Copy"),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 临时密码
                if (showOneTime) ...[
                  Container(
                    width: 1,
                    height: 60,
                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lock,
                              size: 18,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.6),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '一次性密码',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onDoubleTap: () {
                                  Clipboard.setData(ClipboardData(
                                      text: model.serverPasswd.text));
                                  showToast(translate("Copied"));
                                },
                                child: Text(
                                  model.serverPasswd.text,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.color,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              onPressed: () =>
                                  bind.mainUpdateTemporaryPassword(),
                              tooltip: translate('Refresh Password'),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            if (!bind.isDisableSettings())
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () {
                                  DesktopHomePage.switchToSettings(
                                      SettingsTabKey.safety);
                                },
                                tooltip: translate('Change Password'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ],
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

  /// 构建远程控制区域（第二段）
  Widget _buildRemoteControlSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '控制远程桌面',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: translate(isWeb ? "web_id_input_tip" : "id_input_tip"),
                child: Icon(
                  Icons.help_outline,
                  size: 18,
                  color: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.color
                      ?.withOpacity(0.5),
                ),
              ),
              // 显示剩余使用时长（仅开发版）
              if (!kReleaseMode) ...[
                const Spacer(),
                Obx(() {
                  final remainingText = UsageTimeModel.getRemainingTimeDisplayText();
                  if (remainingText == null) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          remainingText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                // 第一行：左侧远程ID输入框和右侧密码输入框
                Row(
                  children: [
                    // 左侧：远程ID输入框
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.desktop_windows,
                                size: 18,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '远程ID',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildRemoteIDTextField(context),
                        ],
                      ),
                    ),
                    // 分隔线
                    Container(
                      width: 1,
                      height: 60,
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    // 右侧：密码输入框
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lock,
                                size: 18,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '验证码',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: !_passwordVisible.value,
                            decoration: InputDecoration(
                              hintText: '验证码（可为空）',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 16),
                              suffixIcon: Obx(() => IconButton(
                                    icon: Icon(
                                      _passwordVisible.value
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _passwordVisible.value =
                                          !_passwordVisible.value;
                                    },
                                  )),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 第二行：功能按钮组
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 左侧：快捷连接按钮组（远程文件/远程摄像头/终端）
                    Row(
                      children: [
                        Tooltip(
                          message: translate('Transfer file'),
                          child: IconButton(
                            icon: const Icon(Icons.folder, size: 20),
                            onPressed: () => onConnect(isFileTransfer: true),
                            tooltip: translate('Transfer file'),
                          ),
                        ),
                        Tooltip(
                          message: translate('View camera'),
                          child: IconButton(
                            icon: const Icon(Icons.videocam, size: 20),
                            onPressed: () => onConnect(isViewCamera: true),
                            tooltip: translate('View camera'),
                          ),
                        ),
                        Tooltip(
                          message: '${translate('Terminal')} (beta)',
                          child: IconButton(
                            icon: const Icon(Icons.terminal, size: 20),
                            onPressed: () => onConnect(isTerminal: true),
                            tooltip: '${translate('Terminal')} (beta)',
                          ),
                        ),
                      ],
                    ),
                    // 右侧：连接按钮和更多菜单
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            onConnect(
                                password: _passwordController.text.isEmpty
                                    ? null
                                    : _passwordController.text);
                          },
                          child: const Text('连接'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建最近连接的设备区域（第三段）
  Widget _buildRecentDevicesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近连接',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: RecentPeersView(
              menuPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  /// Callback for the connect button.
  /// Connects to the selected peer.
  void onConnect({
    bool isFileTransfer = false,
    bool isViewCamera = false,
    bool isTerminal = false,
    String? password,
  }) {
    var id = _idController.id;
    connect(context, id,
        isFileTransfer: isFileTransfer,
        isViewCamera: isViewCamera,
        isTerminal: isTerminal,
        password: password);
  }

  /// UI for the remote ID TextField.
  /// Search for a peer.
  Widget _buildRemoteIDTextField(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: RawAutocomplete<Peer>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text == '') {
            _autocompleteOpts = const Iterable<Peer>.empty();
          } else if (_allPeersLoader.peers.isEmpty &&
              !_allPeersLoader.isPeersLoaded) {
            Peer emptyPeer = Peer(
              id: '',
              username: '',
              hostname: '',
              alias: '',
              platform: '',
              tags: [],
              hash: '',
              password: '',
              forceAlwaysRelay: false,
              rdpPort: '',
              rdpUsername: '',
              loginName: '',
              device_group_name: '',
            );
            _autocompleteOpts = [emptyPeer];
          } else {
            String textWithoutSpaces =
                textEditingValue.text.replaceAll(" ", "");
            if (int.tryParse(textWithoutSpaces) != null) {
              textEditingValue = TextEditingValue(
                text: textWithoutSpaces,
                selection: textEditingValue.selection,
              );
            }
            String textToFind = textEditingValue.text.toLowerCase();
            _autocompleteOpts = _allPeersLoader.peers
                .where((peer) =>
                    peer.id.toLowerCase().contains(textToFind) ||
                    peer.username.toLowerCase().contains(textToFind) ||
                    peer.hostname.toLowerCase().contains(textToFind) ||
                    peer.alias.toLowerCase().contains(textToFind))
                .toList();
          }
          return _autocompleteOpts;
        },
        focusNode: _idFocusNode,
        textEditingController: _idEditingController,
        fieldViewBuilder: (
          BuildContext context,
          TextEditingController fieldTextEditingController,
          FocusNode fieldFocusNode,
          VoidCallback onFieldSubmitted,
        ) {
          updateTextAndPreserveSelection(
              fieldTextEditingController, _idController.text);
          return Obx(() => SizedBox(
                height: 56, // 确保与密码输入框高度一致
                child: TextField(
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  focusNode: fieldFocusNode,
                  style: const TextStyle(
                    fontFamily: 'WorkSans',
                    fontSize: 22,
                    height: 1.4,
                  ),
                  maxLines: 1,
                  cursorColor: Theme.of(context).textTheme.titleLarge?.color,
                  decoration: InputDecoration(
                      filled: false,
                      counterText: '',
                      hintText: _idInputFocused.value
                          ? null
                          : translate('Enter Remote ID'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16)),
                  controller: fieldTextEditingController,
                  inputFormatters: [IDTextInputFormatter()],
                  onChanged: (v) {
                    _idController.id = v;
                  },
                  onSubmitted: (_) {
                    onConnect(
                        password: _passwordController.text.isEmpty
                            ? null
                            : _passwordController.text);
                  },
                ).workaroundFreezeLinuxMint(),
              ));
        },
        onSelected: (option) {
          setState(() {
            _idController.id = option.id;
            FocusScope.of(context).unfocus();
          });
        },
        optionsViewBuilder: (BuildContext context,
            AutocompleteOnSelected<Peer> onSelected, Iterable<Peer> options) {
          options = _autocompleteOpts;
          double maxHeight = options.length * 50;
          if (options.length == 1) {
            maxHeight = 52;
          } else if (options.length == 3) {
            maxHeight = 146;
          } else if (options.length == 4) {
            maxHeight = 193;
          }
          maxHeight = maxHeight.clamp(0, 200);

          return Align(
            alignment: Alignment.topLeft,
            child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Material(
                      elevation: 4,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: maxHeight,
                          maxWidth: 319,
                        ),
                        child: _allPeersLoader.peers.isEmpty &&
                                !_allPeersLoader.isPeersLoaded
                            ? Container(
                                height: 80,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ))
                            : Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: ListView(
                                  children: options
                                      .map((peer) => AutocompletePeerTile(
                                          onSelect: () => onSelected(peer),
                                          peer: peer))
                                      .toList(),
                                ),
                              ),
                      ),
                    ))),
          );
        },
      ),
    );
  }
}
