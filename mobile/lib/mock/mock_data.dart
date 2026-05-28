import '../core/enums.dart';
import '../models/cart_item.dart';
import '../models/chat_message.dart';
import '../models/lobby.dart';
import '../models/lobby_member.dart';
import '../models/payment_record.dart';
import '../models/user.dart';

const mockCurrentUser = User(
  id: 3,
  email: 'example@kaist.ac.kr',
  name: 'Example User',
  role: 'USER',
  profileImageUrl: null,
  trustScore: 4.6,
  status: UserStatus.active,
);

// 백엔드 없이 LobbyListScreen을 확인하기 위한 임시 데이터입니다.
// Phase 3부터는 실제 Lobby model과 같은 구조를 사용합니다.
List<Lobby> createInitialMockLobbies() {
  const momsTouchCartItems = [
    CartItem(
      cartItemId: 101,
      lobbyId: 10,
      ownerUserId: 3,
      itemName: 'Thigh Burger Set',
      unitPrice: 8500,
      quantity: 1,
      subtotal: 8500,
    ),
    CartItem(
      cartItemId: 102,
      lobbyId: 10,
      ownerUserId: 4,
      itemName: 'Cheese Burger',
      unitPrice: 7000,
      quantity: 2,
      subtotal: 14000,
    ),
    CartItem(
      cartItemId: 103,
      lobbyId: 10,
      ownerUserId: 7,
      itemName: 'Coke',
      unitPrice: 2000,
      quantity: 1,
      subtotal: 2000,
    ),
  ];
  const pizzaSchoolCartItems = [
    CartItem(
      cartItemId: 201,
      lobbyId: 11,
      ownerUserId: 5,
      itemName: 'Margherita Pizza',
      unitPrice: 10000,
      quantity: 1,
      subtotal: 10000,
    ),
    CartItem(
      cartItemId: 202,
      lobbyId: 11,
      ownerUserId: 6,
      itemName: 'Cheese Pizza',
      unitPrice: 9000,
      quantity: 1,
      subtotal: 9000,
    ),
    CartItem(
      cartItemId: 203,
      lobbyId: 11,
      ownerUserId: 8,
      itemName: 'Pepperoni Pizza',
      unitPrice: 12000,
      quantity: 1,
      subtotal: 12000,
    ),
  ];
  const subwayCartItems = [
    CartItem(
      cartItemId: 301,
      lobbyId: 12,
      ownerUserId: 9,
      itemName: 'Club Sandwich',
      unitPrice: 12000,
      quantity: 1,
      subtotal: 12000,
    ),
  ];

  return [
    Lobby(
      lobbyId: 10,
      hostUserId: mockCurrentUser.id,
      hostName: mockCurrentUser.name,
      hostTrustScore: mockCurrentUser.trustScore,
      restaurantName: 'MOM\'S TOUCH',
      deliveryZone: DeliveryZone.n3,
      minimumOrderAmount: 23000,
      currentTotalAmount: _cartTotal(momsTouchCartItems),
      remainingAmount: _remainingAmount(23000, momsTouchCartItems),
      deliveryFee: 3000,
      participantCount: 3,
      orderStatus: LobbyStatus.waiting,
      lastReadMessageId: 1052,
      unreadCount: 1,
      members: const [
        LobbyMember(
          userId: 3,
          name: 'Example User',
          roleInLobby: RoleInLobby.host,
          membershipStatus: MembershipStatus.active,
          lastReadMessageId: 1052,
        ),
        LobbyMember(
          userId: 4,
          name: 'Doyun',
          roleInLobby: RoleInLobby.participant,
          membershipStatus: MembershipStatus.active,
          lastReadMessageId: 1052,
        ),
        LobbyMember(
          userId: 7,
          name: 'Hana',
          roleInLobby: RoleInLobby.participant,
          membershipStatus: MembershipStatus.active,
          lastReadMessageId: 1051,
        ),
      ],
      cartItems: momsTouchCartItems,
      paymentRecords: const [],
    ),
    Lobby(
      lobbyId: 11,
      hostUserId: 5,
      hostName: 'Mina',
      hostTrustScore: 4.9,
      restaurantName: 'Pizza School',
      deliveryZone: DeliveryZone.n2,
      minimumOrderAmount: 30000,
      currentTotalAmount: _cartTotal(pizzaSchoolCartItems),
      remainingAmount: _remainingAmount(30000, pizzaSchoolCartItems),
      deliveryFee: 2500,
      participantCount: 3,
      orderStatus: LobbyStatus.locked,
      cartLockedAt: DateTime(2026, 5, 1, 20, 10),
      lastReadMessageId: 1050,
      unreadCount: 0,
      members: const [
        LobbyMember(
          userId: 5,
          name: 'Mina',
          roleInLobby: RoleInLobby.host,
          membershipStatus: MembershipStatus.active,
          lastReadMessageId: 1050,
        ),
        LobbyMember(
          userId: 6,
          name: 'Kai',
          roleInLobby: RoleInLobby.participant,
          membershipStatus: MembershipStatus.active,
          lastReadMessageId: 1050,
        ),
        LobbyMember(
          userId: 8,
          name: 'Leo',
          roleInLobby: RoleInLobby.participant,
          membershipStatus: MembershipStatus.active,
          lastReadMessageId: 1050,
        ),
      ],
      cartItems: pizzaSchoolCartItems,
      paymentRecords: [
        PaymentRecord(
          paymentRecordId: 201,
          lobbyId: 11,
          userId: 5,
          amount: _paymentAmount(
            cartItems: pizzaSchoolCartItems,
            userId: 5,
            deliveryFee: 2500,
            memberCount: 3,
          ),
          status: PaymentStatus.paid,
          confirmedByHostId: 5,
          confirmedAt: DateTime(2026, 5, 1, 20, 10),
        ),
        PaymentRecord(
          paymentRecordId: 202,
          lobbyId: 11,
          userId: 6,
          amount: _paymentAmount(
            cartItems: pizzaSchoolCartItems,
            userId: 6,
            deliveryFee: 2500,
            memberCount: 3,
          ),
          status: PaymentStatus.unpaid,
        ),
        PaymentRecord(
          paymentRecordId: 203,
          lobbyId: 11,
          userId: 8,
          amount: _paymentAmount(
            cartItems: pizzaSchoolCartItems,
            userId: 8,
            deliveryFee: 2500,
            memberCount: 3,
          ),
          status: PaymentStatus.unpaid,
        ),
      ],
    ),
    Lobby(
      lobbyId: 12,
      hostUserId: 9,
      hostName: 'Sora',
      hostTrustScore: 4.7,
      restaurantName: 'Subway',
      deliveryZone: DeliveryZone.west,
      minimumOrderAmount: 25000,
      currentTotalAmount: _cartTotal(subwayCartItems),
      remainingAmount: _remainingAmount(25000, subwayCartItems),
      deliveryFee: 3500,
      participantCount: 1,
      orderStatus: LobbyStatus.waiting,
      lastReadMessageId: null,
      unreadCount: 0,
      members: const [
        LobbyMember(
          userId: 9,
          name: 'Sora',
          roleInLobby: RoleInLobby.host,
          membershipStatus: MembershipStatus.active,
        ),
      ],
      cartItems: subwayCartItems,
      paymentRecords: const [],
    ),
  ];
}

int _cartTotal(List<CartItem> cartItems) {
  return cartItems.fold(0, (sum, item) => sum + item.subtotal);
}

int _remainingAmount(int minimumOrderAmount, List<CartItem> cartItems) {
  final remaining = minimumOrderAmount - _cartTotal(cartItems);
  return remaining > 0 ? remaining : 0;
}

int _paymentAmount({
  required List<CartItem> cartItems,
  required int userId,
  required int deliveryFee,
  required int memberCount,
}) {
  final itemTotal = cartItems
      .where((item) => item.ownerUserId == userId)
      .fold(0, (sum, item) => sum + item.subtotal);
  final deliveryShare =
      memberCount == 0 ? deliveryFee : deliveryFee ~/ memberCount;
  return itemTotal + deliveryShare;
}

Map<int, List<ChatMessage>> createInitialMockMessages() {
  return {
    10: [
      ChatMessage(
        id: 1049,
        lobbyId: 10,
        senderUserId: 3,
        messageType: ChatMessageType.user,
        content: 'I can host this order.',
        createdAt: DateTime(2026, 5, 7, 5, 8),
      ),
      ChatMessage(
        id: 1050,
        lobbyId: 10,
        senderUserId: 4,
        messageType: ChatMessageType.media,
        mediaUrl: 'https://example.com/moms-touch-menu.png',
        createdAt: DateTime(2026, 5, 7, 5, 9),
      ),
      ChatMessage(
        id: 1051,
        lobbyId: 10,
        senderUserId: 7,
        messageType: ChatMessageType.user,
        content: 'I added burgers.',
        createdAt: DateTime(2026, 5, 7, 5, 10),
      ),
      ChatMessage(
        id: 1052,
        lobbyId: 10,
        messageType: ChatMessageType.system,
        content: 'Hana joined the lobby.',
        createdAt: DateTime(2026, 5, 7, 5, 12),
      ),
      ChatMessage(
        id: 1053,
        lobbyId: 10,
        senderUserId: 7,
        messageType: ChatMessageType.user,
        content: 'Can we order soon?',
        createdAt: DateTime(2026, 5, 7, 5, 15),
      ),
    ],
    11: [
      ChatMessage(
        id: 1050,
        lobbyId: 11,
        senderUserId: 5,
        messageType: ChatMessageType.user,
        content: 'Payment records are ready.',
        createdAt: DateTime(2026, 5, 1, 20, 12),
      ),
    ],
  };
}
