// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {KeshacAccount} from "../src/KeshacAccount.sol";
import {DeployKeshac} from "script/DeployKeshac.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract KeshacAccountTest is Test {
    HelperConfig helperConfig;
    KeshacAccount keshacAccount;
    ERC20Mock usdc;
    uint256 constant AMOUNT = 1e18;
    address randomuser = makeAddr("randomUser");
    SendPackedUserOp sendPackedUserOp;

    using MessageHashUtils for bytes32;

    function setUp() public {
        DeployKeshac deployKeshac = new DeployKeshac();
        (helperConfig, keshacAccount) = deployKeshac.deployKeshacAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    // test that owner can call the keshac account. This is without going through the altmempool.
    // usdc mint
    //msg.sender call Keshac account

    function testOwnerCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(keshacAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(keshacAccount),
            AMOUNT
        );
        // Act
        vm.prank(keshacAccount.owner());
        keshacAccount.execute(dest, value, functionData);

        // Assert
        assertEq(usdc.balanceOf(address(keshacAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(keshacAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(keshacAccount),
            AMOUNT
        );
        // Act
        vm.prank(randomuser);
        vm.expectRevert(
            KeshacAccount.KeshacAccount__NotFromEntryPointOrOwner.selector
        );
        keshacAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedOp() public {
        // Arrange
        assertEq(usdc.balanceOf(address(keshacAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(keshacAccount),
            AMOUNT
        );
        bytes memory executeCallData = abi.encodeWithSelector(
            KeshacAccount.execute.selector,
            dest,
            value,
            functionData
        );

        PackedUserOperation memory packedUserOp = sendPackedUserOp
            .generateSignedUserOperation(
                executeCallData,
                helperConfig.getConfig()
            );
        bytes32 userOperationHash = IEntryPoint(
            helperConfig.getConfig().entryPoint
        ).getUserOpHash(packedUserOp);

        // Act
        address actualSigner = ECDSA.recover(
            userOperationHash.toEthSignedMessageHash(),
            packedUserOp.signature
        );

        // Assert
        assertEq(actualSigner, keshacAccount.owner());
    }

    function testValidationOfUserOps() public {
        // Arrange
        assertEq(usdc.balanceOf(address(keshacAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(keshacAccount),
            AMOUNT
        );
        bytes memory executeCallData = abi.encodeWithSelector(
            KeshacAccount.execute.selector,
            dest,
            value,
            functionData
        );
        PackedUserOperation memory packedUserOp = sendPackedUserOp
            .generateSignedUserOperation(
                executeCallData,
                helperConfig.getConfig()
            );
        bytes32 userOperationHash = IEntryPoint(
            helperConfig.getConfig().entryPoint
        ).getUserOpHash(packedUserOp);

        uint256 missingAccountFunds = 1e18;

        // Act
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = keshacAccount.validateUserOp(
            packedUserOp,
            userOperationHash,
            missingAccountFunds
        );
        assertEq(validationData, 0);
    }
}
