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
  return [
    Lobby(
      lobbyId: 10,
      hostUserId: 4,
      hostName: 'Doyun',
      hostTrustScore: 4.5,
      restaurantName: 'MOM\'S TOUCH',
      deliveryZone: DeliveryZone.n3,
      minimumOrderAmount: 23000,
      currentTotalAmount: 16000,
      remainingAmount: 7000,
      deliveryFee: 3000,
      participantCount: 2,
      orderStatus: LobbyStatus.waiting,
      lastReadMessageId: 1052,
      unreadCount: 3,
      members: const [
        LobbyMember(
          userId: 4,
          name: 'Doyun',
          roleInLobby: RoleInLobby.host,
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
      cartItems: const [
        CartItem(
          cartItemId: 101,
          lobbyId: 10,
          ownerUserId: 7,
          itemName: 'Cheese Burger',
          unitPrice: 7000,
          quantity: 2,
          subtotal: 14000,
        ),
        CartItem(
          cartItemId: 102,
          lobbyId: 10,
          ownerUserId: 4,
          itemName: 'Coke',
          unitPrice: 2000,
          quantity: 1,
          subtotal: 2000,
        ),
      ],
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
      currentTotalAmount: 31000,
      remainingAmount: 0,
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
      cartItems: const [],
      paymentRecords: const [
        PaymentRecord(
          paymentRecordId: 201,
          lobbyId: 11,
          userId: 5,
          amount: 11000,
          status: PaymentStatus.paid,
          confirmedByHostId: 5,
        ),
        PaymentRecord(
          paymentRecordId: 202,
          lobbyId: 11,
          userId: 6,
          amount: 10000,
          status: PaymentStatus.unpaid,
        ),
        PaymentRecord(
          paymentRecordId: 203,
          lobbyId: 11,
          userId: 8,
          amount: 12500,
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
      currentTotalAmount: 12000,
      remainingAmount: 13000,
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
      cartItems: const [],
      paymentRecords: const [],
    ),
  ];
}

Map<int, List<ChatMessage>> createInitialMockMessages() {
  return {
    10: [
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
