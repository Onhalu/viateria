/** Error-class hierarchy for eToro API failures (see the API conventions). */

export class EtoroError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "EtoroError";
  }
}

/** HTTP 401 — credentials invalid. Refresh the access token once; then give up. */
export class EtoroAuthError extends EtoroError {
  constructor(message = "eToro authentication failed") {
    super(message);
    this.name = "EtoroAuthError";
  }
}

/** HTTP 403 InsufficientPermissions — e.g. demo key on a real endpoint. */
export class EtoroPermissionError extends EtoroError {
  constructor(message = "eToro insufficient permissions") {
    super(message);
    this.name = "EtoroPermissionError";
  }
}

/** HTTP 429 — rate limited. Backoff and retry at the same payload size. */
export class EtoroRateLimitError extends EtoroError {
  constructor(message = "eToro rate limit exceeded") {
    super(message);
    this.name = "EtoroRateLimitError";
  }
}

/** HTTP 413/414 — payload too large. Halve the payload and retry. */
export class EtoroPayloadTooLargeError extends EtoroError {
  constructor(message = "eToro payload too large") {
    super(message);
    this.name = "EtoroPayloadTooLargeError";
  }
}

/** HTTP 5xx — transient server error. Short exponential backoff and retry. */
export class EtoroServerError extends EtoroError {
  constructor(message = "eToro server error") {
    super(message);
    this.name = "EtoroServerError";
  }
}
