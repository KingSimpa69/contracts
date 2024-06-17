/////////////////////////////////////////////////////////////////////////
// SPDX-License-Identifier: TheUnlicense
//
// Smart contracts, backend and frontend by KingSimpa69.
// Another refactor from a contract I wrote two years ago. 
// Built for the Based Fellas Bridge Authority.
// Bridging ANY project on ANY EVM over to base safely and responsibly.
//
/////////////////////////////////////////////////////////////////////////
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title A contract for bridging NFTs between different blockchains or layers
/// @notice This contract handles the locking, unlocking, and validation of NFTs for cross-chain transfers
/// @dev Utilizes OpenZeppelin's ERC721 interface for NFT interactions and ReentrancyGuard for security against re-entrant calls
contract NOUNSBridgeNative is ReentrancyGuard {
    /// @notice Address of the NFT contract
    address public nounsAddy = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03;

    /// @notice Bridge fee required to lock an NFT
    uint256 public BRIDGE_FEE = 10000000000000000; 

    /// @notice ERC721 NFT contract interface
    IERC721 public NOUNS = IERC721(nounsAddy);

    /// @notice Tracks whether an NFT is locked for bridging
    mapping(uint256 => bool) public lockedNFTs;

    /// @notice Tracks validation status of NFTs by authorized authorities
    mapping(uint256 => address[3]) public validated;

    /// @notice Array of addresses authorized to validate NFTs
    address[3] public authorities;

    /// @notice Address that last validated a change to authority
    address public authorityModValidated = address(0);

    /// @notice Address that last validated a fee modification
    address public feeModValidated = address(0);

    /// @dev Emitted when an NFT is locked for bridging
    event NFTLocked(uint256 tokenId, address owner);

    /// @dev Emitted when an NFT is unlocked from bridging
    event NFTUnlocked(uint256 tokenId, address owner);

    /// @dev Emitted when an NFT is validated by an authority
    event Validated(uint256 tokenId, address receiver, address validator);

    constructor() {
        authorities[0] = 0x5100C59526185Ee1863aae24D6D9064e7CbAC0E4;
        authorities[1] = 0x2B81Aad20Df5539573e4f5C9105164c9E60a8522;
        authorities[2] = 0x299Ed0Ca9226cd196CDb2f5950c49BD49aD8D84f;
    }

    /// @notice Locks an NFT for bridging
    /// @dev Transfers the NFT to the contract and locks it, distributing the bridge fee among authorities in specified percentages
    /// @param tokenId The token ID of the NFT to lock
    function bridgeOut(uint256 tokenId) public nonReentrant payable {
        require(NOUNS.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(!lockedNFTs[tokenId], "NFT is locked.");
        require(msg.value >= BRIDGE_FEE, "You must pay the bridge fee");
        uint256 paymentToAuthority0 = msg.value * 20 / 100; // 20% 
        uint256 paymentToAuthority1 = msg.value * 20 / 100; // 20% 

        payable(authorities[0]).transfer(paymentToAuthority0);
        payable(authorities[1]).transfer(paymentToAuthority1);
        payable(authorities[2]).transfer(address(this).balance);

        NOUNS.transferFrom(msg.sender, address(this), tokenId);
        lockedNFTs[tokenId] = true;

        emit NFTLocked(tokenId, msg.sender);
    }

    /// @notice Unlocks an NFT from the bridge and transfers it to the recipient
    /// @dev Requires full validation from all authorities
    /// @param tokenId The token ID of the NFT
    /// @param recipient The address to receive the unlocked NTP
    function bridgeReceive(uint256 tokenId, address recipient) public {
        require(isAuthority(msg.sender), "Not an authority");
        require(lockedNFTs[tokenId], "NFT not locked.");
        require(validated[tokenId][0] != address(0) && validated[tokenId][1] != address(0) && validated[tokenId][2] != address(0), "NFT not fully validated.");

        NOUNS.transferFrom(address(this), recipient, tokenId);
        delete lockedNFTs[tokenId];
        delete validated[tokenId];

        emit NFTUnlocked(tokenId, recipient);
    }

    /// @notice Validates an NFT for bridging by authorized authorities
    /// @dev Records the validator if they have not already validated the token
    /// @param tokenId The token ID of the NFT to validate
    function validate(uint256 tokenId, address receiver) public {
        require(isAuthority(msg.sender), "Not an authority");
        require(!hasValidated(tokenId, msg.sender), "Already validated this token");

        for (uint i = 0; i < validated[tokenId].length; i++) {
            if (validated[tokenId][i] == address(0)) {
                validated[tokenId][i] = msg.sender;
                emit Validated(tokenId, receiver, msg.sender);
                return;
            }
        }
    }

    /// @notice Checks if a given address has already validated a specific token
    /// @param tokenId The token ID to check
    /// @param validator The address to check
    /// @return bool Whether the address has already validated the token
    function hasValidated(uint256 tokenId, address validator) internal view returns (bool) {
        for (uint i = 0; i < validated[tokenId].length; i++) {
            if (validated[tokenId][i] == validator) {
                return true;
            }
        }
        return false;
    }

    /// @notice Checks if an address is an authorized authority
    /// @param _address The address to check
    /// @return bool Whether the address is an authority
    function isAuthority(address _address) public view returns (bool) {
        for (uint i = 0; i < authorities.length; i++) {
            if (authorities[i] == _address) {
                return true;
            }
        }
        return false;
    }

    /// @notice Sets the bridge fee and requires a validation step before implementation
    /// @param fee The new bridge fee to set
    function feeMod(uint256 fee) public nonReentrant{
        require(isAuthority(msg.sender), "Not authorized");
        require(feeModValidated == address(0) || feeModValidated == msg.sender, "Operation already initiated");
        if (feeModValidated == address(0)) {
            feeModValidated = msg.sender;
        } else {
            BRIDGE_FEE = fee;
            feeModValidated = address(0);
        }
    }

    /// @notice Modifies the authority list after a two-step validation process
    /// @param index The index in the authority array to modify
    /// @param _address The new authority address to set
    function authorityMod(uint256 index, address _address) public nonReentrant{
        require(isAuthority(msg.sender), "Not authorized");
        require(authorityModValidated == address(0) || authorityModValidated == msg.sender, "Operation already initiated");

        if (authorityModValidated == address(0)) {
            authorityModValidated = msg.sender;
        } else {
            require(index < authorities.length, "Invalid index");
            authorities[index] = _address;
            authorityModValidated = address(0);
        }
    }

    /// @notice Retrieves the full list of authority addresses
    /// @return Array of 3 addresses that are authorized
    function getAuthorities() public view returns (address[3] memory) {
        return authorities;
    }
}
