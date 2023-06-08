pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/ILyraRegistry.sol";
import "./interfaces/IShortCollateral.sol";
import "./interfaces/CloberWrappedLyraToken.sol";

contract WrappedLyraToken is ERC20, CloberWrappedLyraToken {
    using SafeERC20 for IERC20;

    ILyraRegistry private constant _LYRA_REGISTRY = ILyraRegistry(0x6c87e4364Fd44B0D425ADfD0328e56b89b201329);
    IOptionMarket private immutable _optionMarket;
    IOptionToken private immutable _optionToken;
    IShortCollateral private immutable _shortCollateral;
    IERC20 private immutable _quoteAsset;
    IERC20 private immutable _baseToken;

    uint256 public immutable collateralPositionId;
    uint256 public immutable expiry;
    uint256 public immutable strikePrice;
    IOptionMarket.OptionType public immutable optionType;
    uint256 public immutable strikeId;
    uint256 public immutable boardId;

    constructor(
        address market,
        uint256 positionId,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        ILyraRegistry.OptionMarketAddresses memory addresses = _LYRA_REGISTRY.getMarketAddresses(market);
        _optionMarket = IOptionMarket(addresses.optionMarket);
        _optionToken = IOptionToken(addresses.optionToken);
        _baseToken = IERC20(addresses.baseAsset);
        _quoteAsset = IERC20(addresses.quoteAsset);
        _shortCollateral = IShortCollateral(addresses.shortCollateral);

        collateralPositionId = positionId;
        IOptionToken.PositionWithOwner memory optionPosition = _optionToken.getPositionWithOwner(positionId);

        strikeId = optionPosition.strikeId;
        optionType = optionPosition.optionType;
        optionPosition.state;

        (IOptionMarket.Strike memory strike, IOptionMarket.OptionBoard memory optionBoard) = _optionMarket
            .getStrikeAndBoard(strikeId);

        boardId = strike.boardId;
        strikePrice = strike.strikePrice;
        expiry = optionBoard.expiry;
    }

    /**
     * @notice
     * @dev
     */
    function initialize() external {
        IOptionToken.PositionWithOwner memory optionPosition = _optionToken.getPositionWithOwner(collateralPositionId);
        require((optionPosition.owner != address(this)) || (optionPosition.amount != totalSupply()), "INITIALIZED");
        if (optionPosition.owner != address(this)) {
            _optionToken.transferFrom(optionPosition.owner, address(this), collateralPositionId);
        }
        _mint(address(this), optionPosition.amount - totalSupply());
    }

    function optionMarket() external view returns (address) {
        return address(_optionMarket);
    }

    function optionToken() external view returns (address) {
        return address(_optionToken);
    }

    function collateralBalance() public view returns (uint256) {
        return _optionToken.positions(collateralPositionId).amount;
    }

    function frozen() public view returns (bool) {
        return _optionMarket.getOptionBoard(boardId).frozen;
    }

    function positionState() public view returns (IOptionToken.PositionState) {
        return _optionToken.positions(collateralPositionId).state;
    }

    function getOptionBoard() external view returns (IOptionMarket.OptionBoard memory) {
        return _optionMarket.getOptionBoard(boardId);
    }

    function _merge(uint256[] memory positionIds) internal {
        require(positionIds[0] == collateralPositionId, "INVALID_ID");
        _optionToken.merge(positionIds);
    }

    function _transferLyra(address to, uint256 amount) internal returns (uint256) {
        if (amount == 0) return 0;
        require(to != address(0), "INVALID_ADDRESS");

        if (amount == _optionToken.getOptionPosition(collateralPositionId).amount) {
            _optionToken.transferFrom(address(this), to, collateralPositionId);
            return collateralPositionId;
        }
        return _optionToken.split(collateralPositionId, amount, 0, to);
    }

    function deposit(
        address to,
        uint256 positionId,
        uint256 amount
    ) external {
        require(amount > 0, "EMPTY_INPUT");

        uint256[] memory positionIds = new uint256[](2);
        positionIds[0] = collateralPositionId;
        if (_optionToken.positions(positionId).amount == amount) {
            _optionToken.transferFrom(msg.sender, address(this), positionId);
            positionIds[1] = positionId;
        } else {
            positionIds[1] = _optionToken.split(positionId, amount, 0, address(this));
        }
        _merge(positionIds);
        positionIds = new uint256[](1);
        positionIds[0] = positionId;
        emit Deposit(msg.sender, to, amount, positionIds);
        _mint(to, amount);
    }

    function deposit(
        address to,
        uint256[] calldata positionIds_,
        uint256 amount
    ) external returns (uint256 refundTokenId) {
        uint256 length = positionIds_.length;
        require((length > 0) && (amount > 0), "EMPTY_INPUT");

        uint256[] memory positionIds = new uint256[](length + 1);
        positionIds[0] = collateralPositionId;
        uint256 lockedLyraAmount = collateralBalance();
        unchecked {
            for (uint256 i = 1; i <= length; i++) {
                uint256 positionId = positionIds_[i - 1];
                _optionToken.transferFrom(msg.sender, address(this), positionId);
                positionIds[i] = positionId;
            }
        }
        _merge(positionIds);
        emit Deposit(msg.sender, to, amount, positionIds_);
        _mint(to, amount);
        return _transferLyra(msg.sender, collateralBalance() - lockedLyraAmount - amount);
    }

    function withdraw(address to, uint256 amount) external returns (uint256 newTokenId) {
        require(amount > 0, "EMPTY_INPUT");

        _burn(msg.sender, amount);
        newTokenId = _transferLyra(to, amount);
        emit Withdraw(msg.sender, to, amount, newTokenId);
    }

    function _settle() private {
        if (_optionMarket.boardToPriceAtExpiry(boardId) == 0) {
            _optionMarket.settleExpiredBoard(boardId);
        }

        uint256[] memory positionIds = new uint256[](1);
        positionIds[0] = collateralPositionId;
        _shortCollateral.settleOptions(positionIds);
    }

    function _claim(
        address spender,
        address to,
        uint256 amount
    ) internal {
        require((spender != address(0)) && (to != address(0)), "EMPTY_ADDRESS");
        require(amount != 0);

        if (_optionToken.getPositionState(collateralPositionId) != IOptionToken.PositionState.SETTLED) _settle();

        uint256 quoteAmount = (_quoteAsset.balanceOf(address(this)) * balanceOf(msg.sender)) / totalSupply();
        _quoteAsset.safeTransfer(to, quoteAmount);
        _burn(spender, amount);
        emit Claim(spender, to, amount, quoteAmount);
    }

    function claim(address to) external {
        _claim(msg.sender, to, balanceOf(msg.sender));
    }

    function delegateClaim(address owner) external {
        uint256 amount = balanceOf(owner);
        _spendAllowance(owner, address(this), amount);
        _claim(owner, owner, amount);
    }
}
