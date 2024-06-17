# Contracts Repository

This repository contains a collection of Solidity smart contracts designed for various decentralized applications. Below is an index of the contracts with brief descriptions of their functionalities.

## Index

- [**bridge_native.sol**](https://github.com/KingSimpa69/contracts/blob/main/bridge_native.sol)  
  _Description:_ Handles the bridging of NFTs between different blockchain networks, including locking and unlocking mechanisms.

- [**bridge_receiver.sol**](https://github.com/KingSimpa69/contracts/blob/main/bridge_receiver.sol)  
  _Description:_ Companion contract to `bridge_native.sol` that receives and processes NFTs on the target blockchain. Manages minting, metadata storage and locking/unlocking mechanisms providing bridge back functionality.

- [**chests_1v1.sol**](https://github.com/KingSimpa69/contracts/blob/main/chests_1v1.sol)  
  _Description:_ Manages the gaming mechanics for king's chests, including the storing and managment of player and game assets.

- [**fella.sol**](https://github.com/KingSimpa69/contracts/blob/main/fella.sol)  
  _Description:_ ERC20 contract for the Based Fellas FELLA token. Handles launch mechanisms, merkle proofs whitelists and taxes.

- [**homes.sol**](https://github.com/KingSimpa69/contracts/blob/main/homes.sol)  
  _Description:_ ERC721 contract for the Based Fellas HOMES. Handles minting, merkle proofs whitelist and kingdom/type probability.

- [**rawr_wrapper.sol**](https://github.com/KingSimpa69/contracts/blob/main/rawr_wrapper.sol)  
  _Description:_ ERC20 wrapper contract that manages the wrapping and unwrapping of RAWR to and from WRAWR

- [**staking_lazy.sol**](https://github.com/KingSimpa69/contracts/blob/main/staking_lazy.sol)  
  _Description:_ Implements a staking mechanism for NFT holders, passivley dripping tokens on a fixed per contract term.

## Licensing

This project is under the Unlicense, which allows free use, modification, and distribution of the included software.

For more detailed information on each contract, please refer to the comments within each `.sol` file.

