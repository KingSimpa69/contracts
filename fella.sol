// SPDX-License-Identifier: The Unlicense
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract FELLA is ERC20, Ownable, ERC20Burnable{
    using Address for address;

    address public basedFellas = 0x217Ec1aC929a17481446A76Ff9B95B9a64F298cF;
    address public taxHandler = 0xB5875473AC9e5dc4614905C46b2EA7712f296e30;
    address[] public sushiRouters;
    uint256 public phase = 3;
    bytes32 public merkleRoot;
    uint256 public constant maxPhase1Tokens = 100000 * 10**18;
    uint256 public taxPercentage = 1;
    bool public isTaxPaused = true;

    mapping(address => bytes32[]) private merkleProof;

    constructor() ERC20("FUCK", "FUCK") Ownable(msg.sender) {
        address[] memory routers = new address[](2);
        routers[0] = 0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891;
        routers[1] = 0x0389879e0156033202C44BF784ac18fC02edeE4f;
        setSushiRouters(routers);
        _mint(0x294fA7c677aa01819DCe2e8371a8C0B751044C70, 3959999 * 10**18);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        bool isEOA = !isContract(recipient);
        bool sushiSwap = isSushiContracts(msg.sender) || isSushiContracts(recipient);
        uint256 _phase = phase;

        require(_phase != 0 || msg.sender == owner() || recipient == owner(), "Fella paused or unauthorized");
        require(_phase != 1 || isWhitelisted(recipient) || sushiSwap, "Not allowed to transfer during phase 1");
        require(_phase != 2 || ownsFella(msg.sender) || ownsFella(recipient), "You must own a Based Fella for phase 2!");

        if (isEOA) {
            require(_phase != 1 || balanceOf(recipient) + amount <= maxPhase1Tokens, "Token limit exceeded for phase 1");
        }

        return _transferWithTax(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        bool isEOA = !isContract(recipient);
        bool sushiSwap = isSushiContracts(msg.sender) || isSushiContracts(recipient) || isSushiContracts(sender);
        uint256 _phase = phase;

        require(_phase != 0 || msg.sender == owner() || sender == owner() || recipient == owner(), "Fella paused or unauthorized");
        require(_phase != 1 || isWhitelisted(recipient) || sushiSwap, "Not allowed to transfer during phase 1");
        require(_phase != 2 || ownsFella(msg.sender) || ownsFella(sender) || ownsFella(recipient), "You must own a Based Fella for phase 2!");

        if (isEOA) {
            require(_phase != 1 || balanceOf(recipient) + amount <= maxPhase1Tokens, "Token limit exceeded for phase 1");
        }

        return _transferFromWithTax(sender, recipient, amount);
    }

    function _transferWithTax(address recipient, uint256 amount) private returns (bool) {
        if (!isTaxPaused) {
            uint256 taxAmount = (amount * taxPercentage) / 100;
            uint256 amountAfterTax = amount - taxAmount;
            super.transfer(taxHandler, taxAmount);
            return super.transfer(recipient, amountAfterTax);
        } else {
            return super.transfer(recipient, amount);
        }
    }

    function _transferFromWithTax(address sender, address recipient, uint256 amount) private returns (bool) {
        if (!isTaxPaused) {
            uint256 taxAmount = (amount * taxPercentage) / 100;
            uint256 amountAfterTax = amount - taxAmount;
            super.transferFrom(sender, taxHandler, taxAmount);
            return super.transferFrom(sender, recipient, amountAfterTax);
        } else {
            return super.transferFrom(sender, recipient, amount);
        }
    }

    function isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function isSushiContracts(address _address) internal view returns (bool) {
        for (uint256 i = 0; i < sushiRouters.length; i++) {
            if (_address == sushiRouters[i]) {
                return true;
            }
        }
        return false;
    }

    function setSushiRouters(address[] memory _sushiRouters) internal onlyOwner {
        sushiRouters = _sushiRouters;
    }

    function setPhase(uint256 _phase) external onlyOwner {
        phase = _phase;
    }

    function setMerkleRoot(bytes32 _whitelistMerkleRoot) external onlyOwner {
        merkleRoot = _whitelistMerkleRoot;
    }

    function setTaxHandler(address _taxHandler) external onlyOwner {
        taxHandler = _taxHandler;
    }

    function setMerkleProof(bytes32[] memory _merkleProof) external {
        merkleProof[msg.sender] = _merkleProof;
    }

    function isWhitelisted(address _address) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_address));
        return MerkleProof.verify(merkleProof[_address], merkleRoot, leaf);
    }

    function ownsFella(address _address) public view returns (bool) {
        return IERC721(basedFellas).balanceOf(_address) > 0;
    }

    function toggleTax() external onlyOwner {
        isTaxPaused = !isTaxPaused;
    }
}
