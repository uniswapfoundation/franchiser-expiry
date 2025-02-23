// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {VotingTokenConcrete} from "./VotingTokenConcrete.sol";
import {FranchiserExpiryFactory} from "../src/FranchiserExpiryFactory.sol";
import {FranchiserLens} from "../src/FranchiserLens.sol";
import {IVotingToken} from "../src/interfaces/IVotingToken.sol";
import {Franchiser} from "../src/Franchiser.sol";
import {IFranchiserLens} from "../src/interfaces/IFranchiserLens.sol";
import {Utils} from "./Utils.sol";

contract FranchiserLensTest is Test {
    VotingTokenConcrete private votingToken;
    FranchiserExpiryFactory private franchiserFactory;
    FranchiserLens private franchiserLens;

    uint safeFutureExpiration = block.timestamp + 1 weeks;

    function setUp() public {
        votingToken = new VotingTokenConcrete();
        franchiserFactory = new FranchiserExpiryFactory(
            IVotingToken(address(votingToken))
        );
        franchiserLens = new FranchiserLens(
            IVotingToken(address(votingToken)),
            franchiserFactory
        );
    }

    function testSetUp() public {
        assertEq(
            address(franchiserLens.franchiserFactory()),
            address(franchiserFactory)
        );
    }

    function testNesting1() public {
        Franchiser[5] memory franchisers = Utils.nestVertical(
            1,
            vm,
            votingToken,
            franchiserFactory,
            safeFutureExpiration
        );

        IFranchiserLens.Delegation memory rootDelegation = franchiserLens
            .getRootDelegation(franchisers[0]);
        assertEq(rootDelegation.delegator, Utils.alice);
        assertEq(rootDelegation.delegatee, Utils.bob);
        assertEq(address(rootDelegation.franchiser), address(franchisers[0]));

        IFranchiserLens.Delegation[] memory verticalDelegations = franchiserLens
            .getVerticalDelegations(franchisers[0]);
        assertEq(verticalDelegations.length, 1);
        assertEq(
            keccak256(abi.encode(verticalDelegations[0])),
            keccak256(abi.encode(rootDelegation))
        );

        IFranchiserLens.Delegation[]
            memory horizontalDelegations = franchiserLens
                .getHorizontalDelegations(franchisers[0]);
        assertEq(horizontalDelegations.length, 0);
    }

    function testNesting2() public {
        Franchiser[5] memory franchisers = Utils.nestVertical(
            2,
            vm,
            votingToken,
            franchiserFactory,
            safeFutureExpiration
        );

        IFranchiserLens.Delegation memory rootDelegation = franchiserLens
            .getRootDelegation(franchisers[0]);
        assertEq(rootDelegation.delegator, Utils.alice);
        assertEq(rootDelegation.delegatee, Utils.bob);
        assertEq(address(rootDelegation.franchiser), address(franchisers[0]));

        IFranchiserLens.Delegation[] memory verticalDelegations = franchiserLens
            .getVerticalDelegations(franchisers[1]);
        assertEq(verticalDelegations.length, 2);
        assertEq(verticalDelegations[1].delegator, Utils.bob);
        assertEq(verticalDelegations[1].delegatee, Utils.carol);
        assertEq(
            address(verticalDelegations[1].franchiser),
            address(franchisers[1])
        );
        assertEq(
            keccak256(abi.encode(verticalDelegations[0])),
            keccak256(abi.encode(rootDelegation))
        );

        IFranchiserLens.Delegation[]
            memory horizontalDelegations = franchiserLens
                .getHorizontalDelegations(franchisers[0]);
        assertEq(horizontalDelegations.length, 1);
        assertEq(horizontalDelegations[0].delegator, Utils.bob);
        assertEq(horizontalDelegations[0].delegatee, Utils.carol);
        assertEq(
            address(horizontalDelegations[0].franchiser),
            address(franchisers[1])
        );
    }

    function testNesting5() public {
        Franchiser[5] memory franchisers = Utils.nestVertical(
            5,
            vm,
            votingToken,
            franchiserFactory,
            safeFutureExpiration
        );

        IFranchiserLens.Delegation memory rootDelegation = franchiserLens
            .getRootDelegation(franchisers[0]);
        assertEq(rootDelegation.delegator, Utils.alice);
        assertEq(rootDelegation.delegatee, Utils.bob);
        assertEq(address(rootDelegation.franchiser), address(franchisers[0]));

        IFranchiserLens.Delegation[]
            memory verticalDelegations = new IFranchiserLens.Delegation[](5);
        verticalDelegations[0] = IFranchiserLens.Delegation({
            delegator: Utils.alice,
            delegatee: Utils.bob,
            franchiser: franchisers[0]
        });
        verticalDelegations[1] = IFranchiserLens.Delegation({
            delegator: Utils.bob,
            delegatee: Utils.carol,
            franchiser: franchisers[1]
        });
        verticalDelegations[2] = IFranchiserLens.Delegation({
            delegator: Utils.carol,
            delegatee: Utils.dave,
            franchiser: franchisers[2]
        });
        verticalDelegations[3] = IFranchiserLens.Delegation({
            delegator: Utils.dave,
            delegatee: Utils.erin,
            franchiser: franchisers[3]
        });
        verticalDelegations[4] = IFranchiserLens.Delegation({
            delegator: Utils.erin,
            delegatee: Utils.frank,
            franchiser: franchisers[4]
        });
        assertEq(
            keccak256(
                abi.encode(
                    franchiserLens.getVerticalDelegations(
                        franchisers[franchisers.length - 1]
                    )
                )
            ),
            keccak256(abi.encode(verticalDelegations))
        );

        unchecked {
            for (uint256 i; i < 4; i++) {
                IFranchiserLens.Delegation[]
                    memory horizontalDelegations = franchiserLens
                        .getHorizontalDelegations(franchisers[i]);
                assertEq(horizontalDelegations.length, 1);
                assertEq(
                    address(horizontalDelegations[0].franchiser),
                    address(franchisers[i + 1])
                );
            }
        }
    }

    function testGetAllDelegations() public {
        Franchiser[][5] memory franchisers = Utils.nestMaximum(
            vm,
            votingToken,
            franchiserFactory,
            safeFutureExpiration
        );

        IFranchiserLens.DelegationWithVotes[][]
            memory delegationsWithVotes = franchiserLens.getAllDelegations(
                franchisers[0][0]
            );
        assertEq(delegationsWithVotes.length, 5);
        assertEq(delegationsWithVotes[0].length, 1);
        assertEq(delegationsWithVotes[1].length, 8);
        assertEq(delegationsWithVotes[2].length, 32);
        assertEq(delegationsWithVotes[3].length, 64);
        assertEq(delegationsWithVotes[4].length, 64);

        assertEq(delegationsWithVotes[0][0].delegator, address(1));
        assertEq(delegationsWithVotes[0][0].delegatee, address(2));

        unchecked {
            for (uint256 i; i < delegationsWithVotes.length; i++)
                for (uint256 j; j < delegationsWithVotes[i].length; j++) {
                    assertEq(
                        address(delegationsWithVotes[i][j].franchiser),
                        address(franchisers[i][j])
                    );
                    assertEq(delegationsWithVotes[i][j].votes, i == 4 ? 1 : 0);
                }
        }
    }
}
