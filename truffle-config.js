var HDWalletProvider = require("@truffle/hdwallet-provider");
var mnemonic =
  "addict alarm fix destroy giraffe hockey disorder festival country unaware spell gallery";

module.exports = {
  networks: {
    development: {
      provider: function () {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/", 0, 50);
      },
      network_id: "5777",
      gas: 9999999,
    },
  },
  compilers: {
    solc: {
      version: "^0.4.24",
    },
  },
};
