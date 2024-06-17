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

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title A contract for receiving NFTs bridged from another blockchain or layer
/// @notice This contract handles the reception, validation, and metadata management of NFTs from the bridge
/// @dev Inherits from ERC721URIStorage for token URI management, and uses OpenZeppelin's ReentrancyGuard for security
contract NOUNSBridgeReceiver is ERC721URIStorage, ReentrancyGuard {
    /// @notice The bridge fee required for locking NFTs
    uint256 public BRIDGE_FEE = 1000000000000000;

    /// @notice Mapping to track whether an NFT is locked for bridging
    mapping(uint256 => bool) public lockedNFTs;

    /// @notice Mapping to store base64 encoded image data for tokens
    mapping(uint256 => string) private tokenImages;

    /// @notice Mapping to track validation status of NFTs by authorized authorities
    mapping(uint256 => address[3]) public validated;

    /// @notice Array of addresses authorized to validate NFTs
    address[3] public authorities;

    /// @notice Address that last validated a change to authority
    address public authorityModValidated = address(0);

    /// @notice Address that last validated a fee modification
    address public feeModValidated = address(0);

    /// @notice Address that last validated an image modification
    address public imageModValidated = address(0);

    /// @dev Emitted when an NFT is locked for bridging
    event NFTLocked(uint256 tokenId, address owner);

    /// @dev Emitted when an NFT is unlocked from bridging
    event NFTUnlocked(uint256 tokenId, address owner);

    /// @dev Emitted when an NFT is validated by an authority
    event Validated(uint256 tokenId, address receiver, address validator);

    constructor() ERC721("Nouns", "NOUN") {
        authorities[0] = 0x5100C59526185Ee1863aae24D6D9064e7CbAC0E4;
        authorities[1] = 0x2B81Aad20Df5539573e4f5C9105164c9E60a8522;
        authorities[2] = 0x299Ed0Ca9226cd196CDb2f5950c49BD49aD8D84f;
    }

    /// @notice Locks an NFT for bridging
    /// @dev Transfers the NFT to the contract and locks it, requiring a fee
    /// @param tokenId The token ID of the NFT to lock
    function bridgeOut(uint256 tokenId) public nonReentrant payable {
        require(_ownerOf(tokenId) != address(0), "NFT does not exist");
        require(!lockedNFTs[tokenId], "NFT is already locked");
        require(msg.value >= BRIDGE_FEE, "You must pay the bridge fee");

        uint256 paymentToAuthority0 = msg.value * 20 / 100; // 20% 
        uint256 paymentToAuthority1 = msg.value * 20 / 100; // 20% 

        payable(authorities[0]).transfer(paymentToAuthority0);
        payable(authorities[1]).transfer(paymentToAuthority1);
        payable(authorities[2]).transfer(address(this).balance);
        transferFrom(msg.sender, address(this), tokenId);
        lockedNFTs[tokenId] = true;

        emit NFTLocked(tokenId, msg.sender);
    }

    /// @notice Receives and validates an NFT, transferring it to the recipient
    /// @dev Requires full validation from all authorities
    /// @param tokenId The token ID of the NFT
    /// @param recipient The address to receive the NFT
    /// @param base64 The base64 encoded image data for the token
    function bridgeReceive(uint256 tokenId, address recipient, string memory base64) public {
        require(isAuthority(msg.sender), "Not an authority");
        require(validated[tokenId][0] != address(0) && validated[tokenId][1] != address(0) && validated[tokenId][2] != address(0), "NFT not fully validated.");
        
        if (_ownerOf(tokenId) != address(0)) {
            require(lockedNFTs[tokenId], "NFT is not locked");
            _transfer(address(this), recipient, tokenId);
            delete lockedNFTs[tokenId];
            delete validated[tokenId];
            emit NFTUnlocked(tokenId, recipient);
        } else {
            tokenImages[tokenId] = base64;
            _mint(recipient, tokenId);
            delete validated[tokenId];
            emit NFTUnlocked(tokenId, recipient);
        }
    }

    /// @notice Generates the metadata URI for an NFT
    /// @param tokenId The token ID of the NFT
    /// @return The URI containing metadata in JSON format
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ERC721Metadata: URI query for nonexistent token");

        string memory json = string(abi.encodePacked(
            '{"name": "Noun ',
            Strings.toString(tokenId),
            '", "description": "A NOUN on Base", "image": "data:image/svg+xml;base64,',
            tokenImages[tokenId],
            '"}'
        ));

        string memory encodedJson = Base64.encode(bytes(json));
        return string(abi.encodePacked('data:application/json;base64,', encodedJson));
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
    function isAuthority(address _address) internal view returns (bool) {
        for (uint i = 0; i < authorities.length; i++) {
            if (authorities[i] == _address) {
                return true;
            }
        }
        return false;
    }

    /// @notice Modifies the image data for an NFT after a two-step validation process
    /// @param tokenId The token ID of the NFT
    /// @param base64 The base64 encoded image data to set
    function imageMod(uint256 tokenId, string memory base64) public nonReentrant{
        require(isAuthority(msg.sender), "Not authorized");
        require(imageModValidated == address(0) || imageModValidated == msg.sender, "Operation already initiated");
        if (imageModValidated == address(0)) {
            imageModValidated = msg.sender;
        } else {
            tokenImages[tokenId] = base64;
            imageModValidated = address(0);
        }
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

