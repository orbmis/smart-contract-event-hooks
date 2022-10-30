const util = require('util')
const ethSigUtil = require('@metamask/eth-sig-util')
const truffleAssert = require('truffle-assertions')
const ethUtil = require('ethereumjs-util')
const { assert } = require('chai')

const Registry = artifacts.require('Registry')
const Publisher = artifacts.require('Publisher')
const Subscriber = artifacts.require('Subscriber')

const digest = web3.utils.soliditySha3(
  { type: 'bytes32', value: web3.utils.keccak256('one') },
  { type: 'bytes32', value: web3.utils.keccak256('two') },
  { type: 'bytes32', value: web3.utils.keccak256('three') }
)

const params = [
  web3.utils.keccak256('one'),
  web3.utils.keccak256('two'),
  web3.utils.keccak256('three'),
]

async function getTypedData(nonce, verifyingContract, publisherAddress) {
  const chainId = await web3.eth.getChainId()

  const salt = '0x5db5bd0cd6f41d9d705525bc4773e06c1cdcb68185b4e00b0b26cc7d2e23761d'

  const data = {
    types: {
      EIP712Domain: [
        { type: 'string', name: 'name' },
        { type: 'string', name: 'version' },
        { type: 'uint256', name: 'chainId' },
        { type: 'address', name: 'verifyingContract' },
        { type: 'bytes32', name: 'salt' },
      ],
      Hook: [
        { type: 'bytes32', name: 'payload' },
        { type: 'uint256', name: 'nonce' },
      ],
    },
    domain: {
      name: 'Hook',
      version: '1',
      chainId,
      verifyingContract,
      salt,
    },
    primaryType: 'Hook',
    message: {
      payload: digest,
      nonce,
    },
  }

  const sendRpc = util.promisify(web3.eth.currentProvider.send)

  const response = await sendRpc.bind(web3.currentProvider)({
    jsonrpc: '2.0',
    method: 'eth_signTypedData',
    params: [publisherAddress, data],
    id: new Date().getTime(),
  })

  const signature = response.result.substring(2)

  r = '0x' + signature.substring(0, 64)
  s = '0x' + signature.substring(64, 128)
  v = parseInt(signature.substring(128, 130), 16)

  recovered = ethSigUtil.recoverTypedSignature({
    data: data,
    signature: response.result,
    version: ethSigUtil.SignTypedDataVersion.V4,
  })

  assert(
    ethUtil.toChecksumAddress(recovered) === ethUtil.toChecksumAddress(publisherAddress),
    'local not verified locally'
  )

  return { v, r, s }
}

contract('Publisher', (accounts) => {
  let publisherInstance

  beforeEach(async () => {
    publisherInstance = await Publisher.deployed()
  })

  it('should add a hook to the publisher', async () => {
    await publisherInstance.addHook(1, accounts[1], { from: accounts[0] })

    const addHookResult = await publisherInstance.hooks.call(1)

    assert.equal(addHookResult, accounts[1])
  })

  it('should verify that a publisher permits regitration of a hook', async () => {
    const verifyHookResult = await publisherInstance.verifyEventHook.call(1, accounts[1])

    assert.isTrue(verifyHookResult)
  })

  it('should fire a Hook event from publisher when triggered by transaction', async () => {
    const hashedMessage = web3.utils.utf8ToHex('hashed message')

    const signature = await web3.eth.sign(hashedMessage, accounts[1])

    const { v, r, s } = ethUtil.fromRpcSig(signature)

    const result = await publisherInstance.fireHook(
      params,
      digest,
      1,
      v,
      ethUtil.bufferToHex(r),
      ethUtil.bufferToHex(s)
    )

    truffleAssert.eventEmitted(result, 'Hook', (ev) => {
      return (ev.digest = digest && ev.threadId.toNumber() === 1)
    })

    const verifyHookResult = await publisherInstance.verifyEventHook.call(1, accounts[1])

    assert.isTrue(verifyHookResult)
  })
})

contract('Registry', (accounts) => {
  let publisherInstance, registryInstance, subscriberInstance

  beforeEach(async () => {
    publisherInstance = await Publisher.deployed()
    subscriberInstance = await Subscriber.deployed()
    registryInstance = await Registry.deployed()
  })

  it('should add a publisher / hook to the registry', async () => {
    await publisherInstance.addHook(1, accounts[1], { from: accounts[0] })
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
      await registryInstance.registerHook(publisherInstance.address, 1, {
        from: accounts[1],
      })
    } catch (e) {
      assert.include(e.message, 'Hook already registered')
    }
  })

  it('should not allow an invalid hook to be added to the registry', async () => {
    try {
      await registryInstance.registerHook(publisherInstance.address, 2, {
        from: accounts[1],
      })
    } catch (e) {
      assert.include(e.message, 'Hook not valid')
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

    await registryInstance.subscribers.call(
      subscriberInstance.address,
      publisherInstance.address,
      1
    )

    const ownerResult = await registryInstance.owners.call(subscriberInstance.address)

    assert.equal(ownerResult, accounts[2])
  })

  it('should not allow a subscriber to be added to the with a fee of zero', async () => {
    try {
      await registryInstance.registerSubscriber(
        publisherInstance.address,
        subscriberInstance.address,
        1,
        0,
        {
          from: accounts[2],
        }
      )
    } catch (e) {
      assert.include(e.message, 'Fee must be greater than 0')
    }
  })

  it('should not allow a subscriber to be added to the registry more than once', async () => {
    const FEE = 460000

    try {
      await registryInstance.registerSubscriber(
        publisherInstance.address,
        subscriberInstance.address,
        1,
        FEE,
        {
          from: accounts[2],
        }
      )
    } catch (e) {
      assert.include(e.message, 'Subscriber already registered')
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
      await registryInstance.updateHook(publisherInstance.address, accounts[3], 1, {
        from: accounts[0],
      })
    } catch (e) {
      assert.include(e.message, 'Not authorized to update hook')
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
      await registryInstance.updateSubscriber(
        publisherInstance.address,
        subscriberInstance.address,
        1,
        520000,
        { from: accounts[0] }
      )
    } catch (e) {
      assert.include(e.message, 'Not authorized to update subscriber')
    }
  })
})

contract('Subscriber', (accounts) => {
  let subscriberInstance

  beforeEach(async () => {
    subscriberInstance = await Subscriber.deployed()
  })

  it('should allow owner to add publisher', async function () {
    await web3.eth.sendTransaction({
      from: accounts[0],
      to: subscriberInstance.address,
      value: web3.utils.toWei('1', 'ether'),
    })

    await subscriberInstance.addPublisher(accounts[1], 1)

    const publishersCheck = await subscriberInstance.getPublisherNonce(accounts[1], 1)

    assert.equal(publishersCheck, 1)
  })

  it('should prevent others from adding publishers', async function () {
    try {
      await subscriberInstance.addPublisher(accounts[2], 1, { from: accounts[1] })
    } catch (e) {
      assert.include(e.message, 'Ownable: caller is not the owner')
    }
  })

  it('should verify incoming hooks', async function () {
    const sig = await getTypedData(2, subscriberInstance.address, accounts[1])

    await subscriberInstance.verifyHook(params, 1, 2, sig.v, sig.r, sig.s)

    const nonceCheck = await subscriberInstance.currentNonce.call()

    assert.equal(nonceCheck.toNumber(), 2)
  })

  it('pay the correct relayer fee', async function () {
    const balanceBefore = await web3.eth.getBalance(accounts[0])

    const sig = await getTypedData(4, subscriberInstance.address, accounts[1])

    const txResult = await subscriberInstance.verifyHook(params, 1, 4, sig.v, sig.r, sig.s)

    const balanceAfter = await web3.eth.getBalance(accounts[0])

    const difference = BigInt(balanceAfter) - BigInt(balanceBefore)

    const txFees = txResult.receipt.effectiveGasPrice * txResult.receipt.gasUsed

    const actual = difference + BigInt(txFees)

    const feeExpected = 0.001

    const feeReceived = Number(web3.utils.fromWei(actual.toString()))

    assert.equal(feeReceived, feeExpected)
  })

  it('should prevent against re-entrancy and replay attacks', async function () {
    try {
      await subscriberInstance.verifyHook(params, 1, 4, v, r, s)
    } catch (e) {
      assert.include(e.message, 'Obsolete hook detected')
    }
  })

  it('should detect invalid hooks', async function () {
    const sig = await getTypedData(2, subscriberInstance.address, accounts[4])

    try {
      await subscriberInstance.verifyHook(params, 1, 2, sig.v, sig.r, sig.s)
    } catch (e) {
      assert.include(e.message, 'Obsolete hook detected')
    }
  })
})
