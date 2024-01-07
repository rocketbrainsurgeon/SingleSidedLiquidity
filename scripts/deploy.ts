import hre from "hardhat"

async function main() {
  const lock = await hre.viem.deployContract("SingleSidedLiquidity", [
    process.env.UNISWAP_FACTORY,
    process.env.WETH9,
  ])

  console.log(`SingleSidedLiquidity deployed to ${lock.address}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
