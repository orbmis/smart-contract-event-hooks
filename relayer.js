const Web3 = require('web3')
const path = require('path')
const { Level } = require('level')
const dbPath = path.resolve(__dirname, 'data')
const db = new Level('relayer', { valueEncoding: 'json' })

class Relayer {
  constructor(_web3, _registryABI, _registryAddress) {
    this.web3 = _web3
    this.registryInstance = new this.web3.eth.Contract(_registryABI, _registryAddress)

    console.log(this.registryInstance)
  }

  getEvents() {
    this.registryInstance.events.HookRegistered({
      fromBlock: '0',
}, function (error, event) {
      console.log('EVENT:', event)
    })
  }
}

function storeValue() {
  init()

  db.put('key 1', 'value 1')
  db.put('key 2', 'value 2')

  db.get('key 1', function (err, value) {
    if (err) {
      return handleError(err)
    }
    console.log('value:', value)
  })
}

module.exports = Relayer
