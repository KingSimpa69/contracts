// SPDX-License-Identifier: The Unlicense
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// The most complex contract I've ever built. For my one and only Based Fellas community
// Keepin it Based af. -KingSimpa69

contract Homes is ERC1155Supply, Ownable {
    using Strings for uint;
    using SafeMath for uint256;

    string private _baseURI = "https://ipfs.basedfellas.io/ipfs/QmTWA7frS3NPLid7eEiCc2Z2nPauDEqCAHrCLFEBzTam8m/";

    string public constant name = "Homes";
    string public constant symbol = "HOMES";

    string[] private availableTypes;

    mapping(uint256 => string) private _types;
    mapping(uint256 => uint256) private _remaining;
    uint256[] private _availableIds;

    uint256 private blockLastUsed;
    bytes32 private theLastSeed;
    uint256 public phase = 0;
    bytes32 public phase1Merkle;
    bytes32 public phase2Merkle;
    mapping(address => uint256) public phase1MaxMint;
    mapping(address => uint256) private phase1Minted;
    mapping(address => bool) private phase2Minted;

    uint256 public constant MINT_PRICE = 0.008 ether;
    uint256[] private probabilities = [10, 30, 60];

    event Mint(address indexed recipient, uint256 tokenId);

    constructor() ERC1155("") Ownable(msg.sender) {
        for (uint256 i = 1; i <= 30; i++) {
            if (i % 3 == 1) {
                _types[i] = "Bungalow";
                _remaining[i] = 275;
            } else if (i % 3 == 2) {
                _types[i] = "Villa";
                _remaining[i] = 150;
            } else {
                _types[i] = "Manor";
                _remaining[i] = 75;
            }
            _availableIds.push(i);
        }
        availableTypes = ["Manor","Villa","Bungalow"];
    }

    function mint(bytes32[] calldata proof) external payable {
        require(phase != 0,"Minting has not yet started");
        require(blockLastUsed != block.number, "One mint allowed per block");
        require(msg.value >= MINT_PRICE, "Insufficient payment");
        require(_availableIds.length != 0, "No more tokens available");

        bytes32 leafHash = keccak256(abi.encodePacked(msg.sender));

        if (phase == 1) {
            require(MerkleProof.verify(proof, phase1Merkle, leafHash), "You are not whitelisted for Phase 1");
            require(phase1Minted[msg.sender] < phase1MaxMint[msg.sender], "You have minted all you whitelist spots");
        } else if (phase == 2) {
            require(MerkleProof.verify(proof, phase2Merkle, leafHash), "You are not whitelisted for Phase 2");
            require(phase2Minted[msg.sender] == false, "You can only mint one home during phase 2");
        }

        uint256 randomIndex = _weightedRandom();
        string memory tokenType = availableTypes[randomIndex];

        uint256[] memory availableIdsOfType = _getAvailableIdsOfType(tokenType);
        require(availableIdsOfType.length > 0, "No more tokens available for the selected type");

        uint256 randomIdIndex = _getRandomIndex(availableIdsOfType);
        uint256 tokenId = availableIdsOfType[randomIdIndex];

        _mint(msg.sender, tokenId, 1, "");
        emit Mint(msg.sender, tokenId);

        if (phase == 1) {
            phase1Minted[msg.sender] ++;
        } else if (phase == 2) {
            phase2Minted[msg.sender] = true;
        }

        _remaining[tokenId]--;

        if (_remaining[tokenId] == 0) {
            removeTokenId(tokenId);
            if (getRemainingCountByType(tokenType) == 0) {
                removeAvailableType(tokenType); 
            }
        }
    }

    function removeAvailableType(string memory tokenType) internal {
        bytes32 typeHash = keccak256(bytes(tokenType));
        for (uint256 i = 0; i < availableTypes.length; i++) {
            if (keccak256(bytes(availableTypes[i])) == typeHash) {
                availableTypes[i] = availableTypes[availableTypes.length - 1];
                availableTypes.pop();
                break;
            }
        }
    }

    function isTypeAvailable(string memory tokenType) internal view returns (bool) {
        for (uint256 i = 0; i < availableTypes.length; i++) {
            if (keccak256(bytes(availableTypes[i])) == keccak256(bytes(tokenType))) {
                return true;
            }
        }
        return false;
    }

    function _getAvailableIdsOfType(string memory tokenType) private view returns (uint256[] memory) {
        uint256[] memory availableIdsOfType;
        for (uint256 i = 1; i <= 30; i++) {
            if (keccak256(bytes(_types[i])) == keccak256(bytes(tokenType)) && _remaining[i] > 0) {
                availableIdsOfType = _appendToArray(availableIdsOfType, i);
            }
        }
        return availableIdsOfType;
    }
    
    function getRemainingCountByType(string memory tokenType) internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 1; i <= 30; i++) {
            if (keccak256(bytes(_types[i])) == keccak256(bytes(tokenType))) {
                count += _remaining[i];
            }
        }
        return count;
    }


    function _weightedRandom() private returns (uint256) {
        require(availableTypes.length > 0, "No available types");

        uint256 totalProbability;
        for (uint256 i = 0; i < probabilities.length && i < availableTypes.length; i++) {
            totalProbability = totalProbability.add(probabilities[i]);
        }

        uint256 randomNumber = uint256(keccak256(abi.encodePacked(blockhash(block.number), msg.sender, theLastSeed))) % totalProbability;
        theLastSeed = keccak256(abi.encodePacked(randomNumber));

        uint256 cumulativeProbability;
        for (uint256 i = 0; i < probabilities.length && i < availableTypes.length; i++) {
            cumulativeProbability = cumulativeProbability.add(probabilities[i]);
            if (randomNumber < cumulativeProbability && isTypeAvailable(availableTypes[i])) return i;
        }
        revert("Weighted random selection failed");
    }

    function _appendToArray(uint256[] memory array, uint256 element) private pure returns (uint256[] memory) {
        uint256 length = array.length;
        uint256[] memory newArray = new uint256[](length + 1);
        for (uint256 i = 0; i < length; i++) {
            newArray[i] = array[i];
        }
        newArray[length] = element;
        return newArray;
    }

    function _getRandomIndex(uint256[] memory array) private returns (uint256) {
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(blockhash(block.number), msg.sender, theLastSeed))) % array.length;
        theLastSeed = keccak256(abi.encodePacked(randomIndex, blockhash(block.number), msg.sender, theLastSeed));
        return randomIndex;
    }

    function removeTokenId(uint256 tokenId) internal {
        uint256 lastIndex = _availableIds.length - 1;
        for (uint256 i = 0; i <= lastIndex; i++) {
            if (_availableIds[i] == tokenId) {
                if (i != lastIndex) _availableIds[i] = _availableIds[lastIndex];
                _availableIds.pop();
                break;
            }
        }
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseURI = baseURI;
    }

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        return string(abi.encodePacked(_baseURI, tokenId.toString(), ".json"));
    }

    function setMerkle(uint256 _phase, bytes32 _whitelistMerkleRoot) external onlyOwner {
        require(_phase == 1 || _phase == 2, "Invalid phase");
        if (_phase == 1) phase1Merkle = _whitelistMerkleRoot;
        else phase2Merkle = _whitelistMerkleRoot;
    }

    function setPhase(uint256 _phase) external onlyOwner {
        phase = _phase;
    }

    function setPhase1MaxMint(address wallet, uint256 amount) external onlyOwner {
        phase1MaxMint[wallet] = amount;
    }
}
