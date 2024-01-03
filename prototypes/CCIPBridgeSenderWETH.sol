// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
}


contract Sender is OwnerIsCreator {
    IRouterClient private s_router;
    IERC20 public depositToken;
    IWETH public weth;

    uint64 public expectedSourceChainSelector;
    address public expectedSenderAddress;

    event MessageSent(bytes32 indexed messageId, uint64 indexed destinationChainSelector, address receiver, uint256 userNumber);
    event WETHDeposited(address indexed depositor, uint256 amount);

    constructor(address _router, address _depositToken, address _wethAddress) {
        s_router = IRouterClient(_router);
        depositToken = IERC20(_depositToken);
        weth = IWETH(_wethAddress);
    }

    function depositETHForWETH() external payable {
        weth.deposit{value: msg.value}();
        emit WETHDeposited(msg.sender, msg.value);
    }

    function sendMessage(
        uint64 destinationChainSelector,
        address receiver,
        address userAddress,
        uint256 userNumber
    ) external returns (bytes32 messageId) {
        require(depositToken.balanceOf(msg.sender) >= userNumber, "Insufficient ERC20 token balance");
        depositToken.transferFrom(msg.sender, address(this), userNumber);

        uint256 wethBalance = weth.balanceOf(address(this));
        require(wethBalance > 0, "Insufficient WETH for fees");

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(userAddress, userNumber),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(weth) // Use WETH for fees
        });

        uint256 fees = s_router.getFee(destinationChainSelector, evm2AnyMessage);
        require(wethBalance >= fees, "Not enough WETH to cover fees");

        weth.approve(address(s_router), fees);
        messageId = s_router.ccipSend(destinationChainSelector, evm2AnyMessage);
        emit MessageSent(messageId, destinationChainSelector, receiver, userNumber);
        return messageId;
    }

    receive() external payable {}

    function withdrawETH(address to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient ETH balance");
        payable(to).transfer(amount);
    }

    function withdrawERC20(address to, uint256 amount, address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient token balance");
        require(token.transfer(to, amount), "Token transfer failed");
    }
}
