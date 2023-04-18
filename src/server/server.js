import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import Config from "./config.json";
import Web3 from "web3";
import express from "express";

let config = Config["localhost"];
let web3 = new Web3(
  new Web3.providers.WebsocketProvider(config.url.replace("http", "ws"))
);

async function main() {
  const accounts = await web3.eth.getAccounts();
  web3.eth.defaultAccount = accounts[0];

  let flightSuretyApp = new web3.eth.Contract(
    FlightSuretyApp.abi,
    config.appAddress
  );
  let testOracles = 20;
  let statusCodeArray = [
    ["STATUS_CODE_UNKNOWN", 0],
    ["STATUS_CODE_ON_TIME", 10],
    ["STATUS_CODE_LATE_AIRLINE", 20],
    ["STATUS_CODE_LATE_WEATHER", 30],
    ["STATUS_CODE_LATE_TECHNICAL", 40],
    ["STATUS_CODE_LATE_OTHER", 50],
  ];

  async function registerOracles() {
    let accounts = await web3.eth.getAccounts();
    let fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();

    for (let i = 1; i < testOracles; i++) {
      let account = accounts[i];
      await flightSuretyApp.methods
        .registerOracle()
        .send({ from: account, value: fee, gas: 1000000 });
      let indexes = await flightSuretyApp.methods
        .getMyIndexes()
        .call({ from: account });
      console.log(`Oracle ${account} registered with ${indexes}`);
    }
  }

  flightSuretyApp.events.OracleRequest(
    { fromBlock: 0 },
    async function (error, event) {
      if (error) console.log(error);
      console.log(event);
      let requestData = event.returnValues;
      let index = requestData.index;
      let airline = requestData.airline;
      let flight = requestData.flight;
      let timestamp = requestData.timestamp;
      let accounts = await web3.eth.getAccounts();

      for (let i = 1; i <= testOracles; i++) {
        let account = accounts[i];
        let oracleIndexes = await flightSuretyApp.methods
          .getMyIndexes()
          .call({ from: account });
        if (oracleIndexes.includes(index)) {
          let statusArray =
            statusCodeArray[Math.floor(Math.random() * statusCodeArray.length)];

          try {
            await flightSuretyApp.methods
              .submitOracleResponse(
                index,
                airline,
                flight,
                timestamp,
                statusCode
              )
              .send({ from: account, gas: 1000000 });
            console.log(`Oracle ${account} show the flight is ${statusArray}`);
          } catch (error) {
            console.log(
              `Oracle ${account} unable to fetch status code ${statusArray}`
            );
          }
        }
      }
    }
  );
  await registerOracles();
}

const app = express();
app.get("/api", (req, res) => {
  res.send({
    message: "An API for use with your Dapp!",
  });
});

main().catch((error) => {
  console.error("Error:", error);
});

export default app;
