// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { Solarray } from "solarray/Solarray.sol";

import { IOwnable2Step } from "../src/external/IOwnable2Step.sol";
import { Factory, IFactory, Initializable } from "../src/Factory.sol";
import { IOwnable } from "../src/external/Ownable.sol";
import { FeeContract, IFeeContract } from "../src/FeeContract.sol";
import { Proxy, InitialImplementation } from "../src/proxy/Proxy.sol";
import { UUPSUpgradeable, ERC1967Utils } from "../src/proxy/UUPSUpgradeable.sol";

contract NoPayableRecipient { }

contract NewImplementation is UUPSUpgradeable {
    function _authorizeUpgrade(address) internal override { }
}

contract OwnableAndProxyTest is Test {
    address owner = makeAddr("owner");
    FeeContract feeContract;

    address wrappedNative = makeAddr("wrappedNative");

    Factory factory;

    bytes32 beaconProxyInitCodeHash;

    address logic;

    IERC20 mockERC20 = IERC20(address(deployMockERC20("mockERC20", "MockERC20", 18)));

    function setUp() external {
        startHoax(owner);
        feeContract = new FeeContract(owner);

        address factoryImplementation = address(new Factory(bytes("")));
        factory = Factory(payable(address(new Proxy())));

        InitialImplementation(address(factory)).upgradeTo(
            factoryImplementation, abi.encodeCall(Factory.initialize, (owner, new bytes[](0)))
        );
        vm.stopPrank();
    }

    // =========================
    // initializer
    // =========================

    function test_factory_disableInitializers(address newOwner) external {
        Factory factoryImplementation = new Factory(bytes(""));

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factoryImplementation.initialize(newOwner, new bytes[](0));
    }

    function test_factory_initialize_cannotBeInitializedAgain(address newOwner) external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.initialize(newOwner, new bytes[](0));
    }

    function test_factory_initialize_shouldInitializeContract(address newOwner) external {
        assumeNotZeroAddress(newOwner);

        Factory _factory = Factory(payable(address(new Proxy())));
        InitialImplementation(address(_factory)).upgradeTo(
            address(new Factory(bytes(""))), abi.encodeCall(Factory.initialize, (newOwner, new bytes[](0)))
        );
        assertEq(_factory.owner(), newOwner);
    }

    // =========================
    // ownable
    // =========================

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function test_factoryOwnable2Step_shouldRevertIfNotOwner(address notOwner) external {
        vm.assume(notOwner != owner);

        vm.startPrank(notOwner);

        vm.expectRevert(abi.encodeWithSelector(IOwnable.Ownable_SenderIsNotOwner.selector, notOwner));
        factory.renounceOwnership();

        vm.expectRevert(abi.encodeWithSelector(IOwnable.Ownable_SenderIsNotOwner.selector, notOwner));
        factory.transferOwnership(notOwner);

        vm.expectRevert(abi.encodeWithSelector(IOwnable.Ownable_SenderIsNotOwner.selector, notOwner));
        feeContract.changeProtocolFee(123);

        vm.expectRevert(abi.encodeWithSelector(IOwnable.Ownable_SenderIsNotOwner.selector, notOwner));
        feeContract.changeReferralFee(IFeeContract.ReferralFee({ protocolPart: 50, referralPart: 50 }));

        vm.expectRevert(abi.encodeWithSelector(IOwnable.Ownable_SenderIsNotOwner.selector, notOwner));
        feeContract.collectProtocolFees(address(0), address(1), 1);

        vm.expectRevert(abi.encodeWithSelector(IOwnable.Ownable_SenderIsNotOwner.selector, notOwner));
        feeContract.collectProtocolFees(address(0), address(1));

        vm.stopPrank();
    }

    function test_factoryOwnable2Step_renounceOwnership_shouldRenounceOwnership() external {
        assertEq(factory.owner(), owner);

        vm.prank(owner);
        vm.expectEmit();
        emit OwnershipTransferred(owner, address(0));
        factory.renounceOwnership();

        assertEq(factory.owner(), address(0));
    }

    function test_factoryOwnable2Step_transferOwnership_shouldRevertIfNewOwnerIsAddressZero() external {
        assertEq(factory.owner(), owner);

        vm.prank(owner);
        vm.expectRevert(IOwnable2Step.Ownable_NewOwnerCannotBeAddressZero.selector);
        factory.transferOwnership(address(0));
    }

    function test_factoryOwnable2Step_transferOwnership_shouldStartTransferOwnership(address newOwner) external {
        assumeNotZeroAddress(newOwner);

        assertEq(factory.owner(), owner);
        assertEq(factory.pendingOwner(), address(0));

        vm.prank(owner);
        vm.expectEmit();
        emit OwnershipTransferStarted(owner, newOwner);
        factory.transferOwnership(newOwner);

        assertEq(factory.owner(), owner);
        assertEq(factory.pendingOwner(), newOwner);
    }

    function test_factoryOwnable2Step_acceptOwnership_shouldRevertIfSenderIsNotPendingOwner(
        address pendingOwner,
        address notPendingOwner
    )
        external
    {
        vm.assume(pendingOwner != notPendingOwner);
        assumeNotZeroAddress(pendingOwner);

        assertEq(factory.owner(), owner);
        assertEq(factory.pendingOwner(), address(0));

        vm.prank(owner);
        vm.expectEmit();
        emit OwnershipTransferStarted(owner, pendingOwner);
        factory.transferOwnership(pendingOwner);

        assertEq(factory.owner(), owner);
        assertEq(factory.pendingOwner(), pendingOwner);

        vm.prank(notPendingOwner);
        vm.expectRevert(abi.encodeWithSelector(IOwnable2Step.Ownable_CallerIsNotTheNewOwner.selector, notPendingOwner));
        factory.acceptOwnership();
    }

    function test_factoryOwnable2Step_acceptOwnership_shouldTransferOwnership(address pendingOwner) external {
        assumeNotZeroAddress(pendingOwner);

        assertEq(factory.owner(), owner);
        assertEq(factory.pendingOwner(), address(0));

        vm.prank(owner);
        vm.expectEmit();
        emit OwnershipTransferStarted(owner, pendingOwner);
        factory.transferOwnership(pendingOwner);

        assertEq(factory.owner(), owner);
        assertEq(factory.pendingOwner(), pendingOwner);

        vm.prank(pendingOwner);
        vm.expectEmit();
        emit OwnershipTransferred(owner, pendingOwner);
        factory.acceptOwnership();

        assertEq(factory.owner(), pendingOwner);
        assertEq(factory.pendingOwner(), address(0));
    }

    // =========================
    // proxy
    // =========================

    function test_factory_upgradeImplementation_shouldRevertIfSenderIsNotOwner(address notOwner) external {
        vm.assume(owner != notOwner);

        address impl = address(new NewImplementation());

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(IOwnable.Ownable_SenderIsNotOwner.selector, notOwner));
        factory.upgradeTo(impl);
    }

    event Upgraded(address indexed implementation);

    function test_factory_upgradeImplementation_shouldUpgradeImplementation() external {
        address impl = address(new NewImplementation());

        vm.prank(owner);
        vm.expectEmit();
        emit Upgraded(impl);
        factory.upgradeTo(impl);

        address impl_ = address(uint160(uint256(vm.load(address(factory), ERC1967Utils.IMPLEMENTATION_SLOT))));

        assertEq(impl_, impl);
    }

    // =========================
    // changeFees
    // =========================

    function test_feeContract_changeFees_shouldRevertIfDataInvalid() external {
        vm.prank(owner);
        vm.expectRevert(IFeeContract.FeeContract_InvalidFeeValue.selector);
        feeContract.changeProtocolFee(10_001);

        vm.prank(owner);
        vm.expectRevert(IFeeContract.FeeContract_InvalidFeeValue.selector);
        feeContract.changeReferralFee(IFeeContract.ReferralFee({ protocolPart: 300, referralPart: 1 }));
    }

    function test_feeContract_changeFees_shouldSuccessfulChangeFees(
        uint256 newPotocolFee,
        IFeeContract.ReferralFee memory newReferralFee
    )
        external
    {
        newPotocolFee = bound(newPotocolFee, 300, 10_000);
        newReferralFee.protocolPart = bound(newReferralFee.protocolPart, 10, 200);
        newReferralFee.referralPart = bound(newReferralFee.referralPart, 10, 50);

        vm.startPrank(owner);
        feeContract.changeProtocolFee(newPotocolFee);
        feeContract.changeReferralFee(newReferralFee);

        (uint256 protocolFee, IFeeContract.ReferralFee memory referralFee) = feeContract.fees();

        assertEq(protocolFee, newPotocolFee);
        assertEq(referralFee.protocolPart, newReferralFee.protocolPart);
        assertEq(referralFee.referralPart, newReferralFee.referralPart);
    }
}
