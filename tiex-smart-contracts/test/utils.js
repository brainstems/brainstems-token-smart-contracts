const { expect } = require("chai");

const getEvents = (txReceipt, contract, eventName) => {
  const events = txReceipt.logs.map((log) => contract.interface.parseLog(log));
  return events.filter((event) => event && event.name == eventName);
};

const verifyEvents = async (tx, contract, event, expectedEvents) => {
  await tx.wait();

  const receipt = await ethers.provider.getTransactionReceipt(tx.hash);
  const events = getEvents(receipt, contract, event);

  expect(events.length).to.equal(expectedEvents.length);
  for (i = 0; i < events.length; i++) {
    const eventFields = Object.keys(expectedEvents[i]);
    for (j = 0; j < eventFields.length; j++) {
      expect(events[i].args[j]).eql(expectedEvents[i][eventFields[j]]);
    }
  }
};

module.exports = {
  verifyEvents,
};
