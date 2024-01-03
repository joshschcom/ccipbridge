// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Sender is OwnerIsCreator {
    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;
    IERC20 public depositToken;

    uint64 public expectedSourceChainSelector;
    address public expectedSenderAddress;

    event MessageSent(bytes32 indexed messageId, uint64 indexed destinationChainSelector, address receiver, uint256 userNumber, address feeToken, uint256 fees);

    constructor(address _router, address _link, address _depositToken) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
        depositToken = IERC20(_depositToken);
    }

    function sendMessage(
        uint64 destinationChainSelector,
        address receiver,
        address userAddress,
        uint256 userNumber
    ) external returns (bytes32 messageId) {
        require(depositToken.balanceOf(msg.sender) >= userNumber, "Insufficient ERC20 token balance");
        depositToken.transferFrom(msg.sender, address(this), userNumber);

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(userAddress, userNumber),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(s_linkToken)
        });

        uint256 fees = s_router.getFee(destinationChainSelector, evm2AnyMessage);
        require(s_linkToken.balanceOf(address(this)) >= fees, "Not enough LINK to cover fees");
        s_linkToken.approve(address(s_router), fees);

        messageId = s_router.ccipSend(destinationChainSelector, evm2AnyMessage);
        emit MessageSent(messageId, destinationChainSelector, receiver, userNumber, address(s_linkToken), fees);
        return messageId;
    }

    function withdrawERC20(address to, uint256 amount) external onlyOwner {
        require(depositToken.balanceOf(address(this)) >= amount, "Insufficient ERC20 balance");
        require(depositToken.transfer(to, amount), "ERC20 transfer failed");
    }

    function withdrawLINK(address to, uint256 amount) external onlyOwner {
        require(s_linkToken.balanceOf(address(this)) >= amount, "Insufficient LINK balance");
        require(s_linkToken.transfer(to, amount), "LINK transfer failed");
    }
}
