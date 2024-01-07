import dotenv from "dotenv"
import { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox-viem"

dotenv.config()

const config: HardhatUserConfig = {
  solidity: "0.7.6",
  networks: {
    hardhat: {
      forking: {
        url: process.env.POLYGON_URL || "",
      },
    },
    polygon: {
      url: process.env.POLYGON_URL || "",
      accounts:
        process.env.POLYGON_PRIVATE_KEY !== undefined
          ? [process.env.POLYGON_PRIVATE_KEY]
          : [],
    },
  },
}

export default config
