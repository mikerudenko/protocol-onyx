// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

// Targets
// NOTE: Always import and apply them in alphabetical order, so much easier to debug!
import { AdminTargets } from "./targets/AdminTargets.sol";
import { DoomsdayTargets } from "./targets/DoomsdayTargets.sol";
import { FeeTargets } from "./targets/FeeTargets.sol";
import { IssuanceTargets } from "./targets/IssuanceTargets.sol";
import { ManagersTargets } from "./targets/ManagersTargets.sol";
import { SharesTargets } from "./targets/SharesTargets.sol";
import { ValuationTargets } from "./targets/ValuationTargets.sol";

abstract contract TargetFunctions is
    AdminTargets,
    DoomsdayTargets,
    FeeTargets,
    IssuanceTargets,
    ManagersTargets,
    SharesTargets,
    ValuationTargets
{


    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///
}
