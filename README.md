# DomiFi

## Overview

**DomiFi** is a **fractional real estate ownership platform** that allows properties to be tokenized, traded, and governed directly on the blockchain. It enables users to **purchase property-backed tokens**, **earn proportional revenue**, and **participate in decentralized governance decisions** related to property management. DomiFi transforms real estate into liquid, divisible digital assets, ensuring transparency, community governance, and automated income distribution.

## Key Features

* **Tokenized Property Ownership**: Each property is represented as a fungible asset divided into tradable tokens.
* **Automated Income Distribution**: Property-generated revenue is distributed proportionally to token holders.
* **On-chain Governance**: Token holders can create, vote on, and finalize proposals affecting property decisions.
* **Fractional Participation**: Investors can own and trade small shares of high-value properties.
* **Secure Revenue Claims**: Automated tracking ensures fair and transparent distribution of rental or dividend income.
* **Decentralized Property Management**: Owners can manage property revenue and proposals directly through smart contract functions.

## Contract Components

### Data Maps

* **`property-map`**: Stores property details including name, location, total supply, price, and status.
* **`balance-map`**: Tracks token balances for each investor across all properties.
* **`supply-map`**: Records total issued tokens per property.
* **`revenue-map`**: Maintains cumulative revenue and revenue-per-token metrics for income distribution.
* **`claim-map`**: Tracks user-specific claims to prevent double withdrawals.
* **`proposal-map`**: Contains governance proposals with voting metrics and metadata.
* **`vote-map`**: Logs each user's voting decision and token weight per proposal.

### Data Variables

* **`property-id-counter`**: Sequential ID generator for new properties.
* **`proposal-id-counter`**: Tracks the next available proposal ID per property.

### Core Functionalities

#### Property & Token Management

* **`create-property`**: Registers a new property for tokenization with supply, price, and metadata.
* **`buy-tokens`**: Enables investors to purchase fractional property tokens with STX.
* **`fetch-property`** / **`fetch-balance-info`**: Provides property and investor balance data.

#### Revenue Distribution

* **`add-revenue`**: Allows property admins to deposit revenue (e.g., rent or profit).
* **`claim-revenue`**: Lets token holders withdraw accumulated earnings based on ownership share.
* **`get-claimable`**: Calculates how much revenue a holder can currently claim.

#### Governance System

* **`create-proposal`**: Allows qualified holders to submit proposals for property-related decisions.
* **`vote`**: Enables holders to cast weighted votes using their token balance.
* **`finalize-proposal`**: Executes proposals once quorum and majority are reached.
* **`fetch-proposal`**: Retrieves details of a specific proposal.

### Read-Only Utilities

* **`fetch-count`**: Returns the total number of registered properties.
* **`fetch-balance-info`**: Displays an investor’s token balance for any property.

## Summary

**DomiFi** establishes a **decentralized framework for real estate tokenization**—combining investment accessibility, transparent governance, and automated revenue sharing. By turning properties into blockchain assets, DomiFi enables **borderless property investment**, **democratic management**, and **trustless dividend distribution**, redefining how property ownership and income generation function in a digital economy.
