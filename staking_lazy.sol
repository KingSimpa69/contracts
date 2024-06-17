// SPDX-License-Identifier: The Unlicense
pragma solidity ^0.8.25;

////----------------------------------------------------------------------------/////
// Refactor of my original lazy staking contract I wrote 2 years ago. Now includes //
// maximum payouts and batched balance fetching.          R.I.P EWD                //
////-----------------------------KINGSIMPA69-----------------------------------//////

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LazyStaking is Ownable, ReentrancyGuard {
    mapping(uint256 => uint256) public lastClaimBlock;
    mapping(uint256 => uint256) public totalRewardsClaimed;

    uint256 public startBlock;
    uint256 public constant rewardPerBlock = 31700000000000000;  // 0.03170 per block (1k per Fella over 365 days)
    uint256 public constant maxRewardPerNFT = 500000 * 10**18;  

    address public nftContractAddress = 0x217Ec1aC929a17481446A76Ff9B95B9a64F298cF;
    address public tokenContractAddress = 0x7ED613AB8b2b4c6A781DDC97eA98a666c6437511;

    event Claim(uint256 indexed tokenID, uint256 amountClaimed);

    constructor() Ownable(msg.sender) {
        startBlock = block.number;
    }

    function claim(uint256 _tokenID) public nonReentrant {
        require(msg.sender == IERC721(nftContractAddress).ownerOf(_tokenID), "You don't own that fella!");
        uint256 reward = fellaUnpaid(_tokenID);
        uint256 totalClaimed = totalRewardsClaimed[_tokenID] + reward;
        require(totalClaimed <= maxRewardPerNFT, "Max reward exceeded");
        
        lastClaimBlock[_tokenID] = block.number;
        totalRewardsClaimed[_tokenID] = totalClaimed;
        IERC20(tokenContractAddress).transfer(msg.sender, reward);
        emit Claim(_tokenID, reward);
    }

    function fellaUnpaid(uint256 _tokenID) public view returns (uint256) {
        uint256 lastChecked = lastClaimBlock[_tokenID] == 0 ? startBlock : lastClaimBlock[_tokenID];
        uint256 reward = (block.number - lastChecked) * rewardPerBlock;
        uint256 possibleTotal = totalRewardsClaimed[_tokenID] + reward;
        if (possibleTotal > maxRewardPerNFT) {
            reward = maxRewardPerNFT - totalRewardsClaimed[_tokenID];
        }
        return reward;
    }

    function batchFellaUnpaid(uint256[] memory _tokenIDs) public view returns (uint256[] memory) {
        uint256[] memory rewards = new uint256[](_tokenIDs.length);
        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            rewards[i] = fellaUnpaid(_tokenIDs[i]);
        }
        return rewards;
    }


    function emergencyWithdraw() public onlyOwner nonReentrant {
        uint256 contractBalance = IERC20(tokenContractAddress).balanceOf(address(this));
        IERC20(tokenContractAddress).transfer(msg.sender, contractBalance);
    }
}
