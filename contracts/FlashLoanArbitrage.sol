// contracts/FlashLoan.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {FlashLoanSimpleReceiverBase} from "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

interface IDex {
    function depositUSDC(uint256 _amount) external;

    function depositDAI(uint256 _amount) external;

    function buyDAI() external;

    function sellDAI() external;
}

contract FlashLoanArbitrage is FlashLoanSimpleReceiverBase {
    address payable owner;

    // Aave ERC20 Token addresses on Goerli network
    address private immutable daiAddress =
        0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357;
    address private immutable usdcAddress =
        0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a;
    address private dexContractAddress =
        0xCF45DD34a0B5Da505C67d78fBCE4D1c518c8CfD5;

    IERC20 private dai;
    IERC20 private usdc;
    IDex private dexContract;

    constructor(address _addressProvider)
        FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider))
    {
        owner = payable(msg.sender);

        dai = IERC20(daiAddress);
        usdc = IERC20(usdcAddress);
        dexContract = IDex(dexContractAddress);
    }

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        //
        // This contract now has the funds requested.
        // Your logic goes here.
        //

        // We get the 1000 USDC loan from Aave

        // Arbirtage operation
        dexContract.depositUSDC(1000000000000000000000); // deposit 1000 USDC into the DeX contract
        dexContract.buyDAI();
        dexContract.depositDAI(dai.balanceOf(address(this)));
        dexContract.sellDAI();

        // At the end of your logic above, this contract owes
        // the flashloaned amount + premiums.
        // Therefore ensure your contract has enough to repay
        // these amounts.

        // Approve the Pool contract allowance to *pull* the owed amount
        uint256 amountOwed = amount + premium;
        IERC20(asset).approve(address(POOL), amountOwed);

        return true;
    }

    function requestFlashLoan(address _token, uint256 _amount) public {
        address receiverAddress = address(this);
        address asset = _token;
        uint256 amount = _amount;
        bytes memory params = "";
        uint16 referralCode = 0;

        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
    }

    function approveUSDC(uint256 _amount) external returns (bool) {
        return usdc.approve(dexContractAddress, _amount);
    }

    function allowanceUSDC() external view returns (uint256) {
        return usdc.allowance(address(this), dexContractAddress);
    }

    function approveDAI(uint256 _amount) external returns (bool) {
        return dai.approve(dexContractAddress, _amount);
    }

    function allowanceDAI() external view returns (uint256) {
        return dai.allowance(address(this), dexContractAddress);
    }

    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can call this function"
        );
        _;
    }

    receive() external payable {}
}