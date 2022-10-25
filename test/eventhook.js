const util = require('util')
const ethSigUtil = require('@metamask/eth-sig-util')
const { getMessage } = require('eip-712')
const truffleAssert = require('truffle-assertions')
const ethUtil = require('ethereumjs-util')
const { assert } = require('chai')
const Registry = artifacts.require('Registry')
const Publisher = artifacts.require('Publisher')
const Subscriber = artifacts.require('Subscriber')

contract('Registry', (accounts) => {
  let publisherInstance, registryInstance, subscriberInstance

  beforeEach(async () => {
    publisherInstance = await Publisher.deployed()
    subscriberInstance = await Subscriber.deployed()
    registryInstance = await Registry.deployed()
  })

  it('should add a hook to the publisher', async () => {
    await subscriberInstance.addPublisher(publisherInstance.address)

    await publisherInstance.addHook(1, accounts[1], { from: accounts[0] })

    const addHookResult = await publisherInstance.hooks.call(1)

    assert.equal(addHookResult, accounts[1])
  })

  it('should verify that a publisher permits regitration of a hook', async () => {
    const verifyHookResult = await publisherInstance.verifyEventHook.call(1, accounts[1])

    assert.equal(verifyHookResult, true)
  })

  it('should fire a Hook event from publisher when triggered by transaction', async () => {
    const hashedMessage = web3.utils.utf8ToHex('hashed message')

    const signature = await web3.eth.sign(hashedMessage, accounts[1])

    const { v, r, s } = ethUtil.fromRpcSig(signature)

    const result = await publisherInstance.fireHook(
      hashedMessage,
      1,
      v,
      ethUtil.bufferToHex(r),
      ethUtil.bufferToHex(s)
    )

    truffleAssert.eventEmitted(result, 'Hook', (ev) => {
      return (ev.hashedMessage = hashedMessage && ev.threadId.toNumber() === 1)
    })

    const verifyHookResult = await publisherInstance.verifyEventHook.call(1, accounts[1])

    assert.equal(verifyHookResult, true)
  })

  it('should add a publisher / hook to the registry', async () => {
    const registerHookResult = await registryInstance.registerHook(publisherInstance.address, 1, {
      from: accounts[1],
    })

    truffleAssert.eventEmitted(registerHookResult, 'HookRegistered', (ev) => {
      return (
        ev.publisherContract === publisherInstance.address &&
        ev.publisherPubKey === accounts[1] &&
        ev.threadId.toNumber() === 1
      )
    })

    const addHookResult = await registryInstance.publishers.call(publisherInstance.address, 1)

    assert.equal(addHookResult, accounts[1])
  })

  it('should not allow a publisher to be added to the registry more than once', async () => {
    try {
      const registerHookResult = await registryInstance.registerHook(publisherInstance.address, 1, {
        from: accounts[1],
      })
    } catch (e) {
      assert.equal(e.message.includes('Hook already registered'), true)
    }
  })

  it('should not allow an invalid hook to be added to the registry', async () => {
    try {
      const registerHookResult = await registryInstance.registerHook(publisherInstance.address, 2, {
        from: accounts[1],
      })
    } catch (e) {
      assert.equal(e.message.includes('Hook not valid'), true)
    }
  })

  it('should add a subscriber to the registry', async () => {
    const FEE = 460000

    const registerSubscriberResult = await registryInstance.registerSubscriber(
      publisherInstance.address,
      subscriberInstance.address,
      1,
      FEE,
      {
        from: accounts[2],
      }
    )

    truffleAssert.eventEmitted(registerSubscriberResult, 'SubscriberRegistered', (ev) => {
      return (
        ev.publisherContract === publisherInstance.address &&
        ev.subscriberContract === subscriberInstance.address &&
        ev.fee.toNumber() === FEE &&
        ev.threadId.toNumber() === 1
      )
    })

    const addSubscriberResult = await registryInstance.subscribers.call(
      subscriberInstance.address,
      publisherInstance.address,
      1
    )

    const ownerResult = await registryInstance.owners.call(subscriberInstance.address)

    assert.equal(ownerResult, accounts[2])
  })

  it('should not allow a subscriber to be added to the with a fee of zero', async () => {
    try {
      const registerSubscriberResult = await registryInstance.registerSubscriber(
        publisherInstance.address,
        subscriberInstance.address,
        1,
        0,
        {
          from: accounts[2],
        }
      )
    } catch (e) {
      assert.equal(e.message.includes('Fee must be greater than 0'), true)
    }
  })

  it('should not allow a subscriber to be added to the registry more than once', async () => {
    const FEE = 460000

    try {
      const registerSubscriberResult = await registryInstance.registerSubscriber(
        publisherInstance.address,
        subscriberInstance.address,
        1,
        FEE,
        {
          from: accounts[2],
        }
      )
    } catch (e) {
      assert.equal(e.message.includes('Subscriber already registered'), true)
    }
  })

  it('should allow a publisher to update an already registered hook', async () => {
    const updateHookResult = await registryInstance.updateHook(
      publisherInstance.address,
      accounts[3],
      1,
      { from: accounts[1] }
    )

    truffleAssert.eventEmitted(updateHookResult, 'HookUpdated', (ev) => {
      return (
        ev.publisherContract === publisherInstance.address,
        ev.publisherPubKey == accounts[3],
        ev.threadId == 1
      )
    })
  })

  it('should prevent a hook from being updated if not authorized', async () => {
    try {
      const updateHookResult = await registryInstance.updateHook(
        publisherInstance.address,
        accounts[3],
        1,
        { from: accounts[0] }
      )
    } catch (e) {
      assert.equal(e.message.includes('Not authorized to update hook'), true)
    }
  })

  it('should allow a subscriber to update an already registered subsscription', async () => {
    const updateSubscriberResult = await registryInstance.updateSubscriber(
      publisherInstance.address,
      subscriberInstance.address,
      1,
      520000,
      { from: accounts[2] }
    )

    truffleAssert.eventEmitted(updateSubscriberResult, 'SubscriberUpdated', (ev) => {
      return (
        ev.publisherContract === publisherInstance.address,
        ev.subscriberContract === subscriberInstance.address,
        ev.fee.toNumber() === 520000,
        ev.threadId.toNumber() === 1
      )
    })
  })

  it('should prevent a subscription from being updated if not authorized', async () => {
    try {
      const updateSubscriberResult = await registryInstance.updateSubscriber(
        publisherInstance.address,
        subscriberInstance.address,
        1,
        520000,
        { from: accounts[0] }
      )
    } catch (e) {
      assert.equal(e.message.includes('Not authorized to update subscriber'), true)
    }
  })

  // https://gist.github.com/markodayan/e05f524b915f129c4f8500df816a369b
  // https://web3auth.io/docs/connect-blockchain/ethereum#sign-message
  // https://stackoverflow.com/questions/58257459/solidity-web3js-eip712-signing-uint256-works-signing-uint256-does-not
  it('Subscriber should verify incoming hooks', async function () {
    const demo = await Subscriber.deployed()

    const chainId = await web3.eth.getChainId()

    const payloadHash = web3.utils.keccak256('test')

    const seed = web3.utils.soliditySha3(
      { type: 'bytes32', value: web3.utils.keccak256('one') },
      { type: 'bytes32', value: web3.utils.keccak256('two') },
      { type: 'bytes32', value: web3.utils.keccak256('three') }
    )

    const params = [
      web3.utils.keccak256('one'),
      web3.utils.keccak256('two'),
      web3.utils.keccak256('three'),
    ]

    const salt = '0xb225c57bf2111d6955b97ef0f55525b5a400dc909a5506e34b102e193dd53406'

    const data = {
      types: {
        EIP712Domain: [
          { type: 'string', name: 'name' },
          { type: 'string', name: 'version' },
          { type: 'uint256', name: 'chainId' },
          { type: 'address', name: 'verifyingContract' },
          { type: 'bytes32', name: 'salt' },
        ],
        Hook: [{ type: 'bytes32', name: 'payload' }],
      },
      domain: {
        name: 'Hook',
        version: '1',
        chainId,
        verifyingContract: demo.address,
        salt,
      },
      primaryType: 'Hook',
      message: {
        payload: seed,
      },
    }

    // const signTypedData = ethSigUtil.signTypedData({
    //   privateKey: Buffer.from(privateKey.substring(2), 'hex'),
    //   data: eip712TypedData,
    //   version: ethSigUtil.SignTypedDataVersion.V4,
    // })

    const sendRpc = util.promisify(web3.eth.currentProvider.send)

    const response = await sendRpc.bind(web3.currentProvider)({
      jsonrpc: '2.0',
      method: 'eth_signTypedData',
      params: [accounts[1], data],
      id: new Date().getTime(),
    })

    const signature = response.result.substring(2)
    const r = '0x' + signature.substring(0, 64)
    const s = '0x' + signature.substring(64, 128)
    const v = parseInt(signature.substring(128, 130), 16)

    recovered = ethSigUtil.recoverTypedSignature({
      data: data,
      signature: response.result,
      version: ethSigUtil.SignTypedDataVersion.V4,
    })

    assert(
      ethUtil.toChecksumAddress(recovered) === ethUtil.toChecksumAddress(accounts[1]),
      'local not verified locally'
    )

    const txResult = await demo.verifyHook(params, accounts[1], v, r, s)

    assert.equal(ethUtil.toChecksumAddress(txResult.signer), ethUtil.toChecksumAddress(accounts[1]))
  })
})
