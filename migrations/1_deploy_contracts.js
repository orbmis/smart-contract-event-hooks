const Publisher = artifacts.require('publisher')
const Registry = artifacts.require('registry')
const Subscriber = artifacts.require('subscriber')

module.exports = function (deployer) {
  deployer.deploy(Registry)
  deployer.deploy(Subscriber)
  deployer.deploy(Publisher)
}
