# SingleSidedLiquidity

To install the project:

```
git clone [repository]
npm i
```

The project requires a .env file with a few deployment settings. A sample .env has been provided and needs 1) an RPC URL, 2) an API_KEY for polygon scan if you want to verify the contract, and 3) a private key for deployment costs.

To deploy the contract to the hardhat network:

```
npx hardhat run scripts/deploy.ts --network hardhat
```

To run the unit tests:

```
npx hardhat test --network hardhat
```