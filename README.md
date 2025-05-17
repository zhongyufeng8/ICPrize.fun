icprize.fun Project Introduction

https://icprize.fun/

Backend container: dvnx6-cqaaa-aaaao-qkalq-cai
Frontend container: cehjb-2yaaa-aaaao-qkaoa-cai

ICPrize is a permissionless token incentive game built on the Internet Computer blockchain. Players can participate in betting pools using various ICP tokens with the chance to win significant rewards.

The platform operates on a simple principle: be one of the last players to place a bet before the countdown ends to win a share of the prize pool.

Prize Distribution
When a pool closes, the total prize amount is distributed as follows:

98% - Distributed equally among winning players
1% - Goes to the pool creator
1% - Goes to platform developers
Example: If a pool has "Winners" set to 100 and 100,000 people place bets before it closes, only the last 100 addresses to place a bet will share 98% of the prize pool.

Getting Started
Connect your Internet Identity wallet by clicking the "Login" button in the top-right corner
Browse available betting pools on the home page
Select from your available tokens in the "My Wallet" section
Place bets on active pools to try to be among the last players when the timer ends
Creating a Pool
To create your own pool, navigate to the "Create" page and configure the following parameters:

Winners
The number of winners who will share the prize pool (98%). Each winner's address must be among the last to place a bet before the countdown ends.

Bet Amount
The exact amount each player must bet to participate in the pool. Each bet must be exactly this amount.

Initial Funding
The starting amount for the pool, provided by the creator. The creator receives 1% of the final pool amount as a fee.

After configuring your pool, the system will automatically:

Create the pool with your specified parameters
Transfer the initial funding from your wallet
Verify and activate the pool
Token Management
ICPrize supports all ICRC-1 standard tokens on the Internet Computer blockchain.

Adding Tokens
You can add any ICP chain token to your wallet using the token's ledger canister ID.

Navigate to "My Wallet" and click "Add New Token" to enter a token's ledger canister ID (e.g., "ryjl3-tyaaa-aaaaa-aaaba-cai" for ICP).

Selecting Tokens
For better performance and user experience, you can select which tokens to display in your wallet. This is particularly useful when there are many tokens available on the system.

Time Rules
Each pool operates with a countdown timer that determines when it will close:

When a new bet is placed, the countdown resets to 60 seconds
The frontend displays 50 seconds (10 seconds less) to account for transaction confirmation time
The actual countdown is managed on-chain using blockchain timestamps
Bet timing is determined by transaction verification, not when you submit the transaction
Bets that are verified after the timer has expired will not be eligible for prizes and cannot be refunded
Important: Due to blockchain transaction times, it's recommended to place your bet well before the countdown ends to ensure it's properly verified.

Rules Summary
Each pool has a 60-second countdown that resets after each verified bet
Winners are determined by the last addresses to place bets before the timer expires
Winnings are automatically distributed to winners after the pool closes
The exact bet amount must be transferred for a bet to be valid
98% of the prize pool is shared equally among winners
1% goes to the pool creator and 1% to the platform developers
