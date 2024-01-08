//@ts-nocheck
import dotenv from "dotenv"
import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers"
import { expect } from "chai"
import hre from "hardhat"
import { getAddress, parseGwei, parseUnits } from "viem"

dotenv.config()

describe("SingleSidedLiquidity", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    // Contracts are deployed using the first signer/account by default
    const [user] = await hre.viem.getWalletClients()

    // @ts-ignore
    const ssl = await hre.viem.deployContract("SingleSidedLiquidity", [
      process.env.UNISWAP_FACTORY,
      process.env.WETH9,
    ])

    const publicClient = await hre.viem.getPublicClient()

    const wmatic = await hre.viem.getContractAt(
      "WMATIC",
      "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
      { walletClient: user }
    )
    const usdc = await hre.viem.getContractAt(
      "FiatTokenV2_2",
      "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359",
      { walletClient: user }
    )
    return {
      ssl,
      wmatic,
      usdc,
      user,
      publicClient,
    }
  }

  describe("Deployment", function () {
    it("Should deposit t0", async function () {
      const { ssl, wmatic, usdc } = await loadFixture(deployFixture)

      await wmatic.write.approve([ssl.address, parseUnits("1", 18)])

      expect(
        await ssl.write.deposit([
          wmatic.address,
          usdc.address,
          500,
          parseUnits("1", 18),
          0n,
          10,
        ])
      ).to.be.ok

      const position = await ssl.read.getPosition()
      expect(position[0]).to.be.greaterThan(0n)
    })

    it("Should deposit t1", async function () {
      const { ssl, wmatic, usdc } = await loadFixture(deployFixture)

      await wmatic.write.approve([ssl.address, parseUnits("1", 18)])

      expect(
        await ssl.write.deposit([
          wmatic.address,
          usdc.address,
          500,
          0n,
          parseUnits("1", 18),
          10,
        ])
      ).to.be.ok

      const position = await ssl.read.getPosition()
      expect(position[0]).to.be.greaterThan(0n)
    })
    /*
    it("Should set the right owner", async function () {
      const { lock, owner } = await loadFixture(deployFixture)

      expect(await lock.read.owner()).to.equal(
        getAddress(owner.account.address)
      )
    })

    it("Should receive and store the funds to lock", async function () {
      const { lock, lockedAmount, publicClient } = await loadFixture(
        deployFixture
      )

      expect(
        await publicClient.getBalance({
          address: lock.address,
        })
      ).to.equal(lockedAmount)
    })

    it("Should fail if the unlockTime is not in the future", async function () {
      // We don't use the fixture here because we want a different deployment
      const latestTime = BigInt(await time.latest())
      await expect(
        hre.viem.deployContract("Lock", [latestTime], {
          value: 1n,
        })
      ).to.be.rejectedWith("Unlock time should be in the future")
    })
  })

  describe("Withdrawals", function () {
    describe("Validations", function () {
      it("Should revert with the right error if called too soon", async function () {
        const { lock } = await loadFixture(deployFixture)

        await expect(lock.write.withdraw()).to.be.rejectedWith(
          "You can't withdraw yet"
        )
      })

      it("Should revert with the right error if called from another account", async function () {
        const { lock, unlockTime, otherAccount } = await loadFixture(
          deployFixture
        )

        // We can increase the time in Hardhat Network
        await time.increaseTo(unlockTime)

        // We retrieve the contract with a different account to send a transaction
        const lockAsOtherAccount = await hre.viem.getContractAt(
          "Lock",
          lock.address,
          { walletClient: otherAccount }
        )
        await expect(lockAsOtherAccount.write.withdraw()).to.be.rejectedWith(
          "You aren't the owner"
        )
      })

      it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
        const { lock, unlockTime } = await loadFixture(deployFixture)

        // Transactions are sent using the first signer by default
        await time.increaseTo(unlockTime)

        await expect(lock.write.withdraw()).to.be.fulfilled
      })
    })
      */
  })
})
