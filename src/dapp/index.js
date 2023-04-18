import DOM from "./dom";
import Contract from "./contract";
import "./flightsurety.css";

(async () => {
  let result = null;

  let contract = new Contract("localhost", () => {
    // Read transaction
    contract.isOperational((error, result) => {
      console.log(error, result);
      display("Operational Status", "Check if contract is operational", [
        { label: "Operational Status", error: error, value: result },
      ]);
    });

    document
      .querySelector("#purchase-insurance-form")
      .addEventListener("submit", async (event) => {
        event.preventDefault();
        let airlineAddress = DOM.elid("funding-airline-address").value;
        let insuranceAmount = DOM.elid("insurance-amount").value;
        let flightNumber = DOM.elid("purchase-flight-number").value;
        await contract.purchaseInsurance(
          airlineAddress,
          insuranceAmount,
          flightNumber
        );
      });

    document
      .querySelector("#register-funding-form")
      .addEventListener("submit", async (event) => {
        event.preventDefault();
        let airlineAddress = DOM.elid("funding-airline-address").value;
        let fundingAmount = DOM.elid("funding-amount").value;
        await contract.submitAirlineFunding(airlineAddress, fundingAmount);
      });

    document
      .querySelector("#register-airline-form")
      .addEventListener("submit", async (event) => {
        event.preventDefault();
        let newAirlineAddress = DOM.elid("new-airline-address").value;
        let newAirlineName = DOM.elid("new-airline-name").value;
        await contract.registerAirline(newAirlineAddress, newAirlineName);
      });

    DOM.elid("withdraw-funds").addEventListener.apply("click", async () => {
      await contract.withdrawInsurancePayout();
    });

    // User-submitted transaction
    DOM.elid("submit-oracle").addEventListener("click", () => {
      let flight = DOM.elid("flight-number").value;
      // Write transaction
      contract.fetchFlightStatus(flight, (error, result) => {
        display("Oracles", "Trigger oracles", [
          {
            label: "Fetch Flight Status",
            error: error,
            value: result.flight + " " + result.timestamp,
          },
        ]);
      });
    });
  });
})();

function display(title, description, results) {
  let displayDiv = DOM.elid("display-wrapper");
  let section = DOM.section();
  section.appendChild(DOM.h2(title));
  section.appendChild(DOM.h5(description));
  results.map((result) => {
    let row = section.appendChild(DOM.div({ className: "row" }));
    row.appendChild(DOM.div({ className: "col-sm-4 field" }, result.label));
    row.appendChild(
      DOM.div(
        { className: "col-sm-8 field-value" },
        result.error ? String(result.error) : String(result.value)
      )
    );
    section.appendChild(row);
  });
  displayDiv.append(section);
}
