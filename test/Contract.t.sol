// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./contracts/BlockchainInvaders.sol";
import "./contracts/InvaderMarketplace.sol";
import "./contracts/Space.sol";
import {Utils} from "./utils/Utils.sol";

contract BaseSetup is Test {

    BlockchainInvaders internal blockchainInvaders;
    InvaderMarketplace internal invaderMarketplace;
    Space internal space;

    Utils internal utils;
    address payable[] internal users;

    address internal alice;
    address internal bob;
    address internal carol;

    struct MarketplaceItem {
        uint itemId;
        address nftContract;
        uint256 nftId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
        bool forSale;
    }

    MarketplaceItem[] internal items;

    function setUp() public virtual {
        space = new Space();
        invaderMarketplace = new InvaderMarketplace(address(space));
        blockchainInvaders = new BlockchainInvaders('https://gateway.pinata.cloud/ipfs/QmWntKmANjGoq3LSP24b6nAnf4gBTyk1gfjEWaG1Ps6Sjs/');
        blockchainInvaders.flipPublicSaleState();
        
        utils = new Utils();
        users = utils.createUsers(3);

        alice = users[0];
        vm.label(alice, "Alice");
        bob = users[1];
        vm.label(bob, "Bob");
        carol = users[2];
        vm.label(carol, "Carol");
    }

 
}

contract AliceMintedAndBobHasTokens is BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
        vm.startPrank(alice);
        blockchainInvaders.publicMint();
        blockchainInvaders.setApprovalForAll(address(invaderMarketplace), true);
        vm.stopPrank();
        space.rewardMint(address(bob), 1000 ether);
        space.rewardMint(address(carol), 1000 ether);
        space.rewardMint(address(alice), 1000 ether);
    }

    function testBobsTokens() public {
        assertEq(space.balanceOf(address(bob)), 1000 ether);
    }

    function testAliceListing() public {     
        vm.startPrank(alice);
        invaderMarketplace.listNFT(address(blockchainInvaders), 0, 20);
        assertEq(invaderMarketplace.listedItems(), 1);
        vm.stopPrank();
    }

    function testBobBuys() public {
        vm.prank(alice);
        invaderMarketplace.listNFT(address(blockchainInvaders), 0, 20 ether);
        vm.startPrank(bob);
        space.approve(address(invaderMarketplace), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        invaderMarketplace.buyNFT(address(blockchainInvaders), 1);
        assertEq(space.balanceOf(bob), 980 ether);
        assertEq(space.balanceOf(alice), 1020 ether);
        assertEq(blockchainInvaders.balanceOf(bob), 1);
        assertEq(blockchainInvaders.balanceOf(alice), 0);
        assertEq(blockchainInvaders.ownerOf(0), bob);
        vm.stopPrank();
    }

    function testCannotBuyInsufficientBalance() public {
        vm.prank(alice);
        invaderMarketplace.listNFT(address(blockchainInvaders), 0, 1001 ether);
        vm.startPrank(bob);
        space.approve(address(invaderMarketplace), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

        vm.expectRevert(stdError.arithmeticError);
        invaderMarketplace.buyNFT(address(blockchainInvaders), 1);

        vm.stopPrank();
    }

    function testCannotBuysUnlistedNFT() public {
        vm.prank(alice);
        invaderMarketplace.listNFT(address(blockchainInvaders), 0, 20 ether);
        vm.startPrank(bob);
        space.approve(address(invaderMarketplace), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        vm.expectRevert(abi.encodeWithSignature('ItemNotListed()'));
        invaderMarketplace.buyNFT(address(blockchainInvaders), 52);  
        vm.stopPrank();
    }

    function testCannotBuyAfterListingSold() public {
        vm.prank(alice);
        invaderMarketplace.listNFT(address(blockchainInvaders), 0, 20 ether);
        vm.startPrank(bob);
        space.approve(address(invaderMarketplace), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        invaderMarketplace.buyNFT(address(blockchainInvaders), 1);
        vm.stopPrank();
        vm.startPrank(carol);
        space.approve(address(invaderMarketplace), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        vm.expectRevert(abi.encodeWithSignature('ItemUnavailable()'));
        invaderMarketplace.buyNFT(address(blockchainInvaders), 1);
        vm.stopPrank();
    }

    function testCannotBuyAfterDelist() public {
        vm.startPrank(alice);
        invaderMarketplace.listNFT(address(blockchainInvaders), 0, 20 ether);
        invaderMarketplace.delistNFT(1);
        vm.stopPrank();
        vm.startPrank(bob);
        space.approve(address(invaderMarketplace), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        vm.expectRevert(abi.encodeWithSignature('ItemDelisted()'));
        invaderMarketplace.buyNFT(address(blockchainInvaders), 1);
        vm.stopPrank();
    }

    function testGetListedItems() public {
        vm.startPrank(bob);
        blockchainInvaders.publicMint();
        blockchainInvaders.setApprovalForAll(address(invaderMarketplace), true);
        invaderMarketplace.listNFT(address(blockchainInvaders), 1, 20 ether);
        vm.stopPrank();
        vm.startPrank(carol);
        blockchainInvaders.publicMint();
        blockchainInvaders.setApprovalForAll(address(invaderMarketplace), true);
        invaderMarketplace.listNFT(address(blockchainInvaders), 2, 20 ether);
        vm.stopPrank();
        vm.startPrank(alice);
        invaderMarketplace.listNFT(address(blockchainInvaders), 0, 20 ether);
        invaderMarketplace.getListedItems();


        space.approve(address(invaderMarketplace), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        invaderMarketplace.buyNFT(address(blockchainInvaders), 1);
        invaderMarketplace.buyNFT(address(blockchainInvaders), 2);
        invaderMarketplace.buyNFT(address(blockchainInvaders), 3);
        invaderMarketplace.getListedItems();

        invaderMarketplace.listNFT(address(blockchainInvaders), 0, 20 ether);
        invaderMarketplace.listNFT(address(blockchainInvaders), 1, 20 ether);

        invaderMarketplace.getListedItems();
    }
}

