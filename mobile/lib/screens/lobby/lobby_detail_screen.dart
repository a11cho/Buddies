import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/enums.dart';
import '../../core/service_registry.dart';
import '../../models/cart_item.dart';
import '../../models/chat_message.dart';
import '../../models/lobby.dart';
import '../../models/lobby_member.dart';
import '../../models/order_history_item.dart';
import '../../models/payment_record.dart';
import '../../models/receipt_attachment.dart';
import '../../models/user.dart';
import '../../services/cart_service.dart';
import '../../services/lobby_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/error_message_view.dart';
import '../../widgets/image_detail_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/payment_record_tile.dart';
import '../cart/cart_item_form_dialog.dart';
import '../profile/rating_dialog.dart';

// Lobby 상세 화면입니다.
// CartItem 편집, Cart Lock, 결제 확인, Lobby 상태 전환을 함께 제공합니다.
class LobbyDetailScreen extends StatefulWidget {
  const LobbyDetailScreen({super.key});

  @override
  State<LobbyDetailScreen> createState() => _LobbyDetailScreenState();
}

class _LobbyDetailScreenState extends State<LobbyDetailScreen> {
  static const int _maxReceiptImageBytes = 10 * 1024 * 1024;

  final ImagePicker _imagePicker = ImagePicker();
  Future<_LobbyDetailData>? _detailFuture;
  _LobbyDetailData? _cachedDetailData;
  int? _lobbyId;
  bool _isJoining = false;
  bool _isLeavingLobby = false;
  bool _isCancelingLobby = false;
  bool _isLockingCart = false;
  bool _isUpdatingStatus = false;
  bool _isUploadingReceipt = false;
  int? _confirmingPaymentRecordId;
  int? _kickingUserId;
  int? _transferringHostUserId;
  StreamSubscription<ChatMessage>? _lobbyEventSubscription;
  Timer? _lobbyEventRefreshTimer;
  int? _subscribedLobbyEventLobbyId;
  bool _isOpeningClosedLobbyRating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Navigator.pushNamed(..., arguments: lobbyId)로 받은 값을 읽습니다.
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final nextLobbyId = arguments is int ? arguments : null;

    if (_lobbyId != nextLobbyId) {
      _cancelLobbyEventSubscription();
      _lobbyId = nextLobbyId;
      _cachedDetailData = null;
      _detailFuture = nextLobbyId == null ? null : _loadDetail(nextLobbyId);
    }
  }

  @override
  void dispose() {
    _cancelLobbyEventSubscription();
    super.dispose();
  }

  Future<_LobbyDetailData> _loadDetail(int lobbyId) async {
    final user = await _loadCurrentUser();
    final lobby = await AppServices.lobbyService.getLobbyDetail(lobbyId);
    final receipt = await _loadReceipt(lobby);
    final myActiveLobby = await AppServices.lobbyService.getMyActiveLobby();
    final currentHostHasPaymentInfo = lobby.hostUserId == user.id
        ? await _loadCurrentHostPaymentInfoStatus()
        : null;
    final data = _LobbyDetailData(
      lobby: lobby,
      currentUser: user,
      isInActiveLobby: myActiveLobby != null,
      currentHostHasPaymentInfo: currentHostHasPaymentInfo,
      receipt: receipt,
    );
    if (mounted) {
      setState(() {
        _cachedDetailData = data;
      });
      _syncLobbyEventSubscription(data);
    } else {
      _cachedDetailData = data;
    }
    return data;
  }

  Future<ReceiptAttachment?> _loadReceipt(Lobby lobby) async {
    try {
      return await AppServices.lobbyService.getReceipt(lobby.lobbyId) ??
          _receiptFromLobby(lobby);
    } catch (_) {
      return _receiptFromLobby(lobby);
    }
  }

  ReceiptAttachment? _receiptFromLobby(Lobby lobby) {
    final receiptImageUrl = lobby.receiptImageUrl;
    if (receiptImageUrl == null || receiptImageUrl.isEmpty) {
      return null;
    }
    return ReceiptAttachment(
      lobbyId: lobby.lobbyId,
      receiptImageUrl: receiptImageUrl,
      uploadedByUserId: lobby.hostUserId,
    );
  }

  Future<User> _loadCurrentUser() async {
    try {
      return await AppServices.userService.getMe();
    } catch (_) {
      return AppServices.authService.getMe();
    }
  }

  Future<bool?> _loadCurrentHostPaymentInfoStatus() async {
    try {
      final paymentInfo = await AppServices.userService.getPaymentInfo();
      return paymentInfo?.isComplete == true;
    } catch (_) {
      return null;
    }
  }

  void _refreshDetail() {
    final lobbyId = _lobbyId;
    if (lobbyId == null) {
      return;
    }
    setState(() {
      _detailFuture = _loadDetail(lobbyId);
    });
  }

  Future<void> _openChat(Lobby lobby) async {
    _cancelLobbyEventSubscription();
    await Navigator.pushNamed(
      context,
      AppRoutes.chat,
      arguments: lobby.lobbyId,
    );
    if (!mounted) {
      return;
    }
    _refreshDetail();
  }

  Future<void> _attachReceipt(Lobby lobby) async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (pickedImage == null || !mounted) {
      return;
    }

    final attachment = await _receiptAttachmentFromPickedImage(pickedImage);
    if (attachment == null || !mounted) {
      return;
    }

    setState(() {
      _isUploadingReceipt = true;
    });
    try {
      final receipt = await AppServices.lobbyService.uploadReceiptImage(
        lobby.lobbyId,
        attachment,
      );
      if (!mounted) {
        return;
      }
      _replaceCachedReceipt(receipt);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt attached.')),
      );
      _refreshDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingReceipt = false;
        });
      }
    }
  }

  Future<ReceiptImageAttachment?> _receiptAttachmentFromPickedImage(
    XFile image,
  ) async {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected image is empty.')),
        );
      }
      return null;
    }
    if (bytes.length > _maxReceiptImageBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt image must be under 10MB.')),
        );
      }
      return null;
    }

    final contentType = image.mimeType ?? _inferImageContentType(image.name);
    if (!_isSupportedReceiptContentType(contentType)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only JPEG, PNG, GIF, or WebP images are supported.'),
          ),
        );
      }
      return null;
    }

    return ReceiptImageAttachment(
      filename: image.name.isEmpty ? 'receipt.jpg' : image.name,
      contentType: contentType,
      bytes: bytes,
    );
  }

  String _inferImageContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'application/octet-stream';
  }

  bool _isSupportedReceiptContentType(String contentType) {
    return contentType == 'image/jpeg' ||
        contentType == 'image/png' ||
        contentType == 'image/gif' ||
        contentType == 'image/webp';
  }

  void _replaceCachedReceipt(ReceiptAttachment receipt) {
    final data = _cachedDetailData;
    if (data == null) {
      return;
    }
    final updatedData = _LobbyDetailData(
      lobby: data.lobby.copyWith(receiptImageUrl: receipt.receiptImageUrl),
      currentUser: data.currentUser,
      isInActiveLobby: data.isInActiveLobby,
      currentHostHasPaymentInfo: data.currentHostHasPaymentInfo,
      receipt: receipt,
    );
    setState(() {
      _cachedDetailData = updatedData;
      _detailFuture = Future.value(updatedData);
    });
  }

  void _syncLobbyEventSubscription(_LobbyDetailData data) {
    final shouldSubscribe = _isActiveMember(data.lobby, data.currentUser.id);
    if (!shouldSubscribe) {
      _cancelLobbyEventSubscription();
      return;
    }

    final lobbyId = data.lobby.lobbyId;
    if (_subscribedLobbyEventLobbyId == lobbyId &&
        _lobbyEventSubscription != null) {
      return;
    }

    _cancelLobbyEventSubscription();
    _subscribedLobbyEventLobbyId = lobbyId;
    _lobbyEventSubscription =
        AppServices.chatService.watchMessages(lobbyId).listen(
      _handleLobbyEventMessage,
      onError: (_) {
        // Chat 화면이 아니므로 연결 실패를 화면 오류로 노출하지 않습니다.
      },
    );
  }

  void _cancelLobbyEventSubscription() {
    _lobbyEventRefreshTimer?.cancel();
    _lobbyEventRefreshTimer = null;
    _lobbyEventSubscription?.cancel();
    _lobbyEventSubscription = null;
    _subscribedLobbyEventLobbyId = null;
  }

  void _handleLobbyEventMessage(ChatMessage message) {
    if (!mounted || message.lobbyId != _lobbyId) {
      return;
    }
    if (_isClosedLobbyEvent(message)) {
      _lobbyEventRefreshTimer?.cancel();
      unawaited(_openClosedLobbyRatingFlow());
      return;
    }
    if (!_shouldRefreshForLobbyEvent(message)) {
      return;
    }

    _lobbyEventRefreshTimer?.cancel();
    _lobbyEventRefreshTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        _refreshDetail();
      }
    });
  }

  bool _shouldRefreshForLobbyEvent(ChatMessage message) {
    final eventType = message.eventType?.trim();
    if (message.isMedia && message.mediaUrl?.trim().isNotEmpty == true) {
      return true;
    }
    return message.isSystem && eventType != null && eventType.isNotEmpty;
  }

  bool _isClosedLobbyEvent(ChatMessage message) {
    if (!message.isSystem) {
      return false;
    }

    final eventType = message.eventType;
    final status =
        (message.eventMetadata['status'] ?? message.eventMetadata['nextStatus'])
            ?.toString()
            .trim()
            .toUpperCase();
    return status == LobbyStatus.closed &&
        (eventType == 'lobby.closed' || eventType == 'lobby.status_updated');
  }

  Future<void> _joinLobby(Lobby lobby) async {
    setState(() {
      _isJoining = true;
    });

    try {
      await AppServices.lobbyService.joinLobby(lobby.lobbyId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${lobby.restaurantName}.')),
      );
      _refreshDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _leaveLobby(Lobby lobby) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5F5FA),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Leave Lobby'),
          content: const Text(
            'Leave this Lobby? Your cart items will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
              ),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
    if (shouldLeave != true) {
      return;
    }

    setState(() {
      _isLeavingLobby = true;
    });

    var didExitScreen = false;
    try {
      await AppServices.lobbyService.leaveLobby(lobby.lobbyId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Left ${lobby.restaurantName}.')),
      );
      Navigator.pop(context, true);
      didExitScreen = true;
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted && !didExitScreen) {
        setState(() {
          _isLeavingLobby = false;
        });
      }
    }
  }

  Future<void> _cancelLobby(Lobby lobby) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5F5FA),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Cancel Lobby'),
          content: const Text(
            'Cancel this Lobby? Members will no longer be able to order here.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel Lobby'),
            ),
          ],
        );
      },
    );
    if (shouldCancel != true) {
      return;
    }

    setState(() {
      _isCancelingLobby = true;
    });

    var didExitScreen = false;
    try {
      await AppServices.lobbyService.cancelLobby(lobby.lobbyId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Canceled ${lobby.restaurantName}.')),
      );
      Navigator.pop(context, true);
      didExitScreen = true;
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted && !didExitScreen) {
        setState(() {
          _isCancelingLobby = false;
        });
      }
    }
  }

  Future<void> _addCartItem(Lobby lobby) async {
    final request = await showDialog<CartItemRequest>(
      context: context,
      builder: (context) => const CartItemFormDialog(),
    );
    if (request == null) {
      return;
    }

    try {
      await AppServices.cartService.addCartItem(lobby.lobbyId, request);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart item added.')),
      );
      _refreshDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _editCartItem(Lobby lobby, CartItem item) async {
    final request = await showDialog<CartItemRequest>(
      context: context,
      builder: (context) => CartItemFormDialog(initialItem: item),
    );
    if (request == null) {
      return;
    }

    try {
      await AppServices.cartService.updateCartItem(
        lobby.lobbyId,
        item.cartItemId,
        request,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart item updated.')),
      );
      _refreshDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _deleteCartItem(Lobby lobby, CartItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete item'),
          content: Text('Delete ${item.itemName}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }

    try {
      await AppServices.cartService.deleteCartItem(
        lobby.lobbyId,
        item.cartItemId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart item deleted.')),
      );
      _refreshDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _lockCart(Lobby lobby) async {
    setState(() {
      _isLockingCart = true;
    });

    try {
      await AppServices.cartService.lockCart(lobby.lobbyId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart locked.')),
      );
      _refreshDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_lockCartErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLockingCart = false;
        });
      }
    }
  }

  String _lockCartErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('LOBBY_ERR31') || message.contains('계좌 정보')) {
      return 'Payment info is required before locking the cart. '
          'Please register it in Profile > Payment Settings.';
    }
    return message;
  }

  Future<void> _kickMember(Lobby lobby, LobbyMember member) async {
    final message = lobby.orderStatus == LobbyStatus.locked
        ? 'Kick ${member.name}? Their payment record will be removed and '
            'amounts will be recalculated.'
        : 'Kick ${member.name}? Their cart items will be removed.';
    final shouldKick = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kick participant'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Kick'),
            ),
          ],
        );
      },
    );
    if (shouldKick != true) {
      return;
    }

    setState(() {
      _kickingUserId = member.userId;
    });

    try {
      await AppServices.lobbyService.kickMember(lobby.lobbyId, member.userId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} was kicked.')),
      );
      _refreshDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _kickingUserId = null;
        });
      }
    }
  }

  Future<void> _transferHost(Lobby lobby, LobbyMember member) async {
    final shouldTransfer = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Transfer Host'),
          content: Text('Transfer Host role to ${member.name}?'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
              ),
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Transfer'),
            ),
          ],
        );
      },
    );
    if (shouldTransfer != true) {
      return;
    }

    setState(() {
      _transferringHostUserId = member.userId;
    });

    var didExitScreen = false;
    try {
      await AppServices.lobbyService.transferHost(lobby.lobbyId, member.userId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${member.name} is now the Host. You left this Lobby.',
          ),
        ),
      );
      didExitScreen = true;
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.lobbyList);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted && !didExitScreen) {
        setState(() {
          _transferringHostUserId = null;
        });
      }
    }
  }

  Future<void> _showMemberProfile(
    Lobby lobby,
    LobbyMember member,
    User currentUser,
  ) async {
    final trustScore = member.trustScore ??
        (member.userId == currentUser.id ? currentUser.trustScore : null) ??
        (member.userId == lobby.hostUserId ? lobby.hostTrustScore : null);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _MemberProfileSheet(
          member: member,
          trustScore: trustScore,
        );
      },
    );
  }

  Future<void> _confirmPaymentRecord(Lobby lobby, int paymentRecordId) async {
    setState(() {
      _confirmingPaymentRecordId = paymentRecordId;
    });

    try {
      final result = await AppServices.paymentService.confirmPaymentRecord(
        lobby.lobbyId,
        paymentRecordId,
      );
      if (!mounted) {
        return;
      }
      final updatedRecords = lobby.paymentRecords.map((record) {
        return record.paymentRecordId == result.paymentRecordId
            ? result
            : record;
      }).toList();
      final allPaymentsPaid = updatedRecords.isNotEmpty &&
          updatedRecords.every((record) => record.isPaid);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allPaymentsPaid
                ? 'Payment confirmed. All payments are paid.'
                : 'Payment confirmed.',
          ),
        ),
      );
      _refreshDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _confirmingPaymentRecordId = null;
        });
      }
    }
  }

  Future<void> _copyHostAccountNumber(Lobby lobby) async {
    final accountNumber = lobby.hostAccountNumber;
    if (accountNumber == null || accountNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Host account number is unavailable.')),
      );
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: accountNumber));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account number copied.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not copy account number.')),
      );
    }
  }

  Future<void> _updateLobbyStatus(Lobby lobby, String newStatus) async {
    setState(() {
      _isUpdatingStatus = true;
    });

    var didExitScreen = false;
    try {
      if (newStatus == LobbyStatus.closed) {
        await AppServices.lobbyService.cancelLobby(lobby.lobbyId);
      } else {
        await AppServices.lobbyService.updateLobbyStatus(
          lobby.lobbyId,
          newStatus,
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == LobbyStatus.closed
                ? 'Lobby closed. You can rate members now.'
                : 'Lobby status changed to $newStatus.',
          ),
        ),
      );
      if (newStatus == LobbyStatus.closed) {
        didExitScreen = true;
        await _openClosedLobbyRatingFlow(
          fallbackLobby: lobby,
          fallbackCurrentUser: _cachedDetailData?.currentUser,
        );
        return;
      }
      _refreshDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted && !didExitScreen) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _openClosedLobbyRatingFlow({
    Lobby? fallbackLobby,
    User? fallbackCurrentUser,
  }) async {
    if (_isOpeningClosedLobbyRating) {
      return;
    }

    final detailData = _cachedDetailData;
    final lobby = fallbackLobby ?? detailData?.lobby;
    var currentUser = fallbackCurrentUser ?? detailData?.currentUser;
    if (lobby == null) {
      return;
    }
    if (currentUser == null) {
      try {
        currentUser = await _loadCurrentUser();
      } catch (_) {
        return;
      }
    }

    _isOpeningClosedLobbyRating = true;
    _cancelLobbyEventSubscription();

    final historyItem = _ratingHistoryItemForClosedLobby(lobby, currentUser);
    if (!mounted) {
      return;
    }

    if (!historyItem.canRate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No members to rate.')),
      );
      Navigator.pushReplacementNamed(context, AppRoutes.lobbyList);
      return;
    }

    final didRate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingDialog(historyItem: historyItem),
    );
    if (!mounted) {
      return;
    }

    if (didRate == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating submitted.')),
      );
    }
    Navigator.pushReplacementNamed(context, AppRoutes.lobbyList);
  }

  OrderHistoryItem _ratingHistoryItemForClosedLobby(
    Lobby lobby,
    User currentUser,
  ) {
    final activeMembers = _visibleMembers(lobby);
    final participants = activeMembers
        .map(
          (member) => OrderHistoryParticipant(
            userId: member.userId,
            name: member.name,
          ),
        )
        .toList();
    final rateableParticipants = participants
        .where((participant) => participant.userId != currentUser.id)
        .toList();
    final myAmount = lobby.paymentRecords
        .where((record) => record.userId == currentUser.id)
        .fold(0, (sum, record) => sum + record.amount);

    return OrderHistoryItem(
      lobbyId: lobby.lobbyId,
      currentUserId: currentUser.id,
      restaurantName: lobby.restaurantName,
      hostName: lobby.hostName ?? _memberNameById(lobby, lobby.hostUserId),
      participantCount: activeMembers.length,
      totalAmount: lobby.currentTotalAmount,
      myAmount: myAmount,
      canRate: rateableParticipants.isNotEmpty,
      participants: participants,
      rateableParticipants: rateableParticipants,
      deliveredAt: DateTime.now(),
      receiptImageUrl:
          _cachedDetailData?.receipt?.receiptImageUrl ?? lobby.receiptImageUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailFuture = _detailFuture;

    if (_lobbyId == null || detailFuture == null) {
      return AppScaffold(
        title: 'Lobby Detail',
        body: ErrorMessageView(
          message: 'Lobby id가 전달되지 않았습니다.',
          onRetry: () {
            Navigator.pop(context);
          },
        ),
      );
    }

    final detailTitle =
        _cachedDetailData?.lobby.restaurantName ?? 'Lobby Detail';

    return AppScaffold(
      title: detailTitle,
      appBarBackgroundColor: AppColors.background,
      body: FutureBuilder<_LobbyDetailData>(
        future: detailFuture,
        initialData: _cachedDetailData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LoadingView(message: 'Loading lobby...');
          }

          if (snapshot.hasError && !snapshot.hasData) {
            return ErrorMessageView(
              message: 'Lobby 상세 정보를 불러오지 못했습니다.',
              onRetry: _refreshDetail,
            );
          }

          final data = snapshot.data!;
          final lobby = data.lobby;
          final isMember = _isActiveMember(lobby, data.currentUser.id);
          final hasKnownMembership =
              _hasKnownMembership(lobby, data.currentUser.id);
          final canJoin = lobby.canJoin && !isMember && !data.isInActiveLobby;
          final showJoinAction = lobby.canJoin && !isMember;
          final joinDisabledReason = showJoinAction && data.isInActiveLobby
              ? 'Already in a lobby'
              : null;
          final isHost = isMember && lobby.hostUserId == data.currentUser.id;
          final visibleMembers = _visibleMembers(lobby);
          final canLeaveLobby =
              isMember && !isHost && lobby.orderStatus == LobbyStatus.waiting;
          final canCancelLobby =
              isMember && isHost && lobby.orderStatus == LobbyStatus.waiting;
          final canEditCart = isMember && lobby.canEditCart;
          final shouldShowLockCart =
              isHost && lobby.orderStatus == LobbyStatus.waiting;
          final canKickMembers = isHost &&
              (lobby.orderStatus == LobbyStatus.waiting ||
                  lobby.orderStatus == LobbyStatus.locked);
          final canTransferHost =
              isHost && lobby.orderStatus == LobbyStatus.waiting;
          final canAttachReceipt = isHost && _canAttachReceipt(lobby);
          final memberActionInProgress =
              _kickingUserId != null || _transferringHostUserId != null;
          final lockDisabledReason = shouldShowLockCart
              ? _lockDisabledReason(
                  lobby,
                  data.currentHostHasPaymentInfo,
                )
              : null;
          final canLockCart = shouldShowLockCart && lockDisabledReason == null;
          final knownMembers = _knownMembers(lobby);
          final displayMembers =
              visibleMembers.isEmpty ? knownMembers : visibleMembers;
          final canViewMembers =
              hasKnownMembership || visibleMembers.isNotEmpty;
          final participantCount =
              lobby.participantCount ?? visibleMembers.length;
          final displayedActiveMemberCount =
              displayMembers.where((member) => member.isActive).length;
          final hiddenMemberCount =
              participantCount > displayedActiveMemberCount
                  ? participantCount - displayedActiveMemberCount
                  : 0;
          final myPaymentRecord = _paymentRecordFor(
            lobby,
            data.currentUser.id,
          );
          final shouldShowTransferInfo = _shouldShowTransferInfo(
            lobby,
            isMember,
            isHost,
          );
          final statusAction = _statusActionFor(lobby);
          final Widget? hostStatusControl;
          if (shouldShowLockCart) {
            hostStatusControl = _LockCartAction(
              canLock: canLockCart,
              disabledReason: lockDisabledReason,
              isLoading: _isLockingCart,
              onLock: () => _lockCart(lobby),
            );
          } else if (isHost && statusAction != null) {
            hostStatusControl = _LobbyStatusAction(
              action: statusAction,
              isLoading: _isUpdatingStatus,
              onPressed: () => _updateLobbyStatus(
                lobby,
                statusAction.nextStatus,
              ),
            );
          } else {
            hostStatusControl = null;
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(color: AppColors.background),
                child: ListView(
                  key: PageStorageKey<String>('lobby-detail-${lobby.lobbyId}'),
                  padding: EdgeInsets.fromLTRB(16, 12, 16, isMember ? 104 : 24),
                  children: [
                    if (isMember) const _MyLobbyBanner(),
                    if (hasKnownMembership && !isMember)
                      const _PastLobbyBanner(),
                    _LobbyStatusCard(
                      status: lobby.orderStatus,
                      action: hostStatusControl,
                    ),
                    const SizedBox(height: 8),
                    _LobbyOverviewPanel(
                      restaurantName: lobby.restaurantName,
                      deliveryZone: lobby.deliveryZone,
                      deliveryFee: lobby.deliveryFee,
                      currentTotalAmount: lobby.currentTotalAmount,
                      minimumOrderAmount: lobby.minimumOrderAmount,
                      orderAmountsKnown: lobby.orderAmountsKnown,
                      deliveryFeeKnown: lobby.deliveryFeeKnown,
                    ),
                    if (data.receipt != null || canAttachReceipt) ...[
                      const SizedBox(height: 12),
                      _ReceiptPanel(
                        receipt: data.receipt,
                        canAttach: canAttachReceipt,
                        isUploading: _isUploadingReceipt,
                        onAttach: () => _attachReceipt(lobby),
                        onOpen: data.receipt == null
                            ? null
                            : () => openImageDetailView(
                                  context,
                                  imageUrl: data.receipt!.receiptImageUrl,
                                  title: 'Receipt',
                                ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _CompactPanel(
                      title: _memberCountTitle(participantCount),
                      children: [
                        if (!canViewMembers)
                          const _CompactMutedText(
                            'Member list is unavailable.',
                          )
                        else if (displayMembers.isEmpty)
                          const _CompactMutedText(
                            'Member list is unavailable.',
                          )
                        else ...[
                          if (visibleMembers.isEmpty)
                            const _CompactMutedText(
                              'Active member list is unavailable.',
                            ),
                          for (final member in displayMembers)
                            _CompactMemberRow(
                              member: member,
                              showDivider: member != displayMembers.last ||
                                  hiddenMemberCount > 0,
                              canKick: canKickMembers &&
                                  !member.isHost &&
                                  member.isActive &&
                                  !memberActionInProgress,
                              isKicking: _kickingUserId == member.userId,
                              canTransferHost: canTransferHost &&
                                  !member.isHost &&
                                  member.isActive &&
                                  !memberActionInProgress,
                              isTransferringHost:
                                  _transferringHostUserId == member.userId,
                              onViewProfile: () => _showMemberProfile(
                                lobby,
                                member,
                                data.currentUser,
                              ),
                              onKick: () => _kickMember(lobby, member),
                              onTransferHost: () =>
                                  _transferHost(lobby, member),
                            ),
                          if (hiddenMemberCount > 0)
                            _CompactMutedText(
                              '$hiddenMemberCount hidden by API.',
                            ),
                        ],
                      ],
                    ),
                    if (isMember) ...[
                      const SizedBox(height: 12),
                      _CompactPanel(
                        title: 'Cart Items',
                        action: canEditCart
                            ? _AddItemIconButton(
                                onPressed: () => _addCartItem(lobby),
                              )
                            : null,
                        children: [
                          if (lobby.cartItems.isEmpty)
                            const _CompactMutedText('No cart items yet.')
                          else
                            for (final item in lobby.cartItems)
                              _CompactCartItemRow(
                                itemName: item.itemName,
                                unitPrice: item.unitPrice,
                                quantity: item.quantity,
                                subtotal: item.subtotal,
                                showDivider: item != lobby.cartItems.last,
                                ownerName: _memberNameById(
                                  lobby,
                                  item.ownerUserId,
                                ),
                                canEdit: canEditCart &&
                                    item.isOwnedBy(data.currentUser.id),
                                onEdit: () => _editCartItem(lobby, item),
                                onDelete: () => _deleteCartItem(lobby, item),
                              ),
                          if (!lobby.canEditCart)
                            const _CompactMutedText(
                              'Editing is unavailable after lock.',
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionHeader(
                        title: isHost ? 'Payment Records' : 'My Payment',
                      ),
                      const SizedBox(height: 8),
                      if (lobby.paymentRecords.isEmpty)
                        const _MutedText(
                          'Payment records will appear after cart lock.',
                        )
                      else if (isHost) ...[
                        for (final record in lobby.paymentRecords)
                          PaymentRecordTile(
                            userName: _memberNameById(lobby, record.userId),
                            amount: record.amount,
                            status: record.status,
                            canConfirm: isHost &&
                                lobby.orderStatus == LobbyStatus.locked &&
                                !record.isPaid &&
                                _confirmingPaymentRecordId == null,
                            onConfirm: () => _confirmPaymentRecord(
                              lobby,
                              record.paymentRecordId,
                            ),
                          ),
                      ] else if (myPaymentRecord == null)
                        const _MutedText('My payment record is not available.')
                      else
                        PaymentRecordTile(
                          userName:
                              _memberNameById(lobby, myPaymentRecord.userId),
                          amount: myPaymentRecord.amount,
                          status: myPaymentRecord.status,
                        ),
                      if (shouldShowTransferInfo) ...[
                        const SizedBox(height: 12),
                        _HostPaymentInfoPanel(
                          lobby: lobby,
                          onCopyAccountNumber: () =>
                              _copyHostAccountNumber(lobby),
                        ),
                      ],
                    ],
                    if (showJoinAction) ...[
                      const SizedBox(height: 16),
                      _JoinLobbyAction(
                        canJoin: canJoin,
                        disabledReason: joinDisabledReason,
                        isLoading: _isJoining,
                        onJoin: () => _joinLobby(lobby),
                      ),
                    ],
                    if (canLeaveLobby || canCancelLobby) ...[
                      const SizedBox(height: 16),
                      _ExitLobbyAction(
                        label: canCancelLobby ? 'Cancel Lobby' : 'Leave Lobby',
                        icon: canCancelLobby
                            ? Icons.cancel_outlined
                            : Icons.logout_outlined,
                        isLoading: canCancelLobby
                            ? _isCancelingLobby
                            : _isLeavingLobby,
                        onPressed: canCancelLobby
                            ? () => _cancelLobby(lobby)
                            : () => _leaveLobby(lobby),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              if (isMember)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _OpenChatFab(onPressed: () => _openChat(lobby)),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _isActiveMember(Lobby lobby, int currentUserId) {
    return lobby.members.any(
      (member) => member.userId == currentUserId && member.isActive,
    );
  }

  bool _hasKnownMembership(Lobby lobby, int currentUserId) {
    return lobby.members.any((member) => member.userId == currentUserId);
  }

  String _memberCountTitle(int count) {
    return count == 1 ? '1 member' : '$count members';
  }

  List<LobbyMember> _visibleMembers(Lobby lobby) {
    // LEFT/KICKED member는 서버 기록으로는 남을 수 있지만, 화면에는 현재 참여자만 보여줍니다.
    final members = lobby.members.where((member) => member.isActive).toList();
    members.sort((first, second) {
      final firstIsHost = first.isHost || first.userId == lobby.hostUserId;
      final secondIsHost = second.isHost || second.userId == lobby.hostUserId;
      if (firstIsHost != secondIsHost) {
        return firstIsHost ? -1 : 1;
      }

      final nameCompare = first.name.toLowerCase().compareTo(
            second.name.toLowerCase(),
          );
      if (nameCompare != 0) {
        return nameCompare;
      }
      return first.userId.compareTo(second.userId);
    });
    return members;
  }

  List<LobbyMember> _knownMembers(Lobby lobby) {
    final members = lobby.members.toList();
    members.sort((first, second) {
      final firstIsHost = first.isHost || first.userId == lobby.hostUserId;
      final secondIsHost = second.isHost || second.userId == lobby.hostUserId;
      if (firstIsHost != secondIsHost) {
        return firstIsHost ? -1 : 1;
      }
      if (first.isActive != second.isActive) {
        return first.isActive ? -1 : 1;
      }

      final nameCompare = first.name.toLowerCase().compareTo(
            second.name.toLowerCase(),
          );
      if (nameCompare != 0) {
        return nameCompare;
      }
      return first.userId.compareTo(second.userId);
    });
    return members;
  }

  String _memberNameById(Lobby lobby, int userId) {
    final activeMembers = lobby.members.where((member) => member.isActive);
    for (final member in activeMembers) {
      if (member.userId == userId) {
        return member.name;
      }
    }
    for (final member in lobby.members) {
      if (member.userId == userId) {
        return member.name;
      }
    }
    return 'User $userId';
  }

  PaymentRecord? _paymentRecordFor(Lobby lobby, int userId) {
    for (final record in lobby.paymentRecords) {
      if (record.userId == userId) {
        return record;
      }
    }
    return null;
  }

  String? _lockDisabledReason(
    Lobby lobby,
    bool? currentHostHasPaymentInfo,
  ) {
    if (currentHostHasPaymentInfo == false) {
      return 'Payment info is required before locking the cart.';
    }
    if (lobby.currentTotalAmount < lobby.minimumOrderAmount) {
      return 'Minimum order amount has not been reached.';
    }
    return null;
  }

  bool _shouldShowTransferInfo(
    Lobby lobby,
    bool isMember,
    bool isHost,
  ) {
    if (!isMember || isHost) {
      return false;
    }
    return lobby.orderStatus != LobbyStatus.waiting &&
        lobby.orderStatus != LobbyStatus.closed &&
        lobby.orderStatus != LobbyStatus.canceled;
  }

  bool _canAttachReceipt(Lobby lobby) {
    return lobby.orderStatus == LobbyStatus.orderPlaced ||
        lobby.orderStatus == LobbyStatus.outForDelivery ||
        lobby.orderStatus == LobbyStatus.delivered;
  }

  _LobbyStatusActionData? _statusActionFor(Lobby lobby) {
    switch (lobby.orderStatus) {
      case LobbyStatus.locked:
        return _LobbyStatusActionData(
          label: 'Mark as Order Placed',
          icon: Icons.receipt_long_outlined,
          nextStatus: LobbyStatus.orderPlaced,
          enabled: lobby.allPaymentsPaid,
          disabledReason: lobby.allPaymentsPaid
              ? null
              : 'All payment records must be PAID first.',
        );
      case LobbyStatus.orderPlaced:
        return const _LobbyStatusActionData(
          label: 'Mark as Out for Delivery',
          icon: Icons.delivery_dining_outlined,
          nextStatus: LobbyStatus.outForDelivery,
          enabled: true,
        );
      case LobbyStatus.outForDelivery:
        return const _LobbyStatusActionData(
          label: 'Mark as Delivered',
          icon: Icons.check_circle_outline,
          nextStatus: LobbyStatus.delivered,
          enabled: true,
        );
      case LobbyStatus.delivered:
        return const _LobbyStatusActionData(
          label: 'Close Lobby',
          icon: Icons.done_all_outlined,
          nextStatus: LobbyStatus.closed,
          enabled: true,
        );
    }
    return null;
  }
}

class _LobbyDetailData {
  const _LobbyDetailData({
    required this.lobby,
    required this.currentUser,
    required this.isInActiveLobby,
    required this.currentHostHasPaymentInfo,
    this.receipt,
  });

  final Lobby lobby;
  final User currentUser;
  final bool isInActiveLobby;
  final bool? currentHostHasPaymentInfo;
  final ReceiptAttachment? receipt;
}

class _MyLobbyBanner extends StatelessWidget {
  const _MyLobbyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: const Color(0xFF0054FF),
          ),
          const SizedBox(width: 8),
          Text(
            'My Lobby',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF0054FF),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PastLobbyBanner extends StatelessWidget {
  const _PastLobbyBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history_outlined,
            size: 18,
            color: colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Text(
            'Past Lobby',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.outline,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _LobbyStatusCard extends StatelessWidget {
  const _LobbyStatusCard({
    required this.status,
    this.action,
  });

  final String status;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.radio_button_checked,
                size: 20,
                color: Color(0xFF0054FF),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Status',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              _BluePill(label: status),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

class _LobbyOverviewPanel extends StatelessWidget {
  const _LobbyOverviewPanel({
    required this.restaurantName,
    required this.deliveryZone,
    required this.deliveryFee,
    required this.currentTotalAmount,
    required this.minimumOrderAmount,
    required this.orderAmountsKnown,
    required this.deliveryFeeKnown,
  });

  final String restaurantName;
  final String deliveryZone;
  final int deliveryFee;
  final int currentTotalAmount;
  final int minimumOrderAmount;
  final bool orderAmountsKnown;
  final bool deliveryFeeKnown;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderProgressCard(
          currentTotalAmount: currentTotalAmount,
          minimumOrderAmount: minimumOrderAmount,
          amountsKnown: orderAmountsKnown,
        ),
        const SizedBox(height: 8),
        _LobbyInfoCard(
          restaurantName: restaurantName,
          deliveryZone: deliveryZone,
          deliveryFee: deliveryFee,
          deliveryFeeKnown: deliveryFeeKnown,
        ),
      ],
    );
  }
}

class _LobbyInfoCard extends StatelessWidget {
  const _LobbyInfoCard({
    required this.restaurantName,
    required this.deliveryZone,
    required this.deliveryFee,
    required this.deliveryFeeKnown,
  });

  final String restaurantName;
  final String deliveryZone;
  final int deliveryFee;
  final bool deliveryFeeKnown;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompactInfoLine(label: 'Restaurant', value: restaurantName),
          const SizedBox(height: 12),
          _CompactInfoLine(label: 'Delivery Zone', value: deliveryZone),
          const SizedBox(height: 12),
          _CompactInfoLine(
            label: 'Delivery Fee',
            value: deliveryFeeKnown ? '₩$deliveryFee' : 'Unavailable',
          ),
        ],
      ),
    );
  }
}

class _CompactInfoLine extends StatelessWidget {
  const _CompactInfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.outline,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderProgressCard extends StatelessWidget {
  const _OrderProgressCard({
    required this.currentTotalAmount,
    required this.minimumOrderAmount,
    required this.amountsKnown,
  });

  final int currentTotalAmount;
  final int minimumOrderAmount;
  final bool amountsKnown;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = !amountsKnown || minimumOrderAmount <= 0
        ? 0.0
        : (currentTotalAmount / minimumOrderAmount).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order Total',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                amountsKnown
                    ? '₩$currentTotalAmount / ₩$minimumOrderAmount'
                    : 'Unavailable',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFDDE7FF),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF0054FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptPanel extends StatelessWidget {
  const _ReceiptPanel({
    required this.receipt,
    required this.canAttach,
    required this.isUploading,
    required this.onAttach,
    required this.onOpen,
  });

  final ReceiptAttachment? receipt;
  final bool canAttach;
  final bool isUploading;
  final VoidCallback onAttach;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final receiptUrl = receipt?.receiptImageUrl;
    final canRenderImage = receiptUrl != null &&
        (receiptUrl.startsWith('http://') || receiptUrl.startsWith('https://'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 20,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Receipt',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (canAttach)
                TextButton.icon(
                  onPressed: isUploading ? null : onAttach,
                  icon: isUploading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(receipt == null ? 'Attach' : 'Replace'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (receipt == null)
            Text(
              canAttach
                  ? 'Attach the final order receipt after placing the order.'
                  : 'No receipt has been attached yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            )
          else if (canRenderImage)
            GestureDetector(
              onTap: onOpen,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    receiptUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _ReceiptFallback(label: _receiptLabel(receiptUrl));
                    },
                  ),
                ),
              ),
            )
          else
            _ReceiptFallback(label: _receiptLabel(receiptUrl)),
        ],
      ),
    );
  }

  String? _receiptLabel(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value.replaceFirst('mock-receipt://', '').split('/').last;
  }
}

class _ReceiptFallback extends StatelessWidget {
  const _ReceiptFallback({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.image_outlined,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label == null ? 'Receipt image attached.' : 'Receipt: $label',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactPanel extends StatelessWidget {
  const _CompactPanel({
    required this.title,
    required this.children,
    this.action,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _AddItemIconButton extends StatelessWidget {
  const _AddItemIconButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Add item',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFF7F9FF),
        foregroundColor: const Color(0xFF0054FF),
        fixedSize: const Size.square(32),
        padding: EdgeInsets.zero,
      ),
      icon: const Icon(Icons.add, size: 18),
    );
  }
}

class _CompactMemberRow extends StatelessWidget {
  const _CompactMemberRow({
    required this.member,
    this.showDivider = true,
    required this.canKick,
    required this.isKicking,
    required this.canTransferHost,
    required this.isTransferringHost,
    required this.onViewProfile,
    required this.onKick,
    required this.onTransferHost,
  });

  final LobbyMember member;
  final bool showDivider;
  final bool canKick;
  final bool isKicking;
  final bool canTransferHost;
  final bool isTransferringHost;
  final VoidCallback onViewProfile;
  final VoidCallback onKick;
  final VoidCallback onTransferHost;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trustScoreText = member.trustScore?.toStringAsFixed(1);
    final isProcessing = isKicking || isTransferringHost;
    final hasHostAction = canTransferHost || canKick;

    return InkWell(
      onTap: onViewProfile,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: showDivider
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.inputBorder.withValues(alpha: 0.55),
                  ),
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    member.isHost ? Icons.star_outline : Icons.person_outline,
                    size: 17,
                    color: const Color(0xFF0054FF),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        trustScoreText == null
                            ? member.roleInLobby
                            : '${member.roleInLobby} · $trustScoreText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                if (isProcessing)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (hasHostAction)
                  PopupMenuButton<_MemberAction>(
                    tooltip: 'Member actions',
                    color: Colors.white,
                    iconColor: AppColors.primaryBlue,
                    padding: EdgeInsets.zero,
                    onSelected: (action) {
                      if (action == _MemberAction.transferHost) {
                        onTransferHost();
                      } else {
                        onKick();
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        if (canTransferHost)
                          PopupMenuItem<_MemberAction>(
                            value: _MemberAction.transferHost,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 18,
                                  color: AppColors.primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Transfer Host',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.primaryBlue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        if (canKick)
                          PopupMenuItem<_MemberAction>(
                            value: _MemberAction.kick,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_remove_outlined,
                                  size: 18,
                                  color: AppColors.darkAction,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Kick',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.darkAction,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ];
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactCartItemRow extends StatelessWidget {
  const _CompactCartItemRow({
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.showDivider = true,
    this.ownerName,
    this.canEdit = false,
    this.onEdit,
    this.onDelete,
  });

  final String itemName;
  final int unitPrice;
  final int quantity;
  final int subtotal;
  final bool showDivider;
  final String? ownerName;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.inputBorder.withValues(alpha: 0.55),
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (canEdit)
                SizedBox.square(
                  dimension: 24,
                  child: PopupMenuButton<_CartItemAction>(
                    tooltip: 'Cart item actions',
                    padding: EdgeInsets.zero,
                    position: PopupMenuPosition.under,
                    child: const Icon(Icons.more_horiz, size: 18),
                    onSelected: (action) {
                      if (action == _CartItemAction.edit) {
                        onEdit?.call();
                      } else {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem<_CartItemAction>(
                          value: _CartItemAction.edit,
                          child: Text('Edit'),
                        ),
                        PopupMenuItem<_CartItemAction>(
                          value: _CartItemAction.delete,
                          child: Text('Delete'),
                        ),
                      ];
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            [
              '₩$unitPrice x $quantity',
              if (ownerName != null) ownerName!,
            ].join(' - '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '₩$subtotal',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF0054FF),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _CompactMutedText extends StatelessWidget {
  const _CompactMutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}

class _BluePill extends StatelessWidget {
  const _BluePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF0054FF),
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _OpenChatFab extends StatelessWidget {
  const _OpenChatFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0054FF).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: 'open-chat-fab',
        onPressed: onPressed,
        backgroundColor: const Color(0xFF0054FF),
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Open Chat'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}

class _HostPaymentInfoPanel extends StatelessWidget {
  const _HostPaymentInfoPanel({
    required this.lobby,
    required this.onCopyAccountNumber,
  });

  final Lobby lobby;
  final VoidCallback onCopyAccountNumber;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!lobby.hasHostPaymentInfo) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 8),
            Expanded(
              child: Text('Host has not registered payment info yet.'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Host Transfer Account',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _PaymentInfoRow(label: 'Bank', value: lobby.hostBankName!),
          _PaymentInfoRow(
            label: 'Holder',
            value: lobby.hostAccountHolderName!,
          ),
          Row(
            children: [
              Expanded(
                child: _PaymentInfoRow(
                  label: 'Account',
                  value: lobby.hostAccountNumber!,
                ),
              ),
              IconButton(
                tooltip: 'Copy account number',
                onPressed: onCopyAccountNumber,
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentInfoRow extends StatelessWidget {
  const _PaymentInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ExitLobbyAction extends StatelessWidget {
  const _ExitLobbyAction({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: AppColors.darkAction,
        disabledBackgroundColor:
            Theme.of(context).colorScheme.surfaceContainerHighest,
        disabledForegroundColor: Theme.of(context).colorScheme.outline,
      ),
      icon: isLoading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}

class _LockCartAction extends StatelessWidget {
  const _LockCartAction({
    required this.canLock,
    required this.isLoading,
    required this.onLock,
    this.disabledReason,
  });

  final bool canLock;
  final bool isLoading;
  final VoidCallback onLock;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading || !canLock ? null : onLock;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: effectiveOnPressed == null
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: FilledButton.icon(
            onPressed: effectiveOnPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              disabledForegroundColor: Theme.of(context).colorScheme.outline,
            ),
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_outline),
            label: const Text('Lock Cart'),
          ),
        ),
        if (disabledReason != null) ...[
          const SizedBox(height: 6),
          Text(
            disabledReason!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ],
    );
  }
}

class _LobbyStatusActionData {
  const _LobbyStatusActionData({
    required this.label,
    required this.icon,
    required this.nextStatus,
    required this.enabled,
    this.disabledReason,
  });

  final String label;
  final IconData icon;
  final String nextStatus;
  final bool enabled;
  final String? disabledReason;
}

class _LobbyStatusAction extends StatelessWidget {
  const _LobbyStatusAction({
    required this.action,
    required this.isLoading,
    required this.onPressed,
  });

  final _LobbyStatusActionData action;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = action.enabled && !isLoading ? onPressed : null;
    final child = isLoading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(action.label);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: effectiveOnPressed == null
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: FilledButton.icon(
            onPressed: effectiveOnPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              disabledForegroundColor: Theme.of(context).colorScheme.outline,
            ),
            icon: Icon(action.icon),
            label: child,
          ),
        ),
        if (!action.enabled && action.disabledReason != null) ...[
          const SizedBox(height: 6),
          Text(
            action.disabledReason!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ],
    );
  }
}

class _JoinLobbyAction extends StatelessWidget {
  const _JoinLobbyAction({
    required this.canJoin,
    required this.isLoading,
    required this.onJoin,
    this.disabledReason,
  });

  final bool canJoin;
  final bool isLoading;
  final VoidCallback onJoin;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    if (canJoin) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: FilledButton.icon(
          onPressed: isLoading ? null : onJoin,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            disabledForegroundColor: Theme.of(context).colorScheme.outline,
          ),
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('Join Lobby'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Opacity(
          opacity: 0.55,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.block),
            label: const Text('Unavailable'),
          ),
        ),
        if (disabledReason != null) ...[
          const SizedBox(height: 6),
          Text(
            disabledReason!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ],
    );
  }
}

enum _MemberAction {
  transferHost,
  kick,
}

enum _CartItemAction {
  edit,
  delete,
}

class _MemberProfileSheet extends StatelessWidget {
  const _MemberProfileSheet({
    required this.member,
    this.trustScore,
  });

  final LobbyMember member;
  final double? trustScore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Icon(
                    member.isHost ? Icons.star_outline : Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.isHost ? 'Host' : 'Participant',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _MemberProfileRow(label: 'User ID', value: '${member.userId}'),
            _MemberProfileRow(
              label: 'Trust Score',
              value:
                  trustScore == null ? 'Unavailable' : _formatRate(trustScore!),
            ),
            _MemberProfileRow(label: 'Role', value: member.roleInLobby),
            _MemberProfileRow(label: 'Status', value: member.membershipStatus),
            _MemberProfileRow(
              label: 'Joined',
              value: _formatDateTime(member.joinedAt),
            ),
            if (member.leftAt != null)
              _MemberProfileRow(
                label: 'Left',
                value: _formatDateTime(member.leftAt),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Unknown';
    }
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }

  String _formatRate(double value) {
    return '${value.toStringAsFixed(1)} / 5.0';
  }
}

class _MemberProfileRow extends StatelessWidget {
  const _MemberProfileRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
