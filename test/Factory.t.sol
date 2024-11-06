// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { Proxy, InitialImplementation } from "../src/proxy/Proxy.sol";
import { Factory, IFactory } from "../src/Factory.sol";

import { DeployEngine } from "../script/DeployEngine.sol";

import { Initializable } from "../src/proxy/Initializable.sol";

import { BaseTest, Solarray } from "./BaseTest.t.sol";

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

contract FactoryTest is BaseTest {
    address component1;
    address component2;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl("bsc"));

        _createUsers();

        _resetPrank(owner);

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
            new Factory({
                componentsAndSelectors: DeployEngine.getBytesArray({
                    selectors: selectors,
                    addressIndexes: Solarray.uint256s(0, 0, 0, 1, 1, 1, 1),
                    componentAddresses: Solarray.addresses(component1, component2)
                })
            })
        );

        factory = Factory(payable(address(new Proxy({ initialOwner: owner }))));

        InitialImplementation(address(factory)).upgradeTo({
            implementation: factoryImplementation,
            data: abi.encodeCall(Factory.initialize, (owner, new bytes[](0)))
        });
    }

    // =========================
    // constructor and initializer
    // =========================

    event Initialized(uint8 version);

    function test_enrtryPoint_constructor_shouldDisavbleInitializers() external {
        _resetPrank(owner);

        vm.expectEmit();
        emit Initialized({ version: 255 });
        Factory _factory = new Factory({ componentsAndSelectors: bytes("") });

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        _factory.initialize({ newOwner: owner, initialCalls: new bytes[](0) });
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
            new Factory({
                componentsAndSelectors: DeployEngine.getBytesArray({
                    selectors: selectors,
                    addressIndexes: Solarray.uint256s(0, 0, 1, 1, 1, 1),
                    componentAddresses: Solarray.addresses(component1, component2)
                })
            })
        );

        InitialImplementation proxy = InitialImplementation(address(new Proxy({ initialOwner: owner })));

        _resetPrank(owner);

        vm.expectEmit();
        emit Initialized({ version: 1 });
        proxy.upgradeTo({
            implementation: factoryImplementation,
            data: abi.encodeCall(
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
        });

        assertEq(Factory(payable(address(proxy))).owner(), owner);
        assertEq(Component1(address(proxy)).getValue1(), 1);
        assertEq(Component2(address(proxy)).getValue2(), 2);
        assertEq(Component2(address(proxy)).getValue3(), 3);
    }

    // =========================
    // empty components and selectors
    // =========================

    function test_factory_shouldRevertIfNoComponentsAndSelectors() external {
        address factoryImplementation = address(new Factory({ componentsAndSelectors: bytes("") }));

        InitialImplementation proxy = InitialImplementation(payable(address(new Proxy({ initialOwner: owner }))));

        _resetPrank(owner);

        proxy.upgradeTo({
            implementation: factoryImplementation,
            data: abi.encodeCall(Factory.initialize, (owner, new bytes[](0)))
        });

        vm.expectRevert(
            abi.encodeWithSelector(IFactory.Factory_FunctionDoesNotExist.selector, Component1.setValue1.selector)
        );
        Component1(address(proxy)).setValue1({ value: 1 });

        vm.expectRevert(abi.encodeWithSelector(IFactory.Factory_FunctionDoesNotExist.selector, bytes4(0x000000)));
        Factory(payable(address(proxy))).multicall({
            data: Solarray.bytess(abi.encodeCall(Component1.setValue1, (1)), abi.encodeCall(Component2.setValue2, (2)))
        });

        vm.expectRevert(abi.encodeWithSelector(IFactory.Factory_FunctionDoesNotExist.selector, bytes4(0x000000)));
        Factory(payable(address(proxy))).multicall({
            replace: bytes32(0),
            data: Solarray.bytess(abi.encodeCall(Component1.setValue1, (1)), abi.encodeCall(Component2.setValue2, (2)))
        });
    }

    // =========================
    // multicall
    // =========================

    function test_factory_multicall_shouldCallSeveralMethodsInOneTx(uint256 value1, uint256 value2) external {
        factory.multicall({
            data: Solarray.bytess(abi.encodeCall(Component1.setValue1, (value1)), abi.encodeCall(Component2.setValue2, (value2)))
        });

        assertEq(Component1(address(factory)).getValue1(), value1);
        assertEq(Component2(address(factory)).getValue2(), value2);
    }

    function test_factory_multicall_shouldRevertIfSelectorDoesNotExists() external {
        vm.expectRevert(
            abi.encodeWithSelector(IFactory.Factory_FunctionDoesNotExist.selector, bytes4(0x11223344))
        );
        factory.multicall({
            data: Solarray.bytess(
                abi.encodeWithSelector(Component1.setValue1.selector, 1), abi.encodeWithSelector(0x11223344, 2)
            )
        });

        vm.expectRevert(
            abi.encodeWithSelector(IFactory.Factory_FunctionDoesNotExist.selector, bytes4(0x11223344))
        );
        factory.multicall({
            data: Solarray.bytess(
                abi.encodeWithSelector(0x11223344, 1), abi.encodeWithSelector(Component2.setValue2.selector, 2)
            )
        });
    }

    function test_factory_multicall_shouldRevertIfOneMethodReverts() external {
        vm.expectRevert("revert method");
        factory.multicall({
            data: Solarray.bytess(
                abi.encodeWithSelector(Component1.revertMethod.selector), abi.encodeWithSelector(Component1.setValue1.selector, 1)
            )
        });

        vm.expectRevert("revert method");
        factory.multicall({
            data: Solarray.bytess(
                abi.encodeWithSelector(Component1.setValue1.selector, 1), abi.encodeWithSelector(Component1.revertMethod.selector)
            )
        });
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
        Component1(address(factory)).setValue1({ value: value1 });
        Component2(address(factory)).setValue3({ value: value2 });

        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000400000004,
            data: Solarray.bytess(
                abi.encodeCall(Component1.getValue1, ()),
                abi.encodeCall(Component2.setValue2, (0)),
                abi.encodeCall(Component2.getValue3, ()),
                abi.encodeCall(Component1.setValue1, (0))
            )
        });

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
        InitialImplementation(address(factory)).upgradeTo({ implementation: address(0), data: bytes("") });
    }

    // =========================
    // diamond getters
    // =========================

    function test_factory_components_diamondGetters() external view {
        assertEq(factory.componentAddress({ functionSelector: Component1.setValue1.selector }), address(component1));
        assertEq(factory.componentAddress({ functionSelector: Component2.setValue2.selector }), address(component2));

        address[] memory _components = factory.componentAddresses();

        assertEq(_components.length, 2);
        assertEq(_components[0], address(component1));
        assertEq(_components[1], address(component2));

        bytes4[] memory componentFunctionSelectors = factory.componentFunctionSelectors({ component: _components[0] });
        bytes4[] memory component1FunctionSelectorsExpected =
            Solarray.bytes4s(Component1.setValue1.selector, Component1.getValue1.selector, Component1.revertMethod.selector);

        for (uint256 i; i < componentFunctionSelectors.length; ++i) {
            _assertEqual(componentFunctionSelectors[i], component1FunctionSelectorsExpected);
        }

        componentFunctionSelectors = factory.componentFunctionSelectors({ component: _components[1] });
        bytes4[] memory component2FunctionSelectorsExpected = Solarray.bytes4s(
            Component2.setValue2.selector, Component2.getValue2.selector, Component2.setValue3.selector, Component2.getValue3.selector
        );

        for (uint256 i; i < componentFunctionSelectors.length; ++i) {
            _assertEqual(componentFunctionSelectors[i], component2FunctionSelectorsExpected);
        }

        IFactory.Component[] memory components = factory.components();

        assertEq(components.length, 2);
        assertEq(components[0].component, address(component1));
        assertEq(components[0].functionSelectors.length, 3);
        for (uint256 i; i < components[0].functionSelectors.length; ++i) {
            _assertEqual(components[0].functionSelectors[i], component1FunctionSelectorsExpected);
        }

        assertEq(components[1].component, address(component2));
        assertEq(components[1].functionSelectors.length, 4);
        for (uint256 i; i < components[1].functionSelectors.length; ++i) {
            _assertEqual(components[1].functionSelectors[i], component2FunctionSelectorsExpected);
        }
    }
}
