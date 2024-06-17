// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IDinoCards {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract WrappedRAWR is ERC20, ReentrancyGuard {
    address public rawrTokenAddress = 0x469FdA1FB46Fcb4BeFc0D8B994B516bD28c87003;
    uint256 public constant CONVERSION_RATE = 1000;
    IDinoCards public rawrToken = IDinoCards(rawrTokenAddress);

    event Wrap(uint256 rawrAmount, uint256 wrappedAmount);
    event Unwrap(uint256 wrappedAmount, uint256 rawrAmount);

    constructor() ERC20("Wrapped RAWR", "WRAWR") {}

    function wrap(uint256 _rawrAmount) external nonReentrant {
        require(rawrToken.allowance(msg.sender, address(this)) >= _rawrAmount, "Insufficient allowance");

        (bool success,) = rawrTokenAddress.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), _rawrAmount)
        );
        require(success, "Transfer to wrapper contract failed");

        _mint(msg.sender, _rawrAmount * CONVERSION_RATE);

        emit Wrap(_rawrAmount, _rawrAmount * CONVERSION_RATE);
    }

    function unwrap(uint256 _wrawrAmount) external nonReentrant {
        require(balanceOf(msg.sender) >= _wrawrAmount, "Insufficient WRAWR balance");
        uint256 rawrAmount = _wrawrAmount / CONVERSION_RATE;
        require(rawrToken.balanceOf(address(this)) >= rawrAmount, "Insufficient RAWR balance in contract");

        _burn(msg.sender, _wrawrAmount);

        (bool success,) = rawrTokenAddress.call(
            abi.encodeWithSignature("transfer(address,uint256)", msg.sender, rawrAmount)
        );
        require(success, "Transfer to msg.sender failed");

        emit Unwrap(_wrawrAmount, rawrAmount);
    }

}
