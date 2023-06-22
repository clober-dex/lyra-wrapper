pragma solidity ^0.8.0;

import "./IOptionMarket.sol";
import "./IOptionToken.sol";

interface CloberWrappedLyraToken {
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
        address,
        uint256[] calldata,
        uint256
    ) external returns (uint256);

    function withdraw(address to, uint256 amount) external returns (uint256);

    function claim(address to) external;

    function delegateClaim(address owner) external;
}
