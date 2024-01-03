// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Receiver is CCIPReceiver, Ownable {
    struct UserData {
        uint256 tokenAmount;
        address userAddress;
    }

    mapping(address => UserData) public userDatas;
    IERC20 public token;
    uint64 private expectedSourceChainSelector = 16015286601757825753;
    address private expectedSenderAddress = 0xE2c04eB02f2301BFd6be2C132308Ba1100dD6646;

    event DataReceived(bytes32 indexed messageId, uint64 indexed sourceChainSelector, address sender, address userAddress, uint256 userNumber);
    event Withdrawal(address user, uint256 amount);

    constructor(address router, address tokenAddress, address initialOwner) CCIPReceiver(router) Ownable(initialOwner) {
        token = IERC20(tokenAddress);
    }

    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
    require(any2EvmMessage.sourceChainSelector == expectedSourceChainSelector, "Invalid source chain");

    address senderAddress = abi.decode(any2EvmMessage.sender, (address));
    require(senderAddress == expectedSenderAddress, "Unauthorized sender address");

    (address userAddress, uint256 userNumber) = abi.decode(any2EvmMessage.data, (address, uint256));

    require(token.balanceOf(address(this)) >= userNumber, "Insufficient token balance in contract");

    require(token.transfer(userAddress, userNumber), "Token transfer failed");

    emit DataReceived(
        any2EvmMessage.messageId, 
        any2EvmMessage.sourceChainSelector, 
        senderAddress, 
        userAddress, 
        userNumber
    );
}


    function getUserData(address userAddress) external view returns (UserData memory) {
        return userDatas[userAddress];
    }

    function withdraw() external {
        UserData memory userData = userDatas[msg.sender];
        require(userData.userAddress == msg.sender, "User not eligible for withdrawal");

        uint256 amount = userData.tokenAmount;
        require(token.balanceOf(address(this)) >= amount, "Insufficient contract balance");

        delete userDatas[msg.sender];

        require(token.transfer(msg.sender, amount), "Token transfer failed");
        emit Withdrawal(msg.sender, amount);
    }

    function setExpectedSourceChainSelector(uint64 _expectedSourceChainSelector) external onlyOwner {
        expectedSourceChainSelector = _expectedSourceChainSelector;
    }

    function setExpectedSenderAddress(address _expectedSenderAddress) external onlyOwner {
        expectedSenderAddress = _expectedSenderAddress;
    }

    function withdrawERC20(address to, uint256 amount) external onlyOwner {
        require(token.balanceOf(address(this)) >= amount, "Insufficient ERC20 balance");
        require(token.transfer(to, amount), "ERC20 transfer failed");
    }
}
