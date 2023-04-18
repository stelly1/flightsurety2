var FlightSuretyApp = artifacts.require("FlightSuretyApp");
var FlightSuretyData = artifacts.require("FlightSuretyData");
var BigNumber = require("bignumber.js");

var Config = async function (accounts) {
  // These test addresses are useful when you need to add
  // multiple users in test scripts
  let testAddresses = [
    "0xd3f9ff69f9ea394a3d78f2a2cb97b90627c84e63",
    "0x3a21594f5b93b278a408ae65b2f39c1d472316e6",
    "0x010ffa27de708bac3564b7a87aa761cff9f66d1c",
    "0x8dd0cd1847a22967cbf7c332caa75aa6d4522d43",
    "0x8eca4f618bcae22ef0b97bb961816c2e6c520dda",
    "0xd1899c961c410cd08d707fac246c202fb0ce9748",
    "0xc7e00d4ae35cdfcd8f634a27ea9a0f91a489b306",
    "0xa3cbd2a5515f14f5a8850f70fc27f047f5604400",
    "0x9571353c7749faa8c9ef7a7ee0ce050328fcae05",
  ];

  let owner = accounts[0];
  let firstAirline = accounts[1];

  let flightSuretyData = await FlightSuretyData.new();
  let flightSuretyApp = await FlightSuretyApp.new();

  return {
    owner: owner,
    firstAirline: firstAirline,
    weiMultiple: new BigNumber(10).pow(18),
    testAddresses: testAddresses,
    flightSuretyData: flightSuretyData,
    flightSuretyApp: flightSuretyApp,
  };
};

module.exports = {
  Config: Config,
};
