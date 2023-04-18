var Test = require("../config/testConfig.js");
var BigNumber = require("bignumber.js");
const timestamp = Math.floor(Date.now() / 1000);

contract("Flight Surety Tests", async (accounts) => {
  var config;
  before("setup contract", async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(
      config.flightSuretyApp.address
    );
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {
    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");
  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false, {
        from: config.testAddresses[2],
      });
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
    // Ensure that access is allowed for Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false);
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(
      accessDenied,
      false,
      "Access not restricted to Contract Owner"
    );
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {
    await config.flightSuretyData.setOperatingStatus(false);

    let reverted = false;
    try {
      await config.flightSurety.setTestingMode(true);
    } catch (e) {
      reverted = true;
    }
    assert.equal(reverted, true, "Access not blocked for requireIsOperational");

    // Set it back for other tests to work
    await config.flightSuretyData.setOperatingStatus(true);
  });

  it("(airline) cannot register an Airline using registerAirline() if it is not funded", async () => {
    // ARRANGE
    let newAirline = accounts[2];
    let newAirline2 = accounts[3];
    let newAirline3 = accounts[4];
    let newAirline5 = accounts[6];
    let newAirline6 = accounts[7];
    // ACT
    try {
      await config.flightSuretyApp.registerAirline(
        newAirline,
        "Nouns Flight Zone",
        {
          from: config.firstAirline,
        }
      );

      await config.flightSuretyApp.registerAirline(
        newAirline2,
        "BAYC Show Tours",
        {
          from: config.firstAirline,
        }
      );

      await config.flightSuretyApp.registerAirline(
        newAirline3,
        "Doodles Arial Display",
        {
          from: config.firstAirline,
        }
      );

      await config.flightSuretyApp.registerAirline(
        newAirline5,
        "Punks Express",
        {
          from: config.firstAirline,
        }
      );

      await config.flightSuretyApp.registerAirline(newAirline6, "Azuki Wings", {
        from: config.firstAirline,
      });
    } catch (e) {
      console.log("error", e.message);
    }

    let result = await config.flightSuretyData.isAirline.call(newAirline);

    // ASSERT
    assert.equal(
      result,
      true,
      "Airline should not be able to register another airline if it hasn't provided funding"
    );

    let count = await config.flightSuretyApp.getAirlineCount.call();
    assert.equal(count, 5, "# of nifty planes");

    let airlineProperlyRegistered =
      await config.flightSuretyData.isAirlineRegistered.call(newAirline3);
    assert.equal(airlineProperlyRegistered, true, "Registered");

    let airlineNotProperlyRegistered =
      await config.flightSuretyData.isAirlineRegistered.call(newAirline6);
    assert.equal(
      airlineNotProperlyRegistered,
      false,
      "Should not be registered"
    );
  });

  it("(airline sponsor) verify funded airlines can participate", async () => {
    // ARRANGE
    let newAirline = accounts[2];
    let newAirline2 = accounts[3];

    //const etherValue = 10 * config.weiMultiple;
    // ACT
    let pay = await config.flightSuretyApp.payFunding.sendTransaction({
      from: newAirline,
      value: 10 * config.weiMultiple,
    });

    let airlineFunded = await config.flightSuretyData.isAirlineFunded.call(
      newAirline
    );
    assert.equal(airlineFunded, true, "New airline valid");

    let pay2 = await config.flightSuretyApp.payFunding.sendTransaction({
      from: newAirline2,
      value: 10 * config.weiMultiple,
    });

    let airline2Funded = await config.flightSuretyData.isAirlineFunded.call(
      newAirline
    );
    assert.equal(airline2Funded, true, "2nd airline valid");
  });

  it(`(airline vote) vote for airlines register`, async function () {
    let newAirline5 = accounts[6];

    let vote1 = await config.flightSuretyApp.voteToRegisterAirline(
      newAirline5,
      {
        from: config.firstAirline,
      }
    );

    let airline5Registered = await config.flightSuretyData.isAirlineRegistered(
      newAirline5
    );
    console.log(airline5Registered);
    assert.equal(airline5Registered, true, "Registered");

    let count = await config.flightSuretyApp.getAirlineCount.call();
    console.log(count);
    assert.equal(vote1, false, "Should not register");
  });

  it(`(flights) check flights can be created`, async () => {
    let newAirline = accounts[2];

    try {
      await config.flightSuretyApp.registerFlight(
        newAirline,
        "MD101",
        timestamp,
        {
          from: config.firstAirline,
        }
      );
    } catch (e) {
      console.log("error", e.message);
    }
    let count = await config.flightSuretyApp.getAirlineCount.call();
    assert.equal(count, 6, "Proper Airline Count");
  });

  it(`(flights) can purchase insurance`, async () => {
    let newAirline = accounts[2];

    const etherValue = 0.5 * config.weiMultiple;

    let payload = {
      flight: "MD101",
      addr: newAirline,
      passenger: config.firstPassenger,
      amount: 0.5 * config.weiMultiple,
      timestamp: timestamp,
    };

    let pay = await config.flightSuretyApp.buy.sendTransaction(
      payload.addr,
      payload.flight,
      payload.timestamp,
      payload.passenger,
      {
        from: newAirline,
        value: etherValue,
      }
    );
    console.log(pay);
  });
});
