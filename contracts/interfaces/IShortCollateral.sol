//SPDX-License-Identifier: ISC

pragma solidity ^0.8.0;

// Interfaces
import "./IOptionMarket.sol";
import "./IOptionToken.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/ShortCollateral.sol";

interface IShortCollateral {
    // The amount the SC underpaid the LP due to insolvency.
    // The SC will take this much less from the LP when settling insolvent positions.
    function LPBaseExcess() external view returns (uint256);

    function LPQuoteExcess() external view returns (uint256);

    /////////////////////////
    // Position Settlement //
    /////////////////////////

    function settleOptions(uint256[] memory positionIds) external;

    ////////////
    // Events //
    ////////////

    /// @dev Emitted when a board is settled
    event BoardSettlementCollateralSent(
        uint256 amountBaseSent,
        uint256 amountQuoteSent,
        uint256 lpBaseInsolvency,
        uint256 lpQuoteInsolvency,
        uint256 lpBaseExcess,
        uint256 lpQuoteExcess
    );

    /**
     * @dev Emitted when an Option is settled.
     */
    event PositionSettled(
        uint256 indexed positionId,
        address indexed settler,
        address indexed optionOwner,
        uint256 strikePrice,
        uint256 priceAtExpiry,
        IOptionMarket.OptionType optionType,
        uint256 amount,
        uint256 settlementAmount,
        uint256 insolventAmount
    );

    /**
     * @dev Emitted when quote is sent to either a user or the LiquidityPool
     */
    event QuoteSent(address indexed receiver, uint256 amount);
    /**
     * @dev Emitted when base is sent to either a user or the LiquidityPool
     */
    event BaseSent(address indexed receiver, uint256 amount);

    event BaseExchangedAndQuoteSent(address indexed recipient, uint256 amountBase, uint256 quoteReceived);

    ////////////
    // Errors //
    ////////////

    // Collateral transfers
    error OutOfQuoteCollateralForTransfer(address thrower, uint256 balance, uint256 amount);
    error OutOfBaseCollateralForTransfer(address thrower, uint256 balance, uint256 amount);
    error OutOfBaseCollateralForExchangeAndTransfer(address thrower, uint256 balance, uint256 amount);

    // Token transfers
    error BaseTransferFailed(address thrower, address from, address to, uint256 amount);
    error QuoteTransferFailed(address thrower, address from, address to, uint256 amount);

    // Access
    error BoardMustBeSettled(address thrower, IOptionToken.PositionWithOwner position);
    error OnlyOptionMarket(address thrower, address caller, address optionMarket);
}
