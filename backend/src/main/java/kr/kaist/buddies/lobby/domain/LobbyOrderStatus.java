package kr.kaist.buddies.lobby.domain;

public enum LobbyOrderStatus {
    WAITING,
    LOCKED,
    ORDER_PLACED,
    OUT_FOR_DELIVERY,
    DELIVERED,
    CLOSED,
    CANCELED
}
