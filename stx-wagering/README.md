# Sports Betting Smart Contract

## Overview
This smart contract implements a decentralized sports betting platform on the Stacks blockchain. It allows users to create betting events, place bets, and manage payouts with multiple betting mechanisms including winner-take-all, proportional, and fixed-odds betting.

## Features
- Multiple betting types support (winner-take-all, proportional, fixed-odds)
- Automated payout calculation and distribution
- Event management (creation, closure, cancellation)
- Refund mechanism for cancelled events
- Support for multiple winners
- Configurable betting options
- Time-locked events using block height
- Stake-based participation tracking

## Contract Functions

### Administrative Functions
1. `create-event`
   - Creates a new betting event
   - Parameters:
     - `event-details`: Description of the event (256 chars max)
     - `betting-options`: List of possible outcomes
     - `event-end-block`: Block height when betting closes
     - `payout-mechanism`: Betting type
     - `option-odds`: Optional odds for fixed-odds betting
   - Returns ERR_EMPTY_EVENT_DESCRIPTION if event details are empty
   - Returns ERR_INSUFFICIENT_BETTING_OPTIONS if less than 2 options provided
   - Returns ERR_INVALID_END_BLOCK if end block is not in future
   - Returns ERR_UNSUPPORTED_BET_TYPE for invalid betting type
   - Returns ERR_ODDS_REQUIRED if fixed-odds type without odds

2. `close-event`
   - Closes betting for an event
   - Can only be called by event organizer or contract administrator
   - Requires event to have reached its end block height
   - Returns ERR_NOT_AUTHORIZED if caller unauthorized
   - Returns ERR_PREMATURE_CLOSURE if called before end block

3. `resolve-event`
   - Declares winning options for an event
   - Can only be called by contract administrator
   - Supports up to 5 winning options
   - Returns ERR_NO_WINNERS_DECLARED if no winners specified
   - Returns ERR_TOO_MANY_WINNERS if more than 5 winners
   - Returns ERR_WINNER_SELECTION_INVALID for invalid selections

### User Functions
1. `place-bet`
   - Places a bet on an event
   - Parameters:
     - `event-id`: Identifier of the event
     - `chosen-option`: Selected betting option
     - `bet-amount`: Amount of STX to bet
   - Returns ERR_EVENT_NOT_FOUND if event doesn't exist
   - Returns ERR_BETTING_CLOSED if event closed
   - Returns ERR_INVALID_OPTION_SELECTION for invalid option
   - Returns ERR_INVALID_BET_AMOUNT if amount is zero

2. `claim-winnings`
   - Claims winnings for a successful bet
   - Automatically calculates payout based on betting mechanism
   - Transfers winnings to winner's address
   - Returns ERR_NOT_A_WINNING_BET if bet didn't win
   - Returns ERR_EVENT_NOT_FOUND if event doesn't exist

3. `cancel-event`
   - Cancels an event and processes refunds
   - Can only be called by event organizer
   - Must be called before event end block
   - Returns ERR_NOT_AUTHORIZED if not organizer
   - Returns ERR_REFUND_FAILED if refund fails
   - Returns ERR_REFUND_PROCESSING if refund already processing

### Read-Only Functions
1. `get-event-details`
   - Retrieves detailed information about an event

2. `get-bettor-position`
   - Retrieves information about a bettor's position in an event

3. `get-current-block-height`
   - Returns the current block height

## Betting Types

### 1. Winner-Take-All
- Total pool is divided equally among winning bets
- Suitable for events with single or multiple winners
- All winners receive equal shares regardless of stake size

### 2. Proportional
- Winnings are distributed proportionally to stake size
- Larger stakes receive larger portions of the pool
- Fair distribution based on risk taken

### 3. Fixed-Odds
- Predefined payout ratios for each betting option
- Requires odds to be set during event creation
- Payout calculated based on stake and predetermined odds

## Error Handling
The contract includes comprehensive error handling with standardized SCREAMING_SNAKE_CASE error constants:
- ERR_NOT_AUTHORIZED: Unauthorized access attempts
- ERR_EVENT_NOT_FOUND: Event doesn't exist
- ERR_BETTING_CLOSED: Event betting period ended
- ERR_BALANCE_TOO_LOW: Insufficient funds
- ERR_EVENT_ALREADY_RESOLVED: Cannot modify resolved event
- ERR_INVALID_BET_AMOUNT: Invalid betting amount
- ERR_EVENT_TIME_ELAPSED: Event time passed
- ERR_WINNER_SELECTION_INVALID: Invalid winner selection
- And other specific error conditions

## Security Features
- Time-locked events prevent premature closures
- Administrator controls for dispute resolution
- Automated refund mechanism for cancelled events
- Strict access control for sensitive operations
- Protected payout calculations
- Validation for all critical operations

## Technical Requirements
- Stacks blockchain compatibility
- Clarity smart contract language
- Block height awareness for timing mechanisms
- STX token for betting and payouts

## Usage Example
```clarity
;; Create a new betting event
(contract-call? .sports-betting create-event 
    "World Cup Final 2026" 
    (list "Team A" "Team B") 
    u100000 
    "winner-take-all" 
    none)

;; Place a bet
(contract-call? .sports-betting place-bet 
    u0  ;; event-id 
    u1  ;; chosen-option
    u1000000)  ;; bet-amount in microSTX

;; Claim winnings after event resolution
(contract-call? .sports-betting claim-winnings u0)
```

## Limitations
- Maximum of 10 betting options per event
- Maximum of 5 winning options per event
- Fixed 256-character limit for event descriptions
- Block height-based timing mechanism
- No partial refunds after betting closes

## Best Practices
1. Event Creation:
   - Set reasonable end block heights
   - Provide clear event descriptions
   - Configure appropriate betting options
   - Choose suitable payout mechanism

2. Betting:
   - Verify event details before betting
   - Check closing time (block height)
   - Confirm betting options
   - Understand payout mechanism

3. Administration:
   - Monitor event progress
   - Resolve events promptly
   - Handle disputes fairly
   - Maintain accurate records