// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TwoWayBridge is CCIPReceiver, Ownable {
    IRouterClient private s_router;
    IERC20 public token;

    uint64 private expectedSourceChainSelector;
    address private expectedSenderAddress = 0x0000000000000000000000000000000000000000;

    event MessageSent(bytes32 indexed messageId, uint64 indexed destinationChainSelector, address receiver, uint256 userNumber, uint256 fees);
    event DataReceived(bytes32 indexed messageId, uint64 indexed sourceChainSelector, address sender, address userAddress, uint256 userNumber);

    constructor(address router, address tokenAddress, uint64 _expectedSourceChainSelector) 
        CCIPReceiver(router) 
        Ownable(msg.sender) 
    {
        s_router = IRouterClient(router);
        token = IERC20(tokenAddress);
        expectedSourceChainSelector = _expectedSourceChainSelector;
    }

    function sendMessage(
        uint64 destinationChainSelector,
        address receiver,
        address userAddress,
        uint256 userNumber
    ) external payable returns (bytes32 messageId) {
        require(token.balanceOf(msg.sender) >= userNumber, "Insufficient ERC20 token balance");
        token.transferFrom(msg.sender, address(this), userNumber);

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(userAddress, userNumber),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(0)
        });

        uint256 fees = s_router.getFee(destinationChainSelector, evm2AnyMessage);
        require(address(this).balance >= fees, "Not enough ETH to cover fees");

        messageId = s_router.ccipSend{value: fees}(
            destinationChainSelector,
            evm2AnyMessage
        );
        emit MessageSent(messageId, destinationChainSelector, receiver, userNumber, fees);
        return messageId;
    }

    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
        require(any2EvmMessage.sourceChainSelector == expectedSourceChainSelector, "Invalid source chain");
        address senderAddress = abi.decode(any2EvmMessage.sender, (address));
        require(senderAddress == expectedSenderAddress, "Unauthorized sender address");

        (address userAddress, uint256 userNumber) = abi.decode(any2EvmMessage.data, (address, uint256));
        require(token.balanceOf(address(this)) >= userNumber, "Insufficient token balance in contract");
        require(token.transfer(userAddress, userNumber), "Token transfer failed");

        emit DataReceived(any2EvmMessage.messageId, any2EvmMessage.sourceChainSelector, senderAddress, userAddress, userNumber);
    }

    function setExpectedSourceChainSelector(uint64 _expectedSourceChainSelector) external onlyOwner {
        expectedSourceChainSelector = _expectedSourceChainSelector;
    }

    function setExpectedSenderAddress(address _expectedSenderAddress) external onlyOwner {
        expectedSenderAddress = _expectedSenderAddress;
    }

    receive() external payable {}

    function withdrawETH(address to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient ETH balance");
        payable(to).transfer(amount);
    }

    function withdrawERC20(address to, uint256 amount) external onlyOwner {
        require(token.balanceOf(address(this)) >= amount, "Insufficient ERC20 balance");
        require(token.transfer(to, amount), "ERC20 transfer failed");
    }
}
