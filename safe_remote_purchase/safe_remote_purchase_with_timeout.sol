// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
contract Purchase {
    uint public value;
    uint public timeout;
    address payable public seller;
    address payable public buyer;

    enum State { Created, Locked, Inactive }
    // The state variable has a default value of the first member, `State.created`
    State public state;

    modifier condition(bool condition_) {
        require(condition_);
        _;
    }

    /// Only the buyer can call this function.
    error OnlyBuyer();
    /// Only the seller can call this function.
    error OnlySeller();
    /// The function cannot be called at the current state.
    error InvalidState();
    /// The provided value has to be even.
    error ValueNotEven();
    /// Only the buyer can call this function or >=5 minutes must have passed after confirmPurchase was called.
    error OnlyBuyerOrTimout();

    modifier onlyBuyer() {
        if (msg.sender != buyer)
            revert OnlyBuyer();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller)
            revert OnlySeller();
        _;
    }

    modifier inState(State state_) {
        if (state != state_)
            revert InvalidState();
        _;
    }

    modifier isBuyerOrTimeout() {
        if (msg.sender != buyer || block.timestamp >= timeout)
            revert OnlyBuyerOrTimout();
        _;
    }

    event Aborted();
    event PurchaseConfirmed();
    event PurchaseCompleted();

    // Ensure that `msg.value` is an even number.
    // Division will truncate if it is an odd number.
    // Check via multiplication that it wasn't an odd number.
    constructor() payable {
        seller = payable(msg.sender);
        value = msg.value / 2;
        if ((2 * value) != msg.value)
            revert ValueNotEven();
    }

    /// Abort the purchase and reclaim the ether.
    /// Can only be called by the seller before
    /// the contract is locked.
    function abort()
        external
        onlySeller
        inState(State.Created)
    {
        emit Aborted();
        state = State.Inactive;
        // We use transfer here directly. It is
        // reentrancy-safe, because it is the
        // last call in this function and we
        // already changed the state.
        seller.transfer(address(this).balance);
    }

    /// Confirm the purchase as buyer.
    /// Transaction has to include `2 * value` ether.
    /// The ether will be locked until confirmReceived
    /// is called.
    function confirmPurchase()
        external
        inState(State.Created)
        condition(msg.value == (2 * value))
        payable
    {
        emit PurchaseConfirmed();
        buyer = payable(msg.sender);
        state = State.Locked;
        timeout = block.timestamp + 5 minutes;
    }

    /// Confirm that the buyer received the item or 5 minutes passed after (confirmPurchase) was called.
    /// Refunds the buyer (value) and pays the seller (3*value).
    function completePurchase()  
        external
        inState(State.Locked)
        condition(msg.sender == buyer || block.timestamp >= timeout)
    {
        emit PurchaseCompleted();
        // It is important to change the state first because
        // otherwise, the contracts called using `send` below
        // can call in again here.
        state = State.Inactive;

        buyer.transfer(value);

        seller.transfer(3 * value);
    }
}

