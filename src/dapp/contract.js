import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import Config from "./config.json";
import Web3 from "web3";

export default class Contract {
  constructor(network, callback) {
    let config = Config[network];
    this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
    this.flightSuretyApp = new this.web3.eth.Contract(
      FlightSuretyApp.abi,
      config.appAddress
    );
    this.initialize(callback);
    this.owner = null;
    this.airlines = [];
    this.passengers = [];
  }

  initialize(callback) {
    this.web3.eth.getAccounts((error, accts) => {
      this.owner = accts[0];

      let counter = 1;

      while (this.airlines.length < 5) {
        this.airlines.push(accts[counter++]);
      }

      while (this.passengers.length < 5) {
        this.passengers.push(accts[counter++]);
      }

      callback();
    });
  }

  isOperational(callback) {
    let self = this;
    self.flightSuretyApp.methods
      .isOperational()
      .call({ from: self.owner }, callback);
  }

  async purchaseInsurance(airlinesAddress, flightNumber, insuranceAmount) {
    let self = this;
    let amountToWei = this.web3.utils.toWei(insuranceAmount, "ether");
    let timestamp = Math.floor(Date.new() / 1000);
    try {
      await self.flightSuretyApp.methods
        .buyInsurance(airlinesAddress, flightNumber, timestamp)
        .send({ from: self.passengers[0], value: amountToWei });
      alert("You're Insured! Have a safe flight!");
    } catch {
      console.log(error);
      alert(
        "Dang, you're wish to purchase insurance has failed. Please try again"
      );
    }
  }

  async registerAirline(newAirlineAddress, newAirlineName) {
    let self = this;
    try {
      await self.flightSuretyApp.methods
        .registerAirline(newAirlineAddress, newAirlineName)
        .send({ from: self.owner });
      alert("Congrats! You are now a registered airline!");
    } catch (error) {
      console.log(error);
      alert(
        "Your wings will not arrive today! Try again at a later time to register!"
      );
    }
  }

  async withdrawInsurancePayout() {
    let self = this;
    try {
      await self.flightSuretyApp.methods.withdraw().send({ from: self.owner });
      alert("You are no longer insured...please be safe out there!");
    } catch (error) {
      console.log(error);
      alert(
        "You are still insured, but if you live dangerously, please try to revoke your insurance again!"
      );
    }
  }

  async submitAirlineFunding(airlineAddress, fundingAmount) {
    let self = this;
    let amountToWei = this.web3.utils.toWei(fundingAmount, "ether");
    try {
      await self.flightSuretyApp.methods
        .fund()
        .send({ from: airlineAddress, value: amountToWei });
      alert(
        "You hard earned ETH enters my pocket gratefully, but hey, you are now funded!"
      );
    } catch (error) {
      console.log(error);
      alert(
        "Welp, your funding levels are as dry as Arizona! Please try to submit funding again."
      );
    }
  }

  fetchFlightStatus(flight, callback) {
    let self = this;
    let payload = {
      airline: self.airlines[0],
      flight: flight,
      timestamp: Math.floor(Date.now() / 1000),
    };
    self.flightSuretyApp.methods
      .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
      .send({ from: self.owner }, (error, result) => {
        callback(error, payload);
      });
  }
}
