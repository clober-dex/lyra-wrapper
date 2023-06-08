pragma solidity ^0.8.0;

import "./IOptionMarket.sol";
import "./IOptionToken.sol";

interface CloberWrappedLyraToken {
    event Deposit(address indexed sender, address indexed recipient, uint256 amount, uint256[] tokenIds);

    event Withdraw(address indexed sender, address indexed recipient, uint256 amount, uint256 newTokenId);

    event Claim(address indexed sender, address indexed recipient, uint256 amount, uint256 quoteAmount);

    function collateralPositionId() external view returns (uint256);

    function expiry() external view returns (uint256);

    function strikePrice() external view returns (uint256);

    function optionType() external view returns (IOptionMarket.OptionType);

    function strikeId() external view returns (uint256);

    function boardId() external view returns (uint256);

    function optionMarket() external view returns (address);

    function optionToken() external view returns (address);

    function collateralBalance() external view returns (uint256);

    function frozen() external view returns (bool);

    function positionState() external view returns (IOptionToken.PositionState);

    function getOptionBoard() external view returns (IOptionMarket.OptionBoard memory);

    function deposit(
        address to,
        uint256 positionId,
        uint256 amount
    ) external;

    function deposit(
        address to,
        uint256[] calldata positionIds_,
        uint256 amount
    ) external returns (uint256 refundTokenId);

    function withdraw(address to, uint256 amount) external returns (uint256);

    function claim(address to) external;

    function delegateClaim(address owner) external;
}
