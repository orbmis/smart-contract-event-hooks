const Publisher = artifacts.require('publisher')
const Registry = artifacts.require('registry')
const Subscriber = artifacts.require('subscriber')
const SubscriberTwo = artifacts.require('subscribertwo')

module.exports = function (deployer) {
  deployer.deploy(Registry)
  deployer.deploy(Subscriber)
  deployer.deploy(SubscriberTwo)
  deployer.deploy(Publisher)
}
