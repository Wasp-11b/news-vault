# News Vault - Digital Newspaper/Magazine Access

A Stacks (STX) smart contract for managing subscription-based access to digital news and magazine content with recurring payment functionality.

## Overview

News Vault is a decentralized subscription service that allows users to purchase tiered access to digital content from newspapers and magazines. The contract handles subscription management, content access control, and revenue tracking entirely on-chain.

## Features

- **Multiple Subscription Tiers**: Basic, Premium, and Pro tiers with different pricing
- **Flexible Duration**: Monthly or yearly subscription options
- **Auto-Renewal**: Optional automatic subscription renewal
- **Content Access Control**: Granular access control based on subscription tier
- **Revenue Tracking**: Built-in revenue analytics for contract owners
- **Publisher Support**: Multi-publisher content management

## Subscription Tiers

| Tier | Monthly Price | Yearly Price | Access Level |
|------|---------------|--------------|--------------|
| Basic (1) | 5 STX | 50 STX | Basic content |
| Premium (2) | 10 STX | 100 STX | Premium content + Basic |
| Pro (3) | 20 STX | 200 STX | All content |

## Smart Contract Functions

### Public Functions

#### `subscribe(tier, is-yearly, auto-renew)`
Subscribe to a tier with specified duration and auto-renewal preference.
- `tier`: Subscription tier (1-3)
- `is-yearly`: Boolean for yearly vs monthly subscription
- `auto-renew`: Boolean for automatic renewal

#### `renew-subscription()`
Manually renew an existing subscription using the same terms and pricing.

#### `cancel-subscription()`
Disable auto-renewal for the current subscription (subscription remains active until expiration).

#### `add-content(content-id, required-tier, publisher)`
*Owner only* - Add new content with specified tier requirement.

#### `deactivate-content(content-id)`
*Owner only* - Deactivate content (makes it inaccessible).

#### `update-prices(tier, monthly-price, yearly-price)`
*Owner only* - Update subscription pricing for a specific tier.

#### `withdraw-revenue(amount)`
*Owner only* - Withdraw accumulated revenue from the contract.

#### `process-auto-renewal(user)`
Process auto-renewal for expired subscriptions (typically called by off-chain services).

### Read-Only Functions

#### `get-subscription-price(tier, is-yearly)`
Get the price for a specific tier and duration.

#### `has-active-subscription(user)`
Check if a user has an active (non-expired) subscription.

#### `get-user-subscription(user)`
Get complete subscription details for a user.

#### `can-access-content(user, content-id)`
Check if a user can access specific content based on their subscription.

#### `get-total-revenue()`
Get the total revenue accumulated by the contract.

## Usage Examples

### Subscribing to Premium Monthly
```clarity
;; Subscribe to Premium tier, monthly, with auto-renewal
(contract-call? .news-vault subscribe u2 false true)
```

### Adding Content
```clarity
;; Add premium article (owner only)
(contract-call? .news-vault add-content "article-123" u2 'SP1234...)
```

### Checking Access
```clarity
;; Check if user can access specific content
(contract-call? .news-vault can-access-content 'SP1234... "article-123")
```

## Technical Details

### Block Time Calculations
- Monthly subscription: 4,320 blocks (~30 days at ~10 min/block)
- Yearly subscription: 52,560 blocks (~365 days at ~10 min/block)

### Payment Flow
1. User calls `subscribe()` with desired tier and options
2. STX payment is transferred from user to contract owner
3. Subscription record is created/updated with start and end blocks
4. Revenue counter is incremented

### Access Control
Content access is determined by:
- User has active subscription (current block < end block)
- User's subscription tier >= content's required tier
- Content is marked as active

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner-only function called by non-owner |
| u101 | Requested item not found |
| u102 | Item already exists |
| u103 | Insufficient funds for payment |
| u104 | Subscription has expired |
| u105 | Invalid duration specified |

## Security Considerations

- **Owner Controls**: Contract owner has significant control over pricing, content, and revenue withdrawal
- **Auto-Renewal**: Requires off-chain monitoring service for automatic processing
- **Payment Security**: All payments are handled through native STX transfers
- **Access Validation**: Content access is validated on every request

## Deployment Requirements

1. Deploy contract to Stacks blockchain
2. Set up off-chain service for auto-renewal processing (optional)
3. Configure content publishing pipeline
4. Initialize subscription tiers and pricing

## Integration

### For Publishers
Publishers can integrate by:
1. Registering content through the `add-content` function
2. Checking user access via `can-access-content` before serving content
3. Managing content lifecycle through activation/deactivation

### For Frontend Applications
Frontend apps should:
1. Check subscription status before displaying premium content
2. Provide subscription management interface
3. Handle payment flows and error states
4. Implement content access validation
