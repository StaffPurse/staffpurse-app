> ## Documentation Index
> Fetch the complete documentation index at: https://bkey.mintlify.site/llms.txt
> Use this file to discover all available pages before exploring further.

# The integration lifecycle

> The single mental model behind BMONI Embedded — six stages in a fixed order, each with its own prerequisite. Learn it once and every other page is a variation.

<div className="bmoni-spine">
  <span>Lifecycle</span>
  <a data-stage="1" href="/lifecycle#1-create-the-user">User</a>
  <a data-stage="2" href="/lifecycle#2-provision-the-smart-wallet">Wallet</a>
  <a data-stage="3" href="/lifecycle#3-verify-identity-kyc">KYC</a>
  <a data-stage="4" href="/lifecycle#4-activate-the-rail">Rail</a>
  <a data-stage="5" href="/lifecycle#5-fund-the-wallet">Fund</a>
  <a data-stage="6" href="/lifecycle#6-move-money">Move money</a>
</div>

Every BMONI Embedded integration walks the same six stages in the same order. Each stage depends on the one before it, which is why a call that looks correct still fails when it runs too early. Learn the order once and the rest of these docs is detail.

| Stage                                                          | You end up with                                     |
| -------------------------------------------------------------- | --------------------------------------------------- |
| [1. Create the user](#1-create-the-user)                       | A `bmoniUserId` to scope every later call           |
| [2. Provision the smart wallet](#2-provision-the-smart-wallet) | A deployed smart wallet owned by an on-device key   |
| [3. Verify identity (KYC)](#3-verify-identity-kyc)             | A submitted, activated KYC profile                  |
| [4. Activate the rail](#4-activate-the-rail)                   | One currency reported `active` by onboarding status |
| [5. Fund the wallet](#5-fund-the-wallet)                       | A balance the user can spend                        |
| [6. Move money](#6-move-money)                                 | Swaps, withdrawals, and payouts                     |

<Note>
  Stages 3 to 6 repeat per currency. KYC data is submitted once and reused, but **activation is per-onboarding**: adding a second currency to an existing user means calling `POST /kyc/activate` again before that rail's `start-*` endpoint.
</Note>

***

## 1. Create the user

Register the person with BMONI and keep the id you get back.

<div className="bmoni-kv">
  <div className="k">Prerequisite</div>
  <div className="v">A partner API key, sent as `x-api-key` on every request.</div>
  <div className="k">You call</div>
  <div className="v">`POST /v1/users`</div>
  <div className="k">Result</div>
  <div className="v">A `bmoniUserId`. Every user-scoped endpoint takes it as a path parameter.</div>
  <div className="k">Watch out</div>
  <div className="v">Persist it. Creating a new user on each launch forks the wallet history.</div>
</div>

Full request and response shapes: [Integration flow](/api-reference/integration-flow).

## 2. Provision the smart wallet

The wallet comes before KYC. The user's device generates the owner key, proves ownership by signing a challenge, and the proxy deploys the smart wallet against that owner address.

<div className="bmoni-kv">
  <div className="k">Prerequisite</div>
  <div className="v">A `bmoniUserId`, and [`bmoni_embedded_sdk`](/sdk/introduction) initialised on-device.</div>
  <div className="k">You call</div>
  <div className="v">`POST /smart-wallets/owner-proof-challenges` → sign with the SDK → `POST /smart-wallets/create-managed`</div>
  <div className="k">Result</div>
  <div className="v">A `SmartWallet` (address, chain, currency, status).</div>
  <div className="k">Watch out</div>
  <div className="v">Smart-wallet calls take the **stablecoin** code, not the fiat one: `USDB`, `CNGN`, `CADC`, `EURe`, `GBPe`, `MEXe`.</div>
</div>

The private key never leaves the device's secure element. See [Wallet provisioning](/sdk/wallet-provisioning) and [Signing](/sdk/signing).

## 3. Verify identity (KYC)

One submission, reused across every currency the user later adds. The submit order is fixed.

<div className="bmoni-kv">
  <div className="k">Prerequisite</div>
  <div className="v">A `bmoniUserId`. Check [`GET /onboarding/status`](/api-reference/integration-flow) first — the currency may already be active.</div>
  <div className="k">You call</div>
  <div className="v">`GET /kyc/options` → document uploads → `PATCH /kyc` → `GET /kyc/readiness` → `POST /kyc/activate`</div>
  <div className="k">Result</div>
  <div className="v">An activated KYC profile, ready for a rail.</div>
  <div className="k">Watch out</div>
  <div className="v">Requirements differ by region, and so does activation: USD, EUR, and Mexico need a biometric selfie and a `sumsubLevelName`; Canada and Nigeria must omit it.</div>
</div>

Region requirements: [USD](/api-reference/kyc-usd-requirements), [Nigeria](/api-reference/kyc-nga-requirements), [Canada](/api-reference/kyc-can-requirements), [Europe](/api-reference/kyc-eur-requirements), [Mexico](/api-reference/kyc-mex-requirements), [Rest of world](/api-reference/kyc-row-requirements).

## 4. Activate the rail

A wallet exists after stage 2, but it cannot receive or send until its local rail is switched on. That is one call per currency.

<div className="bmoni-kv">
  <div className="k">Prerequisite</div>
  <div className="v">KYC activated, plus the smart wallet for that currency. USD additionally gates on `GET /kyc/usd-readiness`.</div>
  <div className="k">You call</div>
  <div className="v">`POST /onboarding/start-usa`, `start-canada`, `start-monerium`, `start-nigeria`, or for Mexico `POST /latam/mx/kyc/activate`</div>
  <div className="k">Result</div>
  <div className="v">`GET /onboarding/status` reports the currency as `active`.</div>
  <div className="k">Watch out</div>
  <div className="v">Nigeria needs a `bvn`; Mexico needs the Etherfuse agreements signed (`GET /latam/mx/kyc/launch/agreements`) before its KYC can approve — the CLABE is provisioned automatically. The body carries currency-prefixed wallet fields.</div>
</div>

Which rail exists where: [Supported regions](/api-reference/supported-regions).

## 5. Fund the wallet

How money arrives depends on the rail you activated.

<div className="bmoni-kv">
  <div className="k">Prerequisite</div>
  <div className="v">An active rail for that currency.</div>
  <div className="k">You call</div>
  <div className="v">`GET /vba/usd`, `POST /vba/eu`, `POST /vba/ngn` for virtual bank accounts; `POST /deposit/wallet` for a crypto top-up address; a SPEI transfer to the user's MXN CLABE (`GET /bank-accounts/deposit-accounts/MXN`) onramps automatically; `POST /latam/cash/orders/fund` for cash pay-in.</div>
  <div className="k">Result</div>
  <div className="v">A balance on `GET /smart-wallets/account/balances`.</div>
  <div className="k">Watch out</div>
  <div className="v">A USD virtual account is issued asynchronously. Poll `GET /vba/usd` until `status` is `active`.</div>
</div>

## 6. Move money

Swap between currencies and send money out of the wallet.

<div className="bmoni-kv">
  <div className="k">Prerequisite</div>
  <div className="v">A funded wallet.</div>
  <div className="k">You call</div>
  <div className="v">`POST /exchange/convert` to swap; `offramp/nigeria`, `/latam/mx/orders`, `/eu/orders/prepare` → sign → `/eu/orders/complete`, or `/latam/cash/orders/send` to pay out.</div>
  <div className="k">Result</div>
  <div className="v">Funds swapped, or sent to a bank account or cash pickup.</div>
  <div className="k">Watch out</div>
  <div className="v">SEPA payouts are a three-call handshake: prepare, sign on-device, complete.</div>
</div>

Rail-specific guides: [MXN on/offramp](/api-reference/mxn-ramp), [LATAM cash orders](/api-reference/latam-cash), [EU SEPA payouts](/api-reference/eu-sepa).

***

## Closing the account

Deleting a user deactivates the account rather than erasing it, and it only succeeds once every wallet is empty. For 90 days the deletion can be undone with a single call; after that only support can restore it. See [Deleting & reactivating an account](/api-reference/account-deletion).

***

## Where to go next

<CardGroup cols={2}>
  <Card title="Start from a goal" icon="bullseye" href="/use-cases">
    Pick what you are building and see which of the six stages it needs.
  </Card>

  <Card title="Full call order" icon="list-ol" href="/api-reference/integration-flow">
    Every endpoint, in sequence, with request bodies and gotchas.
  </Card>

  <Card title="No app of your own?" icon="envelope" href="/api-reference/integration-flow-no-app">
    Invite users into the BMONI app and read their accounts over the API.
  </Card>

  <Card title="Build the client" icon="mobile" href="/quickstart">
    Wire the Flutter packages: wallet, PIN, and first signature.
  </Card>
</CardGroup>
