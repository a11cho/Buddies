package kr.kaist.buddies.lobby;

import org.springframework.http.HttpStatus;

public enum LobbyErrorCode {
    LOBBY_NOT_FOUND("LOBBY_ERR01", "존재하지 않는 로비입니다."),
    AUTH_REQUIRED("LOBBY_ERR02", "토큰이 올바르지 않습니다."),
    FORBIDDEN_ACCESS("LOBBY_ERR03", "해당 로비에 대한 접근 권한이 없습니다."),
    HOST_REQUIRED("LOBBY_ERR04", "Host 권한이 필요합니다."),
    INVALID_DELIVERY_LOCATION("LOBBY_ERR05", "배달 위치가 올바르지 않습니다."),
    INVALID_LOBBY_STATUS("LOBBY_ERR06", "로비 상태가 올바르지 않습니다."),
    ACTIVE_LOBBY_EXISTS("LOBBY_ERR07", "이미 참여 중인 로비가 있습니다."),
    LOBBY_NOT_JOINABLE("LOBBY_ERR08", "참여할 수 없는 로비입니다."),
    HOST_LEAVE_FORBIDDEN("LOBBY_ERR09", "Host는 이 API로 로비를 나갈 수 없습니다."),
    LOBBY_LEAVE_LOCKED("LOBBY_ERR10", "이미 잠긴 로비에서는 직접 나갈 수 없습니다."),
    LOBBY_LOCK_FORBIDDEN("LOBBY_ERR11", "잠글 수 없는 로비 상태입니다."),
    MINIMUM_ORDER_NOT_MET("LOBBY_ERR12", "최소 주문 금액을 충족하지 못했습니다."),
    PAYMENT_NOT_ALL_PAID("LOBBY_ERR13", "모든 정산 기록이 PAID 상태가 아닙니다."),
    HOST_TRANSFER_FORBIDDEN("LOBBY_ERR14", "현재 로비 상태에서는 Host 권한을 위임할 수 없습니다."),
    TRANSFER_TARGET_NOT_FOUND("LOBBY_ERR15", "위임할 참여자를 찾을 수 없습니다."),
    HOST_TRANSFER_TARGET_INVALID("LOBBY_ERR16", "Host 권한은 Participant에게만 위임할 수 있습니다."),
    KICK_FORBIDDEN_STATE("LOBBY_ERR17", "현재 로비 상태에서는 참여자를 강퇴할 수 없습니다."),
    KICK_TARGET_NOT_FOUND("LOBBY_ERR18", "강퇴할 참여자를 찾을 수 없습니다."),
    KICK_HOST_FORBIDDEN("LOBBY_ERR19", "Host는 강퇴할 수 없습니다."),
    LOBBY_DELETE_FORBIDDEN("LOBBY_ERR20", "현재 상태에서는 로비를 종료할 수 없습니다."),
    STATUS_TRANSITION_FORBIDDEN("LOBBY_ERR21", "허용되지 않는 로비 상태 변경입니다."),
    CART_ITEM_NOT_FOUND("LOBBY_ERR22", "장바구니 항목을 찾을 수 없습니다."),
    CART_NOT_EDITABLE("LOBBY_ERR23", "현재 로비에서는 장바구니를 변경할 수 없습니다."),
    CART_ITEM_OWNER_REQUIRED("LOBBY_ERR24", "장바구니 항목 소유자만 변경할 수 있습니다."),
    PAYMENT_CONFIRM_STATE_INVALID("LOBBY_ERR25", "결제 확인은 LOCKED 상태에서만 가능합니다."),
    PAYMENT_RECORD_NOT_FOUND("LOBBY_ERR26", "결제 기록을 찾을 수 없습니다."),
    PAYMENT_RECORD_INACTIVE("LOBBY_ERR27", "비활성화된 결제 기록은 확인할 수 없습니다."),
    NO_PAYABLE_MEMBERS("LOBBY_ERR28", "정산할 로비 멤버가 없습니다."),
    PAYMENT_ACCESS_FORBIDDEN("LOBBY_ERR29", "정산 기록에 접근할 권한이 없습니다."),
    STATUS_DIRECT_CHANGE_FORBIDDEN("LOBBY_ERR30", "요청한 상태로 직접 변경할 수 없습니다."),
    HOST_PAYMENT_INFO_REQUIRED("LOBBY_ERR31", "계좌 정보를 등록해야 합니다."),
    RECEIPT_INVALID_LOBBY_STATUS("LOBBY_ERR32", "현재 로비 상태에서는 영수증을 첨부할 수 없습니다."),
    INVALID_FILE_TYPE("LOBBY_ERR33", "지원하지 않는 이미지 형식입니다."),
    FILE_TOO_LARGE("LOBBY_ERR34", "첨부 파일 크기가 너무 큽니다."),
    INVALID_MEDIA_URL("LOBBY_ERR35", "영수증 이미지 URL이 올바르지 않습니다."),
    RECEIPT_NOT_FOUND("LOBBY_ERR36", "등록된 영수증이 없습니다."),
    INVALID_RECEIPT_METADATA("LOBBY_ERR37", "영수증 첨부 정보가 올바르지 않습니다.");

    private final String code;
    private final String message;

    LobbyErrorCode(String code, String message) {
        this.code = code;
        this.message = message;
    }

    public String code() {
        return code;
    }

    public String message() {
        return message;
    }

    public LobbyException exception(HttpStatus status) {
        return new LobbyException(status, this);
    }
}
