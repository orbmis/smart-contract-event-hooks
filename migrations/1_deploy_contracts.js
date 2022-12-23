const Publisher = artifacts.require('publisher')
const Registry = artifacts.require('registry')
const SubscriberWithSignature = artifacts.require('subscriberWithSignature')
const Subscriber = artifacts.require('subscriber')

module.exports = function (deployer) {
  deployer.deploy(Registry)
  deployer.deploy(SubscriberWithSignature)
  deployer.deploy(Subscriber)
  deployer.deploy(Publisher)
}
