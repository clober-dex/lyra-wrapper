//SPDX-License-Identifier: ISC

pragma solidity ^0.8.0;

// For full documentation refer to @lyrafinance/protocol/contracts/OptionMarket.sol";
interface IOptionMarket {
    enum TradeDirection {
        OPEN,
        CLOSE,
        LIQUIDATE
    }

    enum OptionType {
        LONG_CALL,
        LONG_PUT,
        SHORT_CALL_BASE,
        SHORT_CALL_QUOTE,
        SHORT_PUT_QUOTE
    }

    /// @notice For returning more specific errors
    enum NonZeroValues {
        BASE_IV,
        SKEW,
        STRIKE_PRICE,
        ITERATIONS,
        STRIKE_ID
    }

    ///////////////////
    // Internal Data //
    ///////////////////

    struct Strike {
        // strike listing identifier
        uint256 id;
        // strike price
        uint256 strikePrice;
        // volatility component specific to the strike listing (boardIv * skew = vol of strike)
        uint256 skew;
        // total user long call exposure
        uint256 longCall;
        // total user short call (base collateral) exposure
        uint256 shortCallBase;
        // total user short call (quote collateral) exposure
        uint256 shortCallQuote;
        // total user long put exposure
        uint256 longPut;
        // total user short put (quote collateral) exposure
        uint256 shortPut;
        // id of board to which strike belongs
        uint256 boardId;
    }

    struct OptionBoard {
        // board identifier
        uint256 id;
        // expiry of all strikes belonging to board
        uint256 expiry;
        // volatility component specific to board (boardIv * skew = vol of strike)
        uint256 iv;
        // admin settable flag blocking all trading on this board
        bool frozen;
        // list of all strikes belonging to this board
        uint256[] strikeIds;
    }

    ///////////////
    // In-memory //
    ///////////////

    struct OptionMarketParameters {
        // max allowable expiry of added boards
        uint256 maxBoardExpiry;
        // security module address
        address securityModule;
        // fee portion reserved for Lyra DAO
        uint256 feePortionReserved;
        // expected fee charged to LPs, used for pricing short_call_base settlement
        uint256 staticBaseSettlementFee;
    }

    struct TradeInputParameters {
        // id of strike
        uint256 strikeId;
        // OptionToken ERC721 id for position (set to 0 for new positions)
        uint256 positionId;
        // number of sub-orders to break order into (reduces slippage)
        uint256 iterations;
        // type of option to trade
        OptionType optionType;
        // number of contracts to trade
        uint256 amount;
        // final amount of collateral to leave in OptionToken position
        uint256 setCollateralTo;
        // revert trade if totalCost is below this value
        uint256 minTotalCost;
        // revert trade if totalCost is above this value
        uint256 maxTotalCost;
    }

    struct TradeEventData {
        uint256 expiry;
        uint256 strikePrice;
        OptionType optionType;
        TradeDirection tradeDirection;
        uint256 amount;
        uint256 setCollateralTo;
        bool isForceClose;
        uint256 spotPrice;
        uint256 reservedFee;
        uint256 totalCost;
    }

    struct LiquidationEventData {
        address rewardBeneficiary;
        address caller;
        uint256 returnCollateral; // quote || base
        uint256 lpPremiums; // quote || base
        uint256 lpFee; // quote || base
        uint256 liquidatorFee; // quote || base
        uint256 smFee; // quote || base
        uint256 insolventAmount; // quote
    }

    struct Result {
        uint256 positionId;
        uint256 totalCost;
        uint256 totalFee;
    }

    ///////////////
    // Variables //
    ///////////////

    /// @notice claim all reserved option fees
    function smClaim() external;

    ///////////
    // Views //
    ///////////
    function quoteAsset() external view returns (address);

    function baseAsset() external view returns (address);

    function getOptionMarketParams() external view returns (OptionMarketParameters memory);

    function getLiveBoards() external view returns (uint256[] memory _liveBoards);

    function getNumLiveBoards() external view returns (uint256 numLiveBoards);

    function getStrikeAndExpiry(uint256 strikeId) external view returns (uint256 strikePrice, uint256 expiry);

    function getBoardStrikes(uint256 boardId) external view returns (uint256[] memory strikeIds);

    function getStrike(uint256 strikeId) external view returns (Strike memory);

    function getOptionBoard(uint256 boardId) external view returns (OptionBoard memory);

    function getStrikeAndBoard(uint256 strikeId) external view returns (Strike memory, OptionBoard memory);

    function getBoardAndStrikeDetails(uint256 boardId)
        external
        view
        returns (
            OptionBoard memory,
            Strike[] memory,
            uint256[] memory,
            uint256
        );

    ////////////////////
    // User functions //
    ////////////////////

    function openPosition(TradeInputParameters memory params) external returns (Result memory result);

    function closePosition(TradeInputParameters memory params) external returns (Result memory result);

    /**
     * @notice Attempts to reduce or fully close position within cost bounds while ignoring delta trading cutoffs.
     *
     * @param params The parameters for the requested trade
     */
    function forceClosePosition(TradeInputParameters memory params) external returns (Result memory result);

    function addCollateral(uint256 positionId, uint256 amountCollateral) external;

    function liquidatePosition(uint256 positionId, address rewardBeneficiary) external;

    /////////////////////////////////
    // Board Expiry and settlement //
    /////////////////////////////////

    function settleExpiredBoard(uint256 boardId) external;

    function boardToPriceAtExpiry(uint256 boardId) external returns (uint256 priceAtExpiry);

    function getSettlementParameters(uint256 strikeId)
        external
        view
        returns (
            uint256 strikePrice,
            uint256 priceAtExpiry,
            uint256 strikeToBaseReturned,
            uint256 longScaleFactor
        );

    ////////////
    // Events //
    ////////////

    /**
     * @dev Emitted when a Board is created.
     */
    event BoardCreated(uint256 indexed boardId, uint256 expiry, uint256 baseIv, bool frozen);

    /**
     * @dev Emitted when a Board frozen is updated.
     */
    event BoardFrozen(uint256 indexed boardId, bool frozen);

    /**
     * @dev Emitted when a Board new baseIv is set.
     */
    event BoardBaseIvSet(uint256 indexed boardId, uint256 baseIv);

    /**
     * @dev Emitted when a Strike new skew is set.
     */
    event StrikeSkewSet(uint256 indexed strikeId, uint256 skew);

    /**
     * @dev Emitted when a Strike is added to a board
     */
    event StrikeAdded(uint256 indexed boardId, uint256 indexed strikeId, uint256 strikePrice, uint256 skew);

    /**
     * @dev Emitted when parameters for the option market are adjusted
     */
    event OptionMarketParamsSet(OptionMarketParameters optionMarketParams);

    /**
     * @dev Emitted whenever the security module claims their portion of fees
     */
    event SMClaimed(address securityModule, uint256 quoteAmount, uint256 baseAmount);

    /**
     * @dev Emitted when a Board is liquidated.
     */
    event BoardSettled(
        uint256 indexed boardId,
        uint256 spotPriceAtExpiry,
        uint256 totalUserLongProfitQuote,
        uint256 totalBoardLongCallCollateral,
        uint256 totalBoardLongPutCollateral,
        uint256 totalAMMShortCallProfitBase,
        uint256 totalAMMShortCallProfitQuote,
        uint256 totalAMMShortPutProfitQuote
    );

    ////////////
    // Errors //
    ////////////
    // General purpose
    error ExpectedNonZeroValue(address thrower, NonZeroValues valueType);

    // Admin
    error InvalidOptionMarketParams(address thrower, OptionMarketParameters optionMarketParams);

    // Board related
    error InvalidBoardId(address thrower, uint256 boardId);
    error InvalidExpiryTimestamp(address thrower, uint256 currentTime, uint256 expiry, uint256 maxBoardExpiry);
    error BoardNotFrozen(address thrower, uint256 boardId);
    error BoardAlreadySettled(address thrower, uint256 boardId);
    error BoardNotExpired(address thrower, uint256 boardId);

    // Strike related
    error InvalidStrikeId(address thrower, uint256 strikeId);
    error StrikeSkewLengthMismatch(address thrower, uint256 strikesLength, uint256 skewsLength);

    // Trade
    error TotalCostOutsideOfSpecifiedBounds(address thrower, uint256 totalCost, uint256 minCost, uint256 maxCost);
    error BoardIsFrozen(address thrower, uint256 boardId);
    error BoardExpired(address thrower, uint256 boardId, uint256 boardExpiry, uint256 currentTime);
    error TradeIterationsHasRemainder(
        address thrower,
        uint256 iterations,
        uint256 expectedAmount,
        uint256 tradeAmount,
        uint256 totalAmount
    );

    // Access
    error OnlySecurityModule(address thrower, address caller, address securityModule);

    // Token transfers
    error BaseTransferFailed(address thrower, address from, address to, uint256 amount);
    error QuoteTransferFailed(address thrower, address from, address to, uint256 amount);
}
