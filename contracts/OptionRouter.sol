// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

import "./interfaces/CloberOrderBook.sol";
import "./interfaces/CloberMarketSwapCallbackReceiver.sol";
import "./interfaces/CloberWrappedLyraToken.sol";
import "./interfaces/CloberRouter.sol";
import "./interfaces/CloberMarketFactory.sol";
import "./interfaces/CloberOrderNFT.sol";
import "./interfaces/IOptionToken.sol";
import "./Errors.sol";

contract OptionRouter is CloberMarketSwapCallbackReceiver, CloberRouter {
    using SafeERC20 for IERC20;

    bool private constant _BID = true;
    bool private constant _ASK = false;

    CloberMarketFactory private immutable _factory;

    modifier checkDeadline(uint64 deadline) {
        if (block.timestamp > deadline) {
            revert Errors.CloberError(Errors.DEADLINE);
        }
        _;
    }

    constructor(address factory) {
        _factory = CloberMarketFactory(factory);
    }

    function _safeTransferFromLyraToken(
        address lyraToken,
        address form,
        uint256[] memory tokenIds
    ) private returns (uint256 amount) {
        uint256 length = tokenIds.length;
        IOptionToken.OptionPosition[] memory optionPosition = IOptionToken(lyraToken).getOptionPositions(tokenIds);
        for (uint256 i = 0; i < length; i++) {
            IOptionToken(lyraToken).safeTransferFrom(form, address(this), tokenIds[i]);
            amount += optionPosition[i].amount;
        }
    }

    function cloberMarketSwapCallback(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        bytes calldata data
    ) external payable {
        // check if caller is registered market
        if (_factory.getMarketHost(msg.sender) == address(0)) {
            revert Errors.CloberError(Errors.ACCESS);
        }

        // lyraToken is address(0) when bid order.
        (address user, address payer, uint256[] memory tokenIds) = abi.decode(
            data,
            (address, address, uint256[], address)
        );

        if (tokenIds.length > 0) {
            address lyraToken = CloberWrappedLyraToken(CloberOrderBook(msg.sender).baseToken()).optionToken();
            uint256 totalAmount = _safeTransferFromLyraToken(lyraToken, payer, tokenIds);
            uint256 lyraTokenId;

            if (totalAmount < inputAmount) {
                lyraTokenId = CloberWrappedLyraToken(inputToken).deposit(msg.sender, tokenIds, totalAmount);
                inputAmount -= totalAmount;
            } else {
                lyraTokenId = CloberWrappedLyraToken(inputToken).deposit(msg.sender, tokenIds, inputAmount);
                if (lyraTokenId != 0) IOptionToken(lyraToken).safeTransferFrom(address(this), payer, lyraTokenId);
                inputAmount = 0;
            }
        }

        if (inputAmount > 0) {
            IERC20(inputToken).safeTransferFrom(payer, msg.sender, inputAmount);
        }
        if (outputAmount > 0) {
            IERC20(outputToken).safeTransfer(user, outputAmount);
        }

        if (address(this).balance > 0) {
            (bool success, ) = payer.call{value: address(this).balance}("");
            if (!success) {
                revert Errors.CloberError(Errors.FAILED_TO_SEND_VALUE);
            }
        }
    }

    function wrap(
        address to,
        address wLyraToken,
        uint256[] calldata positionIds,
        uint256 amount
    ) external returns (uint256) {
        address lyraToken = CloberWrappedLyraToken(wLyraToken).optionToken();
        _safeTransferFromLyraToken(lyraToken, msg.sender, positionIds);
        uint256 refundedPositionId = CloberWrappedLyraToken(wLyraToken).deposit(to, positionIds, amount);
        if (refundedPositionId > 0) {
            IOptionToken(lyraToken).safeTransferFrom(address(this), to, refundedPositionId);
        }
        return refundedPositionId;
    }

    function unwrap(
        address to,
        address wLyraToken,
        uint256 amount
    ) external returns (uint256) {
        IERC20(wLyraToken).safeTransferFrom(msg.sender, address(this), amount);
        return CloberWrappedLyraToken(wLyraToken).withdraw(to, amount);
    }

    function limitBid(LimitOrderParams calldata params)
        external
        payable
        checkDeadline(params.deadline)
        returns (uint256)
    {
        return _limitOrder(params, _BID, new uint256[](0));
    }

    function limitAsk(LimitOrderParams calldata params, uint256[] calldata lyraTokenIds)
        external
        payable
        checkDeadline(params.deadline)
        returns (uint256)
    {
        return _limitOrder(params, _ASK, lyraTokenIds);
    }

    function _limitOrder(
        LimitOrderParams calldata params,
        bool isBid,
        uint256[] memory lyraTokenIds
    ) internal returns (uint256 orderIndex) {
        CloberOrderBook market = CloberOrderBook(params.market);
        orderIndex = market.limitOrder{value: uint256(params.claimBounty) * 1 gwei}(
            address(this),
            params.priceIndex,
            params.rawAmount,
            params.baseAmount,
            (isBid ? 1 : 0) + (params.postOnly ? 2 : 0),
            abi.encode(params.user, msg.sender, lyraTokenIds)
        );
        CloberOrderNFT(market.orderToken()).safeTransferFrom(address(this), params.user, orderIndex);
    }

    function marketBid(MarketOrderParams calldata params) external payable checkDeadline(params.deadline) {
        _marketOrder(params, _BID, new uint256[](0));
    }

    function marketAsk(MarketOrderParams calldata params, uint256[] calldata lyraTokenIds)
        external
        payable
        checkDeadline(params.deadline)
    {
        _marketOrder(params, _ASK, lyraTokenIds);
    }

    function _marketOrder(
        MarketOrderParams calldata params,
        bool isBid,
        uint256[] memory lyraTokenIds
    ) internal {
        CloberOrderBook(params.market).marketOrder(
            address(this),
            params.limitPriceIndex,
            params.rawAmount,
            params.baseAmount,
            (isBid ? 1 : 0) + (params.expendInput ? 2 : 0),
            abi.encode(params.user, msg.sender, lyraTokenIds)
        );
    }

    function claim(uint64 deadline, ClaimOrderParams[] calldata paramsList) external checkDeadline(deadline) {
        _claim(paramsList);
    }

    function _claim(ClaimOrderParams[] calldata paramsList) internal {
        for (uint256 i = 0; i < paramsList.length; ++i) {
            ClaimOrderParams calldata params = paramsList[i];
            CloberOrderBook(params.market).claim(msg.sender, params.orderKeys);
        }
    }
}
