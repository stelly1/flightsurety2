//SPDX-License-Identifier: Udacity
pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    //private variable for contract deployer
    address private contractOwner;

    //dynamic array
    address [] multiCalls = new address[](0);

    //constant variable for 10 ether to register airline
    uint8 private constant AIRLINE_DUES = 10;

    //struct to define flight properties
    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    //private mapping corresponding to Flight struct
    mapping(bytes32 => Flight) private flights;

    //data as an instance of data contract to store data
    FlightSuretyData private data;
    
    //private variable to store address of data contract
    address fsDataContractAddress;

    //event emitted when new airline votes for new airline to be registered
    event VoteForAirline(address airline, address newAirline);
 
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() {
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    //check if caller is existing airline
    modifier requireExistingAirline() {
        require(data.isAirline(msg.sender), "Caller is not an already existing airline");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor (address dataContract) public {
        contractOwner = msg.sender;
        data = FlightSuretyData(dataContract);
        fsDataContractAddress = dataContract;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    //return boolean to indicate whether contract is operational or not
    function isOperational() public view returns(bool) 
    {
        return true;  // Modify to call data contract's status
    }

    //return the # of airlines registered
    function getAirlineCount() public view returns(uint256) {
        return data._getAirlineCount();
    }

    //return boolean indicating whether a specified airline is registered
    function getAirlineIsRegistered(address airline) public view returns(bool) {
        return data.isAirlineRegistered(airline);
    }

    //return address of airline at specified index in the list of registered airlines in the data contract
    function getAirlineByIndex(uint256 index) public view returns(address) {
        return data._getAirlineByIndex(index);
    } 

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   

    //externally callable function that takes address and name to register new airline - modifier check operational
    function registerAirline(address addr, string name) external requireIsOperational returns(bool) {
        //retrieves # of registered airlines from data contract
        uint256 airlineCount = data._getAirlineCount();
        bool isRegistered = false;
        if(airlineCount < 5) {
            //if less than 5, require caller to alredy be registered using isAirline() function
            require(data.isAirline(msg.sender), "Airline not current registered");
            isRegistered = true;
        }
        //use _registerAirline from data contract to update its registration to T/F
        data._registerAirline(addr, name, isRegistered);
        //return status
        return isRegistered;
    }

    //externally callable that takes address to vote for registration
    function voteToRegisterAirline(address addr) external requireIsOperational returns(bool success, uint256 votes) {
        //require check for registered airlines
        require(data.isAirline(msg.sender), "Airline must be registered to vote");
        uint256 airlineCount = data._getAirlineCount();
        bool isRegistered = false;
        bool isDuplicate = false;
        //check if caller has voted by searching for address in multiCalls array and set isDuplicate to T/F
        for(uint c=0; c<multiCalls.length; c++) {
            if(multiCalls[c] == msg.sender) {
                isDuplicate = true;
                break;
            }
        }
        require(!isDuplicate, "Already called, mate!");
        multiCalls.push(msg.sender);
        if(multiCalls.length >= (airlineCount / 2)) {
            isRegistered = true;
            multiCalls = new address[](0);
        }
        if(isRegistered) {
            //use data contract to set isRegistered to true
            data._updateAirlineIsRegistered(addr, isRegistered);
        }
        //emit event with airline's address and caller's address as a parameter
        emit VoteForAirline(addr, msg.sender);
        //return boolean to indicate registration and total number of airlines registered
        return(isRegistered, airlineCount);
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */  

    //externally callable taking address, flight name, and time as parameters to register new flight - use modifiers to check operational / registration
    function registerFlight(address addr, string flight, uint256 timestamp) external requireIsOperational requireExistingAirline {
        //create new flight struct
        Flight memory newFlightToRegister = Flight(true, STATUS_CODE_UNKNOWN, timestamp, addr);
        //generate unnique key and set 'flights' mapping to new Flight struct
        bytes32 airLineKey = getFlightKey(addr, flight, timestamp);
        flights[airLineKey] = newFlightToRegister;
    }

    //externally callable taking address, flight name, and time parameters
    function checkFlightStatus(address addr, string flight, uint256 timestamp) returns(uint8) {
        //generate unique flight key and retrieve from flight struct from flights mapping
        bytes32 airLineKey = getFlightKey(addr, flight, timestamp);
        //require registration from Flight struct
        require(flights[airLineKey].isRegistered, "Must register flight first");
        //return statusCode
        return flights[airLineKey].statusCode;
    }

    //function to purchase insurance for a flight - check between 0 and 1, and call buy function of data contract while passing in flight key as paramaters
    function buy(address addr, string flight, uint256 timestamp, address passenger) external payable {
        require(msg.value > 0 ether, "Must pay more than 0 and less than 1 ether");
        require(msg.value <= 1 ether, "Must pay more than 0 and less than 1 ether");
        bytes32 airLineKey = getFlightKey(addr, flight, timestamp);
        Flight memory flightToEnsure = flights[airLineKey];
        require(flightToEnsure.isRegistered, "Flight must be registered");
        require(flightToEnsure.statusCode < STATUS_CODE_ON_TIME, "Too late, flight already arrived... sorry");
        data.buy.value(msg.value)(airLineKey, passenger);
    }

    //function to check if flight is eligible for insurance claim - must have status code greater than 10 - return status code for flight
    function claimInsurance(address addr, string flight, uint256 timestamp) external view returns(uint8) {
        bytes32 airLineKey = getFlightKey(addr, flight, timestamp);
        Flight memory flightToCheck = flights[airLineKey];
        require(flightToCheck.isRegistered, "Register flight to check status");
        require(flightToCheck.statusCode > STATUS_CODE_ON_TIME, "Flight still on time to claim insurance");
        return flightToCheck.statusCode;
    }

    //function to return insurance credits due to passenger - must be greater than 10 - calls _creditInsureeAmount from data contract, 
    //passing in key and passenger address to then calc half of the credit due
    function getInsuranceCredits(address addr, string flight, uint256 timestamp, address passenger) external view returns(uint256) {
        bytes32 airLineKey = getFlightKey(addr, flight, timestamp);
        Flight memory flightToCheck = flights[airLineKey];
        require(flightToCheck.isRegistered, "Register flight to check status");
        require(flightToCheck.statusCode > STATUS_CODE_ON_TIME, "Flight still on time to get insurance credits");
        uint256 credit = data._creditInsureeAmount(airLineKey, passenger);
        credit = credit.add(credit.div(2));
        return credit;
    }

    //function for passenger to withdraw insurance credits - check flight registration to have status code greater than 10, calls
    //_creditInsurees from data contract, passing in passenger address and key
    function withdrawInsuranceCredits(address addr, string flight, uint256 timestamp, address passenger) external requireIsOperational returns(bool) {
        bytes32 airLineKey = getFlightKey(addr, flight, timestamp);
        Flight memory flightToCheck = flights[airLineKey];
        require(flightToCheck.isRegistered, "Register flight to check status");
        require(flightToCheck.statusCode > STATUS_CODE_ON_TIME, "Flight still on time to get insurance credits");
        data._creditInsurees(airLineKey, passenger);
        return true;
    }

    //function for airlines to add funds to account - check that the value is 10 ether - call fundAirline from data contract, passing in value sent and 
    //airline address as arguments
    function payFunding() external payable requireIsOperational requireExistingAirline {
        require(msg.value >= 10 ether, "Need at least 10 ether!");
        data.fundAirline.value(msg.value)(msg.sender);
    }
   /**
    * @dev Called after oracle has updated flight status
    *
    */  

    //internal function called after oracle updates flight status
    //takes address, flight, timestamp, and status code to update corresponding Flight object's statusCode in flights mapping
    function processFlightStatus(address airline, string memory flight, uint256 timestamp, uint8 statusCode) internal {
        bytes32 airLineKey = getFlightKey(airline, flight, timestamp);
        flights[airLineKey].statusCode = statusCode;
    }


    //Generate a request for oracles to fetch flight information on a particular flight - generates unique key for storing and adds
    //to oracleResponses mapping while emitting OracleRequest event with oracle index, address, flight, and timestamp
    function fetchFlightStatus(address airline, string flight, uint256 timestamp) external {
        uint8 index = getRandomIndex(msg.sender);
        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({requester: msg.sender, isOpen: true});
        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");
        uint8[3] memory indexes = generateIndexes(msg.sender);
        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() view external returns(uint8[3]){
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");
        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(uint8 index, address airline, string flight, uint256 timestamp, uint8 statusCode) external {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");
        oracleResponses[key].responses[statusCode].push(msg.sender);
        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);
            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey(address airline, string flight, uint256 timestamp) pure internal returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns(uint8[3]) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }
        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }
        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;
        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);
        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }
        return random;
    }
// endregion
}