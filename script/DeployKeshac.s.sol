// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {KeshacAccount} from "src/KeshacAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployKeshac is Script {
    function deployKeshacAccount()
        public
        returns (HelperConfig, KeshacAccount)
    {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        KeshacAccount keshacAccount = new KeshacAccount(config.entryPoint);
        keshacAccount.transferOwnership(config.account);
        vm.stopBroadcast();
        return (helperConfig, keshacAccount);
    }
}
