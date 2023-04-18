//SPDX-License-Identifier: Udacity
pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    //struct to store insured person's information 
    struct Insured {
        address addr;
        uint256 insuredAmount;
        bool isPayed;
    }

    //struct to store airline information
    struct Airline {
        address addr;
        string name;
        uint256 etherAmount;
        bool isRegistered;
        bool isFunded;
    }

    //variable to store # of airlines approved by contract owner
    uint256 private totalApprovedAirlines = 0;

    //array to store addresses of registered airlines
    address[] private airlines;
    //array to store address of all registered airlines
    address[] private authorizedCallers;

    //map airline address to airline struct that are currently operating
    mapping(address => Airline) private operatingAirlines;
    //map address to uint256 value and store address in contract
    mapping(address => uint256) balanceOf;
    //map flight #s to array of insured structs
    mapping(bytes32 => Insured[]) private flightInsurees;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    //event triggered when new airline is registered
    event RegisterAirline(address airline, string name);
    //event triggered when insurance is purchased
    event BuyFlightInsurance(bytes32 flight, address insuree);
    //event triggered when insurance is paid due to cancelation or delay
    event InsurancePayout(bytes32 flight, address insuree);
    //event triggered when airline is funded
    event FundAirline(address airline);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor(address addr) public  {
        //set contractOwner as contract deployer
        contractOwner = msg.sender;
        //add new airline data to struct
        Airline memory newAirline = Airline(addr, "Nouns Flight Zone DAO", 0, true, false);
        //provides address
        airlines.push(addr);
        //add to mapping
        operatingAirlines[addr] = newAirline;
        //increment counter
        totalApprovedAirlines += 1;
    }

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
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() public view returns(bool) {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus (bool mode)  external requireContractOwner {
        operational = mode;
    }

    //allow contract owner to add authorized caller to contract
    function authorizeCaller(address caller) external requireContractOwner {
        authorizedCallers.push(caller);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function _registerAirline(address addr, string name, bool register) requireIsOperational() external {
        Airline memory newAirline = Airline(addr, name, 0, register, false);
        airlines.push(addr);
        if(register) {
            totalApprovedAirlines += 1;
        }
        operatingAirlines[addr] = newAirline;
        emit RegisterAirline(addr, name);
    }
    //update registration status of airline in operatingAirlines mapping and increment totalApprovedAirlines count
    function _updateAirlineIsRegistered(address addr, bool register) requireIsOperational external {
        Airline memory updateAirline = operatingAirlines[addr];
        operatingAirlines[addr] = updateAirline;
        if(register) {
            totalApprovedAirlines += 1;
        }
    }

    //check if address belongs to an airline from Airline struct from operatingAirlines mapping and return true if not 0
    function isAirline(address caller) external view returns(bool success) {
        Airline memory existingAirline = operatingAirlines[caller];
        return existingAirline.addr != address(0);
    }

    //return address of an airline at specified index in airlines array
    function _getAirlineCount() external view returns(uint256) {
        return totalApprovedAirlines;
    } 

    //return total # of approved airlines
    function _getAirlineByIndex(uint256 index) external view returns(address) {
        return airlines[index];
    }

    //return address of airline at specified index in airlines array
    function isAirlineFunded(address airline) external view returns(bool) {
        Airline storage fundedAirline = operatingAirlines[airline];
        return fundedAirline.isFunded;
    }

    //check registration status - retrieve corresponding Airline struct from operatingAirlines mapping and return value of isRegistered boolean
    function isAirlineRegistered(address airline) external view requireIsOperational returns(bool) {
        Airline storage fundedAirline = operatingAirlines[airline];
        return fundedAirline.isRegistered;
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(bytes32 flight, address insuree) external requireIsOperational payable {
        bool isAlreadyInsuree = false;
        uint256 newInsuredValue = msg.value;
        Insured[] memory insurees = flightInsurees[flight];
        for(uint i=0; i < insurees.length; i++) {
            if(insurees[i].addr == insuree) {
                isAlreadyInsuree = true;
                uint256 totalValue = insurees[i].insuredAmount.add(newInsuredValue);
                if(totalValue > 1) {
                    uint256 returnOverageValue = totalValue.sub(1);
                    insurees[i].insuredAmount = totalValue;

                    insuree.transfer(returnOverageValue);
                }
                break;
            }
        }
        if(!isAlreadyInsuree) {
            Insured memory newInsuree = Insured(insuree, newInsuredValue, false);
            flightInsurees[flight].push(newInsuree);
        }
        emit BuyFlightInsurance(flight, insuree);
    }

    //view function to calc amount credited to passenger for a flight
    function _creditInsureeAmount(bytes32 flight, address passenger) external view requireIsOperational returns(uint256) {
        //retrieves array of insured passengers from flightInsurees mapping
        Insured[] memory insurees = flightInsurees[flight];
        //store payout variable
        uint256 payout = 0;
        //calculate payout amount only if contract is operational
        for(uint i = 0; i < insurees.length; i++) {
            if(insurees[i].addr == passenger) {
                payout = insurees[i].insuredAmount;
                break;
            }
        }
        return payout;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function _creditInsurees(bytes32 flight, address passenger) requireIsOperational external {
        Insured[] memory insurees = flightInsurees[flight];
        for(uint i=0; i < insurees.length; i++) {
            if (insurees[i].addr == passenger) {
                require(!insurees[i].isPayed, "Already paid");
                require(insurees[i].insuredAmount > 0, "No insured amount");
                flightInsurees[flight][i].isPayed = true;
                pay(insurees[i].insuredAmount, passenger);
                flightInsurees[flight][i].insuredAmount = 0;
                emit InsurancePayout(flight, passenger);
                break;
            }
        }
    }
    
    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(uint256 requiredEther, address passenger) public requireIsOperational payable {
        uint256 amountToPay = requiredEther.add(requiredEther.div(2));
        require(contractOwner.balance > amountToPay, "Not enough");
        bool success = passenger.call.value(amountToPay)("");
        require(success, "Insurance payout failed");
    }

    //check airline if registered - and prevent airline from being re-registered
    function fundAirline(address airline) external requireIsOperational payable {
        Airline memory fundedAirline = operatingAirlines[airline];
        require(fundedAirline.isRegistered, "Airline must be registered");
        operatingAirlines[airline].etherAmount = fundedAirline.etherAmount.add(msg.value);
        operatingAirlines[airline].isFunded = true;
        operatingAirlines[airline].isRegistered = true;
        emit FundAirline(airline);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund () public payable requireIsOperational {}


    function getFlightKey(address airline, string memory flight, uint256 timestamp) pure internal returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {
        fund();
    }
}