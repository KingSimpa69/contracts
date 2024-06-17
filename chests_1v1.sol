// SPDX-License-Identifier: The Unlicense
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract ChestsGame is ReentrancyGuard, Ownable {
    uint256 public constant ENTRY_FEE = 2600000000000000 wei;
    uint256 public constant VRF_FEE = 27000000000000 wei;
    uint256 public MAX_PLAYERS = 2;
    uint256 public buffer = 20000;
    address payable[] public players;
    uint256 public volume = 0;
    address private callbackAddress = 0x23FD23C07F9b82DBddC6a7d9497feD4A40Ce1d03;
    address private tokenAddress = 0x122A3f185655847980639E8EdF0F0f66cd91C5fE; 
    address private feeRecipient = 0xc6e6e91957aD7079827103799e3631F2B5Ff8c87;
    address private bufferWallet = 0x9703A30886F7850B74AC3771B5D36d730043f301;
    IUniswapV2Router02 private uniswapRouter;
    IWETH private weth;
    uint256 public gameId;
    bool public gameActive;
    IERC20 FELLA = IERC20(tokenAddress);

    event DepositMade(address indexed player, uint256 amount);
    event WinnerSelected(address indexed winner, uint256 prize, uint256 randomNumber);
    event MaxPlayersReached();
    event EffortsRewarded(address indexed, uint256 amount);
    event DebugLog(string message, uint256 value);

    constructor() Ownable(msg.sender) {
        address _wethAddress = 0x4200000000000000000000000000000000000006;
        address _uniswapRouter = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        weth = IWETH(_wethAddress);
        gameActive = true;
    }

    function deposit() public payable nonReentrant {
        require(gameActive, "Game is not active");
        require(msg.value >= ENTRY_FEE + VRF_FEE, "Insufficient funds");
        require(!isPlayerAlreadyInGame(msg.sender), "Player has already deposited");
        payable(callbackAddress).transfer(VRF_FEE);
        players.push(payable(msg.sender));
        emit DepositMade(msg.sender, msg.value);
        volume += msg.value;
        if (players.length == MAX_PLAYERS) {
            gameActive = false;
            emit MaxPlayersReached();
        }
    }

    function pullStraws(uint256 rn) public nonReentrant {
        require(msg.sender == callbackAddress, "Only the callback address can fire this tx.");

        uint256 winnerIndex = uint256(rn) % players.length;
        address payable winner = players[winnerIndex];

        uint prize = address(this).balance * 95 / 100; 
        winner.transfer(prize);

        emit WinnerSelected(winner, prize, uint256(rn));

        uint fee = address(this).balance; 
        handleBuybackAndAllocations(fee, winnerIndex);
    }

    function handleBuybackAndAllocations(uint256 feeAmount, uint256 winnerIndex) private {

        weth.deposit{value: feeAmount}();
        uint256 wethAmount = weth.balanceOf(address(this));
        require(wethAmount > 0, "No WETH to swap!");

        weth.approve(address(uniswapRouter), wethAmount);

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = tokenAddress;
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(wethAmount, 0, path, address(this), block.timestamp + 200);

        handleBuffer();

        uint256 fellaAmount = FELLA.balanceOf(address(this));
        require(fellaAmount > 0, "No FELLA tokens received from swap");

        uint256 loserShare = (fellaAmount * 95 / 100) / (players.length - 1);
        require(loserShare > 0, "Loser share calculation error");

        for (uint i = 0; i < players.length; i++) {
            if (i != winnerIndex) {
                uint256 share = loserShare;
                require(FELLA.transfer(players[i], share), "Token transfer to loser failed");
                emit EffortsRewarded(players[i], share);
            }
        }

        uint256 remainingBalance = FELLA.balanceOf(address(this));
        require(FELLA.transfer(feeRecipient, remainingBalance), "Token transfer to fee recipient failed");

        delete players;
        gameActive = true;
    }

    function handleBuffer() private {
        
        uint256 bufferBalance = FELLA.balanceOf(bufferWallet);
        uint256 bufferAmount = bufferBalance / buffer;
        uint256 bufferAllowance = FELLA.allowance(bufferWallet, address(this));
        require(bufferBalance >= bufferAmount, "Buffer wallet balance too low");
        require(bufferAllowance >= bufferAmount, "Insufficient allowance from buffer wallet");

        (bool success, /* Low-level call was the only way to get this to work, IDEK.*/) = address(FELLA).call(
            abi.encodeWithSelector(
                FELLA.transferFrom.selector,
                bufferWallet,
                address(this),
                bufferAmount
            )
        );
        require(success, "Transfer from buffer wallet failed");
    }

    function isPlayerAlreadyInGame(address player) internal view returns (bool) {
        for (uint i = 0; i < players.length; i++) {
            if (players[i] == player) {
                return true;
            }
        }
        return false;
    }

    function getAllPlayers() public view returns (address payable[] memory) {
        return players;
    }

    function setBufferFactor(uint256 _buffer) public onlyOwner {
        buffer = _buffer;
    }

    receive() external payable {
        weth.deposit{value: msg.value}();
    }
}
