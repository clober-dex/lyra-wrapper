pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "../../../contracts/interfaces/IShortCollateral.sol";
import "../../../contracts/WrappedLyraToken.sol";

contract WrappedLyraTokenUnitTest is Test {
    string constant URL = "https://arbitrum.public-rpc.com";
    uint256 constant BLOCK_NUMBER_CONTRACT_CREATED = 55693330;
    uint256 constant BLOCK_NUMBER_BOARD_CREATED = 64896605;
    uint256 constant BLOCK_NUMBER_POSITION1_CREATED = 72140961;
    uint256 constant BLOCK_NUMBER_POSITION2_CREATED = 72147404;
    uint256 constant BLOCK_NUMBER_BOARD_EXPIRY = 73112427;
    uint256 constant BLOCK_NUMBER_BOARD_SETTLED = 73112494;
    uint256 constant BLOCK_NUMBER_POSITION_SETTLED = 73113167;

    address constant USER1 = 0xdBeE2B501021Ec7d8D6FE48f1829118178D2E4A3;
    uint256 constant POSITION_ID1 = 4135;
    address constant USER2 = 0x6C0D952C843ADeB1f99894BE2c38c38aF76bf0D1;
    uint256 constant POSITION_ID2 = 4136;

    address constant WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant OPTION_TOKEN = 0xe485155ce647157624C5E2A41db45A9CC88098c3;
    address constant OPTION_MARKET = 0x919E5e0C096002cb8a21397D724C4e3EbE77bC15;
    address constant SHORT_COLLATERAL = 0xef4a92FCde48c84EF2B5c4A141A4CD1988FC73a9;

    mapping(address => uint256[]) positionIdMap;

    uint256 arbitrum;
    WrappedLyraToken token;

    IOptionMarket market;
    IOptionToken lyraToken;
    IShortCollateral shortCollateral;
    uint256 collateralPositionId;

    function setUp() public {
        arbitrum = vm.createFork(URL);
        vm.selectFork(arbitrum);
        assertEq(vm.activeFork(), arbitrum);
        market = IOptionMarket(OPTION_MARKET);
        lyraToken = IOptionToken(OPTION_TOKEN);
        shortCollateral = IShortCollateral(SHORT_COLLATERAL);

        positionIdMap[USER1].push(POSITION_ID1);
        positionIdMap[USER2].push(POSITION_ID2);
    }

    function _mint(address to, uint256 amount) private returns (uint256 id) {
        uint256 beforeBalance = _lyraBalance(POSITION_ID1);
        vm.prank(USER1);
        id = lyraToken.split(POSITION_ID1, amount, 0, to);
        assertEq(beforeBalance - _lyraBalance(POSITION_ID1), amount, "dev only");
    }

    function _initialize() private {
        collateralPositionId = _mint(address(this), 1);
        token = new WrappedLyraToken(address(market), collateralPositionId, "Wrapped Lyra", "WLyra");
        lyraToken.approve(address(token), collateralPositionId);
        token.initialize();
    }

    function _lyraBalance(uint256 id) private view returns (uint256) {
        return lyraToken.getOptionPosition(id).amount;
    }

    function testLyraContract() public {
        vm.rollFork(BLOCK_NUMBER_CONTRACT_CREATED);

        assertEq(IERC721Metadata(address(lyraToken)).name(), "Lyra wETH market Option Token", "TOKEN_NAME");
        assertEq(IERC721Metadata(address(lyraToken)).symbol(), "Ly-wETH-ot", "TOKEN_SYMBOL");

        assertEq(market.baseAsset(), WETH_ADDRESS);

        vm.prank(address(shortCollateral));
        lyraToken.settlePositions(new uint256[](0));
    }

    function testLyraPosition() public {
        vm.rollFork(BLOCK_NUMBER_BOARD_SETTLED - 1);

        IOptionToken.OptionPosition memory optionPosition = lyraToken.positions(POSITION_ID1);
        assertEq(uint256(optionPosition.optionType), uint256(IOptionMarket.OptionType.LONG_CALL), "OPTION_TYPE");
        assertEq(uint256(optionPosition.state), uint256(IOptionToken.PositionState.ACTIVE), "OPTION_STATE");
        assertEq(optionPosition.collateral, 0, "POSITION_COLLATERAL");
    }

    function testWLyraContract() public {
        vm.rollFork(BLOCK_NUMBER_POSITION1_CREATED + 1);

        _initialize();

        assertEq(address(token.optionMarket()), address(market));
        assertEq(address(token.optionToken()), address(lyraToken));

        assertEq(token.expiry(), 1679644800, "EXPIRE_TIMESTAMP");
        assertEq(token.strikePrice(), 1700000000000000000000, "STRIKE_PRICE");
        assertEq(uint256(token.optionType()), uint256(IOptionMarket.OptionType.LONG_CALL), "OPTION_TYPE");
        assertEq(token.collateralPositionId(), collateralPositionId, "POSITION_ID");
        assertEq(token.strikeId(), 105, "STRIKE_ID");

        (, uint256 priceAtExpiry, uint256 strikeToBaseReturned, ) = market.getSettlementParameters(token.strikeId());

        assertEq(priceAtExpiry, 0, "PRICE_AT_EXPIRY");
        assertEq(strikeToBaseReturned, 0, "STRIKE_TO_BASE_RETURNED");
    }

    function _deposit(
        address user,
        uint256[] memory positionIds,
        uint256 amount
    ) private returns (uint256 newPositionId) {
        uint256 beforeLyraBalance;
        for (uint256 i = 0; i < positionIds.length; ++i) {
            beforeLyraBalance += _lyraBalance(positionIds[i]);
        }
        vm.startPrank(user);
        lyraToken.setApprovalForAll(address(token), true);
        if (beforeLyraBalance < amount) {
            vm.expectRevert(stdError.arithmeticError);
            token.deposit(user, positionIds, amount);
            vm.stopPrank();
            return 0;
        }
        if (amount % 3 == 0) {
            // for randomness
            newPositionId = token.deposit(user, positionIds, amount);
        } else {
            if (_lyraBalance(positionId) > amount) {
                newPositionId = positionId;
            }
            token.deposit(user, positionId, amount);
        }
        vm.stopPrank();

        if (newPositionId != 0) {
            assertEq(beforeLyraBalance - _lyraBalance(newPositionId), amount);
            assertEq(lyraToken.ownerOf(newPositionId), user);
            assertEq(token.balanceOf(user), amount);
        } else {
            assertEq(beforeLyraBalance, amount);
            assertEq(token.balanceOf(user), amount);
        }
    }

    function _withdraw(address user, uint256 amount) private returns (uint256 newPositionId) {
        vm.startPrank(user);
        if (token.balanceOf(user) < amount) {
            vm.expectRevert(stdError.arithmeticError);
            token.withdraw(user, amount);
        } else {
            uint256 beforeBalance = token.balanceOf(user);
            newPositionId = token.withdraw(user, amount);
            assertEq(_lyraBalance(newPositionId), amount);
            assertEq(token.balanceOf(user), beforeBalance - amount);
            assertEq(lyraToken.ownerOf(newPositionId), user);
        }
        vm.stopPrank();
    }

    function _claim(address user, uint256 expectedQuoteAmount) private {
        uint256 beforeQuoteBalance = IERC20(market.quoteAsset()).balanceOf(user);
        if (block.timestamp < market.getOptionBoard(token.boardId()).expiry) {
            vm.expectRevert(
                abi.encodeWithSelector(IOptionMarket.BoardNotExpired.selector, address(market), token.boardId())
            );
            vm.prank(user);
            token.claim(user);
            return;
        } else if (lyraToken.getPositionState(collateralPositionId) == IOptionToken.PositionState.SETTLED) {
            vm.prank(user);
            token.claim(user);
        } else if (market.boardToPriceAtExpiry(token.boardId()) == 0) {
            vm.prank(user);
            token.claim(user);
        } else {
            vm.prank(user);
            token.claim(user);
        }
        assertEq(IERC20(market.quoteAsset()).balanceOf(user) - beforeQuoteBalance, expectedQuoteAmount);
    }

    function testWrapLyra() public {
        vm.rollFork(BLOCK_NUMBER_POSITION2_CREATED + 1);

        _initialize();

        uint256[] memory positionIds = new uint256[](1);
        positionIds[0] = POSITION_ID1;
        _deposit(USER1, positionIds, _lyraBalance(POSITION_ID1) / 3);
    }

    function testUnwrapLyra() public {
        vm.rollFork(BLOCK_NUMBER_POSITION2_CREATED + 1);

        _initialize();

        uint256[] memory positionIds = new uint256[](1);
        positionIds[0] = POSITION_ID1;
        _deposit(USER1, positionIds, _lyraBalance(POSITION_ID1));
        _withdraw(USER1, token.balanceOf(USER1) / 2);
    }

    function testClaimLyraBeforeExpire() public {
        vm.rollFork(BLOCK_NUMBER_BOARD_EXPIRY - 1);

        _initialize();

        uint256[] memory positionIds = new uint256[](1);
        positionIds[0] = POSITION_ID1;
        _deposit(USER1, positionIds, _lyraBalance(POSITION_ID1));

        _claim(USER1, 0);
    }

    function testClaimLyraAfterExpire() public {
        vm.rollFork(BLOCK_NUMBER_BOARD_EXPIRY);

        _initialize();

        uint256[] memory positionIds = new uint256[](1);
        positionIds[0] = POSITION_ID1;
        _deposit(USER1, positionIds, _lyraBalance(POSITION_ID1));

        _claim(USER1, 76422764);
    }

    function testClaimLyraAfterSettleBoard() public {
        vm.rollFork(BLOCK_NUMBER_BOARD_SETTLED - 1);

        _initialize();

        uint256[] memory positionIds = new uint256[](1);
        positionIds[0] = POSITION_ID1;
        _deposit(USER1, positionIds, _lyraBalance(POSITION_ID1));

        market.settleExpiredBoard(token.boardId());

        _claim(USER1, 76422764);
    }

    function testClaimLyraAfterSettleOptions() public {
        vm.rollFork(BLOCK_NUMBER_BOARD_SETTLED - 1);

        _initialize();

        uint256[] memory positionIds = new uint256[](1);
        positionIds[0] = POSITION_ID1;
        _deposit(USER1, positionIds, _lyraBalance(POSITION_ID1));

        market.settleExpiredBoard(token.boardId());

        positionIds[0] = collateralPositionId;
        shortCollateral.settleOptions(positionIds);

        _claim(USER1, 76422764);
    }
}
