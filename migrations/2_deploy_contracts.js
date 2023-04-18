const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require("fs");

module.exports = function (deployer) {
  let firstAirline = "0xd3f9ff69f9ea394a3d78f2a2cb97b90627c84e63";
  deployer.deploy(FlightSuretyData).then(() => {
    return deployer.deploy(FlightSuretyApp).then(() => {
      let config = {
        localhost: {
          url: "http://localhost:9545",
          dataAddress: FlightSuretyData.address,
          appAddress: FlightSuretyApp.address,
        },
      };
      fs.writeFileSync(
        __dirname + "/../src/dapp/config.json",
        JSON.stringify(config, null, "\t"),
        "utf-8"
      );
      fs.writeFileSync(
        __dirname + "/../src/server/config.json",
        JSON.stringify(config, null, "\t"),
        "utf-8"
      );
    });
  });
};
