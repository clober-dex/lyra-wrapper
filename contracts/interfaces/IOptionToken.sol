//SPDX-License-Identifier: ISC

pragma solidity ^0.8.0;

// Interfaces
import "./IOptionMarket.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/OptionToken.sol";
interface IOptionToken is IERC721 {
    enum PositionState {
        EMPTY,
        ACTIVE,
        CLOSED,
        LIQUIDATED,
        SETTLED,
        MERGED
    }

    enum PositionUpdatedType {
        OPENED,
        ADJUSTED,
        CLOSED,
        SPLIT_FROM,
        SPLIT_INTO,
        MERGED,
        MERGED_INTO,
        SETTLED,
        LIQUIDATED,
        TRANSFER
    }

    struct OptionPosition {
        uint256 positionId;
        uint256 strikeId;
        IOptionMarket.OptionType optionType;
        uint256 amount;
        uint256 collateral;
        PositionState state;
    }

    struct PartialCollateralParameters {
        // Percent of collateral used for penalty (amm + sm + liquidator fees)
        uint256 penaltyRatio;
        // Percent of penalty used for amm fees
        uint256 liquidatorFeeRatio;
        // Percent of penalty used for SM fees
        uint256 smFeeRatio;
        // Minimal value of quote that is used to charge a fee
        uint256 minLiquidationFee;
    }

    struct PositionWithOwner {
        uint256 positionId;
        uint256 strikeId;
        IOptionMarket.OptionType optionType;
        uint256 amount;
        uint256 collateral;
        PositionState state;
        address owner;
    }

    struct LiquidationFees {
        uint256 returnCollateral; // quote || base
        uint256 lpPremiums; // quote || base
        uint256 lpFee; // quote || base
        uint256 liquidatorFee; // quote || base
        uint256 smFee; // quote || base
        uint256 insolventAmount; // quote
    }

    function positions(uint256 positionId) external view returns (OptionPosition memory);

    function nextId() external view returns (uint256);

    function partialCollatParams() external view returns (PartialCollateralParameters memory);

    function baseURI() external view returns (string memory);

    function canLiquidate(
        OptionPosition memory position,
        uint256 expiry,
        uint256 strikePrice,
        uint256 spotPrice
    ) external view returns (bool);

    function getLiquidationFees(
        uint256 gwavPremium, // quote || base
        uint256 userPositionCollateral, // quote || base
        uint256 convertedMinLiquidationFee, // quote || base
        uint256 insolvencyMultiplier // 1 for quote || spotPrice for base
    ) external view returns (LiquidationFees memory liquidationFees);

    ///////////////
    // Transfers //
    ///////////////

    function split(
        uint256 positionId,
        uint256 newAmount,
        uint256 newCollateral,
        address recipient
    ) external returns (uint256 newPositionId);

    function merge(uint256[] memory positionIds) external;

    //////////
    // View //
    //////////

    /// @dev Returns the PositionState of a given positionId
    function getPositionState(uint256 positionId) external view returns (PositionState);

    /// @dev Returns an OptionPosition struct of a given positionId
    function getOptionPosition(uint256 positionId) external view returns (OptionPosition memory);

    /// @dev Returns an array of OptionPosition structs given an array of positionIds
    function getOptionPositions(uint256[] memory positionIds) external view returns (OptionPosition[] memory);

    /// @dev Returns a PositionWithOwner struct of a given positionId (same as OptionPosition but with owner)
    function getPositionWithOwner(uint256 positionId) external view returns (PositionWithOwner memory);

    /// @dev Returns an array of PositionWithOwner structs given an array of positionIds
    function getPositionsWithOwner(uint256[] memory positionIds) external view returns (PositionWithOwner[] memory);

    /// @notice Returns an array of OptionPosition structs owned by a given address
    /// @dev Meant to be used offchain as it can run out of gas
    function getOwnerPositions(address target) external view returns (OptionPosition[] memory);

    /// @dev returns PartialCollateralParameters struct
    function getPartialCollatParams() external view returns (PartialCollateralParameters memory);

    ////////////////////
    // Owner Function //
    ////////////////////

    function settlePositions(uint256[] memory positionIds) external;

    ////////////
    // Events //
    ///////////

    /**
     * @dev Emitted when the URI is modified
     */
    event URISet(string uri);

    /**
     * @dev Emitted when partial collateral parameters are modified
     */
    event PartialCollateralParamsSet(PartialCollateralParameters partialCollateralParams);

    /**
     * @dev Emitted when a position is minted, adjusted, burned, merged or split.
     */
    event PositionUpdated(
        uint256 indexed positionId,
        address indexed owner,
        PositionUpdatedType indexed updatedType,
        OptionPosition position,
        uint256 timestamp
    );

    ////////////
    // Errors //
    ////////////

    // Admin
    error InvalidPartialCollateralParameters(address thrower, PartialCollateralParameters partialCollatParams);

    // Adjusting
    error AdjustmentResultsInMinimumCollateralNotBeingMet(address thrower, OptionPosition position, uint256 spotPrice);
    error CannotClosePositionZero(address thrower);
    error CannotOpenZeroAmount(address thrower);
    error CannotAdjustInvalidPosition(
        address thrower,
        uint256 positionId,
        bool invalidPositionId,
        bool positionInactive,
        bool strikeMismatch,
        bool optionTypeMismatch
    );
    error OnlyOwnerCanAdjustPosition(address thrower, uint256 positionId, address trader, address owner);
    error FullyClosingWithNonZeroSetCollateral(address thrower, uint256 positionId, uint256 setCollateralTo);
    error AddingCollateralToInvalidPosition(
        address thrower,
        uint256 positionId,
        bool invalidPositionId,
        bool positionInactive,
        bool isShort
    );

    // Liquidation
    error PositionNotLiquidatable(address thrower, OptionPosition position, uint256 spotPrice);

    // Splitting
    error SplittingUnapprovedPosition(address thrower, address caller, uint256 positionId);
    error InvalidSplitAmount(address thrower, uint256 originalPositionAmount, uint256 splitAmount);
    error ResultingOriginalPositionLiquidatable(address thrower, OptionPosition position, uint256 spotPrice);
    error ResultingNewPositionLiquidatable(address thrower, OptionPosition position, uint256 spotPrice);

    // Merging
    error MustMergeTwoOrMorePositions(address thrower);
    error MergingUnapprovedPosition(address thrower, address caller, uint256 positionId);
    error PositionMismatchWhenMerging(
        address thrower,
        OptionPosition firstPosition,
        OptionPosition nextPosition,
        bool ownerMismatch,
        bool strikeMismatch,
        bool optionTypeMismatch,
        bool duplicatePositionId
    );

    // Access
    error StrikeIsSettled(address thrower, uint256 strikeId);
    error OnlyOptionMarket(address thrower, address caller, address optionMarket);
    error OnlyShortCollateral(address thrower, address caller, address shortCollateral);
}
