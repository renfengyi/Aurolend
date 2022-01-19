NETWORK=aurora_test

deploy:
	yarn hardhat run scripts/deploy.js --network ${NETWORK}
