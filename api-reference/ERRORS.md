> ## Documentation Index
> Fetch the complete documentation index at: https://bkey.mintlify.site/llms.txt
> Use this file to discover all available pages before exploring further.

# Errors and status codes

> Every error the Embedded API returns, what caused it, and what to do about it — including the failures that succeed quietly.

This page lists the errors the Embedded API returns, what each one means, and how to recover from it.

## The error shape

Every error uses the same body:

```json theme={null}
{
  "statusCode": 409,
  "message": "User already exists with this email",
  "error": "Conflict"
}
```

| Field        |                                                                 |
| ------------ | --------------------------------------------------------------- |
| `statusCode` | HTTP status, repeated in the body.                              |
| `message`    | A string, or an array of strings when request validation fails. |
| `error`      | The HTTP status name, such as `Conflict`.                       |

<Warning>
  There is no stable machine-readable error code yet. Branch on `statusCode` and, where you must distinguish two errors sharing a status, match on `message`. Treat `message` as unstable: log it, show it to your own operators, but do not parse it in a way that a wording change would break.
</Warning>

### Validation errors return an array

When a request body fails validation, `message` is an array with one entry per invalid field:

```json theme={null}
{
  "statusCode": 400,
  "message": [
    "email must be an email",
    "phoneNumber must be a valid phone number"
  ],
  "error": "Bad Request"
}
```

Handle both shapes:

```javascript theme={null}
const detail = Array.isArray(body.message) ? body.message.join('; ') : body.message
```

## Errors by status

### 400 — Bad Request

| Message                         | Cause                                                                     | What to do                                                                                                    |
| ------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `BVN must be exactly 11 digits` | The Bank Verification Number (BVN) is not 11 digits after trimming.       | Strip spaces and check the length before you call. See [Sandbox test data](/api-reference/sandbox-test-data). |
| `NIN must be exactly 11 digits` | The National Identification Number (NIN) is not 11 digits after trimming. | As above.                                                                                                     |
| An array of field messages      | One or more body fields failed validation.                                | Fix the named fields. The array is exhaustive — you do not need to retry to discover the next fault.          |

### 401 — Unauthorized

| Message                     | Cause                                                     | What to do                                                                                      |
| --------------------------- | --------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `Unauthorized`              | The `x-api-key` header is missing, malformed, or revoked. | Check the header is present and that you are using the key for the environment you are calling. |
| `Invalid webhook signature` | An inbound webhook failed signature verification.         | Verify you are computing the signature over the raw request body, before any JSON parsing.      |

### 403 — Forbidden

| Message                                | Cause                                                                | What to do                                                                                                                                              |
| -------------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `User does not belong to this partner` | The `bmoniUserId` in the path exists but belongs to another partner. | Use a `bmoniUserId` your own key created. This is the error you get from pasting an identifier out of another environment or another partner's example. |

### 404 — Not Found

| Message                             | Cause                                                                                                                       | What to do                                                                                                                                                                                                                        |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `User not found`                    | No user matches this `bmoniUserId`.                                                                                         | Confirm you stored the `bmoniUserId` from the create-user response, not your own employee identifier.                                                                                                                             |
| `requested item could not be found` | Passed through from upstream. The resource does not exist, **or** it exists but is not yet in a state this endpoint serves. | See [A 404 does not always mean missing](#a-404-does-not-always-mean-missing). From an identity look-up in the sandbox it means the number is not one of the [test personas](/api-reference/sandbox-test-data#the-test-personas). |
| `No webhook config found`           | No webhook is configured for this partner scope.                                                                            | Create one with `POST /v1/webhooks` before you expect deliveries.                                                                                                                                                                 |

### 409 — Conflict

| Message                                                                      | Cause                                                                                                                                          | What to do                                                                                                                                                                                |
| ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `User already exists with this email`                                        | A user already holds that email. The message names the field that actually collided, and lists several joined by `and` when more than one did. | Reuse the existing user rather than creating another. This is the correct response to a retry of a create that already succeeded — see [Retries and duplicates](#retries-and-duplicates). |
| `Webhook config already exists for this partner scope. Use PATCH to update.` | A webhook already exists for this scope.                                                                                                       | Use `PATCH` instead of `POST`.                                                                                                                                                            |

### 500 — Internal Server Error

A `500` here is usually an upstream error passed through unchanged rather than a fault in the proxy. The two you are most likely to meet both come from signature validation:

| Message                                | Cause                                                                                                                                                   | What to do                                                                                                                      |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `Point is not on curve`                | The bytes submitted as `signature` are not a decodable secp256k1 signature — wrong length, wrong encoding, or `r`/`s`/`v` assembled in the wrong order. | See [Why your signature is rejected](/api-reference/signing#why-your-signature-is-rejected).                                    |
| `Invalid yParityOrV`                   | The `v` byte is `0` or `1` instead of `27` or `28`.                                                                                                     | Normalise with `v = yParity + 27`. See [Why your signature is rejected](/api-reference/signing#why-your-signature-is-rejected). |
| `The current status does not allow it` | The card is in a state that does not permit the requested transition.                                                                                   | See [Card status transitions](#card-status-transitions). Do not retry unchanged — the state will not change on its own.         |

<Note>
  These are validation faults reported with a `500`. Returning `400` for a malformed signature is tracked as platform work; until it lands, treat a `500` carrying one of the messages above as a client-side bug and fix the request rather than retrying it.
</Note>

## Failures that return success

The dangerous errors are the ones that do not look like errors. Each of these returns `2xx`.

### Employment data is dropped when the occupation does not resolve

You send an `occupation` as free text. The API matches it to an occupation code, and **silently omits your employment data when no match is found**. The call returns success. Nothing in the response says the data was dropped.

Matching works as follows:

1. The API searches occupations using your `occupation` string as the search term.
2. It looks for an **active** occupation whose display name equals your string exactly, ignoring case and surrounding whitespace, or one of whose aliases does.
3. If there is no exact match but the search returned **exactly one** active result, that one is used.
4. Otherwise no code is resolved, and `employment` is not sent upstream.

So a title that returns several near-matches and matches none of them exactly — `Financial Administrator` is the recorded example — resolves to nothing and is discarded.

<Warning>
  Do not send `occupation` as free text in production. Resolve the code yourself and send `occupationCode`, which is never silently dropped.
</Warning>

```http theme={null}
GET /v1/users/{userId}/kyc/occupations?search=financial
```

Pick the entry you want from the response and submit its code:

```http theme={null}
PATCH /v1/users/{userId}/kyc
{
  "employment": {
    "employmentStatus": "employed",
    "occupationCode": "15-1252",
    "employerName": "Acme Ltd"
  }
}
```

Then confirm it stuck, rather than trusting the `2xx`:

```http theme={null}
GET /v1/users/{userId}/kyc
```

If `employment` is absent or its `occupationCode` is null, the write did not land.

## Card status transitions

`The current status does not allow it` means the card is not in a state that permits what you asked for. Retrying the same call cannot succeed — one recorded case retried four times over sixteen hours against an unchanged state.

Through the Embedded API you can set exactly two statuses — `BLOCKED` to freeze and `ACTIVE` to unfreeze:

```http theme={null}
PUT /v1/users/{userId}/cards/{cardId}/status
{
  "status": "BLOCKED"
}
```

A card also carries issuer-set statuses you can only read, such as `pending` on a card that has never been activated. Attempting a transition the issuer does not permit from the card's current state produces this error.

Read the current status before you try a transition:

```http theme={null}
GET /v1/users/{userId}/cards/{cardId}
```

The full status list, the reason there is no published transition matrix, and the `ACTIVE`-does-not-mean-activate trap are covered in [Card statuses](/api-reference/cards#card-statuses).

## A 404 does not always mean missing

`requested item could not be found` is an upstream message that covers two different situations, and the distinction matters when you are polling.

The clearest case is the proposal signing payload. `GET …/proposals/{proposalId}/sign-payload` returns `404` until the proposal reaches `PENDING_SIGNATURES`. The proposal exists; it is simply not ready to be signed.

So a `404` from `sign-payload` after you have just approved a proposal means *wait and try again*, not *the proposal is gone*. Confirm with `GET …/proposals/{proposalId}`: if that returns the proposal, keep polling `sign-payload`.

## Retries and duplicates

There are no idempotency keys on the Embedded API today. When a request times out and you did not read a response, you cannot assume it failed.

Create-user is the case that matters most, because a blind retry is what turns one intended user into two. It is protected by a uniqueness check on email, phone number, and employee identifier, so a retry of a create that already succeeded returns `409` naming the field that collided — not a second user.

Treat that `409` as **success from a previous attempt**, not as a failure:

```javascript theme={null}
const res = await createUser(payload)

if (res.status === 409) {
  // The earlier attempt landed. Recover the existing user instead of retrying.
  const existing = await findUserByEmail(payload.email)
  return existing
}
```

<Warning>
  Wallet creation has no equivalent uniqueness guard, so a blind retry there can produce a second wallet. Before you retry a wallet create that timed out, list the account's wallets and check whether the first attempt landed.
</Warning>

```http theme={null}
GET /v1/users/{userId}/smart-wallets/account/balances
```

Retry only when that shows no wallet for the currency you were creating.

<Note>
  Idempotency keys on user and wallet creation are tracked as platform work. When they ship, this section will describe them and the read-before-retry workaround above becomes unnecessary.
</Note>

## Related

* [Sign a proposal](/api-reference/signing) — the full diagnosis path for a rejected signature.
* [Sandbox test data](/api-reference/sandbox-test-data) — values that resolve, and values that fail on purpose.
* [Transfers](/api-reference/transfers) — the proposal lifecycle these errors appear in.
* [SDK error handling](/sdk/error-handling) — the equivalent surface in `bmoni_embedded_sdk`.

***

*Last reviewed: 7 August 2026.*
