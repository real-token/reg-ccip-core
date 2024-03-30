// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";

contract RouterMock {
    function ccipReceive(
        Client.Any2EVMMessage calldata message,
        address ccipReceiver
    ) external {
        IAny2EVMMessageReceiver(ccipReceiver).ccipReceive(message);
    }
}
