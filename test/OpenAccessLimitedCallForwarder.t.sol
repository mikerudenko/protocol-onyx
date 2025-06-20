// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {OpenAccessLimitedCallForwarder} from "src/components/roles/OpenAccessLimitedCallForwarder.sol";
import {ComponentHelpersMixin} from "src/components/utils/ComponentHelpersMixin.sol";
import {Shares} from "src/shares/Shares.sol";

import {OpenAccessLimitedCallForwarderHarness} from "test/harnesses/OpenAccessLimitedCallForwarderHarness.sol";
import {TestHelpers} from "test/utils/TestHelpers.sol";

contract OpenAccessLimitedCallForwarderTest is TestHelpers {
    Shares shares;
    address owner;

    OpenAccessLimitedCallForwarderHarness callForwarder;
    CallTarget callTarget;
    bytes4 callSelector = CallTarget.foo.selector;

    function setUp() public {
        shares = createShares();
        owner = shares.owner();

        callForwarder = new OpenAccessLimitedCallForwarderHarness({_shares: address(shares)});

        callTarget = new CallTarget();
    }

    //==================================================================================================================
    // Config (access: admin or owner)
    //==================================================================================================================

    function test_addCall_fail_alreadyRegistered() public {
        vm.prank(owner);
        callForwarder.addCall({_target: address(callTarget), _selector: callSelector});

        vm.expectRevert(OpenAccessLimitedCallForwarder.OpenAccessLimitedCallForwarder__AddCall__AlreadyAdded.selector);

        // fails upon adding the same call
        vm.prank(owner);
        callForwarder.addCall({_target: address(callTarget), _selector: callSelector});
    }

    function test_addCall_fail_unauthorized() public {
        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        callForwarder.addCall({_target: address(callTarget), _selector: callSelector});
    }

    function test_addCall_success() public {
        assertFalse(callForwarder.canCall({_target: address(callTarget), _selector: callSelector}));

        vm.expectEmit();
        emit OpenAccessLimitedCallForwarder.CallAdded({target: address(callTarget), selector: callSelector});

        vm.prank(owner);
        callForwarder.addCall({_target: address(callTarget), _selector: callSelector});

        assertTrue(callForwarder.canCall({_target: address(callTarget), _selector: callSelector}));
    }

    function test_removeCall_fail_notRegistered() public {
        vm.expectRevert(OpenAccessLimitedCallForwarder.OpenAccessLimitedCallForwarder__RemoveCall__NotAdded.selector);

        vm.prank(owner);
        callForwarder.removeCall({_target: address(callTarget), _selector: callSelector});
    }

    function test_removeCall_fail_unauthorized() public {
        vm.expectRevert(ComponentHelpersMixin.ComponentHelpersMixin__OnlyAdminOrOwner__Unauthorized.selector);

        callForwarder.removeCall({_target: address(callTarget), _selector: callSelector});
    }

    function test_removeCall_success() public {
        vm.prank(owner);
        callForwarder.addCall({_target: address(callTarget), _selector: callSelector});

        assertTrue(callForwarder.canCall({_target: address(callTarget), _selector: callSelector}));

        vm.expectEmit();
        emit OpenAccessLimitedCallForwarder.CallRemoved({target: address(callTarget), selector: callSelector});

        vm.prank(owner);
        callForwarder.removeCall({_target: address(callTarget), _selector: callSelector});

        assertFalse(callForwarder.canCall({_target: address(callTarget), _selector: callSelector}));
    }

    //==================================================================================================================
    // Calls
    //==================================================================================================================

    function test_executeCall_fail_unregisteredCall() public {
        // do not register call

        vm.expectRevert(
            OpenAccessLimitedCallForwarder.OpenAccessLimitedCallForwarder__ExecuteCall__UnauthorizedCall.selector
        );

        callForwarder.executeCall({_target: address(callTarget), _data: abi.encodeWithSelector(CallTarget.foo.selector)});
    }

    function test_executeCall_success() public {
        address caller = makeAddr("caller");

        assertFalse(callTarget.called());

        // register call
        vm.prank(owner);
        callForwarder.addCall({_target: address(callTarget), _selector: callSelector});

        // pre-assert event
        vm.expectEmit();
        emit OpenAccessLimitedCallForwarder.CallExecuted({
            sender: caller,
            target: address(callTarget),
            data: abi.encodeWithSelector(callSelector),
            value: 0
        });

        // call
        vm.prank(caller);
        callForwarder.executeCall({_target: address(callTarget), _data: abi.encodeWithSelector(CallTarget.foo.selector)});

        assertTrue(callTarget.called());
    }
}

contract CallTarget {
    bool public called;

    function foo() external {
        called = true;
    }
}
