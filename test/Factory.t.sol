// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { Proxy, InitialImplementation } from "../src/proxy/Proxy.sol";
import { Factory, IFactory } from "../src/Factory.sol";

import { DeployEngine } from "../script/DeployEngine.sol";
import { Solarray } from "solarray/Solarray.sol";

import { Initializable } from "../src/proxy/Initializable.sol";

contract Component1 {
    struct ComponentStorage {
        uint256 value;
    }

    bytes32 internal constant STORAGE_POINTER = keccak256("component1");

    function _getLocalStorage() internal pure returns (ComponentStorage storage s) {
        bytes32 pointer = STORAGE_POINTER;
        assembly ("memory-safe") {
            s.slot := pointer
        }
    }

    function getValue1() external view returns (uint256) {
        return _getLocalStorage().value;
    }

    function setValue1(uint256 value) external {
        _getLocalStorage().value = value;
    }

    function revertMethod() external pure {
        revert("revert method");
    }
}

contract Component2 {
    struct ComponentStorage {
        uint256 value;
        uint256 value2;
    }

    bytes32 internal constant STORAGE_POINTER = keccak256("component2");

    function _getLocalStorage() internal pure returns (ComponentStorage storage s) {
        bytes32 pointer = STORAGE_POINTER;
        assembly ("memory-safe") {
            s.slot := pointer
        }
    }

    function getValue2() external view returns (uint256) {
        return _getLocalStorage().value;
    }

    function setValue2(uint256 value) external {
        _getLocalStorage().value = value;
    }

    function getValue3() external view returns (uint256) {
        return _getLocalStorage().value2;
    }

    function setValue3(uint256 value) external {
        _getLocalStorage().value2 = value;
    }
}

contract FactoryTest is Test {
    Factory factory;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    address component1;
    address component2;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl("bsc"));

        startHoax(owner);

        component1 = address(new Component1());
        component2 = address(new Component2());

        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = Component1.getValue1.selector;
        selectors[1] = Component1.setValue1.selector;
        selectors[2] = Component1.revertMethod.selector;
        selectors[3] = Component2.getValue2.selector;
        selectors[4] = Component2.setValue2.selector;
        selectors[5] = Component2.getValue3.selector;
        selectors[6] = Component2.setValue3.selector;

        address factoryImplementation = address(
            new Factory(
                DeployEngine.getBytesArray(
                    selectors, Solarray.addresses(component1, component1, component1, component2, component2, component2, component2)
                )
            )
        );

        factory = Factory(payable(address(new Proxy(owner))));

        InitialImplementation(address(factory)).upgradeTo(
            factoryImplementation, abi.encodeCall(Factory.initialize, (owner, new bytes[](0)))
        );

        vm.stopPrank();
    }

    // =========================
    // constructor and initializer
    // =========================

    event Initialized(uint8 version);

    function test_enrtryPoint_constructor_shouldDisavbleInitializers() external {
        vm.expectEmit();
        emit Initialized(255);
        Factory _factory = new Factory(bytes(""));

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _factory.initialize(owner, new bytes[](0));
    }

    function test_factory_initialize_shouldInitializeWithNewOwnerAndCallInitialCalls() external {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = Component1.getValue1.selector;
        selectors[1] = Component1.setValue1.selector;
        selectors[2] = Component2.getValue2.selector;
        selectors[3] = Component2.setValue2.selector;
        selectors[4] = Component2.getValue3.selector;
        selectors[5] = Component2.setValue3.selector;

        address factoryImplementation = address(
            new Factory(
                DeployEngine.getBytesArray(
                    selectors, Solarray.addresses(component1, component1, component2, component2, component2, component2)
                )
            )
        );

        InitialImplementation proxy = InitialImplementation(address(new Proxy(owner)));

        hoax(owner);
        vm.expectEmit();
        emit Initialized(1);
        proxy.upgradeTo(
            factoryImplementation,
            abi.encodeCall(
                Factory.initialize,
                (
                    owner,
                    Solarray.bytess(
                        abi.encodeCall(Component1.setValue1, (1)),
                        abi.encodeCall(Component2.setValue2, (2)),
                        abi.encodeCall(Component2.setValue3, (3))
                    )
                )
            )
        );

        assertEq(Factory(payable(address(proxy))).owner(), owner);
        assertEq(Component1(address(proxy)).getValue1(), 1);
        assertEq(Component2(address(proxy)).getValue2(), 2);
        assertEq(Component2(address(proxy)).getValue3(), 3);
    }

    // =========================
    // empty components and selectors
    // =========================

    function test_factory_shouldRevertIfNoComponentsAndSelectors() external {
        address factoryImplementation = address(new Factory(bytes("")));

        InitialImplementation proxy = InitialImplementation(payable(address(new Proxy(owner))));

        hoax(owner);
        proxy.upgradeTo(factoryImplementation, abi.encodeCall(Factory.initialize, (owner, new bytes[](0))));

        vm.expectRevert(
            abi.encodeWithSelector(IFactory.Factory_FunctionDoesNotExist.selector, Component1.setValue1.selector)
        );
        Component1(address(proxy)).setValue1(1);

        vm.expectRevert(abi.encodeWithSelector(IFactory.Factory_FunctionDoesNotExist.selector, bytes4(0x000000)));
        Factory(payable(address(proxy))).multicall(
            Solarray.bytess(abi.encodeCall(Component1.setValue1, (1)), abi.encodeCall(Component2.setValue2, (2)))
        );

        vm.expectRevert(abi.encodeWithSelector(IFactory.Factory_FunctionDoesNotExist.selector, bytes4(0x000000)));
        Factory(payable(address(proxy))).multicall(
            bytes32(0), Solarray.bytess(abi.encodeCall(Component1.setValue1, (1)), abi.encodeCall(Component2.setValue2, (2)))
        );
    }

    // =========================
    // multicall
    // =========================

    function test_factory_multicall_shouldCallSeveralMethodsInOneTx(uint256 value1, uint256 value2) external {
        factory.multicall(
            Solarray.bytess(abi.encodeCall(Component1.setValue1, (value1)), abi.encodeCall(Component2.setValue2, (value2)))
        );

        assertEq(Component1(address(factory)).getValue1(), value1);
        assertEq(Component2(address(factory)).getValue2(), value2);
    }

    function test_factory_multicall_shouldRevertIfSelectorDoesNotExists() external {
        vm.expectRevert(
            abi.encodeWithSelector(IFactory.Factory_FunctionDoesNotExist.selector, bytes4(0x11223344))
        );
        factory.multicall(
            Solarray.bytess(abi.encodeWithSelector(Component1.setValue1.selector, 1), abi.encodeWithSelector(0x11223344, 2))
        );

        vm.expectRevert(
            abi.encodeWithSelector(IFactory.Factory_FunctionDoesNotExist.selector, bytes4(0x11223344))
        );
        factory.multicall(
            Solarray.bytess(abi.encodeWithSelector(0x11223344, 1), abi.encodeWithSelector(Component2.setValue2.selector, 2))
        );
    }

    function test_factory_multicall_shouldRevertIfOneMethodReverts() external {
        vm.expectRevert("revert method");
        factory.multicall(
            Solarray.bytess(
                abi.encodeWithSelector(Component1.revertMethod.selector),
                abi.encodeWithSelector(Component1.setValue1.selector, 1)
            )
        );

        vm.expectRevert("revert method");
        factory.multicall(
            Solarray.bytess(
                abi.encodeWithSelector(Component1.setValue1.selector, 1),
                abi.encodeWithSelector(Component1.revertMethod.selector)
            )
        );
    }

    // =========================
    // multicall with replace
    // =========================

    function test_factory_multicallWithReplace_shouldCallSeveralMethodsInOneTx(
        uint256 value1,
        uint256 value2
    )
        external
    {
        Component1(address(factory)).setValue1(value1);
        Component2(address(factory)).setValue3(value2);

        factory.multicall(
            0x0000000000000000000000000000000000000000000000000000000400000004,
            Solarray.bytess(
                abi.encodeCall(Component1.getValue1, ()),
                abi.encodeCall(Component2.setValue2, (0)),
                abi.encodeCall(Component2.getValue3, ()),
                abi.encodeCall(Component1.setValue1, (0))
            )
        );

        assertEq(Component1(address(factory)).getValue1(), value2);
        assertEq(Component2(address(factory)).getValue2(), value1);
    }

    // =========================
    // fallback
    // =========================

    function test_factory_fallback_shouldRevertIfComponentDoesNotExists() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IFactory.Factory_FunctionDoesNotExist.selector, InitialImplementation.upgradeTo.selector
            )
        );
        InitialImplementation(address(factory)).upgradeTo(address(0), bytes(""));
    }
}
